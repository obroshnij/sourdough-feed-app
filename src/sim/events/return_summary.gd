class_name ReturnSummary
extends RefCounted
## "While you were away" (game-mechanics §8, events-catalog §5, game-copy §10). Pure: built from a
## CatchUpResult. Session builds one on every launch and resume (Session.get_return_summary()) before it
## emits session_ready or resumed, so T3 reads it in that signal's handler.
##
## What T3 renders:
## - Nothing when `show` is false. `first_launch` is true on the very first launch (no save existed): run the
##   new-game start instead (Session.is_first_run()).
## - The heading `title_key` (AWAY_TITLE, or AWAY_TITLE_LONG after 3 days or more).
## - `lines`: at most 3 rows, oldest first, each a ReturnLine rendered with Keys.format(). The AWAY_CAPPED
##   row (absences past the 14-day cap, D-024) is always kept and always last, and takes one of the 3.
## - Then the "Now" row from the current snapshot (status word and hint, no new copy).
## - `prompt`: at most 1. The attention event, else the newest nudge still valid at to_unix. When it is an
##   attention event the card is skipped and the rows go at the top of its sheet (ux-design §12).
##
## Selection. Keep priority: attention > milestone > peak > hunger and hooch > other info > moments > ambient,
## newest first inside a class. Drop order is the reverse: ambient first, then same-kind lines merged (one
## hunger line: hungry_again wins over hooch_forming), then the oldest. The warning line is never dropped.
## Events that get no row and aren't the prompt are listed in `dropped`; they are already in the journal.

const MAX_LINES: int = 3
## AWAY_TITLE_LONG from 3 days away (game-copy §10).
const LONG_AWAY_S: int = 3 * 86400
## EVENT_WARNING_SIGNS_AWAY_HOURS covers 2 to 47 hours, _DAYS 2 days or more (events-catalog §3.6).
const WARNING_DAYS_FROM_H: int = 48
const WARNING_MIN_HOURS: int = 2
const PRIORITY: Dictionary[StringName, int] = {
	&"attention": 0, &"milestone": 1, &"peak": 2, &"hunger": 3, &"info": 4, &"moment": 5, &"ambient": 6,
}
## Event id to keep class (game-mechanics §8). Anything else is plain info.
const EVENT_CLASS: Dictionary[StringName, StringName] = {
	&"warning_signs": &"attention", &"mold_found": &"attention",
	&"first_rise": &"milestone", &"first_acetone": &"milestone", &"getting_stretchy": &"milestone",
	&"trait_revealed": &"milestone",
	&"peaked_while_away": &"peak", &"peak_now": &"peak",
	&"hungry_again": &"hunger", &"hooch_forming": &"hunger",
	&"big_bubble": &"ambient",
}

## Away long enough, with something that happened, to show the summary at all (AWAY_SUMMARY_MIN_S).
var show: bool = false
## The first launch ever: there is no absence to summarize.
var first_launch: bool = false
## The absence passed the 14-day catch-up cap (D-024).
var capped: bool = false
var title_key: StringName = &"AWAY_TITLE"
var lines: Array[ReturnLine] = []
## The one attention event, else the newest valid nudge, else null.
var prompt: SimEvent = null
## Not shown. Always written to the journal.
var dropped: Array[SimEvent] = []
var away_s: int = 0
var from_unix: int = 0
var to_unix: int = 0


## The first launch: nothing to show.
static func for_first_launch(at_unix: int) -> ReturnSummary:
	var s := ReturnSummary.new()
	s.first_launch = true
	s.from_unix = at_unix
	s.to_unix = at_unix
	return s


## `final_derived` is the derivation at to_unix. With it, a nudge that is already stale (its expires_if
## holds) is never the prompt.
static func build(result: CatchUpResult, final_derived: DerivedState = null) -> ReturnSummary:
	var s := ReturnSummary.new()
	s.capped = result.capped
	s.away_s = result.simulated_s
	s.from_unix = result.from_unix
	s.to_unix = result.to_unix
	s.show = result.simulated_s >= SimConstants.AWAY_SUMMARY_MIN_S \
		and (not result.events.is_empty() or not result.transitions.is_empty())
	s.title_key = &"AWAY_TITLE_LONG" if result.simulated_s >= LONG_AWAY_S or result.capped else &"AWAY_TITLE"
	# The prompt.
	var attention: SimEvent = null
	var nudge: SimEvent = null
	for e: SimEvent in result.events:
		if e.tier == &"attention":
			attention = e
		elif e.tier == &"nudge":
			if final_derived == null or not EventScheduler.is_stale(e, final_derived, result.to_unix):
				nudge = e
	s.prompt = attention if attention != null else nudge
	# Candidate rows: events first, with the hunger class merged into one row.
	var by_uid: Dictionary[int, SimEvent] = {}
	var candidates: Array[ReturnLine] = []
	var hunger: ReturnLine = null
	var unshown: Array[SimEvent] = []
	for e: SimEvent in result.events:
		by_uid[e.uid] = e
		var line: ReturnLine = _event_line(e, result.to_unix)
		if line.kind == &"hunger":
			if hunger == null:
				hunger = line
				candidates.append(line)
			elif e.id == &"hungry_again" and hunger.event_id != &"hungry_again":
				unshown.append(by_uid[hunger.event_uid])
				candidates.erase(hunger)
				hunger = line
				candidates.append(line)
			else:
				unshown.append(e)
			continue
		candidates.append(line)
	# Moments that aren't events, one row per key (the latest).
	var has_peak: bool = false
	for line: ReturnLine in candidates:
		if line.kind == &"peak":
			has_peak = true
	var moments: Dictionary[StringName, ReturnLine] = {}
	for t: Dictionary in result.transitions:
		var key: StringName = _moment_key(StringName(str(t.get("to", ""))), StringName(str(t.get("cause", ""))),
			has_peak)
		if key != &"":
			var at: int = int(DictReader.float_of(t.get("at_unix", 0)))
			moments[key] = ReturnLine.make(&"moment", key, at)
	if moments.size() == 1 and moments.has(&"AWAY_FRIDGE") and result.simulated_s >= LONG_AWAY_S:
		var rest: ReturnLine = moments[&"AWAY_FRIDGE"]
		rest.text_key = &"AWAY_LONG_REST"
	candidates.append_array(moments.values())
	# Keep the best rows, then show them oldest first.
	candidates.sort_custom(func(a: ReturnLine, b: ReturnLine) -> bool:
		var pa: int = PRIORITY.get(a.kind, 4)
		var pb: int = PRIORITY.get(b.kind, 4)
		if pa != pb:
			return pa < pb
		return a.at_unix > b.at_unix)
	var slots: int = MAX_LINES - (1 if s.capped else 0)
	var kept: Array[ReturnLine] = []
	for i: int in candidates.size():
		var line: ReturnLine = candidates[i]
		if i < slots:
			kept.append(line)
		elif line.event_uid > 0 and by_uid.has(line.event_uid):
			unshown.append(by_uid[line.event_uid])
	kept.sort_custom(func(a: ReturnLine, b: ReturnLine) -> bool: return a.at_unix < b.at_unix)
	if s.capped:
		kept.append(ReturnLine.make(&"capped", &"AWAY_CAPPED", result.to_unix))
	if kept.is_empty() and s.show:
		kept.append(ReturnLine.make(&"moment", &"AWAY_QUIET", result.to_unix))
	s.lines = kept
	for e: SimEvent in unshown:
		if e != s.prompt:
			s.dropped.append(e)
	return s


## The row for one event. Every event that can happen offline has an EVENT_<ID>_AWAY key (events-catalog §1).
static func _event_line(e: SimEvent, to_unix: int) -> ReturnLine:
	var kind: StringName = EVENT_CLASS.get(e.id, &"info")
	var line: ReturnLine = ReturnLine.make(kind, e.key_for("AWAY"), e.created_unix)
	line.event_id = e.id
	line.event_uid = e.uid
	match e.id:
		&"warning_signs":
			var began: int = e.created_unix
			if e.payload.has("began_unix"):
				began = int(DictReader.float_of(e.payload["began_unix"]))
			@warning_ignore("integer_division")
			var hours: int = maxi(to_unix - began, 0) / 3600
			if hours < WARNING_DAYS_FROM_H:
				line.text_key = &"EVENT_WARNING_SIGNS_AWAY_HOURS"
				line.args = {"hours": maxi(hours, WARNING_MIN_HOURS)}
			else:
				line.text_key = &"EVENT_WARNING_SIGNS_AWAY_DAYS"
				@warning_ignore("integer_division")
				line.args = {"days": hours / 24}
		&"peaked_while_away", &"peak_now":
			var word: String = str(e.payload.get("rise_word", ""))
			if word.is_empty():
				word = String(Inspection.peak_word(DictReader.float_of(e.payload.get("peak_rise", 0.0))))
			line.text_key = StringName("EVENT_PEAKED_WHILE_AWAY_AWAY_%s" % word)
			line.args = {"time_unix": int(DictReader.float_of(e.payload.get("time_unix", e.created_unix)))}
		_:
			line.args = DictReader.canonical_dict(e.payload)
	return line


## The AWAY_* row for entering `to_state`, or &"" when an event row covers it or nothing is worth a row.
static func _moment_key(to_state: StringName, cause: StringName, has_peak: bool) -> StringName:
	match to_state:
		&"developing", &"active", &"near_peak", &"at_peak":
			return &"" if has_peak else &"AWAY_ROSE"
		&"collapsing":
			return &"" if has_peak else &"AWAY_FELL"
		&"dormant":
			return &"AWAY_FRIDGE" if cause == &"cold" else &"AWAY_RAN_DOWN"
		&"recovering":
			return &"AWAY_RECOVERING"
	return &""

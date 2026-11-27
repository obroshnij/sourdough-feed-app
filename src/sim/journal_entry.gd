class_name JournalEntry
extends RefCounted
## One journal line (data-models.md §6). The journal outlives a starter (memorial, then a new one).
##
## Rendering (T3): the timeline line is Keys.format(text_key, args, utc_offset_s), or Session.format_text().
## The expanded view adds Keys.format(body_key(), args, ...) when body_key() isn't empty. Args that are keys
## (FLOUR_RYE) are translated, `time_unix` becomes {time}, and `start_unix` and `end_unix` become
## {start_date} and {end_date}.
##
## What the slice journal writes (mvp-scope "minimal journal"):
## - feed: JOURNAL_LOG_FEED (or _AT_PEAK, _RESCUE). A hooch entry comes just before it when hooch was poured
##   off or stirred in (JOURNAL_LOG_HOOCH_POURED or _STIRRED).
## - event: EVENT_<ID>_JOURNAL_TITLE with body EVENT_<ID>_JOURNAL_BODY. A peaked_while_away entry uses its
##   EVENT_PEAKED_WHILE_AWAY_AWAY_<WORD> line instead, so peaks read the same everywhere (events-catalog §3.2).
## - milestone: the Day one page after the first feed (JOURNAL_DAY_ONE_TITLE, body in data.body_key).
## - memorial: MEMORIAL_TITLE with {name}. The page itself reads Session.get_memorials().
## - environment, smell, inspect, rename, state_change: one log line each.

const CAP: int = 400
const KINDS: Array[StringName] = [
	&"feed", &"environment", &"smell", &"inspect", &"event", &"state_change", &"milestone", &"rename", &"memorial",
	&"hooch",
]

var uid: int = 0
var starter_id: String = ""
## Real time of the act, not grid time.
var at_unix: int = 0
var kind: StringName = &"feed"
var state_id: StringName = &""
var text_key: StringName = &""
## Primitives the UI formats into the translated text.
var args: Dictionary = {}
## Facts, for example a feed's grams, ratio and hydration.
var data: Dictionary = {}


## Appends and trims to `cap`: the oldest state_change first, then the oldest inspect or smell, then the
## oldest of any other kind. memorial and milestone entries are never dropped.
static func append_capped(list: Array[JournalEntry], entry: JournalEntry, cap: int = CAP) -> void:
	list.append(entry)
	while list.size() > cap:
		var drop: int = _first_index(list, [&"state_change"])
		if drop < 0:
			drop = _first_index(list, [&"inspect", &"smell"])
		if drop < 0:
			drop = _first_index(list, [&"feed", &"hooch", &"environment", &"event", &"rename"])
		if drop < 0:
			return
		list.remove_at(drop)


static func _first_index(list: Array[JournalEntry], kinds: Array[StringName]) -> int:
	for i: int in list.size():
		if kinds.has(list[i].kind):
			return i
	return -1


## The longer text for the expanded entry, or &"" when the entry is one line. Uses the same args.
func body_key() -> StringName:
	var explicit: String = str(data.get("body_key", ""))
	if not explicit.is_empty():
		return StringName(explicit)
	if kind == &"event":
		var event_id: String = str(data.get("event_id", ""))
		if not event_id.is_empty():
			return StringName("EVENT_%s_JOURNAL_BODY" % event_id.to_upper())
	return &""


func to_dict() -> Dictionary:
	return {
		"uid": uid, "starter_id": starter_id, "at_unix": at_unix, "kind": String(kind),
		"state_id": String(state_id), "text_key": String(text_key), "args": DictReader.canonical_dict(args),
		"data": DictReader.canonical_dict(data),
	}


static func from_dict(d: Dictionary) -> JournalEntry:
	var r := DictReader.new(d)
	var e := JournalEntry.new()
	e.uid = r.integer("uid")
	e.starter_id = r.text("starter_id")
	e.at_unix = r.integer("at_unix")
	e.kind = r.id("kind")
	e.state_id = r.id("state_id")
	e.text_key = r.id("text_key")
	e.args = DictReader.canonical_dict(r.dict("args"))
	e.data = DictReader.canonical_dict(r.dict("data"))
	if not r.ok or not KINDS.has(e.kind):
		return null
	return e

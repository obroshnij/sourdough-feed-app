class_name PlayerHistory
extends RefCounted
## Saved player counters the events and copy need (data-models.md §5, game-mechanics.md §7.5).
## Every `*_unix` field is grid-aligned sim time (a multiple of 60), so rules can compare it exactly with
## SimEvent.created_unix. 0 means "never". Fields marked "per starter" reset in `reset_for_new_starter()`.
## Fields added in Phase 3 are optional on load (DictReader.*_or), so v1 saves from Phase 2 still load.

const RECENT_FEEDS_CAP: int = 3
const DAILY_CAP: int = 14
const STRONG_VIGOR_AT_FEED: float = 0.75
## narrative.md §9.3: MEMORIAL_CAUSE_UNFED counts days unfed at temp_c >= 11 C. Fridge days don't count.
const WARM_UNFED_MIN_C: float = 11.0
const ONBOARDING_PATHS: Array[StringName] = [&"tour", &"skip"]

var consecutive_early_feeds: int = 0
## The last peak_rise from a cycle with vigor_at_feed >= 0.75 that reached at_peak (back_to_strength's
## reference). A cycle cut short by an early feed, or spent in the fridge, never peaked, so it keeps the old
## reference (t4-events' review).
var last_strong_peak_rise: float = 0.0
## Per starter. The current cycle's rise_phase has entered at_peak. Cleared by every feed.
var cycle_reached_peak: bool = false
var smelled_descriptors: Dictionary[StringName, bool] = {}
## Keys smell.<id> and inspect.<kind>.level_<n>. Meaning lines fade after 3.
var seen_counts: Dictionary[StringName, int] = {}
## Real time (action.at_unix) of the last feeds, newest last, at most 3. The feed sheet's routine hint.
var recent_feed_unix: Array[int] = []
var daily: Array[DailyBucket] = []

# --- Phase 3 (T4's event rules, the journal and the memorial) ---
## Per starter. Accepted feeds of this starter. first_rise: "after the first real-time feed".
var real_feeds: int = 0
## Per starter. Sim time of the last feed (the grid point it applied at).
var last_feed_unix: int = 0
## Per starter. Timing class of the last feed (feed_timing_class).
var last_feed_timing: StringName = &""
## Per starter. Sim time of the last feed whose class was very_late or rescue. Arms back_to_strength and
## survives the next feed, so the strong second cycle can still fire.
var last_very_late_feed_unix: int = 0
## Per starter. Sim time the jar last left the fridge while it was cold-dormant (a fridge wake). A short
## visit that never cooled it below the dormant temperature doesn't count.
var fridge_left_unix: int = 0
## Per starter. Sim time the state last left unhealthy (an accepted feed from unhealthy; only a feed exits
## it). warning_signs re-arms 24 h after this.
var unhealthy_left_unix: int = 0
## Per starter. False from the step rise_phase enters at_peak; true once any step or action in that at_peak
## phase ran in the foreground. peaked_while_away fires on leaving at_peak only if it stayed false.
var peak_seen_foreground: bool = false
## Per starter. Sim time of the latest step with rise >= peak_rise: the cycle's peak time (spec §14.1),
## the {time} of EVENT_PEAKED_WHILE_AWAY_*.
var cycle_peak_unix: int = 0
## Per starter. Times rise_phase entered at_peak (the memorial's "Peaks").
var peaks: int = 0
## Per starter. The tallest rise seen (the memorial's "Tallest rise").
var best_rise: float = 0.0
## Per starter. Seconds since the last feed spent at temp_c >= 11 C, before mold (MEMORIAL_CAUSE_UNFED).
var warm_unfed_s: int = 0
## FeedAction.to_dict() of the last accepted feed, for "feed like last time". Kept across starters
## (it is the player's habit). Empty until the first feed.
var last_feed: Dictionary = {}
## &"tour" or &"skip" from adoption until the first feed writes the Day one entry, then &"".
var onboarding_path: StringName = &""
## Real time the feed sheet last showed FEED_ROUTINE_HINT (at most once a week, game-mechanics §2.2).
var routine_hint_unix: int = 0


## game-mechanics.md §2.4: early, on_time, late, very_late, rescue, or &"" (no feed when moldy).
## Reads the derivation of the state at feed time; rise-phase rows read rise_phase, not the label.
static func feed_timing_class(d: DerivedState) -> StringName:
	match d.state:
		&"moldy":
			return &""
		&"unhealthy":
			return &"rescue"
		&"dormant", &"recovering":
			return &"very_late"
		&"hungry":
			return &"late"
	match d.rise_phase:
		&"freshly_fed", &"developing", &"active":
			return &"early"
		&"hungry":
			return &"late"
	return &"on_time"


## Called by Session after an accepted action, with the state, derivation and environment from before it.
## Every action is a foreground act, so an action during an at_peak phase means the player saw the peak.
func record_action(action: GameAction, before: StarterState, derived_before: DerivedState,
		env_before: EnvironmentState = null) -> void:
	if derived_before.rise_phase == &"at_peak":
		peak_seen_foreground = true
	if action.kind == &"environment":
		# A fridge wake: a cold-dormant jar moves out of the fridge. Without env_before (a caller that doesn't
		# track it), any move of a cold-dormant jar to a place that isn't the fridge counts.
		var move: SetEnvironmentAction = action
		var from_fridge: bool = env_before == null or env_before.location == &"fridge"
		var to_other: bool = move.env != null and move.env.location != &"fridge"
		if from_fridge and to_other and derived_before.dormant_cause == &"cold":
			fridge_left_unix = before.sim_time_unix
		return
	if action.kind != &"feed":
		return
	var feed: FeedAction = action
	var timing: StringName = feed_timing_class(derived_before)
	if timing == &"early":
		consecutive_early_feeds += 1
	else:
		consecutive_early_feeds = 0
	if before.vigor_at_feed >= STRONG_VIGOR_AT_FEED and cycle_reached_peak:
		last_strong_peak_rise = before.peak_rise
	cycle_reached_peak = false
	recent_feed_unix.append(action.at_unix)
	while recent_feed_unix.size() > RECENT_FEEDS_CAP:
		recent_feed_unix.remove_at(0)
	real_feeds += 1
	last_feed_unix = before.sim_time_unix
	last_feed_timing = timing
	if timing == &"very_late" or timing == &"rescue":
		last_very_late_feed_unix = before.sim_time_unix
	if derived_before.state == &"unhealthy":
		unhealthy_left_unix = before.sim_time_unix
	warm_unfed_s = 0
	last_feed = feed.to_dict()


## Called after every grid step (live and catch-up), before the event rules see that step.
## `prev_derived` is the derivation one step earlier; null skips the phase-entry checks.
func record_step(state: StarterState, derived: DerivedState, prev_derived: DerivedState = null,
		app_foreground: bool = false) -> void:
	if derived.rise_phase == &"at_peak":
		if prev_derived != null and prev_derived.rise_phase != &"at_peak":
			peak_seen_foreground = false
			peaks += 1
			cycle_reached_peak = true
		if app_foreground:
			peak_seen_foreground = true
	if state.rise >= state.peak_rise:
		cycle_peak_unix = state.sim_time_unix
	best_rise = maxf(best_rise, state.rise)
	if not state.moldy and state.temp_c >= WARM_UNFED_MIN_C:
		warm_unfed_s += SimConstants.GRID_S


## A new starter (adoption, or after a discard). Earned knowledge (smells, seen counts) and the feeding habit
## stay; everything about the old starter's cycles goes.
func reset_for_new_starter() -> void:
	consecutive_early_feeds = 0
	last_strong_peak_rise = 0.0
	cycle_reached_peak = false
	recent_feed_unix.clear()
	real_feeds = 0
	last_feed_unix = 0
	last_feed_timing = &""
	last_very_late_feed_unix = 0
	fridge_left_unix = 0
	unhealthy_left_unix = 0
	peak_seen_foreground = false
	cycle_peak_unix = 0
	peaks = 0
	best_rise = 0.0
	warm_unfed_s = 0
	onboarding_path = &""


## Increments and returns the new count.
func record_seen(key: StringName) -> int:
	var n: int = seen_counts.get(key, 0) + 1
	seen_counts[key] = n
	return n


func copy() -> PlayerHistory:
	var h: PlayerHistory = PlayerHistory.from_dict(to_dict())
	return h


func to_dict() -> Dictionary:
	var smelled: Dictionary = {}
	for k: StringName in smelled_descriptors:
		smelled[String(k)] = smelled_descriptors[k]
	var seen: Dictionary = {}
	for k: StringName in seen_counts:
		seen[String(k)] = seen_counts[k]
	var recent: Array = []
	for t: int in recent_feed_unix:
		recent.append(t)
	var days: Array = []
	for b: DailyBucket in daily:
		days.append(b.to_dict())
	return {
		"consecutive_early_feeds": consecutive_early_feeds,
		"last_strong_peak_rise": last_strong_peak_rise,
		"smelled_descriptors": smelled,
		"seen_counts": seen,
		"recent_feed_unix": recent,
		"daily": days,
		"real_feeds": real_feeds,
		"cycle_reached_peak": cycle_reached_peak,
		"last_feed_unix": last_feed_unix,
		"last_feed_timing": String(last_feed_timing),
		"last_very_late_feed_unix": last_very_late_feed_unix,
		"fridge_left_unix": fridge_left_unix,
		"unhealthy_left_unix": unhealthy_left_unix,
		"peak_seen_foreground": peak_seen_foreground,
		"cycle_peak_unix": cycle_peak_unix,
		"peaks": peaks,
		"best_rise": best_rise,
		"warm_unfed_s": warm_unfed_s,
		"last_feed": DictReader.canonical_dict(last_feed),
		"onboarding_path": String(onboarding_path),
		"routine_hint_unix": routine_hint_unix,
	}


static func from_dict(d: Dictionary) -> PlayerHistory:
	var r := DictReader.new(d)
	var h := PlayerHistory.new()
	h.consecutive_early_feeds = r.integer("consecutive_early_feeds")
	h.last_strong_peak_rise = r.num("last_strong_peak_rise")
	h.smelled_descriptors = r.bool_map("smelled_descriptors")
	h.seen_counts = r.int_map("seen_counts")
	for item: Variant in r.list("recent_feed_unix"):
		var t: int = typeof(item)
		if t == TYPE_INT:
			var n: int = item
			h.recent_feed_unix.append(n)
		elif t == TYPE_FLOAT:
			var x: float = item
			if x != floorf(x):
				return null
			h.recent_feed_unix.append(int(x))
		else:
			return null
	for item: Variant in r.list("daily"):
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var b: DailyBucket = DailyBucket.from_dict(item)
		if b == null:
			return null
		h.daily.append(b)
	h.real_feeds = r.integer_or("real_feeds", 0)
	h.cycle_reached_peak = r.flag_or("cycle_reached_peak", false)
	h.last_feed_unix = r.integer_or("last_feed_unix", 0)
	h.last_feed_timing = StringName(r.text_or("last_feed_timing", ""))
	h.last_very_late_feed_unix = r.integer_or("last_very_late_feed_unix", 0)
	h.fridge_left_unix = r.integer_or("fridge_left_unix", 0)
	h.unhealthy_left_unix = r.integer_or("unhealthy_left_unix", 0)
	h.peak_seen_foreground = r.flag_or("peak_seen_foreground", false)
	h.cycle_peak_unix = r.integer_or("cycle_peak_unix", 0)
	h.peaks = r.integer_or("peaks", 0)
	h.best_rise = r.num_or("best_rise", 0.0)
	h.warm_unfed_s = r.integer_or("warm_unfed_s", 0)
	h.last_feed = DictReader.canonical_dict(r.dict_or_empty("last_feed"))
	h.onboarding_path = StringName(r.text_or("onboarding_path", ""))
	h.routine_hint_unix = r.integer_or("routine_hint_unix", 0)
	if not h.onboarding_path.is_empty() and not ONBOARDING_PATHS.has(h.onboarding_path):
		return null
	return h if r.ok else null

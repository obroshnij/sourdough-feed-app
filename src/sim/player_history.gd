class_name PlayerHistory
extends RefCounted
## Saved player counters the events and copy need (data-models.md §5, game-mechanics.md §7.5).

const RECENT_FEEDS_CAP: int = 3
const DAILY_CAP: int = 14
const STRONG_VIGOR_AT_FEED: float = 0.75

var consecutive_early_feeds: int = 0
## The last peak_rise from a cycle with vigor_at_feed >= 0.75 (back_to_strength).
var last_strong_peak_rise: float = 0.0
var smelled_descriptors: Dictionary[StringName, bool] = {}
## Keys smell.<id> and inspect.<kind>.level_<n>. Meaning lines fade after 3.
var seen_counts: Dictionary[StringName, int] = {}
## Newest last, at most 3.
var recent_feed_unix: Array[int] = []
var daily: Array[DailyBucket] = []


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


## Called by Session after an accepted action, with the state and derivation from before it.
func record_action(action: GameAction, before: StarterState, derived_before: DerivedState) -> void:
	if action.kind != &"feed":
		return
	if feed_timing_class(derived_before) == &"early":
		consecutive_early_feeds += 1
	else:
		consecutive_early_feeds = 0
	if before.vigor_at_feed >= STRONG_VIGOR_AT_FEED:
		last_strong_peak_rise = before.peak_rise
	recent_feed_unix.append(action.at_unix)
	while recent_feed_unix.size() > RECENT_FEEDS_CAP:
		recent_feed_unix.remove_at(0)


## Called after every grid step (live and catch-up). Daily trait buckets are P1; nothing yet.
func record_step(_state: StarterState, _derived: DerivedState) -> void:
	pass


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
	return h if r.ok else null

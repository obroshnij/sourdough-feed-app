class_name EventLedger
extends RefCounted
## Saved event bookkeeping (data-models.md §5): cooldowns, one-time flags, daily caps, pending events.

const PENDING_CAP: int = 20

var next_uid: int = 1
var last_fired_unix: Dictionary[StringName, int] = {}
var once_flags: Dictionary[StringName, bool] = {}
## Local "YYYY-MM-DD" that day_counts belongs to.
var day_key: String = ""
## Per tier, current local day only.
var day_counts: Dictionary[StringName, int] = {}
var pending: Array[SimEvent] = []


func take_uid() -> int:
	var u: int = next_uid
	next_uid += 1
	return u


## Resets the daily counts when the local day changes.
func roll_day(key: String) -> void:
	if key != day_key:
		day_key = key
		day_counts.clear()


func count_today(tier: StringName) -> int:
	return day_counts.get(tier, 0)


## Appends, then trims to PENDING_CAP: the oldest `info` goes first, then the oldest of any tier.
func add_pending(e: SimEvent) -> void:
	pending.append(e)
	while pending.size() > PENDING_CAP:
		var drop: int = 0
		for i: int in pending.size():
			if pending[i].tier == &"info":
				drop = i
				break
		pending.remove_at(drop)


func find_pending(uid: int) -> SimEvent:
	for e: SimEvent in pending:
		if e.uid == uid:
			return e
	return null


func remove_pending(uid: int) -> void:
	for i: int in pending.size():
		if pending[i].uid == uid:
			pending.remove_at(i)
			return


func pending_attention() -> SimEvent:
	for e: SimEvent in pending:
		if e.tier == &"attention":
			return e
	return null


func copy() -> EventLedger:
	var l: EventLedger = EventLedger.from_dict(to_dict())
	return l


func to_dict() -> Dictionary:
	var fired: Dictionary = {}
	for k: StringName in last_fired_unix:
		fired[String(k)] = last_fired_unix[k]
	var once: Dictionary = {}
	for k: StringName in once_flags:
		once[String(k)] = once_flags[k]
	var counts: Dictionary = {}
	for k: StringName in day_counts:
		counts[String(k)] = day_counts[k]
	var list: Array = []
	for e: SimEvent in pending:
		list.append(e.to_dict())
	return {
		"next_uid": next_uid,
		"last_fired_unix": fired,
		"once_flags": once,
		"day_key": day_key,
		"day_counts": counts,
		"pending": list,
	}


static func from_dict(d: Dictionary) -> EventLedger:
	var r := DictReader.new(d)
	var l := EventLedger.new()
	l.next_uid = r.integer("next_uid")
	l.last_fired_unix = r.int_map("last_fired_unix")
	l.once_flags = r.bool_map("once_flags")
	l.day_key = r.text("day_key")
	l.day_counts = r.int_map("day_counts")
	for item: Variant in r.list("pending"):
		if typeof(item) != TYPE_DICTIONARY:
			return null
		var e: SimEvent = SimEvent.from_dict(item)
		if e == null:
			return null
		l.pending.append(e)
	if not r.ok:
		return null
	return l

class_name SimEvent
extends RefCounted
## One event (data-models.md §5). Text keys come from the id (events-catalog.md), never stored here.

var uid: int = 0
## Rule id, for example &"peak_now".
var id: StringName = &""
## &"info", &"nudge" or &"attention".
var tier: StringName = &"info"
## Sim time of the step that fired it.
var created_unix: int = 0
var local_minute_of_day: int = 0
## Primitives only (int, float, String, bool).
var payload: Dictionary = {}
## 0 = never.
var expires_unix: int = 0
## Condition id that drops a stale event, for example &"state_not_hungry". &"" = none.
var expires_if: StringName = &""
## Quiet-hours deferral. 0 = show at once.
var not_before_unix: int = 0
## &"pending", &"shown", &"acked" or &"expired".
var status: StringName = &"pending"


func copy() -> SimEvent:
	var e := SimEvent.new()
	e.uid = uid
	e.id = id
	e.tier = tier
	e.created_unix = created_unix
	e.local_minute_of_day = local_minute_of_day
	e.payload = payload.duplicate()
	e.expires_unix = expires_unix
	e.expires_if = expires_if
	e.not_before_unix = not_before_unix
	e.status = status
	return e


func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"id": String(id),
		"tier": String(tier),
		"created_unix": created_unix,
		"local_minute_of_day": local_minute_of_day,
		"payload": DictReader.canonical_dict(payload),
		"expires_unix": expires_unix,
		"expires_if": String(expires_if),
		"not_before_unix": not_before_unix,
		"status": String(status),
	}


static func from_dict(d: Dictionary) -> SimEvent:
	var r := DictReader.new(d)
	var e := SimEvent.new()
	e.uid = r.integer("uid")
	e.id = r.id("id")
	e.tier = r.id("tier")
	e.created_unix = r.integer("created_unix")
	e.local_minute_of_day = r.integer("local_minute_of_day")
	e.payload = DictReader.canonical_dict(r.primitives("payload"))
	e.expires_unix = r.integer("expires_unix")
	e.expires_if = r.id("expires_if")
	e.not_before_unix = r.integer("not_before_unix")
	e.status = r.id("status")
	if not r.ok or not SimConstants.TIERS.has(e.tier):
		return null
	return e

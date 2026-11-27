class_name SimEvent
extends RefCounted
## One event (data-models.md §5). Text keys come from the id (events-catalog.md), never stored here.
## How the UI shows it follows from the tier (events-catalog §1, ux-design §12): see `presentation()`.
## Payload conventions (agreed with T4): `time_unix` (sim time, int) fills {time}; warning_signs has
## `began_unix`; peaked_while_away has `peak_rise` (float) and `rise_word` (SMALL, NEAR, DOUBLE, BIG).
## After a load, floats in the payload are D-040 hex strings: read them with DictReader.float_of().

## info: a toast live, or a line in the return summary. No buttons. Session releases it once and drops it
## from the pending list, so the UI never acknowledges a toast.
const PRESENT_TOAST: StringName = &"toast"
## nudge: a card above the action bar with one action and a dismiss. Pending until acknowledged.
const PRESENT_CARD: StringName = &"card"
## attention: a half sheet that must be acknowledged. Pending until acknowledged; never more than 1.
const PRESENT_SHEET: StringName = &"sheet"

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


## PRESENT_TOAST, PRESENT_CARD or PRESENT_SHEET, from the tier.
func presentation() -> StringName:
	match tier:
		&"attention":
			return PRESENT_SHEET
		&"nudge":
			return PRESENT_CARD
	return PRESENT_TOAST


## The events-catalog key for one part of this event, for example key_for("TOAST") is EVENT_FIRST_RISE_TOAST.
## Parts: TOAST, TITLE, BODY, BTN, DISMISS, AWAY, JOURNAL_TITLE, JOURNAL_BODY (and event-specific ones).
func key_for(part: String) -> StringName:
	return StringName("EVENT_%s_%s" % [String(id).to_upper(), part])


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

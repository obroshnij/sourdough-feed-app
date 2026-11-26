class_name AckEventAction
extends GameAction
## Acknowledge a pending event, optionally with a choice (data-models.md §4).
## Session checks the uid against the ledger; `validate` alone can't see the ledger.

var event_uid: int = 0
var choice: StringName = &""


func _init(uid: int = 0, choice_id: StringName = &"") -> void:
	kind = &"ack_event"
	event_uid = uid
	choice = choice_id


func validate(_state: StarterState, _env: EnvironmentState, _catalog: SimCatalog) -> StringName:
	return &"" if event_uid > 0 else REASON_EVENT


func to_dict() -> Dictionary:
	return {"kind": "ack_event", "event_uid": event_uid, "choice": String(choice)}

class_name DiscardStarterAction
extends GameAction
## Discard a moldy starter: memorial, then a new starter (data-models.md §4, D-002). Only when moldy.

var new_name: String = ""


func _init(name_text: String = "") -> void:
	kind = &"discard_starter"
	new_name = name_text


func validate(state: StarterState, _env: EnvironmentState, _catalog: SimCatalog) -> StringName:
	if not state.moldy:
		return REASON_NOT_MOLDY
	return &"" if valid_name(new_name) else REASON_NAME


func to_dict() -> Dictionary:
	return {"kind": "discard_starter", "new_name": new_name.strip_edges()}

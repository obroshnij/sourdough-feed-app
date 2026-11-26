class_name RenameAction
extends GameAction
## Rename the starter (data-models.md §4). 1 to 24 characters after trimming.

var new_name: String = ""


func _init(name_text: String = "") -> void:
	kind = &"rename"
	new_name = name_text


func validate(_state: StarterState, _env: EnvironmentState, _catalog: SimCatalog) -> StringName:
	return &"" if valid_name(new_name) else REASON_NAME


func to_dict() -> Dictionary:
	return {"kind": "rename", "new_name": new_name.strip_edges()}

class_name InspectAction
extends GameAction
## Inspect one aspect (data-models.md §4). Changes no sim variable; the readout is in ActionResult.readout.

## One of SimConstants.INSPECT_KINDS.
var inspect_kind: StringName = &"height"


func _init(kind_id: StringName = &"height") -> void:
	kind = &"inspect"
	inspect_kind = kind_id


func validate(_state: StarterState, _env: EnvironmentState, _catalog: SimCatalog) -> StringName:
	return &"" if SimConstants.INSPECT_KINDS.has(inspect_kind) else REASON_INSPECT_KIND


func to_dict() -> Dictionary:
	return {"kind": "inspect", "inspect_kind": String(inspect_kind)}

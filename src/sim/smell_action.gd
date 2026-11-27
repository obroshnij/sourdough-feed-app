class_name SmellAction
extends GameAction
## Smell the starter (data-models.md §4). Changes no sim variable; the readout is in ActionResult.readout.
## Refused while moldy (D-043, game-mechanics §1): the UI shows the "Best not" card instead
## (SMELL_MOLDY_*, AC-08.5), and the sim never produces a smell readout for a moldy starter.


func _init() -> void:
	kind = &"smell"


func validate(state: StarterState, _env: EnvironmentState, _catalog: SimCatalog) -> StringName:
	return REASON_MOLDY_LOCKED if state.moldy else &""

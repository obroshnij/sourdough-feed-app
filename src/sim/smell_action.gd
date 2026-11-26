class_name SmellAction
extends GameAction
## Smell the starter (data-models.md §4). Changes no sim variable; the readout is in ActionResult.readout.


func _init() -> void:
	kind = &"smell"

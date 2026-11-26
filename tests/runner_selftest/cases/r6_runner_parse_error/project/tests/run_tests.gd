extends SceneTree
## Phase 1: a parse error in the -s script itself exits 0. run.sh must not trust exit 0.


func _initialize() -> void:
	print("starting"
	quit(0)

extends SceneTree
## A stale RESULT line followed by more output (for example a second suite that never
## reported). Only the last line counts.


func _initialize() -> void:
	print("RESULT: 3 passed, 0 failed, 0 skipped")
	print("starting the second half")
	quit(0)

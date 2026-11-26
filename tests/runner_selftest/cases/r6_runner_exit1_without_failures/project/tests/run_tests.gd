extends SceneTree
## A crash or engine abort after a clean RESULT line. run.sh must also read the exit code.


func _initialize() -> void:
	print("RESULT: 3 passed, 0 failed, 0 skipped")
	quit(1)

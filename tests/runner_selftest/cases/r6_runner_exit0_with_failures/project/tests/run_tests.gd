extends SceneTree
## A runner bug that reports a failure but exits 0. run.sh must read the RESULT line too.


func _initialize() -> void:
	print("RESULT: 3 passed, 1 failed, 0 skipped")
	quit(0)

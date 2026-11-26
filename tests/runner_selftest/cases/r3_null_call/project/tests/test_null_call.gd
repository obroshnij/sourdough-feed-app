extends TestCase
## Phase 1 false pass: a null call aborts the function, call() returns null, and the run
## continues to quit(0). The check before it passed, so only the Logger can see this.

var _missing: Object = null


func test_null_call_after_a_passing_check() -> void:
	check(true, "this check passes")
	_missing.call(&"anything")
	check(true, "never reached")

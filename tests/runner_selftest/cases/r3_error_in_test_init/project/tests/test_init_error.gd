extends TestCase
## Phase 1: a runtime error in the -s script's _init hangs. In a test file's _init the
## object is still created, so the runner must fail the file instead of running its tests.

var _missing: Object = null


func _init() -> void:
	_missing.call(&"anything")


func test_would_pass() -> void:
	check(true, "must not count: the file's setup failed")

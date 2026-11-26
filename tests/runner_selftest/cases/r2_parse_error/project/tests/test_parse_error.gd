extends TestCase
## Phase 1 false pass: a parse error exits 0 under -s. Must be reported as a failure.


func test_never_runs() -> void:
	check(true, "unreachable"

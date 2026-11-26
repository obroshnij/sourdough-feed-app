extends TestCase
## R-4: a test with zero checks fails. An early return or a stubbed body can't pass.


func test_does_nothing() -> void:
	var total: int = 1 + 1
	if total == 2:
		return
	check(false, "unreachable")

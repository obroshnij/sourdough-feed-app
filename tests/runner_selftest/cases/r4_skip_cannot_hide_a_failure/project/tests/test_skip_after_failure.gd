extends TestCase
## A failure recorded before a skip still fails the test.


func test_fails_then_skips() -> void:
	check(false, "this failed before the skip")
	skip("trying to hide it")

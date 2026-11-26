extends TestCase
## With --strict (RUN_STRICT=1), the phase exit gate, a skip fails the run.


func test_waits() -> void:
	skip("waits on purpose")

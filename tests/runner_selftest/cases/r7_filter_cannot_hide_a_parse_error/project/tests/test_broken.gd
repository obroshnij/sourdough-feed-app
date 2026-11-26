extends TestCase
## Every test file is loaded before filtering, so a filter never hides a broken file.


func test_broken() -> void:
	check(true, "unreachable"

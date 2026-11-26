extends TestCase
## Excluded by --filter, so its failure must not run.


func test_would_fail() -> void:
	check(false, "the filter should have excluded this")

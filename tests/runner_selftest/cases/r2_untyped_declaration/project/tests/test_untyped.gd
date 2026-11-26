extends TestCase
## Phase 1 false pass: an untyped declaration with untyped_declaration=2 exits 0 under -s.

var count = 0


func test_counts() -> void:
	check(count == 0, "would pass if the file loaded")

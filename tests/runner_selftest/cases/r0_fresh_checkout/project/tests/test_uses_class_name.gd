extends TestCase
## Phase 1: on a fresh checkout (no .godot/), class_name types don't resolve under -s.
## With R-0's --import this passes. Without it, the file can't compile.


func test_class_name_resolves() -> void:
	check_eq(SelftestHelper.value(), 1, "SelftestHelper.value()")

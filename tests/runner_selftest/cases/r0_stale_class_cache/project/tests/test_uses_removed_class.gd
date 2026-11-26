extends TestCase
## Stale .godot/ (R-9): the class cache still maps StaleHelper to src/stale_helper.gd, so
## without --import this compiles and passes against code that no longer declares the class.
## With R-0's --import the cache is rebuilt and the file correctly fails to compile.


func test_removed_class_still_resolves() -> void:
	check_eq(StaleHelper.value(), 1, "StaleHelper.value()")

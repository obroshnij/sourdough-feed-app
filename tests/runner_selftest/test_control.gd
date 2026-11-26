extends TestCase
## Copied into every self-test case that has no `no_control` file, so a case that fails
## does so for its own reason, never because nothing passed.


func test_control_passes() -> void:
	check(true, "control")
	check_eq(2 + 2, 4, "control arithmetic")

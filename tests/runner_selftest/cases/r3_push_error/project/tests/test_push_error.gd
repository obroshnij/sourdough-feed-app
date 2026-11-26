extends TestCase
## push_error() fails a test (R-3). expect_error() lets one through and fails if it never comes.


func test_push_error_fails() -> void:
	check(true, "this check passes")
	push_error("boom from a test")


func test_expected_error_is_allowed() -> void:
	expect_error("an expected boom")
	push_error("an expected boom")
	check(true, "the declared error doesn't fail the test")


func test_expected_error_that_never_comes() -> void:
	expect_error("this never happens")
	check(true, "but the declared error is missing")

extends TestCase
## Phase 1: a failed assert() in a called function aborts it and the run carries on.
## Tests must never rely on assert() (stripped in release), but if one fires, it fails.


func test_assert_false() -> void:
	check(true, "this check passes")
	assert(false, "assert in a test")

extends TestCase
## require() runs a test once T1 lists the milestone, and skips it with a reason before.


func test_runs_when_landed() -> void:
	if not require(&"m2_sim"):
		return
	check(true, "ran because m2_sim is in Milestones.LANDED")


func test_skips_until_landed() -> void:
	if not require(&"m4_save"):
		return
	check(false, "must not run: m4_save is not in Milestones.LANDED")

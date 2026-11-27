extends SliceCase
## AC-09 (offline progression) through the real Session: an absence of any length equals the same
## time with the app open, capped at 14 days and then held; the time-lapse frames stay within 30 and
## end on the jar the player sees; a clock set back holds the starter and an action during the hold
## applies at the anchor. CLK-01 to CLK-05, 08, 11, 12, 14, 16 and 17 live in tests/clock/.
## Planned until T1's contracts land: AC-09.2 to 09.4 (the return summary), the summary's long-absence
## line, and events inside the window (CLK-08's second half).

## AC-09.1's absences, in seconds.
const AWAY: Array[int] = [
	60, 59 * 60, 60 * 60, 8 * 3600, 25 * 3600, 3 * 86400, 7 * 86400, 13 * 86400, 14 * 86400, 30 * 86400,
]


## AC-09.1: fed at T0, then away for each absence. The launch simulates min(away, 14 d), and the
## starter, environment and state journal equal one phone that stayed open the whole time (ticking
## irregularly, then hourly). Past 14 days the state is the 14-day state, held, with the clock moved
## to now. Same seed, so the same feed draw.
func test_ac_09_1_any_absence_equals_the_app_left_open() -> void:
	if not ready_for_integration():
		return
	var rng_seed: int = 21
	var open: SliceHarness = mature_phone("open", rng_seed)
	check(open.apply(feed_111()).ok, "open: fed")
	var expected: Dictionary[int, Array] = {}
	var played: int = 0
	for away: int in AWAY:
		var target: int = mini(away, CAP_S)
		if target > played:
			var irregular: int = clampi(25 * HOUR - played, 0, target - played)
			open.play_irregular(irregular)
			open.play(target - played - irregular, HOUR)
			played = target
		expected[away] = [open.session.get_starter().to_dict(), open.session.get_environment().to_dict(),
			_state_log(open)]
	for away: int in AWAY:
		var shut: SliceHarness = mature_phone("away_%d" % away, rng_seed)
		check(shut.apply(feed_111()).ok, "%d s: fed" % away)
		shut.reopen_at(T0 + away)
		var r: CatchUpResult = shut.session.get_last_catch_up()
		check_eq(r.simulated_s, mini(away, CAP_S), "%d s: simulated_s" % away)
		check_eq(r.capped, away > CAP_S, "%d s: capped" % away)
		var want_starter: Dictionary = (expected[away][0] as Dictionary).duplicate()
		if away > CAP_S:
			want_starter["sim_time_unix"] = Sim.grid(T0 + away)
		check_eq(shut.session.get_starter().to_dict(), want_starter, "%d s: starter equals the open phone" % away)
		check_eq(shut.session.get_environment().to_dict(), expected[away][1], "%d s: environment" % away)
		check_eq(_state_log(shut), expected[away][2], "%d s: the same state changes, at the same times" % away)
		shut.kill()


## AC-09.5 (sim side): every launch's time-lapse has at most 30 frames, at least 1 when time passed,
## none when nothing did, and its last frame is the jar the player sees.
func test_ac_09_5_time_lapse_frames_are_bounded_and_end_on_the_jar() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("frames", 21)
	h.apply(feed_111())
	var at: int = T0
	for away: int in [0, 60, 59 * 60, 25 * 3600, 3 * 86400, 30 * 86400]:
		at += away
		h.reopen_at(at)
		var r: CatchUpResult = h.session.get_last_catch_up()
		var n: int = r.snapshots.size()
		if r.steps == 0:
			check_eq(n, 0, "no time passed: no frames")
			continue
		check_between(n, 1, CatchUpResult.MAX_SNAPSHOTS, "%d s away: frame count" % away)
		check_eq(n, mini(r.steps, CatchUpResult.MAX_SNAPSHOTS), "%d s away: as many frames as allowed" % away)
		check_eq(r.snapshots[n - 1].to_dict(), h.session.get_visuals().to_dict(), "%d s away: the last frame is the jar" % away)


## AC-09 clock rollback with an action: the clock goes back 1 h (inside the 6 h hold). Nothing is
## simulated, the anchor holds, a feed during the hold applies at the anchor exactly once, and the
## starter only ages again once the wall clock passes the anchor. No step is repeated.
func test_ac_09_clock_back_holds_and_a_feed_applies_at_the_anchor() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("rollback", 23)
	h.play(2 * HOUR)
	var anchor: int = T0 + 2 * HOUR
	h.reopen_at(T0 + HOUR)
	var r: CatchUpResult = h.session.get_last_catch_up()
	check(r.steps == 0 and not r.reanchored, "1 h back: held, not re-anchored")
	check_eq(h.session.get_starter().sim_time_unix, anchor, "the anchor holds")
	var fed: ActionResult = h.apply(feed_111())
	check(fed.ok, "a feed during the hold is accepted")
	check_eq(h.session.get_starter().sim_time_unix, anchor, "it applies at the anchor")
	check_eq(h.session.get_starter().since_feed_s, 0.0, "since_feed_s is 0")
	h.play(HOUR)
	check_eq(h.session.get_starter().sim_time_unix, anchor, "no step while the wall clock is behind the anchor")
	h.play(HOUR)
	check_eq(h.session.get_starter().since_feed_s, float(HOUR), "then it ages with the wall clock")
	check_eq(h.journal_of(&"feed").size(), 1, "exactly one feed")
	h.reopen_at(T0 + 3 * HOUR)
	check_eq(h.session.get_last_catch_up().steps, 0, "a relaunch at the same moment repeats nothing")


## AC-09 big jump: the clock jumps 40 days ahead while the app is closed, then is corrected. The jump is
## credited at most 14 days (then held), the correction re-anchors once without rewinding, and the
## feed made in between is kept (EC-12).
func test_ac_09_big_jump_then_correction_keeps_actions() -> void:
	if not ready_for_integration():
		return
	var h: SliceHarness = mature_phone("jump", 25)
	h.reopen_at(T0 + 40 * DAY)
	var jump: CatchUpResult = h.session.get_last_catch_up()
	check(jump.capped and jump.simulated_s == CAP_S, "40 days: 14 simulated, capped")
	var moldy_or_not: StringName = h.state()
	h.apply(InspectAction.new(&"height"))
	h.reopen_at(T0 + HOUR)
	var back: CatchUpResult = h.session.get_last_catch_up()
	check(back.reanchored and back.steps == 0, "corrected: re-anchored, nothing simulated")
	check_eq(h.state(), moldy_or_not, "the corrected clock rewinds nothing")
	check_eq(h.journal_of(&"inspect").size(), 1, "the inspect made in the future is kept")
	check_eq(int(h.disk_meta().get("clock_reanchors", 0)), 1, "one re-anchor recorded")


# ------------------------------------------------------------------ helpers

## [state_id, at_unix] for every state_change entry, in order.
func _state_log(h: SliceHarness) -> Array:
	var out: Array = []
	for e: JournalEntry in h.journal_of(&"state_change"):
		out.append([String(e.state_id), e.at_unix])
	return out

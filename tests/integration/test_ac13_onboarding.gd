extends SliceCase
## Phase 4, AC-13.5, AC-13.6, AC-13.7 (the save part) and AC-13.8, through the real Session: the onboarding
## seam that exists before T1's Phase 4 contracts (Demo, Session.adopt_starter, AdoptStarterAction).
## The B1 start state is a stand-in until T1 names its preset (see tests/scenario/test_ac13_demo.gd).

const OFF_GRID_S: int = 37


func test_ac_13_5_the_demo_never_touches_the_clock_or_the_save() -> void:
	if not require(&"p3_contracts"):
		return
	var h: SliceHarness = phone("ac13_5", T0 + OFF_GRID_S)
	var s: GameSession = h.launch()
	if not check(s.is_first_run(), "a first launch has no name yet"):
		return
	var saved: PackedByteArray = h.bytes_of(SaveStore.FILE_MAIN)
	var env: EnvironmentState = EnvironmentState.at_location(&"counter")
	var b1: StarterState = _b1()
	Demo.run(b1, env, 400)
	var peak: StarterState = Demo.run_to_peak(b1, env)
	check_eq(s.now_unix(), h.clock.now_unix(), "the demo never moves the session clock")
	check_eq(s.get_debug_time_scale(), 1.0, "no time scale")
	check(not s.is_time_traveling(), "no time travel")
	check(h.bytes_of(SaveStore.FILE_MAIN) == saved, "the save on disk is byte-identical after the demo")
	# Killed before the name: two days later onboarding starts over, and the adopted starter is fresh.
	h.kill()
	h.clock.set_now(T0 + OFF_GRID_S + 2 * DAY)
	s = h.launch()
	check(s.is_first_run(), "still no name after the relaunch, so onboarding starts again")
	s.adopt_starter(peak, SliceHarness.STARTER_NAME)
	# EC-26 (QA finding, 2026-11-27, sent to T1): today the 2 unnamed days leave 5 journal entries
	# (collapsing, hungry, peaked_while_away, hungry_again, hooch_forming) and a pending hungry_again after
	# naming, and the relaunch builds a return summary. The commit that fixes it adds those checks here.
	var st: StarterState = h.disk_starter()
	check_eq(st.sim_time_unix, Sim.grid(h.clock.now_unix()), "adopted at grid(now), not 2 days back")
	check_eq(StateDeriver.derive(st, s.get_environment()).rise_phase, &"at_peak", "fresh at its peak")
	check_eq(st.name, SliceHarness.STARTER_NAME, "named")


func test_ac_13_6_adopting_the_demo_saves_at_grid_now_with_no_time_travel() -> void:
	if not require(&"p3_contracts"):
		return
	var h: SliceHarness = phone("ac13_6", T0 + OFF_GRID_S)
	var s: GameSession = h.launch()
	var peak: StarterState = Demo.run_to_peak(_b1(), EnvironmentState.at_location(&"counter"))
	var saves_before: int = int(h.disk_meta().get("save_count", 0))
	s.adopt_starter(peak, " %s " % SliceHarness.STARTER_NAME)
	var st: StarterState = h.disk_starter()
	var meta: Dictionary = h.disk_meta()
	check_eq(int(meta.get("save_count", 0)), saves_before + 1, "naming writes one save")
	check_eq(st.sim_time_unix, Sim.grid(T0 + OFF_GRID_S), "sim_time_unix = grid(now)")
	check_eq(st.name, SliceHarness.STARTER_NAME, "the name is trimmed")
	check_close(st.maturity, 0.2, 0.0, 1e-9, "maturity 0.2")
	check_eq(s.get_environment().location, &"counter", "at the counter")
	check_eq(StateDeriver.derive(st, s.get_environment()).rise_phase, &"at_peak", "at its peak")
	check(not s.is_time_traveling(), "no time travel")
	check(not s.is_first_run(), "named")
	var reanchors: int = int(meta.get("clock_reanchors", 0))
	s = h.reopen_at(T0 + OFF_GRID_S + MIN)
	check_eq(s.get_last_catch_up().steps, 1, "a relaunch 60 s later catches up exactly 1 step")
	check_eq(int(h.disk_meta().get("clock_reanchors", 0)), reanchors, "and never re-anchors")


func test_ac_13_7_and_13_8_each_path_writes_one_day_one_entry() -> void:
	if not require(&"p3_contracts"):
		return
	for path: StringName in [&"tour", &"skip"]:
		var h: SliceHarness = phone("ac13_8_" + String(path))
		var s: GameSession = h.launch()
		if path == &"tour":
			s.adopt_starter(Demo.run_to_peak(_b1(), EnvironmentState.at_location(&"counter")), SliceHarness.STARTER_NAME)
		else:
			check(h.apply(AdoptStarterAction.new(SliceHarness.STARTER_NAME, &"skip")).ok, "skip adopts")
		h.play(MIN)
		var first: ActionResult = h.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
		check(first.ok, "%s: the B7 feed applies" % path)
		check_eq(String(first.journal_entry.data.get("timing", "")), "on_time",
			"%s: the B7 feed lands at the peak (game-mechanics §8.1)" % path)
		h.play(HOUR)
		h.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
		var day_one: Array[JournalEntry] = []
		for e: JournalEntry in h.journal_of(&"milestone"):
			if String(e.data.get("milestone", "")) == "day_one":
				day_one.append(e)
		if check_eq(day_one.size(), 1, "%s: exactly one day-one entry after two feeds" % path):
			var want: String = "JOURNAL_DAY_ONE_BODY" if path == &"tour" else "JOURNAL_DAY_ONE_SKIP_BODY"
			check_eq(String(day_one[0].data.get("body_key", "")), want, "%s: its body" % path)
			check_eq(String(day_one[0].args.get("name", "")), SliceHarness.STARTER_NAME, "%s: with the name" % path)


func _b1() -> StarterState:
	var s: StarterState = SimFixtures.young()
	SimFixtures.feed_ratio(s)
	# The B1 feed adds about 0.008 maturity; StarterPresets resets it, so the tour and skip paths both start
	# at 0.2 (game-mechanics §8.2). T1's B1 preset must do the same (AC-13.6, AC-13.7).
	s.maturity = StarterPresets.PRESET_MATURITY
	return s

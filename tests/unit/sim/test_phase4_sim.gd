extends TestCase
## Phase 4 contracts on the pure sim side (D-059): hydration presets, the onboarding demo, traits, unlocks, the
## empty jar, the warning-signs forecast, T4's feed reference, the smell check, rye cracks and the step-rule
## filter. Owner: T1.

const T0: int = 1795651200
const H: int = 3600


func _counter() -> EnvironmentState:
	return EnvironmentState.at_location(&"counter")


func _fed_mature() -> StarterState:
	var s: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(s)
	s.sim_time_unix = T0
	return s


func test_hydration_presets_keep_about_150_g() -> void:
	if not require(&"p4_contracts"):
		return
	# QA's AC-14.1 table: [f, hydration, kept, flour, water].
	var rows: Array = [
		[1.0, 60.0, 58.0, 58.0, 34.8], [2.0, 60.0, 36.0, 72.0, 43.2], [5.0, 60.0, 17.0, 85.0, 50.0],
		[1.0, 125.0, 46.0, 46.0, 57.5], [2.0, 125.0, 27.0, 54.0, 67.5], [5.0, 125.0, 12.0, 60.0, 75.0],
	]
	var s: StarterState = SimFixtures.mature()
	for row: Array in rows:
		var f: float = row[0]
		var h: float = row[1]
		var a: FeedAction = FeedAction.from_preset(f, &"rye", h)
		var tag: String = "1:%d at %d%%" % [roundi(f), roundi(h)]
		check_close(a.kept_g, row[2], 0.0, 0.001, tag + " kept")
		check_close(a.flour_total_g(), row[3], 0.0, 0.001, tag + " flour")
		check_close(a.water_g, row[4], 0.0, 0.001, tag + " water")
		check_eq(a.validate(s, _counter(), null), &"", tag + " is accepted")
	for f: float in [1.0, 2.0, 5.0]:
		var std: FeedAction = FeedAction.from_preset(f, &"white_bread", 100.0)
		var old: FeedAction = FeedAction.from_ratio(f, f, &"white_bread")
		check_eq(std.journal_facts(), old.journal_facts(), "100%% equals the slice's from_ratio at 1:%d" % roundi(f))
	check_eq(FeedPlanner.HYDRATION_IDS.size(), 3, "three presets")
	check_eq(FeedPlanner.HYDRATION_PRESETS[&"stiff"], 60.0, "stiff 60")
	check_eq(FeedPlanner.HYDRATION_PRESETS[&"loose"], 125.0, "loose 125")


func test_planner_feeds_at_the_chosen_hydration() -> void:
	if not require(&"p4_contracts"):
		return
	var s: StarterState = Demo.run_to_peak(_fed_mature(), _counter())
	for h: float in [60.0, 100.0, 125.0]:
		for answer: StringName in FeedPlanner.ANSWERS:
			var p: FeedPreview = FeedPlanner.plan(s, _counter(), PlayerHistory.new(), answer, &"whole_wheat",
				&"pour_off", T0, 0, h)
			check_eq(p.reason_key, &"", "%s at %d%% is accepted" % [answer, roundi(h)])
			check_between(p.action.hydration_pct(), h - 2.0, h + 2.0, "%s feeds at about %d%%" % [answer, roundi(h)])
			check(p.forecast.has_window, "%s at %d%% has a forecast" % [answer, roundi(h)])


func test_demo_runs_the_rise_phases_to_the_new_game_starter() -> void:
	if not require(&"p4_contracts"):
		return
	var start: StarterState = Demo.start_state(T0)
	var env: EnvironmentState = StarterPresets.environment_for(&"demo_start", T0)
	check_eq(StateDeriver.derive(start, env).state, &"freshly_fed", "B1: just mixed")
	check_eq(SmellModel.read(start, env).primary, &"wet_flour", "B3: it smells of wet flour")
	check_eq(Inspection.read(start, env, &"bubbles").observations, [&"few_tiny"] as Array[StringName],
		"B5: few, tiny bubbles")
	var s: StarterState = start.copy()
	var res: CatchUpResult = Demo.playback(s, env)
	var seen: Array[StringName] = []
	for k: TimeLapseKeyframe in res.keyframes:
		if seen.is_empty() or seen[-1] != k.state:
			seen.append(k.state)
	check_eq(seen, [&"freshly_fed", &"developing", &"active", &"near_peak", &"at_peak"] as Array[StringName],
		"B6 passes every rise phase in order")
	check_eq(StateDeriver.derive(s, env).rise_phase, &"at_peak", "it stops at the peak")
	check(res.keyframes.size() > CatchUpResult.MAX_KEYFRAMES, "many frames (%d)" % res.keyframes.size())
	check_eq(res.time_lapse_duration_s(), Demo.DURATION_S, "the demo's own length")
	check_between(Demo.DURATION_S, 90.0, 120.0, "BT-12: 90 to 120 s")
	check_between(float(res.simulated_s) / H, 5.5, 8.0, "a young starter peaks in about 6.7 h (%.2f h)"
		% (float(res.simulated_s) / H))
	var game: StarterState = StarterPresets.make(&"new_game", T0)
	var a: Dictionary = s.to_dict()
	var b: Dictionary = game.to_dict()
	for k: String in ["sim_time_unix", "born_unix"]:
		a.erase(k)
		b.erase(k)
	check_eq(a, b, "the demo's end equals the new_game preset, so tour and skip adopt the same starter")


func test_trait_scores_reveal_and_tie_break() -> void:
	if not require(&"p4_contracts"):
		return
	check_eq(Traits.leader([]), &"resilient", "an empty ring falls to the tie-break order")
	var warm: Array[DailyBucket] = []
	for i: int in 3:
		var b := DailyBucket.new()
		b.day_key = "2026-12-0%d" % (i + 1)
		b.hours = 24.0
		b.hours_warm = 16.0
		warm.append(b)
	check_eq(Traits.leader(warm), &"energetic", "two thirds of the hours warm")
	var slow: Array[DailyBucket] = []
	for i: int in 4:
		var b := DailyBucket.new()
		b.hours = 24.0
		b.feeds = 1
		b.ratio_sum = 5.0
		slow.append(b)
	check_eq(Traits.leader(slow), &"patient", "once a day at 1:5:5")
	var busy: Array[DailyBucket] = []
	for i: int in 10:
		var b := DailyBucket.new()
		b.hours = 24.0
		b.feeds = 2
		b.ratio_sum = 3.0
		busy.append(b)
	check_eq(Traits.leader(busy), &"energetic", "twice a day at 1:1:1 or 1:2:2 on 10 days")
	busy[0].changes = 9
	busy[1].comebacks = 2
	check_eq(Traits.leader(busy), &"sensitive", "9 changes beat the rest")
	busy[2].comebacks = 4
	check_eq(Traits.leader(busy), &"resilient", "6 comebacks lead")
	# The reveal: the feed that brings maturity to steady.
	var h := PlayerHistory.new()
	h.daily = slow
	var before: StarterState = _fed_mature()
	before.maturity = 0.329
	var after: StarterState = before.copy()
	after.maturity = 0.331
	var d: DerivedState = StateDeriver.derive(before, _counter())
	h.record_action(FeedAction.from_ratio(5.0, 5.0, &"white_bread"), before, d, _counter(), after)
	check_eq(h.dominant_trait, &"patient", "revealed at steady")
	check_eq(h.trait_since_unix, before.sim_time_unix, "at the feed's grid time")
	check(h.past_traits.is_empty(), "a reveal, not a drift")
	var again: PlayerHistory = PlayerHistory.from_dict(h.to_dict())
	check(again != null and again.dominant_trait == &"patient", "the trait survives a save")
	h.reset_for_new_starter()
	check_eq(h.dominant_trait, &"", "a new starter has no trait yet")


func test_trait_drift_needs_14_days_and_28_since_the_change() -> void:
	if not require(&"p4_contracts"):
		return
	var h := PlayerHistory.new()
	var counter: EnvironmentState = _counter()
	var sill: EnvironmentState = EnvironmentState.at_location(&"window_sill")
	var warm: EnvironmentState = EnvironmentState.at_location(&"warm_spot")
	var s: StarterState = _fed_mature()
	var d: DerivedState = StateDeriver.derive(s, counter)
	h.dominant_trait = &"patient"
	h.trait_since_unix = T0
	var drift_day: int = -1
	for day: int in 40:
		for hour: int in 24:
			s.sim_time_unix = T0 + day * 86400 + hour * H
			h.record_step(s, d, d, false, 0, warm)
		if h.dominant_trait == &"energetic" and drift_day < 0:
			drift_day = day
	check_eq(drift_day, 28, "energetic leads from day 1, but the change waits for 28 days since the reveal")
	check_eq(h.past_traits, [&"patient"] as Array[StringName], "the old trait is remembered")
	check_eq(h.trait_since_unix, T0 + 28 * 86400, "dated to the day roll")
	# Warm and cool hours follow the place, never the starter's lagging temp_c (spec §14.2).
	var g := PlayerHistory.new()
	var lag: StarterState = _fed_mature()
	lag.temp_c = 23.99999999999984
	g.record_step(lag, d, d, false, 0, EnvironmentState.at_location(&"proofing_box"))
	lag.sim_time_unix += 60
	lag.temp_c = 18.00000000000016
	g.record_step(lag, d, d, false, 0, sill)
	check_close(g.daily[-1].hours_warm, PlayerHistory.STEP_H, 0.0, 1e-12, "a 26 C box counts warm")
	check_close(g.daily[-1].hours_cool, PlayerHistory.STEP_H, 0.0, 1e-12, "the 18 C sill counts cool")
	check_close(g.daily[-1].hours, 2.0 * PlayerHistory.STEP_H, 0.0, 1e-12, "both count as hours")


func test_unlocks_follow_progression_and_outlive_the_starter() -> void:
	if not require(&"p4_contracts"):
		return
	var none: Dictionary[StringName, int] = {}
	check(Unlocks.is_open(none, &"white_bread") and Unlocks.is_open(none, &"fridge"), "the base set is open")
	check(not Unlocks.is_open(none, &"rye") and not Unlocks.is_open(none, &"consistency"), "P1 is earned")
	check_eq(Unlocks.due(none, 0.2, false, false), [] as Array[StringName], "a young starter, nothing yet")
	check_eq(Unlocks.due(none, 0.2, true, false), [&"whole_wheat"] as Array[StringName], "the first peak")
	check_eq(Unlocks.due(none, 0.2, false, true), [&"window_sill"] as Array[StringName], "a fridge wake")
	check_eq(Unlocks.due(none, 0.33, false, false),
		[&"window_sill", &"rye", &"hydration", &"consistency", &"development"] as Array[StringName], "steady")
	check_eq(Unlocks.due(none, 0.5, true, false).size(), Unlocks.EARNED.size(), "mature opens the rest")
	check_eq(Unlocks.toast_key(&"development"), &"UNLOCK_INSPECT_TOAST", "the inspect kinds share a line")
	check_eq(Unlocks.body_key(&"proofing_box"), &"UNLOCK_PROOFING_BOX_BODY", "body key")
	var h := PlayerHistory.new()
	var s: StarterState = _fed_mature()
	s.maturity = 0.4
	h.record_action(FeedAction.from_ratio(1.0, 1.0, &"white_bread"), s, StateDeriver.derive(s, _counter()),
		_counter(), s)
	check(h.unlocks.has(&"rye") and not h.unlocks.has(&"spelt"), "steady after a feed")
	check_eq(h.take_new_unlocks(), [&"window_sill", &"rye", &"hydration", &"consistency", &"development"]
		as Array[StringName], "the new ones, once")
	check(h.take_new_unlocks().is_empty(), "taken")
	h.reset_for_new_starter()
	check(h.unlocks.has(&"rye"), "a new starter keeps them")
	var skip := PlayerHistory.new()
	skip.open_all_unlocks(T0)
	check_eq(skip.unlocks.size(), Unlocks.EARNED.size(), "the skip path opens everything")
	check(skip.take_new_unlocks().is_empty(), "without journal lines")
	check_eq(PlayerHistory.from_dict(skip.to_dict()).unlocks.size(), Unlocks.EARNED.size(), "saved")


func test_empty_jar_is_a_real_state() -> void:
	if not require(&"p4_contracts"):
		return
	var e: StarterState = StarterState.make_empty(T0 + 17)
	check(e.empty and e.id.is_empty() and e.name.is_empty(), "no starter")
	check_eq(e.sim_time_unix, T0, "on the grid")
	check(e.to_dict().get("empty", false), "saved as empty")
	check(not _fed_mature().to_dict().has("empty"), "a starter's save has no new key (v1 saves unchanged)")
	var back: StarterState = StarterState.from_dict(e.to_dict())
	check(back != null and back.empty, "round trip")
	check(e.copy().empty, "copy keeps it")
	var res: CatchUpResult = CatchUp.run(e, _counter(), PlayerHistory.new(), EventLedger.new(),
		SimCatalog.builtin(), T0 + 5 * 86400, 0, false)
	check_eq(res.steps, 0, "nothing is stepped")
	check(res.events.is_empty() and res.keyframes.is_empty(), "no events, no time-lapse")
	check_eq(e.sim_time_unix, T0 + 5 * 86400, "but time passes")
	check_eq(VisualMapper.from_state(e, _counter()).level_m, 0.0, "the jar shows nothing")
	var snap: StarterSnapshot = StarterSnapshot.make(e, DerivedState.new(), _counter())
	check(snap.empty_jar and not snap.can_feed and snap.state == &"", "the HUD knows")
	check_eq(DiscardStarterAction.to_empty_jar().validate(e, _counter(), null), GameAction.REASON_NOT_MOLDY,
		"nothing to discard")
	check_eq(StartAgainAction.new("Juniper").validate(e, _counter(), null), &"", "start again is open")
	check_eq(StartAgainAction.new(" ").validate(e, _counter(), null), GameAction.REASON_NAME, "needs a name")
	check_eq(StartAgainAction.new("Juniper").validate(_fed_mature(), _counter(), null), GameAction.REASON_NOT_EMPTY,
		"not on a full jar")
	check_eq(AdoptStarterAction.new("Juniper").validate(e, _counter(), null), GameAction.REASON_EMPTY_JAR,
		"adoption is the new-game start, not this")


func test_warning_signs_forecast_matches_v9_and_skips_the_fridge() -> void:
	if not require(&"p4_contracts"):
		return
	var s: StarterState = _fed_mature()
	var t: int = Forecast.warning_signs_after_s(s, _counter())
	check_between(float(t) / H, 103.7, 111.3, "V9: unhealthy 104 to 111 h unfed at the counter (%.2f h)"
		% (float(t) / H))
	check_eq(Forecast.warning_signs_after_s(s, EnvironmentState.at_location(&"fridge")), -1,
		"the fridge never gets there in 14 days")
	var warned: StarterState = s.copy()
	warned.mold_risk = 0.5
	check_eq(Forecast.warning_signs_after_s(warned, _counter()), 0, "already there")
	warned.moldy = true
	check_eq(Forecast.warning_signs_after_s(warned, _counter()), -1, "moldy: no forecast")
	check_eq(Forecast.warning_signs_after_s(StarterState.make_empty(T0), _counter()), -1, "empty: no forecast")


func test_feed_reference_is_the_counter_peak_of_the_same_feed() -> void:
	if not require(&"p4_contracts"):
		return
	var s: StarterState = _fed_mature()
	var ref: int = Forecast.reference_at_peak_s(s)
	var f: PeakForecast = Forecast.peak_window(s, _counter())
	check_between(float(ref), f.at_peak_start_min_s - 60.0, f.at_peak_start_max_s + 60.0,
		"inside the counter forecast's at_peak window")
	var warm: StarterState = s.copy()
	warm.temp_c = 26.0
	check_eq(Forecast.reference_at_peak_s(warm), ref, "temp_c is set to 22 for the reference")
	var h := PlayerHistory.new()
	var before: StarterState = Demo.run_to_peak(_fed_mature(), _counter())
	var after: StarterState = before.copy()
	SimFixtures.feed_ratio(after)
	h.record_action(FeedAction.from_ratio(1.0, 1.0, &"white_bread"), before, StateDeriver.derive(before, _counter()),
		_counter(), after)
	check_eq(h.feed_ref_at_peak_s, Forecast.reference_at_peak_s(after), "recorded on the feed")
	h.reset_for_new_starter()
	check_eq(h.feed_ref_at_peak_s, -1, "per starter")


func test_smell_check_offers_the_surface_when_unsure() -> void:
	if not require(&"p4_contracts"):
		return
	var s: StarterState = _fed_mature()
	check_eq(SmellModel.read(s, _counter()).check, &"", "fresh feed: wet flour, nothing to check")
	var watch: StarterState = s.copy()
	watch.mold_risk = 0.35
	check_eq(SmellModel.read(watch, _counter()).check, &"musty", "musty: inspect the surface")
	var moldy: StarterState = s.copy()
	moldy.moldy = true
	moldy.mold_risk = 1.0
	check_eq(SmellModel.read(moldy, _counter()).check, &"", "moldy: the discard flow, not a check")
	# V7's fridge stay: whenever the check says faint, every non-musty smell is under 0.30.
	var fridge: EnvironmentState = EnvironmentState.at_location(&"fridge")
	var cold: StarterState = s.copy()
	var faint: int = 0
	for hour: int in 14 * 24:
		for i: int in 60:
			Sim.step(cold, fridge)
		var r: SmellReadout = SmellModel.read(cold, fridge)
		if r.check != &"faint":
			continue
		faint += 1
		for id: StringName in r.intensities:
			if id != &"musty" and r.intensities[id] >= SimConstants.SMELL_FAINT_MAX:
				fail("faint at %d h with %s at %.2f" % [hour, id, r.intensities[id]])
		if r.faint_cause != &"cold":
			fail("the fridge's faint cause is cold, got %s at %d h" % [r.faint_cause, hour])
	check(faint > 0, "a cold jar reads faint at some point (%d hours)" % faint)


func test_surface_from_the_watch_stage_is_a_warning() -> void:
	if not require(&"p4_contracts"):
		return
	var s: StarterState = _fed_mature()
	var counter: EnvironmentState = _counter()
	while s.mold_risk < SimConstants.MOLD_WATCH:
		Sim.step(s, counter)
	check(s.mold_risk < SimConstants.MOLD_WARN, "the watch stage, not yet unhealthy")
	var r: InspectionReadout = Inspection.read(s, counter, &"surface")
	check(r.is_warning, "a warning")
	check_eq(r.meaning_key, &"INSPECT_SURFACE_UNHEALTHY_MEAN", "the warning meaning")


func test_rye_cracks_show_exactly_when_the_text_says_so() -> void:
	if not require(&"p4_contracts"):
		return
	var shown: int = 0
	var listed: int = 0
	for share: float in [0.3, 0.5, 0.6, 1.0]:
		for place: StringName in [&"counter", &"warm_spot", &"window_sill"]:
			var env: EnvironmentState = EnvironmentState.at_location(place)
			var s: StarterState = SimFixtures.mature()
			var mix: Dictionary = {&"rye": 50.0 * share}
			if share < 1.0:
				mix[&"white_bread"] = 50.0 * (1.0 - share)
			for i: int in 3:
				Sim.feed(s, 50.0, mix, 50.0, 0.5, false)
				for k: int in 720:
					Sim.step(s, env)
			Sim.feed(s, 50.0, mix, 50.0, 0.5, false)
			for k: int in 72 * 60:
				Sim.step(s, env)
				if k % 10 != 0:
					continue
				var d: DerivedState = StateDeriver.derive(s, env)
				var cracked: bool = Inspection.read(s, env, &"surface").observations.any(
					func(o: StringName) -> bool: return o == &"cracked" or o == &"sunken_cracked")
				var crack: float = VisualMapper.from_derived(s, env, d).crack
				if crack > 0.0:
					shown += 1
				if cracked:
					listed += 1
				if (crack > 0.0) != cracked:
					fail("rye %.1f at %s, %d min: crack %.3f, text cracked %s" % [share, place, k, crack, cracked])
					return
	check(shown > 0 and shown == listed, "cracks shown on %d samples, all with the text" % shown)
	var collapsing: bool = false
	var s2: StarterState = SimFixtures.mature()
	for i: int in 4:
		Sim.feed(s2, 50.0, {&"rye": 50.0}, 50.0, 0.5, false)
		for k: int in 720:
			Sim.step(s2, _counter())
			var d2: DerivedState = StateDeriver.derive(s2, _counter())
			if i == 3 and d2.rise_phase == &"collapsing" and Inspection.shows_cracks(s2, d2):
				collapsing = true
				check(Inspection.read(s2, _counter(), &"surface").observations.has(&"sunken_cracked"),
					"a collapsing rye top is sunken and cracked")
				break
	check(collapsing, "rye keeps its cracks into the collapse")


func test_consistency_reads_pasty_for_rye() -> void:
	if not require(&"p4_contracts"):
		return
	var s: StarterState = SimFixtures.mature()
	for i: int in 4:
		SimFixtures.feed_ratio(s, 1.0, 1.0, &"rye")
		for k: int in 720:
			Sim.step(s, _counter())
	SimFixtures.feed_ratio(s, 1.0, 1.0, &"rye")
	var seen: bool = false
	for k: int in 10 * 60:
		Sim.step(s, _counter())
		var d: DerivedState = StateDeriver.derive(s, _counter())
		if d.rise_phase == &"active" or d.rise_phase == &"at_peak":
			var r: InspectionReadout = Inspection.read(s, _counter(), &"consistency")
			check_eq(r.observations, [&"airy_pasty"] as Array[StringName], "rye is airy but pasty")
			check_eq(r.level, 3, "at the airy level")
			seen = true
			break
	check(seen, "reached a rising phase")


func test_step_registry_skips_action_only_and_foreground_only_rules() -> void:
	if not require(&"p4_contracts"):
		return
	var all: Array[EventRule] = EventRules.registry()
	var front: Array[EventRule] = EventRules.step_registry(true)
	var back: Array[EventRule] = EventRules.step_registry(false)
	check(back.size() <= front.size() and front.size() <= all.size(), "filters only remove")
	var last: int = -1
	for rule: EventRule in front:
		check(rule.on_steps, "%s runs on steps" % rule.id)
		var at: int = all.find(rule)
		check(at > last, "%s keeps registry order" % rule.id)
		last = at
	for rule: EventRule in back:
		check(rule.on_steps and rule.background, "%s runs in the background" % rule.id)
	for rule: EventRule in all:
		if rule.on_steps and rule.background:
			check(back.has(rule), "%s is not dropped" % rule.id)

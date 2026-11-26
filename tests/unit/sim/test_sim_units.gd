extends SimVectorCase
## Pure sim unit tests (test-plan.md §2.1): temperature response, the spec §7 step procedure, feed math,
## the one RNG draw, derivation precedence, smell safety, inspection keys, VisualMapper rules, presets,
## the derived discard and the forecast. Owner: T1.

const T_ROWS: Array[float] = [4.0, 10.0, 14.0, 18.0, 22.0, 24.0, 26.0, 28.0, 32.0, 36.0]
const PHI_Y: Array[float] = [0.0, 0.03, 0.23, 0.53, 0.82, 0.93, 0.99, 0.99, 0.73, 0.0]
const PHI_L: Array[float] = [0.001, 0.09, 0.22, 0.40, 0.60, 0.71, 0.81, 0.90, 1.00, 0.89]
const FERM: Array[float] = [0.07, 0.26, 0.44, 0.66, 0.89, 1.00, 1.11, 1.20, 1.34, 1.33]
const DEC: Array[float] = [0.21, 0.33, 0.45, 0.62, 0.85, 1.00, 1.17, 1.37, 1.88, 2.32]
## art-direction.md §8 max change per 60 s step (PROP-10).
const MAX_DELTA: Dictionary = {
	&"rise": 0.02, &"dome": 0.03, &"lumps": 0.03, &"bubble_density": 0.03, &"bubble_size": 0.02,
	&"activity": 0.05, &"streak_amount": 0.05, &"hooch_depth": 0.02, &"surface_dryness": 0.02,
	&"sheen": 0.03, &"dullness": 0.02,
}


func test_temperature_response_matches_spec_table() -> void:
	if not require(&"m2_sim"):
		return
	for i: int in T_ROWS.size():
		var t: float = T_ROWS[i]
		check_close(Sim.ctmi(t, 8.0, 27.0, 36.0), PHI_Y[i], 0.0, 0.0051, "phi_y(%s)" % t)
		check_close(Sim.ctmi(t, 3.5, 32.5, 41.0), PHI_L[i], 0.0, 0.0051, "phi_l(%s)" % t)
		check_close(Sim.ferm(t), FERM[i], 0.0, 0.0051, "ferm(%s)" % t)
		if t <= 34.0:
			check_close(Sim.dec(t), DEC[i], 0.0, 0.0051, "dec(%s)" % t)
	# Spec §3's table prints dec(36) = 2.32, but its formula and the reference give 2.2^1.2 x 9/11 = 2.108
	# (2.32 matches 9/10). The formula is the oracle; the table row is reported to sourdough-scientist.
	check_close(Sim.dec(36.0), pow(2.2, 1.2) * 9.0 / 11.0, 1e-12, 0.0, "dec(36) by the spec formula")
	for t: int in 41:
		var x: float = float(t)
		check(Sim.mold_t(x) >= 0.0 and Sim.dec(x) > 0.0 and Sim.ferm(x) >= 0.0, "finite, non-negative at %d C" % t)
	check_close(Sim.dec(40.0), 1.6, 0.0, 0.01, "dec(40) about 1.6")


func test_step_follows_spec_order() -> void:
	if not require(&"m2_sim"):
		return
	var env: EnvironmentState = env_at(30.0)
	var s: StarterState = fed(SimFixtures.mature())
	for i: int in 90:
		Sim.step(s, env)
	var before: StarterState = s.copy()
	var r: SimRates = Sim.rates(before, env)
	var dt_h: float = 60.0 / 3600.0
	Sim.step(s, env)
	# 2 to 4: every rate from the start-of-step state, then clamp
	check_eq(s.food, clampf(before.food + r.food * dt_h, 0.0, 1.0), "food from start-of-step rate")
	check_eq(s.yeast, clampf(before.yeast + r.yeast * dt_h, 0.001, 1.5), "yeast from start-of-step rate")
	check_eq(s.acid, clampf(before.acid + r.acid * dt_h, 0.0, 1.0), "acid from start-of-step rate")
	check_eq(s.rise, clampf(before.rise + r.rise * dt_h, 1.0, 3.0), "rise from start-of-step rate")
	# 6: peak_rise from the new rise, peak_rate from the pre-clamp rate
	check_eq(s.peak_rise, maxf(before.peak_rise, s.rise), "peak_rise from the new rise")
	check_eq(s.peak_rate, maxf(before.peak_rate, r.rise), "peak_rate from the step-2 rate")
	# 7: the temperature lag uses the start-of-step temp_c and a 1.5 h time constant
	check_eq(s.temp_c, before.temp_c + (30.0 - before.temp_c) * (1.0 - exp(-dt_h / 1.5)), "temperature lag")
	# 8: the clock
	check_eq(s.since_feed_s, before.since_feed_s + 60.0, "since_feed_s += 60")
	check_eq(s.sim_time_unix, before.sim_time_unix + 60, "sim_time_unix += 60")


func test_temperature_lag_has_no_overshoot() -> void:
	if not require(&"m2_sim"):
		return
	var s: StarterState = SimFixtures.mature()
	s.temp_c = 4.0
	var env: EnvironmentState = counter()
	var last: float = s.temp_c
	for i: int in 6 * 60:
		Sim.step(s, env)
		if i % 30 == 0:
			check(s.temp_c >= last and s.temp_c <= 22.0, "warms monotonically toward 22 C")
		last = s.temp_c
	# 4 time constants leave 18 * e^-4 = 0.33 C to go.
	check_close(s.temp_c, 22.0 - 18.0 * exp(-4.0), 1e-9, 0.0, "exponential approach with a 1.5 h constant")


func test_moldy_step_moves_only_the_clock() -> void:
	if not require(&"m2_sim"):
		return
	var s: StarterState = SimFixtures.mature()
	s.moldy = true
	var before: Dictionary = s.to_dict()
	Sim.step(s, env_at(35.0))
	var after: Dictionary = s.to_dict()
	for k: String in before:
		if k == "since_feed_s" or k == "sim_time_unix":
			continue
		check_eq(JSON.stringify(after[k]), JSON.stringify(before[k]), "moldy step leaves %s" % k)
	check_eq(s.since_feed_s, float(before["since_feed_s"]) + 60.0, "moldy step still counts time")


func test_feed_is_a_dilution() -> void:
	if not require(&"m2_sim"):
		return
	var m: StarterState = SimFixtures.mature()
	m.mold_risk = 0.4
	m.dryness = 0.5
	m.hooch = 0.3
	var s: StarterState = m.copy()
	check(Sim.feed(s, 50.0, {&"white_bread": 50.0}, 50.0, 0.25, false), "feed accepted")
	var p: float = 50.0 / 150.0
	check_eq(s.yeast, maxf(0.001, m.yeast * p), "yeast diluted")
	check_eq(s.lab, maxf(0.001, m.lab * p), "lab diluted")
	check_eq(s.acid, m.acid * p, "acid diluted")
	check_close(s.mold_risk, 0.4 * 0.3, 1e-12, 0.0, "mold_risk x 0.3")
	check(s.starved_h == 0.0 and s.dryness == 0.0 and s.hooch == 0.0, "starved_h, dryness and hooch reset")
	check(s.rise == 1.0 and s.peak_rise == 1.0 and s.peak_rate == 0.0, "rise and peaks reset")
	check_eq(s.mass_g, 150.0, "mass is the total")
	check_close(s.feed_jitter, 0.975, 1e-12, 0.0, "feed_jitter = 0.95 + 0.10 x feed_u")
	check_close(s.culture_hydration, 100.0, 1e-12, 0.0, "1:1:1 at 100% keeps 100% hydration")
	var rye: StarterState = m.copy()
	Sim.feed(rye, 50.0, {&"rye": 50.0}, 50.0, 0.5, false)
	check_eq(rye.flour_mix.keys(), [&"rye", &"white_bread"], "flour_mix keys sorted")
	check_close(rye.flour_mix[&"rye"] + rye.flour_mix[&"white_bread"], 1.0, 1e-12, 0.0, "shares sum to 1")


func test_apply_feed_draws_exactly_once() -> void:
	if not require(&"m2_sim"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var twin := RandomNumberGenerator.new()
	twin.seed = 12345
	var s: StarterState = SimFixtures.mature()
	var feed: FeedAction = FeedAction.from_ratio(1.0, 1.0, &"white_bread")
	check(Sim.apply_feed(s, feed, rng), "feed applied")
	var u: float = twin.randf()
	check_eq(s.feed_u, u, "feed_u is the one draw")
	check_eq(rng.state, twin.state, "exactly one draw")
	s.moldy = true
	var state_before: int = rng.state
	check(not Sim.apply_feed(s, feed, rng), "moldy refuses the feed")
	check_eq(rng.state, state_before, "a refused feed draws nothing")


func test_state_precedence() -> void:
	if not require(&"m2_sim"):
		return
	var env: EnvironmentState = counter()
	var s: StarterState = SimFixtures.mature()
	s.moldy = true
	s.mold_risk = 1.0
	check_eq(StateDeriver.derive(s, env).state, &"moldy", "moldy wins")
	s.moldy = false
	s.mold_risk = 0.6
	s.starved_h = 80.0
	s.temp_c = 4.0
	check_eq(StateDeriver.derive(s, env).state, &"unhealthy", "unhealthy over dormant")
	s.mold_risk = 0.0
	var d: DerivedState = StateDeriver.derive(s, env)
	check(d.state == &"dormant" and d.dormant_cause == &"cold", "dormant, cold wins over starved")
	s.temp_c = 22.0
	d = StateDeriver.derive(s, env)
	check(d.state == &"dormant" and d.dormant_cause == &"starved", "dormant from starvation")
	var h: StarterState = advance(fed(SimFixtures.mature()), 24.0, env)
	h.vigor = 0.5
	check_eq(StateDeriver.derive(h, env).state, &"hungry", "hungry over recovering")
	var r: StarterState = fed(SimFixtures.mature())
	r.vigor_at_feed = 0.7
	d = StateDeriver.derive(r, env)
	check(d.state == &"recovering" and d.rise_phase == &"freshly_fed", "recovering keeps its rise phase")
	check(StateDeriver.derive(fed(SimFixtures.mature()), env).state == &"freshly_fed", "a fed mature starter is freshly_fed")


func test_smell_safety_rules() -> void:
	if not require(&"m2_sim"):
		return
	var env: EnvironmentState = counter()
	var moldy: StarterState = SimFixtures.mature()
	moldy.moldy = true
	var r: SmellReadout = SmellModel.read(moldy, env)
	check(r.primary == &"musty" and r.secondary.is_empty() and r.is_warning, "moldy smells of musty only")
	var watch: StarterState = advance(fed(SimFixtures.mature()), 80.0, env)
	check(watch.mold_risk >= 0.3, "80 h unfed reaches the watch stage")
	var w: SmellReadout = SmellModel.read(watch, env)
	check(w.primary == &"musty" and w.is_warning, "musty is listed first from the watch stage")
	check_eq(SmellModel.read(watch, env).primary, w.primary, "the same state gives the same smell")
	var cold: StarterState = watch.copy()
	cold.temp_c = 2.0
	check_eq(SmellModel.read(cold, env).primary, &"musty", "musty is never hidden by cold damping")
	check_eq(SmellModel.intensity_word(0.36), &"clear", "intensity words")


func test_inspection_keys_exist_in_catalog() -> void:
	if not require(&"m2_sim"):
		return
	var keys: Dictionary = _catalog_keys()
	check(keys.size() > 600, "catalog read")
	var env: EnvironmentState = counter()
	var states: Array[StarterState] = []
	var s: StarterState = fed(SimFixtures.mature())
	for h: int in 260:
		if h % 4 == 0:
			states.append(s.copy())
		s = advance(s, 1.0, env)
	states.append(s)
	var cold: StarterState = advance(fed(SimFixtures.mature()), 72.0, fridge())
	states.append(cold)
	states.append(trace(fed(cold), 12.0, counter()).end)
	var weak: StarterState = SimFixtures.mature()
	weak.vigor = 0.5
	states.append(weak)
	for fl: StringName in [&"rye", &"whole_wheat", &"spelt"]:
		states.append(StarterPresets.make(&"new_game", 0))
		var at_peak: StarterState = trace(fed(converted(SimFixtures.mature(), fl), 1, 1, fl), 5.4, counter()).end
		states.append(at_peak)
	var stiff: StarterState = converted(SimFixtures.mature(), &"white_bread", 60.0)
	states.append(stiff)
	states.append(advance(stiff, 80.0, counter()))
	var missing: Dictionary = {}
	for x: StarterState in states:
		for kind: StringName in SimConstants.INSPECT_KINDS:
			var r: InspectionReadout = Inspection.read(x, env, kind)
			for k: StringName in [r.text_key, r.meaning_key]:
				if not keys.has(String(k)):
					missing[k] = true
	check(missing.is_empty(), "inspection keys missing from src/i18n/en.csv: %s" % [missing.keys()])


func test_visual_mapper_rules() -> void:
	if not require(&"m2_sim"):
		return
	var env: EnvironmentState = counter()
	var s: StarterState = fed(SimFixtures.mature())
	var prev: VisualParams = VisualMapper.from_state(s, env)
	var worst: Dictionary = {}
	for i: int in 9 * 24 * 60:
		Sim.step(s, env)
		var v: VisualParams = VisualMapper.from_state(s, env)
		if not s.moldy:
			if v.mold != 0.0:
				fail("mold is %s while not moldy" % v.mold)
			if v.peak_line < prev.peak_line:
				fail("peak_line decreased within a cycle")
			for f: StringName in MAX_DELTA:
				var delta: float = absf(float(v.get(f)) - float(prev.get(f)))
				worst[f] = maxf(float(worst.get(f, 0.0)), delta)
		for u: StringName in VisualParams.UNIFORMS:
			if u != &"tint" and u != &"time_override" and u != &"level_m" and u != &"rise" and u != &"peak_line":
				var x: float = v.get(u)
				if x < -1.0 or x > 1.0:
					fail("%s out of range: %s" % [u, x])
		prev = v
	check(s.moldy, "9 days unfed at the counter ends moldy")
	check_eq(VisualMapper.from_state(s, env).mold, VisualMapper.MOLD_SHOWN, "moldy shows mold")
	for f: StringName in MAX_DELTA:
		check(float(worst.get(f, 0.0)) <= float(MAX_DELTA[f]), "%s max step %s <= %s" % [f, worst.get(f, 0.0), MAX_DELTA[f]])


func test_presets() -> void:
	if not require(&"m2_sim"):
		return
	var now: int = 1795651234
	var env: EnvironmentState = counter()
	for id: StringName in [&"new_game", &"restart"]:
		var s: StarterState = StarterPresets.make(id, now)
		var d: DerivedState = StateDeriver.derive(s, env)
		check(d.rise_phase == &"at_peak" and d.state == &"at_peak", "%s starts at_peak, got %s" % [id, d.state])
		check_eq(s.maturity, 0.2, "%s maturity 0.2" % id)
		check_eq(s.sim_time_unix, Sim.grid(now), "%s anchored at grid(now)" % id)
		check_eq(s.born_unix, now, "%s born now" % id)
	var fr: StarterState = StarterPresets.make(&"first_restart", now)
	var fd: DerivedState = StateDeriver.derive(fr, env)
	check(fd.state == &"dormant" and fd.dormant_cause == &"cold", "first_restart is cold dormant")
	check(fr.temp_c < 4.5, "first_restart just out of the fridge, temp_c %s" % fr.temp_c)
	check_eq(StarterPresets.make(&"new_game", now + 7).to_dict(), StarterPresets.make(&"new_game", now + 7).to_dict(), "presets are deterministic")


func test_derived_discard_presets() -> void:
	if not require(&"m2_sim"):
		return
	var rows: Array = [[1.0, 50.0, 50.0, 50.0], [2.0, 30.0, 60.0, 60.0], [5.0, 14.0, 70.0, 70.0]]
	var mature: StarterState = SimFixtures.mature()
	mature.mass_g = 150.0
	for row: Array in rows:
		var f: float = row[0]
		var tag: String = "1:%d:%d" % [roundi(f), roundi(f)]
		var a: FeedAction = FeedAction.from_ratio(f, f, &"white_bread")
		check_eq(a.kept_g, row[1], tag + " keep")
		check_eq(a.flour_total_g(), row[2], tag + " flour")
		check_eq(a.water_g, row[3], tag + " water")
		check_eq(a.validate(mature, counter(), SimCatalog.builtin()), &"", tag + " validates")
	var timing: Dictionary = {&"freshly_fed": &"early", &"active": &"early", &"near_peak": &"on_time",
		&"at_peak": &"on_time", &"collapsing": &"on_time"}
	for phase: StringName in timing:
		var d := DerivedState.new()
		d.state = phase
		d.rise_phase = phase
		check_eq(PlayerHistory.feed_timing_class(d), timing[phase], "timing class at %s" % phase)


func test_forecast() -> void:
	if not require(&"m2_sim"):
		return
	var s: StarterState = SimFixtures.mature()
	var f: PeakForecast = Forecast.peak_window(s, counter(), FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	check(f.has_window, "1:1:1 at the counter has a window")
	check_between(f.at_peak_start_min_s / 3600.0, 6.0 - 0.5, 6.2 + 0.3, "earliest at_peak start (h)")
	check_between(f.at_peak_start_max_s / 3600.0, 6.0 - 0.3, 6.2 + 0.5, "latest at_peak start (h)")
	check(f.at_peak_start_min_s < f.at_peak_start_max_s, "jitter 0.95 and 1.05 give a range")
	var chilled: StarterState = s.copy()
	chilled.temp_c = 4.0
	var cold: PeakForecast = Forecast.peak_window(chilled, fridge(), FeedAction.from_ratio(1.0, 1.0, &"white_bread"))
	check(not cold.has_window, "a cold (dormant) starter in the fridge has no window")


static func _catalog_keys() -> Dictionary:
	var keys: Dictionary = {}
	for path: String in ["res://src/i18n/en.csv", "res://src/i18n/pending_core.csv"]:
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		f.get_csv_line()
		while not f.eof_reached():
			var row: PackedStringArray = f.get_csv_line()
			if row.size() > 0 and not row[0].is_empty():
				keys[row[0]] = true
	return keys

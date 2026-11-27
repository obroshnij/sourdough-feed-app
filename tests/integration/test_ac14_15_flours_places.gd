extends SliceCase
## Phase 4, AC-14 (flours and hydration) and AC-15 (the new places) through the real Session, with the API
## that exists before T1's Phase 4 contracts. Grams for 60% and 125% use AC-14.1's proposed rule (OD-25):
## today's FeedAction.from_ratio(f, f, flour, h) keeps w = f and Session rejects those feeds with
## REASON_MASS. The commit that lands T1's hydration rule switches `_feed()` to T1's planner.

const FLOURS: Array[StringName] = [&"white_bread", &"whole_wheat", &"rye", &"spelt"]
## AC-14.1's table: [f, hydration %, keep g, flour g, water g].
const TABLE: Array[Array] = [
	[1.0, 60.0, 58.0, 58.0, 34.8], [1.0, 100.0, 50.0, 50.0, 50.0], [1.0, 125.0, 46.0, 46.0, 57.5],
	[2.0, 60.0, 36.0, 72.0, 43.2], [2.0, 100.0, 30.0, 60.0, 60.0], [2.0, 125.0, 27.0, 54.0, 67.5],
	[5.0, 60.0, 17.0, 85.0, 50.0], [5.0, 100.0, 14.0, 70.0, 70.0], [5.0, 125.0, 12.0, 60.0, 75.0],
]
## Spec §18 drift allowance on top of a vector's range.
const DRIFT_H: float = 0.3
const DRIFT_X: float = 0.05


func test_ac_14_1_every_flour_ratio_and_hydration_is_accepted() -> void:
	if not require(&"p3_contracts"):
		return
	for row: Array in TABLE:
		var a: FeedAction = _feed(row[0], row[1], &"white_bread")
		var label: String = "1:%d:%d at %d%%" % [int(row[0]), int(row[0]), int(row[1])]
		check_close(a.kept_g, row[2], 0.0, 1e-9, label + " keep")
		check_close(a.flour_total_g(), row[3], 0.0, 1e-9, label + " flour")
		check_close(a.water_g, row[4], 0.0, 1e-9, label + " water")
		check_between(a.mass_after_g(), 145.0, 155.0, label + " total within 150 ± 5 g")
	var h: SliceHarness = phone("ac14_1")
	h.seed_save(SliceHarness.mature())
	var s: GameSession = h.launch()
	var rejected: PackedStringArray = PackedStringArray()
	var fed: int = 0
	for flour: StringName in FLOURS:
		for row: Array in TABLE:
			h.play(10 * MIN)
			var a: FeedAction = _feed(row[0], row[1], flour)
			var r: ActionResult = h.apply(a)
			if not r.ok:
				rejected.append("%s 1:%d:%d at %d%%: %s" % [flour, int(row[0]), int(row[0]), int(row[1]), r.reason_key])
				continue
			fed += 1
			var flours: Dictionary = r.journal_entry.data.get("flour_g", {})
			check_eq(float(flours.get(String(flour), -1.0)), float(row[3]), "the journal keeps the %s grams" % flour)
			check_eq(s.get_snapshot().state, &"freshly_fed", "%s 1:%d:%d at %d%% leaves it freshly fed" % [
				flour, int(row[0]), int(row[0]), int(row[1])])
	check(rejected.is_empty(), "Session rejected:\n    " + "\n    ".join(rejected))
	check_eq(fed, 36, "36 feeds applied")


func test_ac_14_2_the_culture_follows_spec_6() -> void:
	if not require(&"p3_contracts"):
		return
	var h: SliceHarness = phone("ac14_2")
	h.seed_save(SliceHarness.mature())
	var s: GameSession = h.launch()
	var plan: Array[Array] = [[&"rye", 1.0, 100.0], [&"rye", 1.0, 100.0], [&"rye", 1.0, 100.0],
		[&"spelt", 2.0, 60.0], [&"whole_wheat", 5.0, 125.0], [&"white_bread", 1.0, 125.0], [&"rye", 2.0, 60.0]]
	var n: int = 0
	for step: Array in plan:
		h.play(12 * HOUR)
		var before: StarterState = s.get_starter()
		var a: FeedAction = _feed(step[1], step[2], step[0])
		if not check(h.apply(a).ok, "feed %d applies" % (n + 1)):
			return
		var after: StarterState = s.get_starter()
		var kept_flour: float = a.kept_g * 100.0 / (100.0 + before.culture_hydration)
		var kept_water: float = a.kept_g - kept_flour
		var hyd: float = (kept_water + a.water_g) / (kept_flour + a.flour_total_g()) * 100.0
		check_close(after.culture_hydration, hyd, 1e-9, 1e-9, "feed %d: culture hydration (spec §6)" % (n + 1))
		var total: float = 0.0
		for k: StringName in after.flour_mix:
			var want: float = (kept_flour * float(before.flour_mix.get(k, 0.0)) + float(a.flour_g.get(k, 0.0))) \
				/ (kept_flour + a.flour_total_g())
			check_close(after.flour_mix[k], want, 1e-9, 1e-12, "feed %d: %s share (spec §6)" % [n + 1, k])
			total += after.flour_mix[k]
		check_close(total, 1.0, 0.0, 1e-9, "feed %d: shares sum to 1" % (n + 1))
		n += 1
		if n == 3:
			check(float(s.get_starter().flour_mix.get(&"rye", 0.0)) >= 0.5, "3 rye conversion feeds make rye the main flour")


func test_ac_14_3_v5_and_v6_through_the_session() -> void:
	if not require(&"p3_contracts"):
		return
	# [flour, hydration, at_peak lo, hi (h), peak rise target or [lo, hi], tolerance kind]
	var cases: Array[Array] = [
		[&"rye", 100.0, 5.1, 5.3, 1.66], [&"whole_wheat", 100.0, 5.5, 5.7, 1.91], [&"spelt", 100.0, 5.5, 5.8, 1.91],
		[&"white_bread", 60.0, 6.75, 7.0, [2.33, 2.35]], [&"white_bread", 100.0, 6.2, 6.4, null],
		[&"white_bread", 125.0, 6.0, 6.2, null],
	]
	var acid_24: Dictionary[StringName, float] = {}
	for c: Array in cases:
		var label: String = "%s %d%%" % [c[0], int(c[1])]
		var h: SliceHarness = phone("ac14_3_%s_%d" % [c[0], int(c[1])])
		h.seed_save(SliceHarness.mature())
		var s: GameSession = h.launch()
		for i: int in 3:
			check(h.apply(_feed(1.0, c[1], c[0])).ok, label + " conversion feed")
			h.resume_at(h.clock.now_unix() + 12 * HOUR)
		check(h.apply(_feed(1.0, c[1], c[0])).ok, label + " test feed")
		var t_feed: int = h.clock.now_unix()
		var best: float = 0.0
		var best_t: int = 0
		for m: int in 10 * 60:
			h.play(MIN)
			var r: float = s.get_starter().rise
			if r > best:
				best = r
				best_t = h.clock.now_unix()
		var peak_h: float = (best_t - t_feed) / float(HOUR)
		# V5 and V6 give the peak (max rise) time; "at_peak" starts 0.05 to 0.15 h earlier, so the peak's own
		# window is the stated one for V5 and V6 (spec §18).
		check_between(peak_h, float(c[2]) - DRIFT_H, float(c[3]) + DRIFT_H, "%s peaks at %.2f h" % [label, peak_h])
		if c[4] is float:
			var x: float = c[4]
			check_between(best, x * 0.95 - DRIFT_X, x * 1.05 + DRIFT_X, "%s peak rise about %.2f (%.3f)" % [label, x, best])
		elif c[4] is Array:
			var band: Array = c[4]
			check_between(best, float(band[0]) - DRIFT_X, float(band[1]) + DRIFT_X, "%s peak rise %.3f" % [label, best])
		if float(c[1]) == 100.0:
			h.resume_at(t_feed + 24 * HOUR)
			acid_24[c[0]] = s.get_starter().acid
		if float(c[1]) == 60.0:
			h.resume_at(t_feed + 48 * HOUR)
			check(s.get_starter().hooch < 0.1, "60%%: hooch never reaches 0.1 in 48 h (%.3f)" % s.get_starter().hooch)
	if acid_24.has(&"rye") and acid_24.has(&"whole_wheat") and acid_24.has(&"white_bread"):
		check(acid_24[&"rye"] > acid_24[&"whole_wheat"] and acid_24[&"whole_wheat"] > acid_24[&"white_bread"],
			"acid at 24 h: rye > whole_wheat > white (%s)" % str(acid_24))


func test_ac_15_1_the_new_places_take_their_climate() -> void:
	if not require(&"p3_contracts"):
		return
	var h: SliceHarness = phone("ac15_1")
	h.seed_save(SliceHarness.mature())
	var s: GameSession = h.launch()
	var sill: SetEnvironmentAction = SetEnvironmentAction.to_location(&"window_sill")
	sill.env.humidity_pct = 99.0
	var r: ActionResult = h.apply(sill)
	check(r.ok, "window_sill applies")
	check_eq(s.get_environment().temperature_c, 18.0, "window_sill 18 °C (spec §2.2)")
	check_eq(s.get_environment().humidity_pct, 55.0, "window_sill 55% RH, from the place, not the caller")
	check_eq(r.journal_entry.text_key, &"JOURNAL_LOG_MOVE_WINDOW_SILL", "the move's journal line")
	var temps: Array[float] = [s.get_starter().temp_c]
	for i: int in 90:
		h.play(MIN)
		temps.append(s.get_starter().temp_c)
	var falling: bool = true
	for i: int in range(1, temps.size()):
		falling = falling and temps[i] <= temps[i - 1] and temps[i] >= 18.0
	check(falling, "temp_c falls toward 18 °C with no overshoot (%.2f after 1.5 h)" % temps[temps.size() - 1])
	check_between(temps[temps.size() - 1], 18.0 + 4.0 * 0.30, 18.0 + 4.0 * 0.42, "about 1/e of the gap left after 1.5 h")
	var box: ActionResult = h.apply(SetEnvironmentAction.to_location(&"proofing_box"))
	check(box.ok, "proofing_box applies")
	check_eq(s.get_environment().temperature_c, 26.0, "proofing_box 26 °C by default")
	check_eq(s.get_environment().humidity_pct, 60.0, "proofing_box 60% RH")
	check_eq(box.journal_entry.text_key, &"JOURNAL_LOG_MOVE_PROOFING_BOX", "the move's journal line")


func test_ac_15_2_the_proofing_box_dial_stays_in_24_to_30() -> void:
	if not require(&"p3_contracts"):
		return
	var h: SliceHarness = phone("ac15_2")
	h.seed_save(SliceHarness.mature())
	var s: GameSession = h.launch()
	for t: float in [24.0, 30.0]:
		check(h.apply(SetEnvironmentAction.to_location(&"proofing_box", t)).ok, "%.1f °C applies" % t)
		check_eq(s.get_environment().temperature_c, t, "the box is at %.1f °C" % t)
	for t: float in [23.5, 30.5]:
		var save_before: PackedByteArray = h.bytes_of(SaveStore.FILE_MAIN)
		var journal_before: int = s.get_journal().size()
		var r: ActionResult = h.apply(SetEnvironmentAction.to_location(&"proofing_box", t))
		check(not r.ok, "%.1f °C is rejected" % t)
		check_eq(r.reason_key, GameAction.REASON_ENVIRONMENT, "with REASON_ENVIRONMENT")
		check(h.bytes_of(SaveStore.FILE_MAIN) == save_before, "%.1f °C: the save is byte-unchanged" % t)
		check_eq(s.get_journal().size(), journal_before, "%.1f °C: no journal line" % t)
	var other: ActionResult = h.apply(SetEnvironmentAction.to_location(&"counter", 25.0))
	check(not other.ok, "no other place takes a dial value")


func test_ac_15_3_peak_order_across_places() -> void:
	if not require(&"p3_contracts"):
		return
	var rng_seed: int = SliceHarness.seed_for_draw(0.5)
	# [label, location, temperature]
	var places: Array[Array] = [["box 30", &"proofing_box", 30.0], ["warm spot", &"warm_spot", 26.0],
		["box 26", &"proofing_box", 26.0], ["counter", &"counter", 22.0], ["window sill", &"window_sill", 18.0]]
	var peaks: Array[float] = []
	for p: Array in places:
		var h: SliceHarness = phone("ac15_3_%s" % String(p[0]).replace(" ", "_"))
		var env: EnvironmentState = EnvironmentState.at_location(p[1])
		env.temperature_c = p[2]
		var st: StarterState = SliceHarness.mature()
		st.temp_c = p[2]
		h.seed_save(st, env, rng_seed)
		var s: GameSession = h.launch()
		if not check(h.apply(FeedAction.from_ratio(1.0, 1.0, &"white_bread")).ok, "%s: feed" % p[0]):
			return
		var t_feed: int = h.clock.now_unix()
		var best: float = 0.0
		var best_t: int = 0
		for m: int in 12 * 60:
			h.play(MIN)
			if s.get_starter().rise > best:
				best = s.get_starter().rise
				best_t = h.clock.now_unix()
		peaks.append((best_t - t_feed) / float(HOUR))
	print("    AC-15.3 peaks (h): box 30 %.2f, warm spot %.2f, box 26 %.2f, counter %.2f, window sill %.2f" % peaks)
	check(peaks[0] < peaks[1], "the box at 30 °C peaks before the warm spot")
	check_eq(peaks[1], peaks[2], "the warm spot and the box at 26 °C peak in the same minute")
	check(peaks[2] < peaks[3] and peaks[3] < peaks[4], "then the counter, then the window sill")
	check_between(peaks[4], 8.7 * 0.95 - DRIFT_H, 8.7 * 1.05 + DRIFT_H, "the window sill peaks at about 8.7 h (spec §15)")


func test_ac_15_4_neglect_at_the_window_sill_and_the_hot_box() -> void:
	if not require(&"m2_sim"):
		return
	var sill: Array[float] = _neglect(EnvironmentState.at_location(&"window_sill"), 18.0)
	print("    AC-15.4 window sill: unhealthy at %.1f h (%.2f d), moldy at %.1f h (%.2f d)" % [
		sill[0], sill[0] / 24.0, sill[1], sill[1] / 24.0])
	check_between(sill[0], 5.8 * 24.0 * 0.95 - DRIFT_H, 5.8 * 24.0 * 1.05 + DRIFT_H, "unhealthy at about 5.8 d (spec §15)")
	check_between(sill[1], 11.4 * 24.0 * 0.95 - DRIFT_H, 11.4 * 24.0 * 1.05 + DRIFT_H, "moldy at about 11.4 d (spec §15)")
	check(sill[1] - sill[0] >= 72.0, "warning to mold ≥ 72 h at the window sill (%.1f h)" % (sill[1] - sill[0]))
	var hot_env: EnvironmentState = EnvironmentState.at_location(&"proofing_box")
	hot_env.temperature_c = 30.0
	var hot: Array[float] = _neglect(hot_env, 30.0)
	print("    AC-15.4 proofing box 30 °C: unhealthy at %.1f h, moldy at %.1f h, gap %.1f h" % [hot[0], hot[1], hot[1] - hot[0]])
	check(hot[0] > 0.0 and hot[1] > 0.0, "the hot box reaches unhealthy and moldy in 14 d")
	check(hot[1] - hot[0] >= 59.0, "warning to mold ≥ 59 h at 30 °C (SIM-WARN-03 floor)")


# ------------------------------------------------------------------ helpers

## AC-14.1's proposed rule (OD-25): keep = round(150 / (1 + f + f × h / 100)), flour = keep × f,
## water = flour × h / 100; 1:5:5 rounds flour and water to 5 g.
static func _feed(f: float, h: float, flour: StringName) -> FeedAction:
	var a := FeedAction.new()
	var keep: float = roundf(150.0 / (1.0 + f + f * h / 100.0))
	var fl: float = keep * f
	var water: float = fl * h / 100.0
	if f >= 5.0:
		fl = roundf(fl / 5.0) * 5.0
		water = roundf(water / 5.0) * 5.0
	a.kept_g = keep
	a.flour_g = {flour: fl}
	a.water_g = water
	return a


## Hours from a 1:1:1 feed (feed_u 0.5, temp_c at the place) to the first unhealthy and the first moldy
## step, unfed, within 14 days. -1 when not reached.
static func _neglect(env: EnvironmentState, temp_c: float) -> Array[float]:
	var s: StarterState = SimFixtures.mature()
	s.temp_c = temp_c
	SimFixtures.feed_ratio(s)
	var out: Array[float] = [-1.0, -1.0]
	for i: int in 14 * 1440:
		Sim.step(s, env)
		var st: StringName = StateDeriver.derive(s, env).state
		if out[0] < 0.0 and (st == &"unhealthy" or st == &"moldy"):
			out[0] = (i + 1) / 60.0
		if st == &"moldy":
			out[1] = (i + 1) / 60.0
			break
	return out

extends SliceCase
## AC-04.4 (the designer's BT scenarios, game-mechanics §10) and AC-04.5 (leniency floors L-1 to L-11,
## §9), with AC-10.10's sweep (SIM-WARN-03). Session schedules where events or the journal matter, the pure
## sim where only the state does. Already covered elsewhere: BT-1, 2, 3, 9 (int/ac10), BT-7 (int/ac04
## neglect: unhealthy 104 to 111 h, moldy 207 to 219 h, 72 h apart), BT-12 (Phase 4 demo), BT-17
## (t1/phase3_sim).

const FIXTURES: String = "res://tests/unit/ui/fixtures"
## Spec §12.2 precedence, worst first. Rise phases share rank 0.
const RANK: Dictionary[StringName, int] = {
	&"moldy": 5, &"unhealthy": 4, &"dormant": 3, &"hungry": 2, &"recovering": 1,
}
const STRONG: float = 0.85


## BT-4: a weekend in the fridge from steady state. Fed Fri 18:00, fridge 19:00, counter and fed Sun 18:00,
## then BT-1 care. No attention event, mold risk under 0.3, and the peak is back to 85% of the
## pre-weekend peak within 2 feeds.
func test_bt_4_weekend_in_the_fridge() -> void:
	if not _ready():
		return
	var h: SliceHarness = _steady("bt4")
	var events: Array[SimEvent] = []
	h.reopen_at(T0 + 3 * DAY + 18 * HOUR)
	var before: float = h.session.get_starter().peak_rise
	events.append_array(h.apply(_f122()).events)
	h.reopen_at(T0 + 3 * DAY + 19 * HOUR)
	events.append_array(h.apply(SetEnvironmentAction.to_location(&"fridge")).events)
	h.reopen_at(T0 + 5 * DAY + 18 * HOUR)
	events.append_array(h.session.get_last_catch_up().events)
	var max_mold: float = h.session.get_starter().mold_risk
	events.append_array(h.apply(SetEnvironmentAction.to_location(&"counter")).events)
	events.append_array(h.apply(_f122()).events)
	var peaks: Array[float] = []
	for at_h: int in [6 * 24 + 8, 6 * 24 + 20]:
		h.reopen_at(T0 + at_h * HOUR)
		events.append_array(h.session.get_last_catch_up().events)
		peaks.append(h.session.get_starter().peak_rise)
		max_mold = maxf(max_mold, h.session.get_starter().mold_risk)
		events.append_array(h.apply(_f122()).events)
	check(events.all(func(e: SimEvent) -> bool: return e.tier != &"attention"), "no attention event")
	check(max_mold < 0.3, "mold risk under 0.3 (max %.4f)" % max_mold)
	check(peaks.any(func(p: float) -> bool: return p >= STRONG * before),
		"85%% of the pre-weekend peak (%.3f) within 2 feeds: %s" % [before, str(peaks)])


## BT-5: 24 h away from steady state. Hungry on return with no attention event, and one feed gives a peak
## of at least 85% of normal.
func test_bt_5_a_day_away() -> void:
	if not _ready():
		return
	var h: SliceHarness = _steady("bt5")
	h.reopen_at(T0 + 3 * DAY + 8 * HOUR)
	var normal: float = h.session.get_starter().peak_rise
	h.apply(_f122())
	h.reopen_at(T0 + 4 * DAY + 8 * HOUR)
	var r: CatchUpResult = h.session.get_last_catch_up()
	check_eq(h.state(), &"hungry", "hungry on return")
	check(r.events.all(func(e: SimEvent) -> bool: return e.tier != &"attention"), "no attention event")
	h.apply(_f122())
	h.reopen_at(T0 + 4 * DAY + 20 * HOUR)
	check(h.session.get_starter().peak_rise >= STRONG * normal,
		"one feed: %.3f vs normal %.3f" % [h.session.get_starter().peak_rise, normal])


## BT-6: 14 days in the fridge. Never unhealthy, and a normal rise (85% of before) within 2 feeds.
func test_bt_6_two_weeks_in_the_fridge() -> void:
	if not _ready():
		return
	var h: SliceHarness = _steady("bt6")
	h.reopen_at(T0 + 3 * DAY + 8 * HOUR)
	var normal: float = h.session.get_starter().peak_rise
	h.apply(_f122())
	h.apply(SetEnvironmentAction.to_location(&"fridge"))
	h.reopen_at(T0 + 17 * DAY + 8 * HOUR)
	var r: CatchUpResult = h.session.get_last_catch_up()
	check(r.transitions.all(func(t: Dictionary) -> bool: return String(t.get("to", "")) != "unhealthy"), "never unhealthy")
	h.apply(SetEnvironmentAction.to_location(&"counter"))
	h.apply(_f122())
	var peaks: Array[float] = []
	for k: int in 2:
		h.reopen_at(T0 + 17 * DAY + (8 + 12 * (k + 1)) * HOUR)
		peaks.append(h.session.get_starter().peak_rise)
		h.apply(_f122())
	check(peaks.any(func(p: float) -> bool: return p >= STRONG * normal), "normal within 2 feeds: %s vs %.3f" % [str(peaks), normal])


## BT-8: fed at the unhealthy onset, then BT-1 care. Out of unhealthy after the one feed, and a normal
## rise (85% of the healthy peak) within 3 feeds.
func test_bt_8_rescue_at_the_warning() -> void:
	if not _ready():
		return
	var h: SliceHarness = _mature_phone("bt8")
	var healthy: float = 0.0
	h.apply(feed_111())
	h.reopen_at(T0 + 12 * HOUR)
	healthy = h.session.get_starter().peak_rise
	h.reopen_at(T0 + 112 * HOUR)
	check_eq(h.state(), &"unhealthy", "unhealthy at 112 h")
	h.apply(_f122())
	check(h.state() != &"unhealthy", "out of unhealthy after one feed (%s)" % h.state())
	var peaks: Array[float] = []
	for k: int in 3:
		h.reopen_at(T0 + (112 + 12 * (k + 1)) * HOUR)
		peaks.append(h.session.get_starter().peak_rise)
		h.apply(_f122())
	check(peaks.any(func(p: float) -> bool: return p >= STRONG * healthy), "normal within 3 feeds: %s vs %.3f" % [str(peaks), healthy])


## BT-10: the same save and inputs give the same state, events and return summary, byte for byte.
func test_bt_10_same_inputs_same_everything() -> void:
	if not _ready():
		return
	var outs: Array[Array] = []
	for i: int in 2:
		var h: SliceHarness = _mature_phone("bt10_%d" % i)
		h.apply(feed_111())
		h.reopen_at(T0 + 30 * HOUR)
		h.apply(FeedAction.from_ratio(5.0, 5.0, &"whole_wheat"))
		h.reopen_at(T0 + 8 * DAY)
		var s: ReturnSummary = h.session.get_return_summary()
		var lines: Array = []
		for line: ReturnLine in s.lines:
			lines.append([String(line.text_key), line.args, line.at_unix])
		var ev: Array = []
		for e: JournalEntry in h.journal_of(&"event"):
			ev.append([String(e.data.get("event_id", "")), e.at_unix])
		outs.append([SliceHarness.payload_text(h.session.build_payload()), ev, lines, s.prompt.id if s.prompt != null else &""])
	check_eq(outs[1][0], outs[0][0], "the same saved state")
	check_eq(outs[1][1], outs[0][1], "the same events at the same times")
	check_eq(outs[1][2], outs[0][2], "the same summary lines")
	check_eq(outs[1][3], outs[0][3], "the same prompt")


## BT-11: with the environment unchanged, the actual at_peak start falls inside the forecast window for
## every slice preset and flour, at the counter and the warm spot, at feed_u 0, 0.25, 0.5, 0.75 and the top.
func test_bt_11_at_peak_starts_inside_the_forecast() -> void:
	if not require(&"m2_sim"):
		return
	var misses: PackedStringArray = PackedStringArray()
	var runs: int = 0
	for place: StringName in [&"counter", &"warm_spot"]:
		var env: EnvironmentState = EnvironmentState.at_location(place)
		for preset: Vector2 in [Vector2(1, 1), Vector2(2, 2), Vector2(5, 5)]:
			for flour: StringName in [&"white_bread", &"whole_wheat"]:
				for u: float in [0.0, 0.25, 0.5, 0.75, 0.9999999]:
					var s: StarterState = SimFixtures.mature()
					s.temp_c = env.temperature_c
					var feed: FeedAction = FeedAction.from_ratio(preset.x, preset.y, flour)
					var f: PeakForecast = Forecast.peak_window(s, env, feed)
					Sim.feed(s, feed.kept_g, feed.flour_g, feed.water_g, u, false)
					var start_s: float = -1.0
					for step: int in 24 * 60:
						Sim.step(s, env)
						if StateDeriver.derive(s, env).rise_phase == &"at_peak":
							start_s = float((step + 1) * 60)
							break
					runs += 1
					if not f.has_window or start_s < f.at_peak_start_min_s - 60.0 or start_s > f.at_peak_start_max_s + 60.0:
						misses.append("%s 1:%d:%d %s u %.2f: at %.0f s, window %.0f to %.0f" % [place, int(preset.x),
							int(preset.y), flour, u, start_s, f.at_peak_start_min_s, f.at_peak_start_max_s])
	check_eq(runs, 60, "60 feeds forecast")
	check(misses.is_empty(), "inside the window:\n    " + "\n    ".join(misses.slice(0, 8)))


## BT-14 and BT-14b: maturity pacing from 0.2. Twice daily (BT-1 care): steady by days 5 to 8, mature by
## 12 to 18, seasoned by 45 to 60. Once daily (BT-2 care): each stage within 1.5x its BT-14 day.
func test_bt_14_maturity_pacing() -> void:
	if not require(&"m2_sim"):
		return
	var twice: Array[float] = _stage_days(12, 30.0, 2.0, 70)
	var once: Array[float] = _stage_days(24, 14.0, 5.0, 95)
	var windows: Array[Vector2] = [Vector2(5, 8), Vector2(12, 18), Vector2(45, 60)]
	var names: Array[String] = ["steady", "mature", "seasoned"]
	for i: int in 3:
		check_between(twice[i], windows[i].x, windows[i].y, "twice daily: %s by day" % names[i])
		check(once[i] > 0.0 and once[i] <= 1.5 * twice[i], "once daily: %s by day %.1f, within 1.5x of %.1f" % [names[i], once[i], twice[i]])


## BT-16, L-11 and L-10 over T3's 12 state fixtures (every state but moldy). L-10: no slice action makes any
## of them moldy. L-11: the corrective action (a feed, or the counter for a cold dormant) gives, within 6 h,
## a state no worse in precedence, with mold risk not higher.
func test_bt_16_l_10_l_11_no_loss_and_no_dead_ends() -> void:
	if not _ready():
		return
	var actions: Array[GameAction] = [feed_111(), FeedAction.from_ratio(2.0, 2.0, &"whole_wheat"),
		FeedAction.from_ratio(5.0, 5.0, &"white_bread"), SetEnvironmentAction.to_location(&"counter"),
		SetEnvironmentAction.to_location(&"warm_spot"), SetEnvironmentAction.to_location(&"fridge"),
		SmellAction.new(), InspectAction.new(&"height"), InspectAction.new(&"bubbles"), InspectAction.new(&"surface")]
	var seen: int = 0
	for file: String in DirAccess.get_files_at(FIXTURES):
		if not file.ends_with(".json") or file == "moldy.json":
			continue
		seen += 1
		var path: String = FIXTURES.path_join(file)
		for a: GameAction in actions:
			var h: SliceHarness = phone("l10_" + file.get_basename())
			h.launch_fixture(path)
			h.apply(a)
			check(h.state() != &"moldy", "L-10: %s then %s is not moldy" % [file, a.kind])
			h.dispose()  # free the Session now; after_each's second dispose is a no-op
		var fix: SliceHarness = phone("l11_" + file.get_basename())
		fix.launch_fixture(path)
		var before: StringName = fix.state()
		var mold_before: float = fix.session.get_starter().mold_risk
		if before == &"dormant" and fix.session.get_snapshot().dormant_cause == &"cold":
			fix.apply(SetEnvironmentAction.to_location(&"counter"))
		fix.apply(feed_111())
		fix.play(6 * HOUR, 10 * MIN)
		var after: StringName = fix.state()
		check(RANK.get(after, 0) <= RANK.get(before, 0), "L-11: %s within 6 h of its fix is %s, no worse" % [file, after])
		check(fix.session.get_starter().mold_risk <= mold_before + 1e-12, "L-11: %s mold risk not higher" % file)
	check_eq(seen, 11, "11 non-moldy fixtures")


## SIM-WARN-03 (AC-04.5, AC-10.10, L-6, L-7): unfed after a 1:1:1 feed at every temperature from 4 to 40 °C
## (loose lid, 50% RH), plus every cover and 30 or 70% RH at 22 and 30 °C. Wherever mold comes within 20
## days, the warning (mold risk 0.5) came at least 59 h before it and the watch stage (0.3) at least 76 h
## before it (the spec's test floors; it guarantees 60 and 77 h).
func test_sim_warn_03_warning_to_mold_at_every_temperature() -> void:
	if not require(&"m2_sim"):
		return
	var cases: Array[Array] = []
	for t: int in range(4, 41):
		cases.append([float(t), 50.0, &"loose_lid"])
	for t: float in [22.0, 30.0]:
		for cover: StringName in [&"cloth", &"tight_lid"]:
			cases.append([t, 50.0, cover])
		for rh: float in [30.0, 70.0]:
			cases.append([t, rh, &"loose_lid"])
	var short: PackedStringArray = PackedStringArray()
	var molded: int = 0
	for c: Array in cases:
		var env: EnvironmentState = EnvironmentState.make(c[0], c[1], c[2])
		var s: StarterState = SimFixtures.mature()
		s.temp_c = env.temperature_c
		SimFixtures.feed_ratio(s)
		var watch_h: float = -1.0
		var warn_h: float = -1.0
		for step: int in 20 * 1440:
			Sim.step(s, env)
			var hrs: float = float(step + 1) / 60.0
			if watch_h < 0.0 and s.mold_risk >= 0.3:
				watch_h = hrs
			if warn_h < 0.0 and s.mold_risk >= 0.5:
				warn_h = hrs
			if s.moldy:
				molded += 1
				if hrs - warn_h < 59.0 or hrs - watch_h < 76.0:
					short.append("%.0f °C %.0f%% %s: warning %.1f h, watch %.1f h before mold" % [c[0], c[1], c[2],
						hrs - warn_h, hrs - watch_h])
				break
	check(molded >= 25, "mold reached in %d of %d cases" % [molded, cases.size()])
	check(short.is_empty(), "gaps below the floors:\n    " + "\n    ".join(short))


# ------------------------------------------------------------------ helpers

func _ready() -> bool:
	return ready_for_integration() and require(&"p3_contracts") and require(&"p3_rules")


static func _f122() -> FeedAction:
	return FeedAction.from_ratio(2.0, 2.0, &"white_bread")


func _mature_phone(label: String) -> SliceHarness:
	var h: SliceHarness = phone(label)
	h.seed_save(SliceHarness.mature(), null, SliceHarness.seed_for_draw(0.5))
	h.launch()
	return h


## Steady state: 3 days of BT-1 care (1:2:2 at 08:00 and 20:00, UTC offset 0), the last feed at day 3 08:00
## not yet made.
func _steady(label: String) -> SliceHarness:
	var h: SliceHarness = _mature_phone(label)
	h.reopen_at(T0 + 8 * HOUR)
	h.apply(_f122())
	for k: int in range(1, 6):
		h.reopen_at(T0 + (8 + 12 * k) * HOUR)
		h.apply(_f122())
	return h


## Days from maturity 0.2 to steady, mature and seasoned, feeding 1 : f : f every `every_h` hours with
## `kept` grams kept, at the counter. -1 for a stage not reached in `max_days`.
static func _stage_days(every_h: int, kept: float, f: float, max_days: int) -> Array[float]:
	var s: StarterState = SimFixtures.young()
	var env: EnvironmentState = EnvironmentState.at_location(&"counter")
	var days: Array[float] = [-1.0, -1.0, -1.0]
	var mins: Array[float] = [0.33, 0.50, 0.83]
	var hours_done: int = 0
	while hours_done < max_days * 24:
		SimFixtures.feed_ratio(s, 1.0, f, &"white_bread", 100.0, kept)
		for i: int in 3:
			if days[i] < 0.0 and s.maturity >= mins[i]:
				days[i] = float(hours_done) / 24.0
		for step: int in every_h * 60:
			Sim.step(s, env)
		hours_done += every_h
	return days

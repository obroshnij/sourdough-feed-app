extends SimVectorCase
## Spec §18 golden vectors V1 to V20, the same checks as `python3 -I tools/sim-reference/sim.py vectors`.
## Each vector runs at feed_u 0, 0.5 and 1 (jitter 0.95 to 1.05); ranges get the §18 drift allowance
## (±0.3 h, ±0.05 rise; "about X" = X ± 5% plus drift). Owner: T1.


func test_v1_one_to_one_at_24c() -> void:
	if not require(&"m2_sim"):
		return
	var v1: Array[Trace] = ratio_vector(SimFixtures.mature(), 1, 1, 24, 50, 48, [2, 4, 8, 12, 24, 48])
	check_peak("V1", v1, Vector2(5.3, 5.5), Vector2(5.4, 5.6), Vector2(2.20, 2.22))
	check_states("V1 2 h", v1, 2, [&"active"])
	within("V1 2 h rise", rises_at(v1, 2), 1.37, 1.38, TOL_R)
	check_states("V1 4 h", v1, 4, [&"active", &"near_peak"])
	within("V1 4 h rise", rises_at(v1, 4), 1.87, 1.92, TOL_R)
	check_states("V1 8 h", v1, 8, [&"collapsing"])
	about("V1 8 h rise", rises_at(v1, 8), 1.94, TOL_R)
	check_states("V1 12 h", v1, 12, [&"collapsing", &"hungry"])
	about("V1 12 h rise", rises_at(v1, 12), 1.60, TOL_R)
	check_states("V1 24 h", v1, 24, [&"hungry"])
	within("V1 24 h rise", rises_at(v1, 24), 1.16, 1.16, TOL_R)
	for r: Trace in v1:
		check(r.row(24).hooch, "V1 24 h hooch visible")
		var sm: Array[StringName] = r.row(24).smells
		check(_same_set(sm, [&"alcohol", &"pleasantly_tangy", &"acetone"]) and sm[0] == &"alcohol", "V1 24 h smells %s" % [sm])
		check(_same_set(r.row(48).smells, [&"acetone", &"alcohol", &"strongly_acidic"]), "V1 48 h smells %s" % [r.row(48).smells])
		for h: int in [2, 4, 8, 12, 24, 48]:
			check_eq(r.row(h).mold_stage, &"none", "V1 %d h mold stage" % h)
	check_states("V1 48 h", v1, 48, [&"hungry"])
	within("V1 48 h rise", rises_at(v1, 48), 1.01, 1.01, TOL_R)


func test_v2_temperature_order() -> void:
	if not require(&"m2_sim"):
		return
	var base: StarterState = SimFixtures.mature()
	var v1: Array[Trace] = ratio_vector(base, 1, 1, 24, 50, 48)
	var rows: Array = [[20.0, Vector2(7.0, 7.2), Vector2(7.1, 7.4), 2.12], [22.0, Vector2(6.0, 6.2), Vector2(6.1, 6.3), 2.17],
		[28.0, Vector2(4.5, 4.7), Vector2(4.6, 4.8), 2.23]]
	var by_t: Dictionary = {}
	for row: Array in rows:
		var t: float = row[0]
		var recs: Array[Trace] = ratio_vector(base, 1, 1, t, 50, 48, [48])
		by_t[t] = recs
		check_peak("V2 %d C" % roundi(t), recs, row[1], row[2], Vector2.ZERO, row[3])
	var v20: Array[Trace] = by_t[20.0]
	var v28: Array[Trace] = by_t[28.0]
	for i: int in 3:
		check(v28[i].peak_t < v1[i].peak_t and v1[i].peak_t < v20[i].peak_t, "V2 order 28 < 24 < 20 for draw %d" % i)
	check_states("V2 28 C 48 h", v28, 48, [&"dormant"])


func test_v3_dilution_at_24c() -> void:
	if not require(&"m2_sim"):
		return
	var base: StarterState = SimFixtures.mature()
	var v1: Array[Trace] = ratio_vector(base, 1, 1, 24, 50, 48)
	var a: Array[Trace] = ratio_vector(base, 1, 5, 24, 10)
	var b: Array[Trace] = ratio_vector(base, 1, 10, 24, 10)
	check_peak("V3 1:5:5", a, Vector2(9.5, 10.0), Vector2(9.6, 10.1), Vector2(2.52, 2.55))
	check_peak("V3 1:10:10", b, Vector2(11.3, 12.0), Vector2(11.4, 12.1), Vector2(2.57, 2.60))
	for i: int in 3:
		check_between(a[i].peak_t - v1[i].peak_t, 3.9 - TOL_T, 4.6 + TOL_T, "V3 1:5:5 later than V1")
		check_between(b[i].peak_t - v1[i].peak_t, 5.8 - TOL_T, 6.6 + TOL_T, "V3 1:10:10 later than V1")


func test_v4_one_to_fifty() -> void:
	if not require(&"m2_sim"):
		return
	var v4: Array[Trace] = ratio_vector(SimFixtures.mature(), 1, 50, 24, 2, 48, [24])
	check_peak("V4", v4, Vector2.ZERO, Vector2(15.6, 16.7), Vector2(2.60, 2.64))


func test_v5_flours() -> void:
	if not require(&"m2_sim"):
		return
	var base: StarterState = SimFixtures.mature()
	var peaks: Dictionary = {}
	var acid24: Dictionary = {}
	var expect: Dictionary = {&"rye": [Vector2(5.1, 5.3), 1.66], &"whole_wheat": [Vector2(5.5, 5.7), 1.91],
		&"spelt": [Vector2(5.5, 5.8), 1.91]}
	for fl: StringName in [&"white_bread", &"rye", &"whole_wheat", &"spelt"]:
		var conv: StarterState = converted(base, fl)
		var recs: Array[Trace] = ratio_vector(conv, 1, 1, 22, 50, 48, [24], fl)
		peaks[fl] = recs[1].peak_t
		acid24[fl] = advance(fed(at_temp(conv, 22), 1, 1, fl), 24.0, counter()).acid
		if expect.has(fl):
			var e: Array = expect[fl]
			check_peak("V5 %s" % fl, recs, Vector2.ZERO, e[0], Vector2.ZERO, e[1])
	check(float(acid24[&"rye"]) > float(acid24[&"whole_wheat"]) and float(acid24[&"whole_wheat"]) > float(acid24[&"white_bread"]),
		"V5 acid at 24 h rye > whole_wheat > white: %s" % [acid24])
	check(float(peaks[&"rye"]) < float(peaks[&"whole_wheat"]) and float(peaks[&"whole_wheat"]) <= float(peaks[&"spelt"])
		and float(peaks[&"spelt"]) < float(peaks[&"white_bread"]), "V5 speed rye > whole_wheat >= spelt > white: %s" % [peaks])


func test_v6_hydration() -> void:
	if not require(&"m2_sim"):
		return
	var base: StarterState = SimFixtures.mature()
	for row: Array in [[60.0, Vector2(6.75, 7.0)], [100.0, Vector2(6.2, 6.4)], [125.0, Vector2(6.0, 6.2)]]:
		var hyd: float = row[0]
		var recs: Array[Trace] = ratio_vector(converted(base, &"white_bread", hyd), 1, 1, 22, 50, 48, [48], &"white_bread", hyd)
		var ht: Vector2 = Vector2(2.33, 2.35) if hyd == 60.0 else Vector2.ZERO
		check_peak("V6 %d%%" % roundi(hyd), recs, Vector2.ZERO, row[1], ht)
		if hyd == 60.0:
			for r: Trace in recs:
				check(r.end.hooch < 0.1, "V6 60%% no visible hooch in 48 h")


func test_v7_fridge() -> void:
	if not require(&"m2_sim"):
		return
	var base: StarterState = SimFixtures.mature()
	for days: int in [3, 14]:
		var s: StarterState = advance(advance(fed(base), 1.0, counter()), days * 24.0, fridge())
		var st: DerivedState = StateDeriver.derive(s, fridge())
		var recs: Array[Trace] = ratio_vector(s, 1, 1, 22, 50, 24, [2, 4, 8, 12], &"white_bread", 100.0, true)
		var nxt: Trace = trace(fed(recs[1].end), 24.0, counter())
		check_eq(st.state, &"dormant", "V7 %d d dormant in the fridge" % days)
		check(not nxt.first.has(&"recovering"), "V7 %d d next feed not recovering" % days)
		if days == 3:
			for r: Trace in recs:
				check(not r.first.has(&"recovering"), "V7 3 d not recovering")
			check_peak("V7 3 d", recs, Vector2.ZERO, Vector2(10.2, 10.6))
		else:
			check(s.hooch >= 0.3, "V7 14 d hooch >= 0.3, got %s" % s.hooch)
			check(s.mold_risk < 0.3, "V7 14 d mold < 0.3")
			check_between(s.vigor, 0.6, 0.7, "V7 14 d vigor")
			for h: int in [2, 4, 8, 12]:
				check_states("V7 14 d %d h" % h, recs, h, [&"recovering"])
			check_peak("V7 14 d", recs, Vector2.ZERO, Vector2(13.5, 14.1), Vector2.ZERO, 1.9)


func test_v8_away_24h() -> void:
	if not require(&"m2_sim"):
		return
	var base: StarterState = SimFixtures.mature()
	var s: StarterState = advance(fed(base), 24.0, counter())
	check_eq(StateDeriver.derive(s, counter()).state, &"hungry", "V8 hungry before the feed")
	check(s.hooch >= 0.1, "V8 hooch before the feed")
	check_between(s.vigor, 0.92, 0.96, "V8 vigor before the feed")
	var v8: Array[Trace] = ratio_vector(s, 1, 1, 22, 50, 24, [12])
	check_peak("V8", v8, Vector2.ZERO, Vector2(6.7, 6.9))
	var v2: Array[Trace] = ratio_vector(base, 1, 1, 22, 50, 48)
	for i: int in 3:
		check(v8[i].peak_rise >= 0.85 * v2[i].peak_rise, "V8 peak >= 0.85 x V2 22 C")
		check(not v8[i].first.has(&"recovering"), "V8 not recovering")


func test_v9_neglect_at_counter() -> void:
	if not require(&"m2_sim"):
		return
	var res: Array = state_times(fed(SimFixtures.mature()), 14 * 24.0, counter())
	var first: Dictionary = res[0]
	var marks: Dictionary = res[1]
	for row: Array in [[&"hungry", 12.4, 12.8], [&"dormant", 74.0, 77.0], [&"unhealthy", 104.0, 111.0], [&"moldy", 207.0, 219.0]]:
		var id: StringName = row[0]
		check(first.has(id), "V9 reaches %s" % id)
		check_between(float(first.get(id, -1.0)), float(row[1]) - TOL_T, float(row[2]) + TOL_T, "V9 %s onset" % id)
	check_between(float(marks.get("watch", -1.0)), 72.0 - TOL_T, 80.0 + TOL_T, "V9 watch onset")
	check(float(first[&"moldy"]) - float(first[&"unhealthy"]) >= 72.0, "V9 warning to mold >= 72 h")
	check(float(first[&"moldy"]) - float(marks["watch"]) >= 96.0, "V9 watch to mold >= 96 h")


func test_v9b_rescue_from_unhealthy() -> void:
	if not require(&"m2_sim"):
		return
	var base: StarterState = SimFixtures.mature()
	var s: StarterState = advance(fed(base), 120.0, counter())
	check_eq(StateDeriver.derive(s, counter()).state, &"unhealthy", "V9b unhealthy at 120 h")
	check(fed(s).mold_risk < 0.3, "V9b mold < 0.3 after the feed")
	var rec: Array[Trace] = ratio_vector(s, 1, 1, 22, 50, 24, [2, 12])
	for h: int in [2, 12]:
		check_states("V9b %d h" % h, rec, h, [&"recovering"])
	check_peak("V9b", rec, Vector2.ZERO, Vector2(12.8, 13.3), Vector2.ZERO, 1.76)
	var x: StarterState = rec[1].end
	var heights_next: Array[float] = []
	for i: int in 2:
		x = fed(x)
		var t: Trace = trace(x, 12.0, counter())
		heights_next.append(t.peak_rise)
		x = t.end
	var normal: float = trace(fed(base), 12.0, counter()).peak_rise
	check(heights_next[1] >= 0.95 * normal, "V9b normal (>= 0.95x) by feed 3: %s vs %s" % [heights_next[1], normal])


func test_v10_rapid_feeds() -> void:
	if not require(&"m2_sim"):
		return
	var s: StarterState = SimFixtures.mature()
	for i: int in 12:
		s = advance(fed(s), 1.0 / 6.0, counter())
	var rec: Trace = trace(s, 48.0, counter())
	check(s.yeast <= 0.002 and s.lab <= 0.002, "V10 populations near the floor")
	check(s.yeast >= 0.001 and s.lab >= 0.001, "V10 populations at or above the floor")
	check([&"freshly_fed", &"developing"].has(StateDeriver.derive(s, counter()).state), "V10 state")
	about("V10 next peak time", [rec.peak_t], 25.0, TOL_T)
	about("V10 next peak height", [rec.peak_rise], 2.6, TOL_R)


func test_v11_tiny_keeps() -> void:
	if not require(&"m2_sim"):
		return
	var base: StarterState = SimFixtures.mature()
	var a: StarterState = base.copy()
	Sim.feed(a, 1.0, {&"white_bread": 1.0}, 1.0, 0.5, false)
	var b: StarterState = base.copy()
	Sim.feed(b, 1.0, {&"white_bread": 50.0}, 50.0, 0.5, false)
	within("V11 1:1:1 like V2 22 C", [trace(a, 30.0, counter()).peak_t], 6.1, 6.3, TOL_T)
	about("V11 1:50:50 peak time", [trace(b, 30.0, counter()).peak_t], 18.0, TOL_T)
	var zero := FeedAction.new()
	zero.kept_g = 0.0
	zero.flour_g = {&"white_bread": 75.0}
	zero.water_g = 75.0
	check_eq(zero.validate(base, counter(), SimCatalog.builtin()), GameAction.REASON_KEEP_RANGE, "V11 keep 0 rejected")


func test_v12_hot() -> void:
	if not require(&"m2_sim"):
		return
	var base: StarterState = SimFixtures.mature()
	for row: Array in [[32.0, Vector2(4.5, 4.6)], [35.0, Vector2(5.0, 5.2)]]:
		var t: float = row[0]
		var recs: Array[Trace] = ratio_vector(base, 1, 1, t, 50, 48, [48])
		check_peak("V12 %d C" % roundi(t), recs, Vector2.ZERO, row[1])
		check_states("V12 %d C 48 h" % roundi(t), recs, 48, [&"dormant"])
		for r: Trace in recs:
			check_eq(r.row(48).mold_stage, &"watch", "V12 48 h mold stage")
			check(not r.row(48).smells.is_empty() and r.row(48).smells[0] == &"musty", "V12 48 h musty first")


func test_v13_long_absence_capped() -> void:
	if not require(&"m2_sim"):
		return
	var base: StarterState = SimFixtures.mature()
	var s: StarterState = advance(fed(base), 14 * 24.0, counter())
	check_eq(StateDeriver.derive(s, counter()).state, &"moldy", "V13 counter moldy at the cap")
	var f: StarterState = advance(advance(fed(base), 1.0, counter()), 14 * 24.0, fridge())
	check_eq(StateDeriver.derive(f, fridge()).state, &"dormant", "V13 fridge dormant")
	check_between(f.vigor, 0.6, 0.7, "V13 fridge vigor")
	check(f.mold_risk < 0.3, "V13 fridge mold < 0.3")


func test_v14_moldy_refuses_feed() -> void:
	if not require(&"m2_sim"):
		return
	var moldy: StarterState = advance(fed(SimFixtures.mature()), 14 * 24.0, counter())
	var before: Dictionary = moldy.to_dict()
	var after: StarterState = moldy.copy()
	check(not SimFixtures.feed_ratio(after), "V14 feed refused")
	check_eq(JSON.stringify(after.to_dict(), "", true, true), JSON.stringify(before, "", true, true), "V14 state unchanged")
	var later: StarterState = advance(moldy, 1.0, counter())
	check_eq(later.since_feed_s, moldy.since_feed_s + 3600.0, "V14 the clock moves")
	for k: String in ["food", "yeast", "lab", "acid", "rise", "hooch", "dryness", "vigor", "starved_h", "mold_risk", "temp_c"]:
		check_eq(later.get(k), moldy.get(k), "V14 %s unchanged" % k)


func test_v15_fridge_then_neglect() -> void:
	if not require(&"m2_sim"):
		return
	var f: StarterState = advance(advance(fed(SimFixtures.mature()), 1.0, counter()), 14 * 24.0, fridge())
	check_between(f.mold_risk, 0.10, 0.18, "V15 mold at exit")
	var first: Dictionary = state_times(f, 10 * 24.0, counter())[0]
	check_between(float(first.get(&"unhealthy", -1.0)), 55.0 - TOL_T, 65.0 + TOL_T, "V15 unhealthy after exit")
	check_between(float(first.get(&"moldy", -1.0)), 160.0 - TOL_T, 170.0 + TOL_T, "V15 moldy after exit")
	check(float(first.get(&"moldy", 0.0)) - float(first.get(&"unhealthy", 0.0)) >= 72.0, "V15 gap >= 72 h")


func test_v16_once_a_day() -> void:
	if not require(&"m2_sim"):
		return
	for t: float in [22.0, 24.0]:
		var env: EnvironmentState = env_at(t)
		var s: StarterState = at_temp(SimFixtures.mature(), t)
		var min_vigor: float = 1.0
		var max_mold: float = 0.0
		var seen: Dictionary = {}
		for day: int in 14:
			s = fed(s)
			for i: int in 24 * 60:
				min_vigor = minf(min_vigor, s.vigor)
				max_mold = maxf(max_mold, s.mold_risk)
				seen[StateDeriver.derive(s, env).state] = true
				Sim.step(s, env)
		check(min_vigor >= 0.8, "V16 %d C vigor >= 0.8, got %s" % [roundi(t), min_vigor])
		check_eq(max_mold, 0.0, "V16 %d C mold 0" % roundi(t))
		for bad: StringName in [&"recovering", &"dormant", &"unhealthy"]:
			check(not seen.has(bad), "V16 %d C never %s" % [roundi(t), bad])


## Any split of a 5-day run on the 60 s grid equals the unsplit run exactly (same build).
func test_v17_split_equals_unsplit() -> void:
	if not require(&"m2_sim"):
		return
	var whole: StarterState = advance(fed(SimFixtures.mature()), 5 * 24.0, counter())
	var rng := RandomNumberGenerator.new()
	for trial: int in 3:
		rng.seed = 7 + trial
		var split: StarterState = fed(SimFixtures.mature())
		var t: int = 0
		var total: int = 5 * 24 * 60
		while t < total:
			var n: int = mini(total - t, rng.randi_range(1, 120))
			for i: int in n:
				Sim.step(split, counter())
			t += n
		check_eq(JSON.stringify(split.to_dict(), "", true, true), JSON.stringify(whole.to_dict(), "", true, true),
			"V17 split run %d equals the unsplit run" % trial)


func test_v18_v19_slower_ratios_at_22c() -> void:
	if not require(&"m2_sim"):
		return
	var base: StarterState = SimFixtures.mature()
	check_peak("V18", ratio_vector(base, 1, 2, 22, 10), Vector2(8.0, 8.4), Vector2(8.1, 8.5), Vector2(2.34, 2.36))
	check_peak("V19", ratio_vector(base, 1, 5, 22, 10), Vector2(10.75, 11.4), Vector2(10.85, 11.5), Vector2(2.47, 2.50))


func test_v20_pour_off_vs_stir_in() -> void:
	if not require(&"m2_sim"):
		return
	var s: StarterState = advance(fed(SimFixtures.mature()), 36.0, counter())
	var pa: StarterState = fed(s, 1, 1, &"white_bread", 100.0, 50.0, 0.5, false)
	var sa: StarterState = fed(s, 1, 1, &"white_bread", 100.0, 50.0, 0.5, true)
	var ra: Trace = trace(pa, 24.0, counter())
	var rb: Trace = trace(sa, 24.0, counter())
	check(pa.hooch == 0.0 and sa.hooch == 0.0, "V20 hooch 0 after both")
	check_between(sa.culture_hydration - pa.culture_hydration, 0.5, 1.1, "V20 stir-in hydration gain")
	check(absf(ra.peak_t - rb.peak_t) <= 0.05 and absf(ra.peak_rise - rb.peak_rise) <= 0.01, "V20 peaks close")
	check_eq(pa.acid, sa.acid, "V20 acid identical")


static func _same_set(a: Array[StringName], b: Array[StringName]) -> bool:
	if a.size() != b.size():
		return false
	for x: StringName in a:
		if not b.has(x):
			return false
	return true

extends TestCase
## Phase 4, AC-17.1 to AC-17.3: the P1 inspection kinds follow spec §14, and every key any inspection can
## return is in the catalog.
## - AC-17.1 `consistency` at its thresholds (h_eff 75 and 110, acid 0.66, cold dormant), and over sampled
##   real states against an independent copy of spec §14's first-match rules.
## - AC-17.2 `development` at maturity 0.33, 0.50, 0.83 and vigor 0.6, 0.85, and the copy key it picks.
## - AC-17.3 every observation and meaning key of all 5 kinds, over states from real sim runs (every flour,
##   60, 100 and 125%, every place, fed then neglected to moldy), exists in en.csv with text and no digit.
## The spec numbers are written out here, not read from SimConstants, so a drifted constant fails.
## Spec v1.1 (scientist, 2026-11-27, not yet in the code) changes rye-majority airy paste to `airy_pasty`. The
## sampled comparison leaves that one case out until T1's commit, which adds it here in the same merge (OD-36).

const EPS: float = 1e-6
## Spec §4 `absorb`.
const ABSORB: Dictionary[StringName, float] = {
	&"white_bread": 1.00, &"whole_wheat": 1.12, &"rye": 1.25, &"spelt": 0.95,
}
const FLOURS: Array[StringName] = [&"white_bread", &"whole_wheat", &"rye", &"spelt"]
const HYDRATIONS: Array[float] = [60.0, 100.0, 125.0]
const KINDS: Array[StringName] = [&"bubbles", &"consistency", &"height", &"surface", &"development"]
const AIRY: Array[StringName] = [&"active", &"near_peak", &"at_peak"]
const SLACK: Array[StringName] = [&"collapsing", &"hungry"]
const CATALOG: String = "res://src/i18n/en.csv"

## Built once per file (the runner makes one instance per file), freed with it.
var _samples: Array[Array] = []


func test_ac_17_1_spec_absorb_matches_the_code() -> void:
	if not require(&"m2_sim"):
		return
	for f: StringName in FLOURS:
		var row: Array = SimConstants.FLOURS[f]
		check_eq(row[2], ABSORB[f], "spec §4 absorb for %s" % f)


func test_ac_17_1_consistency_thresholds() -> void:
	if not require(&"m2_sim"):
		return
	var counter: EnvironmentState = EnvironmentState.at_location(&"counter")
	# A freshly fed white starter: not slack, not airy, not cold. Stiff below h_eff 75, loose from 110.
	var fed: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(fed)
	for i: int in 6:
		Sim.step(fed, counter)
	var d: DerivedState = StateDeriver.derive(fed, counter)
	if not check_eq(d.rise_phase, &"freshly_fed", "precondition: 6 min after a feed is freshly_fed"):
		return
	var rows: Array[Array] = [[75.0 - 1e-4, &"stiff_dough"], [75.0, &"thick_batter"], [110.0 - 1e-4, &"thick_batter"],
		[110.0, &"loose_batter"]]
	for row: Array in rows:
		var s: StarterState = fed.copy()
		s.culture_hydration = row[0]
		check_eq(_obs(s, counter, &"consistency"), row[1], "white, culture hydration %s" % show(row[0]))
	# Rye absorbs more water (1.25), so the stiff edge sits at 93.75%: rye at 100% is not stiff.
	var rye: StarterState = fed.copy()
	rye.flour_mix = {&"rye": 1.0}
	rye.culture_hydration = 93.75 - 1e-4
	check_eq(_obs(rye, counter, &"consistency"), &"stiff_dough", "rye just under h_eff 75")
	rye.culture_hydration = 100.0
	check_ne(_obs(rye, counter, &"consistency"), &"stiff_dough", "rye at 100% (h_eff 80) is not stiff")
	# Acid 0.66 in a slack phase: MATURE is 12 h after a feed, collapsing or hungry.
	var slack: StarterState = SimFixtures.mature()
	var ds: DerivedState = StateDeriver.derive(slack, counter)
	if not check(SLACK.has(ds.rise_phase), "precondition: MATURE is collapsing or hungry (%s)" % ds.rise_phase):
		return
	slack.acid = 0.66 - EPS
	check_eq(_obs(slack, counter, &"consistency"), &"thick_batter", "acid just under 0.66")
	slack.acid = 0.66
	check_eq(_obs(slack, counter, &"consistency"), &"slack_soupy", "acid 0.66")
	# Cold dormant replaces airy, loose and thick with firm_cold; stiff still wins.
	var cold: StarterState = fed.copy()
	cold.temp_c = 4.0
	var fridge: EnvironmentState = EnvironmentState.at_location(&"fridge")
	var dc: DerivedState = StateDeriver.derive(cold, fridge)
	if not check(dc.state == &"dormant" and dc.dormant_cause == &"cold", "precondition: 4 °C is cold dormant"):
		return
	check_eq(_obs(cold, fridge, &"consistency"), &"firm_cold", "cold dormant")
	cold.culture_hydration = 60.0
	check_eq(_obs(cold, fridge, &"consistency"), &"stiff_dough", "stiff beats firm_cold")


func test_ac_17_1_consistency_matches_spec_14_over_real_states() -> void:
	if not require(&"m2_sim"):
		return
	var compared: int = 0
	var left_out: int = 0
	var misses: PackedStringArray = PackedStringArray()
	for sample: Array in _all_samples():
		var s: StarterState = sample[0]
		var env: EnvironmentState = sample[1]
		var d: DerivedState = StateDeriver.derive(s, env)
		var want: StringName = _consistency_oracle(s, d)
		if want == &"airy_webby" and s.flour_mix.get(&"rye", 0.0) >= 0.5:
			left_out += 1  # spec v1.1 `airy_pasty`, added with T1's commit
			continue
		compared += 1
		var got: StringName = _obs(s, env, &"consistency")
		if got != want and misses.size() < 8:
			misses.append("%s: got %s, spec §14 gives %s" % [sample[2], got, want])
	print("    AC-17.1: %d sampled states compared, %d rye-majority airy states left for spec v1.1" % [compared, left_out])
	check(compared > 1000, "enough states compared (%d)" % compared)
	check(misses.is_empty(), "consistency differs from spec §14:\n    " + "\n    ".join(misses))


func test_ac_17_2_development_thresholds_and_keys() -> void:
	if not require(&"m2_sim"):
		return
	var counter: EnvironmentState = EnvironmentState.at_location(&"counter")
	var base: StarterState = SimFixtures.mature()
	base.vigor = 0.9
	var stages: Array[Array] = [[0.33, &"young", &"steady"], [0.50, &"steady", &"mature"], [0.83, &"mature", &"seasoned"]]
	for row: Array in stages:
		var s: StarterState = base.copy()
		s.maturity = float(row[0]) - EPS
		check_eq(_development(s, counter)[0], row[1], "maturity just under %s" % show(row[0]))
		s.maturity = row[0]
		check_eq(_development(s, counter)[0], row[2], "maturity %s" % show(row[0]))
		var keys: PackedStringArray = Inspection.keys(&"development", s, StateDeriver.derive(s, counter))
		check_eq(keys[0], "INSPECT_DEVELOPMENT_%s_OBS" % String(row[2]).to_upper(), "the stage's copy key")
	var strengths: Array[Array] = [[0.6, &"weakened", &"steady"], [0.85, &"steady", &"strong"]]
	for row: Array in strengths:
		var s: StarterState = base.copy()
		s.vigor = float(row[0]) - EPS
		check_eq(_development(s, counter)[1], row[1], "vigor just under %s" % show(row[0]))
		s.vigor = row[0]
		check_eq(_development(s, counter)[1], row[2], "vigor %s" % show(row[0]))
	var weak: StarterState = base.copy()
	weak.vigor = 0.6 - EPS
	check_eq(Inspection.keys(&"development", weak, StateDeriver.derive(weak, counter))[0],
		"INSPECT_DEVELOPMENT_WEAKENED_OBS", "vigor under 0.6 reads weakened, whatever the stage")
	var sick: StarterState = base.copy()
	sick.mold_risk = 0.5
	var dsick: DerivedState = StateDeriver.derive(sick, counter)
	if check_eq(dsick.state, &"unhealthy", "precondition: mold_risk 0.5 is unhealthy"):
		check_eq(Inspection.keys(&"development", sick, dsick)[0], "INSPECT_DEVELOPMENT_UNHEALTHY_OBS", "unhealthy")


func test_ac_17_3_every_inspection_key_is_in_the_catalog_without_digits() -> void:
	if not require(&"m2_sim"):
		return
	var catalog: Dictionary[String, String] = _catalog()
	check(catalog.size() > 500, "en.csv read (%d keys)" % catalog.size())
	var missing: Dictionary[String, String] = {}
	var digits: Dictionary[String, bool] = {}
	var moldy_bad: Dictionary[String, bool] = {}
	var keys_seen: Dictionary[String, bool] = {}
	var reads: int = 0
	var moldy_reads: int = 0
	for sample: Array in _all_samples():
		var s: StarterState = sample[0]
		var env: EnvironmentState = sample[1]
		for kind: StringName in KINDS:
			var r: InspectionReadout = Inspection.read(s, env, kind)
			reads += 1
			for key: String in [String(r.text_key), String(r.meaning_key)]:
				keys_seen[key] = true
				if not catalog.has(key) or catalog[key].strip_edges().is_empty():
					missing[key] = "%s %s" % [sample[2], kind]
				elif _has_digit(catalog[key]):
					digits[key] = true
			if s.moldy:
				moldy_reads += 1
				var mean: String = catalog.get(String(r.meaning_key), "")
				if not String(r.text_key).contains("MOLDY") or not mean.to_lower().contains("discard"):
					moldy_bad[String(r.text_key)] = true
	print("    AC-17.3: %d readouts, %d distinct keys, %d on a moldy starter" % [reads, keys_seen.size(), moldy_reads])
	check(moldy_reads > 0, "the samples reach moldy")
	var miss_lines: PackedStringArray = PackedStringArray()
	for k: String in missing:
		miss_lines.append("%s (first at %s)" % [k, missing[k]])
	check(missing.is_empty(), "inspection keys missing from en.csv:\n    " + "\n    ".join(miss_lines))
	check(digits.is_empty(), "inspection text with digits: %s" % ", ".join(digits.keys()))
	check(moldy_bad.is_empty(), "moldy readouts that aren't moldy keys or don't say discard: %s" % ", ".join(moldy_bad.keys()))


# ------------------------------------------------------------------ the oracle (spec §14, v1)

static func _consistency_oracle(s: StarterState, d: DerivedState) -> StringName:
	var absorb: float = 0.0
	for k: StringName in s.flour_mix:
		absorb += s.flour_mix[k] * ABSORB[k]
	var h_eff: float = s.culture_hydration / absorb
	if h_eff < 75.0:
		return &"stiff_dough"
	var slack: bool = SLACK.has(d.rise_phase) or (d.state == &"dormant" and d.dormant_cause == &"starved") \
		or d.state == &"unhealthy"
	if slack and s.acid >= 0.66:
		return &"slack_soupy"
	if d.state == &"dormant" and d.dormant_cause == &"cold":
		return &"firm_cold"
	if AIRY.has(d.rise_phase):
		return &"airy_webby"
	if h_eff >= 110.0:
		return &"loose_batter"
	return &"thick_batter"


static func _obs(s: StarterState, env: EnvironmentState, kind: StringName) -> StringName:
	var r: InspectionReadout = Inspection.read(s, env, kind)
	return r.observations[0] if not r.observations.is_empty() else &""


static func _development(s: StarterState, env: EnvironmentState) -> Array[StringName]:
	return Inspection.read(s, env, &"development").observations


# ------------------------------------------------------------------ sampled states

## [StarterState, EnvironmentState, label] from real runs. Built once per process (about 160,000 steps).
## For each flour and hydration: 3 conversion feeds 12 h apart at the counter, then a feed at each place and
## 36 h there, sampled every 90 min. Two long neglect runs (white 100%, rye 125%) go 10 days at the counter,
## to moldy. One risen-then-fridge run covers spec v1.1's dormant-and-risen case.
func _all_samples() -> Array[Array]:
	if not _samples.is_empty():
		return _samples
	var counter: EnvironmentState = EnvironmentState.at_location(&"counter")
	var places: Array[EnvironmentState] = [counter, EnvironmentState.at_location(&"warm_spot"),
		EnvironmentState.at_location(&"window_sill"), EnvironmentState.at_location(&"proofing_box"),
		EnvironmentState.at_location(&"fridge")]
	var hot: EnvironmentState = EnvironmentState.at_location(&"proofing_box")
	hot.temperature_c = 30.0
	places.append(hot)
	for flour: StringName in FLOURS:
		for h: float in HYDRATIONS:
			var s: StarterState = SimFixtures.mature()
			for n: int in 3:
				_feed(s, flour, h)
				_run(s, counter, 720, 0, "", [])
			for env: EnvironmentState in places:
				var t: StarterState = s.copy()
				_feed(t, flour, h)
				_run(t, env, 36 * 60, 90, "%s %d%% %s" % [flour, int(h), env.location], _samples)
	for case: Array in [[&"white_bread", 100.0], [&"rye", 125.0]]:
		var n: StarterState = SimFixtures.mature()
		_feed(n, case[0], case[1])
		_run(n, counter, 10 * 1440, 240, "%s %d%% neglected" % [case[0], int(case[1])], _samples)
	var risen: StarterState = SimFixtures.mature()
	_feed(risen, &"white_bread", 100.0)
	_run(risen, counter, 240, 0, "", [])
	_run(risen, places[4], 24 * 60, 60, "risen then fridge", _samples)
	return _samples


static func _feed(s: StarterState, flour: StringName, h: float) -> void:
	SimFixtures.feed_ratio(s, 1.0, 1.0, flour, h)


static func _run(s: StarterState, env: EnvironmentState, steps: int, every: int, label: String,
		out: Array[Array]) -> void:
	for i: int in steps:
		Sim.step(s, env)
		if every > 0 and (i + 1) % every == 0:
			out.append([s.copy(), env, "%s at %.1f h" % [label, (i + 1) / 60.0]])


static func _catalog() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	var f: FileAccess = FileAccess.open(CATALOG, FileAccess.READ)
	if f == null:
		return out
	f.get_csv_line()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() >= 2 and row[0] != "":
			out[row[0]] = row[1]
	return out


static func _has_digit(text: String) -> bool:
	for c: String in text:
		if c >= "0" and c <= "9":
			return true
	return false

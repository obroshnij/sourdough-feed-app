extends TestCase
## AC-07.1 to 07.3: the smell model and the smell card's text rules.
## - 07.1: SmellModel.intensities equals an independent transcription of spec §13 within 1e-9, across a
##   1:1:1 cycle, a long neglect and the fridge. The display rules (top 3 at 0.15 or more, musty first,
##   ties by the vision order, word bands) and the §13 primary-by-hour script hold.
## - 07.2: SmellCardText's line is 1 + (feed_count + order) % 3. Smelling again in a cycle repeats it,
##   every variant appears within any 3 consecutive feeds, and no line repeats on consecutive cycles.
## - 07.3: musty shows from mold_risk 0.3 (not 0.3 - ε), at least 0.2, first, at any temperature from 0 to
##   40 °C, and its meaning line never fades.

const ORDER: Array[StringName] = [
	&"wet_flour", &"mildly_fruity", &"fresh_yeasty", &"yogurt", &"pleasantly_tangy",
	&"strongly_acidic", &"alcohol", &"acetone", &"cheesy", &"musty",
]
const EPS: float = 1e-6


func test_ac_07_1_intensities_match_spec_13_and_the_display_rules() -> void:
	if not require(&"m2_sim"):
		return
	var counter: EnvironmentState = EnvironmentState.at_location(&"counter")
	var fridge: EnvironmentState = EnvironmentState.at_location(&"fridge")
	var s: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(s)
	var samples: int = 0
	var off: PackedStringArray = PackedStringArray()
	for minute: int in 10 * 24 * 60:
		var env: EnvironmentState = fridge if minute >= 9 * 24 * 60 else counter
		Sim.step(s, env)
		if minute % 37 != 0:
			continue
		samples += 1
		var got: Dictionary[StringName, float] = SmellModel.intensities(s, env)
		var want: Dictionary[StringName, float] = _spec_13(s, env)
		for d: StringName in ORDER:
			if not is_close(got.get(d, 0.0), want[d], 1e-9, 1e-12):
				off.append("%s at %d min: %s vs spec %s" % [d, minute, show(got.get(d, 0.0)), show(want[d])])
		var shown: Array[StringName] = SmellModel.shown(got)
		var expect: Array[StringName] = _spec_shown(want)
		if shown != expect:
			off.append("shown at %d min: %s vs %s" % [minute, shown, expect])
	check(samples > 300, "sampled %d states (cycle, neglect, fridge)" % samples)
	check(off.is_empty(), "SmellModel vs spec §13:\n    " + "\n    ".join(off.slice(0, 8)))
	for pair: Array in [[0.149999, &""], [0.15, &"faint"], [0.349999, &"faint"], [0.35, &"clear"],
			[0.699999, &"clear"], [0.7, &"strong"]]:
		var v: float = pair[0]
		var w: StringName = pair[1]
		if w != &"":
			check_eq(SmellModel.intensity_word(v), w, "word at %s" % v)
	# §13 script: the primary through a 1:1:1 cycle at 22 °C (mid-window hours).
	var cycle: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(cycle)
	var script: Array[Array] = [[1.0, &"wet_flour"], [2.75, &"fresh_yeasty"], [4.5, &"yogurt"],
		[10.0, &"pleasantly_tangy"], [20.0, &"alcohol"]]
	var done_min: int = 0
	for row: Array in script:
		var at_min: int = roundi(float(row[0]) * 60.0)
		while done_min < at_min:
			Sim.step(cycle, counter)
			done_min += 1
		check_eq(SmellModel.read(cycle, counter).primary, row[1], "primary at %.2f h" % row[0])


func test_ac_07_2_sensory_line_variants_rotate_with_feeds() -> void:
	if not require(&"m2_sim"):
		return
	var r := SmellReadout.new()
	for d: StringName in ORDER.slice(0, 9):
		r.primary = d
		r.intensities = {d: 0.6}
		r.intensity_value = 0.6
		var lines: Array[StringName] = []
		for feeds: int in 9:
			var first: SmellCardText = SmellCardText.build(r, false, feeds, 1)
			var again: SmellCardText = SmellCardText.build(r, false, feeds, 2)
			check_eq(again.body_key, first.body_key, "%s: smelling again in a cycle repeats the line" % d)
			var n: int = 1 + posmod(feeds + ORDER.find(d), 3)
			check(String(first.body_key).ends_with("_%d" % n), "%s after %d feeds: line %d (%s)" % [d, feeds, n, first.body_key])
			lines.append(first.body_key)
		for i: int in range(1, lines.size()):
			check_ne(lines[i], lines[i - 1], "%s: no line repeats on consecutive cycles" % d)
		for i: int in range(0, lines.size() - 2):
			var window: Dictionary[StringName, bool] = {lines[i]: true, lines[i + 1]: true, lines[i + 2]: true}
			check_eq(window.size(), 3, "%s: all 3 variants within feeds %d to %d" % [d, i, i + 2])


func test_ac_07_3_musty_from_the_watch_stage_at_any_temperature() -> void:
	if not require(&"m2_sim"):
		return
	var base: StarterState = SimFixtures.mature()
	SimFixtures.feed_ratio(base)
	for i: int in 30 * 60:
		Sim.step(base, EnvironmentState.at_location(&"counter"))
	for t: int in range(0, 41):
		var env: EnvironmentState = EnvironmentState.make(float(t), 50.0)
		var s: StarterState = base.copy()
		s.temp_c = float(t)
		s.mold_risk = 0.3 - EPS
		check(not SmellModel.read(s, env).secondary.has(&"musty") and SmellModel.read(s, env).primary != &"musty",
			"%d °C: no musty just below 0.3" % t)
		s.mold_risk = 0.3
		var r: SmellReadout = SmellModel.read(s, env)
		check(r.primary == &"musty" and r.intensities[&"musty"] >= 0.2 and r.is_warning,
			"%d °C: musty first, at least 0.2, a warning, at 0.3" % t)
		var card_first: SmellCardText = SmellCardText.build(r, false, 4, 1)
		var card_late: SmellCardText = SmellCardText.build(r, false, 4, 9)
		check(card_first.meaning_key != &"" and card_late.meaning_key == card_first.meaning_key,
			"%d °C: musty's meaning line shows every time" % t)


## Spec §13, transcribed independently of SmellModel.
static func _spec_13(s: StarterState, env: EnvironmentState) -> Dictionary[StringName, float]:
	if s.moldy:  # "moldy: {musty: 1.0} only"
		var only: Dictionary[StringName, float] = {}
		for d: StringName in ORDER:
			only[d] = 1.0 if d == &"musty" else 0.0
		return only
	var gas_n: float = clampf(Sim.rates(s, env).gas, 0.0, 1.0)
	var p: float = 1.0 if s.food_at_feed <= 0.0 else clampf(1.0 - s.food / s.food_at_feed, 0.0, 1.0)
	var damp: float = clampf(0.35 + 0.65 * Sim.ferm(s.temp_c), 0.0, 1.0)
	var out: Dictionary[StringName, float] = {
		&"wet_flour": clampf(1.0 - p / 0.3, 0.0, 1.0),
		&"mildly_fruity": 0.9 * gas_n * _tri(p, 0.05, 0.3, 0.7),
		&"fresh_yeasty": gas_n * clampf(s.yeast / 0.5, 0.0, 1.0),
		&"yogurt": _tri(s.acid, 0.25, 0.45, 0.70) * clampf(0.3 + gas_n, 0.0, 1.0),
		&"pleasantly_tangy": _tri(s.acid, 0.40, 0.58, 0.72),
		&"strongly_acidic": clampf((s.acid - 0.66) / 0.15, 0.0, 1.0),
		&"alcohol": 0.8 * clampf(s.starved_h / 10.0, 0.0, 1.0) + 0.2 * s.hooch,
		&"acetone": clampf((s.starved_h - 14.0) / 24.0, 0.0, 1.0),
		&"cheesy": clampf((0.33 - s.maturity) / 0.13, 0.0, 1.0) * (0.5 + 0.5 * gas_n),
	}
	for d: StringName in out:
		out[d] = out[d] * damp
	out[&"musty"] = 0.0 if s.mold_risk < 0.3 else maxf(0.2, clampf((s.mold_risk - 0.2) / 0.5, 0.0, 1.0))
	return out


static func _tri(x: float, a: float, b: float, c: float) -> float:
	if x <= a or x >= c:
		return 0.0
	return (x - a) / (b - a) if x <= b else (c - x) / (c - b)


## Spec §13 display: intensity 0.15 or more, musty first, then strongest, ties by the vision order, top 3.
static func _spec_shown(v: Dictionary[StringName, float]) -> Array[StringName]:
	var picked: Array[StringName] = []
	for d: StringName in ORDER:
		if v[d] >= 0.15:
			picked.append(d)
	picked.sort_custom(func(a: StringName, b: StringName) -> bool:
		if (a == &"musty") != (b == &"musty"):
			return a == &"musty"
		if v[a] != v[b]:
			return v[a] > v[b]
		return ORDER.find(a) < ORDER.find(b))
	return picked.slice(0, 3)

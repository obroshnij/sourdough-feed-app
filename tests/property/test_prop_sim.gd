extends TestCase
## Property tests over random schedules (test-plan §2.3, AC-04.6): PROP-03 ranges, PROP-04 mold only
## from its causes, PROP-05 mold is latched, PROP-08 feeding never hurts, PROP-09 closed vocabulary,
## PROP-14 maturity only grows. Pure sim, no files. The generator is a test-local seeded RNG, so a
## failure prints its schedule seed and can be replayed with --filter. PROP-01, 02 and 13 are covered
## elsewhere (t1/catch_up, save/payload, int/ac09).
##
## Schedules mix slice feeds with sim-level feeds (keep 1 g and up, ratios up to 1:50:50, all four
## flours, hydration 40 to 200%, stir-in), every location including proofing_box at 24 to 30 °C, and
## gaps from 1 minute to 6 days. `--seeds=<n>` sets the schedule count (default 100).

const MAX_STEPS: int = 2 * 1440
## Every NEGLECTED_EVERY-th schedule starts from a starter left 200 h unfed at the counter (unhealthy,
## close to mold), so the mold latch and refused feeds are exercised.
const NEGLECTED_EVERY: int = 4
const NEGLECTED_H: int = 200
const SEED_BASE: int = 41_000
const RATIOS: Array[float] = [1.0, 2.0, 5.0, 10.0, 50.0]
const HYDRATIONS: Array[float] = [60.0, 100.0, 100.0, 125.0, 40.0, 200.0]
## Spec §1. Each [field, low, high].
const RANGES: Array[Array] = [
	["food", 0.0, 1.0], ["food_at_feed", 0.0, 1.0], ["acid", 0.0, 1.0], ["hooch", 0.0, 1.0],
	["dryness", 0.0, 1.0], ["maturity", 0.0, 1.0], ["mold_risk", 0.0, 1.0],
	["vigor", 0.15, 1.0], ["vigor_at_feed", 0.15, 1.0], ["yeast", 0.001, 1.5], ["lab", 0.001, 1.5],
	["rise", 1.0, 3.0], ["peak_rise", 1.0, 3.0], ["starved_h", 0.0, 336.0], ["temp_c", 0.0, 40.0],
	["culture_hydration", 40.0, 200.0], ["feed_jitter", 0.95, 1.05],
]

var _neglected: StarterState = null


func test_prop_03_04_05_08_09_14_over_random_schedules() -> void:
	if not require(&"m2_sim"):
		return
	var problems: PackedStringArray = PackedStringArray()
	var steps_total: int = 0
	var feeds_total: int = 0
	var moldy_runs: int = 0
	for i: int in seeds():
		var schedule_seed: int = SEED_BASE + i
		var out: Dictionary = _run_schedule(schedule_seed)
		var found: PackedStringArray = out["problems"]
		steps_total += int(out["steps"])
		feeds_total += int(out["feeds"])
		moldy_runs += 1 if bool(out["moldy"]) else 0
		for p: String in found:
			problems.append("seed %d: %s" % [schedule_seed, p])
		if problems.size() > 12:
			break
	check(problems.is_empty(), "%d violations:\n    %s" % [problems.size(), "\n    ".join(problems.slice(0, 12))])
	check(steps_total >= seeds() * MAX_STEPS, "every schedule ran to the end (%d steps, %d feeds)" % [steps_total, feeds_total])
	check(moldy_runs >= 1, "at least one schedule reached moldy, so PROP-05 was exercised (%d)" % moldy_runs)


## PROP-06: for a 1:1:1 feed on MATURE (feed_u 0.5), the time to peak falls from 12 °C to the
## optimum and then rises, sampled every 1 °C up to 36 °C: exactly one valley, no second dip.
func test_prop_06_peak_time_has_one_valley_over_temperature() -> void:
	if not require(&"m2_sim"):
		return
	var times: Array[float] = []
	for t: int in range(12, 37):
		times.append(_peak_hours(1.0, EnvironmentState.make(float(t), 50.0)))
	var valley: int = times.find(times.min())
	var bumps: PackedStringArray = PackedStringArray()
	for i: int in range(1, times.size()):
		var falling: bool = i <= valley
		if falling and times[i] > times[i - 1]:
			bumps.append("%d °C slower than %d °C" % [12 + i, 11 + i])
		if not falling and times[i] < times[i - 1]:
			bumps.append("%d °C faster than %d °C" % [12 + i, 11 + i])
	check(valley > 0 and valley < times.size() - 1, "the fastest peak is inside 12 to 36 °C (at %d °C)" % (12 + valley))
	check(bumps.is_empty(), "one valley: " + ", ".join(bumps))
	check(times.all(func(h: float) -> bool: return h > 0.0), "every temperature peaks within 48 h")


## PROP-07: at 24 °C, 1:1:1 < 1:2:2 < 1:5:5 < 1:10:10 < 1:50:50 in time to peak.
func test_prop_07_more_dilution_peaks_later() -> void:
	if not require(&"m2_sim"):
		return
	var env: EnvironmentState = EnvironmentState.make(24.0, 50.0)
	var prev: float = 0.0
	for f: float in RATIOS:
		var h: float = _peak_hours(f, env)
		check(h > prev, "1:%d:%d peaks later than the ratio before (%.2f h after %.2f h)" % [int(f), int(f), h, prev])
		prev = h


## Hours from a 1 : f : f feed on MATURE (feed_u 0.5) to the highest rise, within 48 h. -1 if none.
static func _peak_hours(f: float, env: EnvironmentState) -> float:
	var s: StarterState = SimFixtures.mature()
	s.temp_c = env.temperature_c
	SimFixtures.feed_ratio(s, 1.0, f)
	var best: float = s.rise
	var best_step: int = -1
	for step: int in 48 * 60:
		Sim.step(s, env)
		if s.rise > best:
			best = s.rise
			best_step = step + 1
		elif best_step > 0 and s.rise < best - 0.05:
			break
	return float(best_step) / 60.0 if best_step > 0 else -1.0


## Runs one random schedule and returns {"problems", "steps", "feeds", "moldy"}.
func _run_schedule(schedule_seed: int) -> Dictionary:
	var gen := RandomNumberGenerator.new()
	gen.seed = schedule_seed
	var env: EnvironmentState = EnvironmentState.at_location(&"counter")
	var s: StarterState = _neglected_start(env) if schedule_seed % NEGLECTED_EVERY == 0 else SimFixtures.mature()
	var problems: PackedStringArray = PackedStringArray()
	var steps: int = 0
	var feeds: int = 0
	var long_gap_left: int = 1 if gen.randf() < 0.3 else 0
	while steps < MAX_STEPS and problems.size() < 4:
		var roll: float = gen.randf()
		if roll < 0.25:
			feeds += 1
			_feed(s, gen, problems, steps)
		elif roll < 0.40:
			env = _move(gen)
		var gap: int = gen.randi_range(1, 18 * 60)
		if long_gap_left > 0 and gen.randf() < 0.2:
			gap = gen.randi_range(24 * 60, 6 * 1440)
			long_gap_left -= 1
		gap = mini(gap, MAX_STEPS - steps)
		for k: int in gap:
			var food: float = s.food
			var starved_h: float = s.starved_h
			var mold_risk: float = s.mold_risk
			var maturity: float = s.maturity
			var was_moldy: bool = s.moldy
			Sim.step(s, env)
			steps += 1
			if s.mold_risk > mold_risk and not (food < SimConstants.HUNGRY_FOOD and starved_h > SimConstants.MOLD_ONSET_H):
				problems.append("PROP-04: mold_risk rose with food %.4f, starved_h %.2f at step %d" % [food, starved_h, steps])
			if was_moldy and not s.moldy:
				problems.append("PROP-05: moldy cleared at step %d" % steps)
			if s.maturity < maturity:
				problems.append("PROP-14: maturity fell at step %d" % steps)
			_check_step(s, env, problems, steps)
			if problems.size() >= 4:
				break
		if steps % 97 == 0:
			_check_smell(s, env, problems, steps)
	return {"problems": problems, "steps": steps, "feeds": feeds, "moldy": s.moldy}


func _feed(s: StarterState, gen: RandomNumberGenerator, problems: PackedStringArray, at: int) -> void:
	var before: StarterState = s.copy()
	var f: float = RATIOS[gen.randi_range(0, RATIOS.size() - 1)]
	var keep: float = roundf(150.0 / (1.0 + 2.0 * f))
	if gen.randf() < 0.3:
		keep = float(gen.randi_range(1, maxi(1, int(s.mass_g))))
	var hydration: float = HYDRATIONS[gen.randi_range(0, HYDRATIONS.size() - 1)]
	var flour: StringName = SimConstants.FLOUR_IDS[gen.randi_range(0, SimConstants.FLOUR_IDS.size() - 1)]
	var flour_g: float = keep * f
	var u: float = minf(gen.randf(), 0.9999999)
	var stir_in: bool = gen.randf() < 0.3
	var fed: bool = Sim.feed(s, keep, {flour: flour_g}, flour_g * hydration / 100.0, u, stir_in)
	if before.moldy:
		if fed:
			problems.append("PROP-05: a moldy starter accepted a feed at step %d" % at)
		if s.to_dict() != before.to_dict():
			problems.append("PROP-05: a refused feed changed the state at step %d" % at)
		return
	if not fed:
		problems.append("a feed on a non-moldy starter was refused at step %d" % at)
	if s.mold_risk > before.mold_risk:
		problems.append("PROP-08: a feed raised mold_risk %.6f -> %.6f at step %d" % [before.mold_risk, s.mold_risk, at])
	if s.maturity < before.maturity:
		problems.append("PROP-14: a feed lowered maturity at step %d" % at)
	_check_ranges(s, problems, "after a feed at step %d" % at)


func _move(gen: RandomNumberGenerator) -> EnvironmentState:
	var id: StringName = SimConstants.LOCATION_IDS[gen.randi_range(0, SimConstants.LOCATION_IDS.size() - 1)]
	var e: EnvironmentState = EnvironmentState.at_location(id)
	if id == &"proofing_box":
		e.temperature_c = float(gen.randi_range(24, 30))
	return e


## MATURE, fed 1:1:1, then NEGLECTED_H hours unfed at the counter. Computed once.
func _neglected_start(env: EnvironmentState) -> StarterState:
	if _neglected == null:
		_neglected = SimFixtures.mature()
		SimFixtures.feed_ratio(_neglected)
		for i: int in NEGLECTED_H * 60:
			Sim.step(_neglected, env)
	return _neglected.copy()


func _check_step(s: StarterState, env: EnvironmentState, problems: PackedStringArray, at: int) -> void:
	_check_ranges(s, problems, "at step %d" % at)
	var state: StringName = StateDeriver.derive(s, env).state
	if not SimConstants.STATES.has(state):
		problems.append("PROP-09: unknown state %s at step %d" % [state, at])
	if s.moldy and state != &"moldy":
		problems.append("PROP-05: a moldy starter derived %s at step %d" % [state, at])


func _check_ranges(s: StarterState, problems: PackedStringArray, where: String) -> void:
	for r: Array in RANGES:
		var field: String = r[0]
		var v: float = s.get(field)
		var low: float = r[1]
		var high: float = r[2]
		if is_nan(v) or is_inf(v) or v < low or v > high:
			problems.append("PROP-03: %s = %s outside %s to %s %s" % [field, show(v), show(low), show(high), where])
	if s.peak_rate < 0.0 or is_nan(s.peak_rate):
		problems.append("PROP-03: peak_rate %s %s" % [show(s.peak_rate), where])
	if s.mass_g < 1.0 or s.since_feed_s < 0.0:
		problems.append("PROP-03: mass_g %s or since_feed_s %s %s" % [show(s.mass_g), show(s.since_feed_s), where])
	if s.feed_u < 0.0 or s.feed_u >= 1.0:
		problems.append("PROP-03: feed_u %s %s" % [show(s.feed_u), where])
	var share: float = 0.0
	for k: StringName in s.flour_mix:
		share += s.flour_mix[k]
	if absf(share - 1.0) > 1e-9:
		problems.append("PROP-03: flour_mix sums to %s %s" % [show(share), where])


func _check_smell(s: StarterState, env: EnvironmentState, problems: PackedStringArray, at: int) -> void:
	var smell: SmellReadout = SmellModel.read(s, env)
	for d: StringName in [smell.primary] + smell.secondary:
		if d != &"" and not SimConstants.DESCRIPTORS.has(d):
			problems.append("PROP-09: unknown smell %s at step %d" % [d, at])
	if s.moldy and (smell.primary != &"musty" or not smell.secondary.is_empty()):
		problems.append("moldy smell is not musty only at step %d" % at)

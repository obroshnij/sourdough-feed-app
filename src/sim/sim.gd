class_name Sim
extends RefCounted
## The starter model, spec v1 (docs/starter-simulation-spec.md).
## A line-by-line port of tools/sim-reference/sim.py. It repeats the same float operations in the same order
## (integer powers as plain multiplication, fractional powers with pow, the lag with exp, the maturity weight
## as log(x) / log(3)), so qa-engineer's DIFF-01 can match the reference traces at 1e-9.
## Pure: no engine state. Time arrives as arguments; the only randomness is the RNG passed to apply_feed.

static var _ferm_ref: float = ctmi(24.0, -2.0, 34.0, 45.0)


## The 60 s grid point at or before t (architecture.md §5.1).
static func grid(t: int) -> int:
	return t - posmod(t, SimConstants.GRID_S)


# ------------------------------------------------------------------ temperature (spec §3)
static func ctmi(t: float, tmin: float, topt: float, tmax: float) -> float:
	if t <= tmin or t >= tmax:
		return 0.0
	var dmin: float = t - tmin
	var num: float = (t - tmax) * dmin * dmin
	var den: float = (topt - tmin) * ((topt - tmin) * (t - topt) - (topt - tmax) * (topt + tmin - 2.0 * t))
	return maxf(0.0, num / den)


static func ferm(t: float) -> float:
	return ctmi(t, -2.0, 34.0, 45.0) / _ferm_ref


static func dec(t: float) -> float:
	var m: float = pow(2.2, (t - 24.0) / 10.0)
	if t > 34.0:
		m *= maxf(0.0, (45.0 - t) / 11.0)
	return m


static func mold_t(t: float) -> float:
	if t > 3.0:
		return clampf(0.05 + 0.05 * (t - 3.0), 0.0, 1.6)
	return maxf(0.0, 0.05 * t / 3.0)


# ------------------------------------------------------------------ rates (spec §5, §7, §10, §11)
static func rates(s: StarterState, env: EnvironmentState) -> SimRates:
	var r := SimRates.new()
	var t: float = s.temp_c
	var sp: float = 0.0
	var ac: float = 0.0
	var ab: float = 0.0
	var rt: float = 0.0
	for k: StringName in s.flour_mix:
		var w: float = s.flour_mix[k]
		var row: Array = SimConstants.FLOURS[k]
		var f_speed: float = row[0]
		var f_acid: float = row[1]
		var f_absorb: float = row[2]
		var f_retain: float = row[3]
		sp += w * f_speed
		ac += w * f_acid
		ab += w * f_absorb
		rt += w * f_retain
	var h_eff: float = s.culture_hydration / ab
	var hyd_speed: float = clampf(pow(h_eff / 100.0, 0.6), 0.6, 1.2)
	var hyd_ret: float = clampf(pow(100.0 / h_eff, 0.5), 0.6, 1.35)
	var hyd_acid: float = clampf(pow(100.0 / h_eff, 0.3), 0.85, 1.2)
	var hyd_hooch: float = clampf((h_eff - 55.0) / 45.0, 0.0, 1.6)
	var mat_f: float = 0.7 + 0.3 * minf(1.0, s.maturity / 0.5)
	var f: float = ferm(t)
	var d: float = dec(t)
	var phy: float = ctmi(t, SimConstants.Y_TMIN, SimConstants.Y_TOPT, SimConstants.Y_TMAX)
	var phl: float = ctmi(t, SimConstants.L_TMIN, SimConstants.L_TOPT, SimConstants.L_TMAX)
	var sf: float = s.food / (SimConstants.KS_FOOD + s.food)
	var hunger: float = maxf(0.0, 1.0 - sf * (1.0 + SimConstants.KS_FOOD))
	var starving: bool = s.food < SimConstants.HUNGRY_FOOD
	var k: float = s.vigor * sp * hyd_speed * s.feed_jitter * mat_f
	var al: float = s.acid / SimConstants.L_ACID_STOP
	var ay: float = s.acid / SimConstants.Y_ACID_STOP
	var inh_l: float = maxf(0.0, 1.0 - al * al * al * al)
	var inh_y: float = maxf(0.0, 1.0 - ay * ay * ay)
	var g_y: float = SimConstants.MU_Y * phy * k * sf * inh_y * (1.0 - s.yeast / SimConstants.CAP)
	var g_l: float = SimConstants.MU_L * phl * k * sf * inh_l * (1.0 - s.lab / SimConstants.CAP)
	var act: float = (s.yeast + 0.6 * s.lab) * f * sf * minf(1.0, 0.5 + 0.5 * s.vigor)
	var gas: float = (s.yeast + SimConstants.LAB_GAS * s.lab) * f * sf * s.vigor * mat_f
	r.gas = gas
	r.starving = starving
	r.yeast = g_y * s.yeast - SimConstants.DEATH_Y * d * s.yeast * hunger
	r.lab = g_l * s.lab - SimConstants.DEATH_L * d * s.lab * hunger
	r.food = -SimConstants.EAT * act * sp
	r.rise = SimConstants.GAS_GAIN * gas * rt * hyd_ret \
		- SimConstants.LEAK * (s.rise - 1.0) * (1.0 + SimConstants.LEAK_ACID * s.acid)
	r.acid = (SimConstants.ACID_RATE * s.lab * f * sf + SimConstants.ACID_STARVE * s.lab * f * hunger) \
		* ac * hyd_acid * (1.0 - s.acid)
	r.starved_h = d if starving else 0.0
	if s.starved_h > SimConstants.HOOCH_DELAY_H:
		r.hooch = SimConstants.HOOCH_RATE * f * hyd_hooch * hunger
	else:
		r.hooch = 0.0
	if starving and s.starved_h > SimConstants.VIGOR_GRACE_H:
		r.vigor = -SimConstants.VIGOR_LOSS * d
	elif not starving:
		r.vigor = SimConstants.VIGOR_GAIN * (1.0 - s.vigor) * sf * minf(1.0, phy + phl)
	else:
		r.vigor = 0.0
	var cover_dry: float = SimConstants.COVER_DRY[env.cover]
	var container_dry: float = SimConstants.CONTAINER_DRY[env.container]
	r.dryness = (SimConstants.DRY_RATE * cover_dry * container_dry
		* (1.0 - env.humidity_pct / 100.0) * (1.0 - s.dryness) * minf(1.5, d))
	if starving and s.starved_h > SimConstants.MOLD_ONSET_H:
		var mult: float = minf(SimConstants.MOLD_MULT_CAP, mold_t(t) * (1.0 + 0.4 * s.dryness))
		r.mold_risk = SimConstants.MOLD_RATE * mult * (1.0 - SimConstants.MOLD_SLOW * s.mold_risk)
	elif not starving:
		r.mold_risk = -SimConstants.MOLD_DECAY * sf
	else:
		r.mold_risk = 0.0
	return r


# ------------------------------------------------------------------ step (spec §7 per-step procedure)
## Advances `s` by one grid step, in place. Also advances `sim_time_unix` by dt_s.
static func step(s: StarterState, env: EnvironmentState, dt_s: float = SimConstants.DT_S) -> void:
	var dt_h: float = dt_s / 3600.0
	var t_env: float = clampf(env.temperature_c, SimConstants.T_ENV_MIN, SimConstants.T_ENV_MAX)  # 1
	s.sim_time_unix += int(dt_s)
	if s.moldy:
		s.since_feed_s = s.since_feed_s + dt_s
		return
	var r: SimRates = rates(s, env)  # 2
	var old_temp: float = s.temp_c
	s.food = clampf(s.food + r.food * dt_h, 0.0, 1.0)  # 3, 4
	s.yeast = clampf(s.yeast + r.yeast * dt_h, SimConstants.POP_FLOOR, SimConstants.CAP)
	s.lab = clampf(s.lab + r.lab * dt_h, SimConstants.POP_FLOOR, SimConstants.CAP)
	s.acid = clampf(s.acid + r.acid * dt_h, 0.0, 1.0)
	var old_peak_rise: float = s.peak_rise
	s.rise = clampf(s.rise + r.rise * dt_h, SimConstants.RISE_MIN, SimConstants.RISE_MAX)
	s.hooch = clampf(s.hooch + r.hooch * dt_h, 0.0, 1.0)
	s.dryness = clampf(s.dryness + r.dryness * dt_h, 0.0, 1.0)
	s.vigor = clampf(s.vigor + r.vigor * dt_h, SimConstants.VIGOR_FLOOR, 1.0)
	s.starved_h = clampf(s.starved_h + r.starved_h * dt_h, 0.0, SimConstants.STARVED_H_MAX)
	s.mold_risk = clampf(s.mold_risk + r.mold_risk * dt_h, 0.0, 1.0)
	if s.mold_risk >= 1.0:  # 5
		s.moldy = true
	s.peak_rise = maxf(old_peak_rise, s.rise)  # 6
	s.peak_rate = maxf(s.peak_rate, r.rise)
	s.temp_c = old_temp + (t_env - old_temp) * (1.0 - exp(-dt_h / SimConstants.TAU_H))  # 7
	s.since_feed_s = s.since_feed_s + dt_s  # 8


# ------------------------------------------------------------------ feeding (spec §6)
## Feeds `s` in place. `flours` maps flour id (StringName or String) to grams. Returns false and changes
## nothing when the starter is moldy (a refused feed).
static func feed(s: StarterState, kept_g: float, flours: Dictionary, water_g: float, feed_u: float,
		stir_in: bool) -> bool:
	if s.moldy:
		return false
	var flour_g: float = 0.0
	for k: Variant in flours:
		var g: float = flours[k]
		flour_g += g
	var kept: float = maxf(1.0, minf(kept_g, s.mass_g))
	var total: float = kept + flour_g + water_g
	var p: float = kept / total
	if s.peak_rise >= 1.5 and s.vigor >= SimConstants.RECOVER_VIGOR:
		var w: float = minf(SimConstants.MAT_W_CAP, log(total / kept) / log(3.0))
		s.maturity = minf(1.0, s.maturity + SimConstants.MAT_STEP * w * (1.0 - s.maturity))
	var kept_flour: float = kept * 100.0 / (100.0 + s.culture_hydration)
	var kept_water: float = kept - kept_flour
	if stir_in:
		kept_water += 5.0 * s.hooch * kept_flour / 100.0
	var new_flour: float = kept_flour + flour_g
	s.food = (kept_flour * s.food + flour_g) / new_flour
	var mix: Dictionary[StringName, float] = {}
	for k: StringName in s.flour_mix:
		mix[k] = s.flour_mix[k] * kept_flour
	for k: Variant in flours:
		var id: StringName = StringName("%s" % [k])
		var g: float = flours[k]
		mix[id] = mix.get(id, 0.0) + g
	var shares: Dictionary[StringName, float] = {}
	for k: StringName in mix:
		shares[k] = mix[k] / new_flour
	s.set_flour_mix(shares)
	s.yeast = maxf(SimConstants.POP_FLOOR, s.yeast * p)
	s.lab = maxf(SimConstants.POP_FLOOR, s.lab * p)
	s.acid = s.acid * p
	s.culture_hydration = (kept_water + water_g) / new_flour * 100.0
	s.mass_g = total
	s.rise = 1.0
	s.peak_rise = 1.0
	s.peak_rate = 0.0
	s.hooch = 0.0
	s.dryness = 0.0
	s.starved_h = 0.0
	s.since_feed_s = 0.0
	s.mold_risk *= SimConstants.MOLD_FEED_KEEP
	s.food_at_feed = s.food
	s.vigor_at_feed = s.vigor
	s.feed_u = feed_u
	s.feed_jitter = 0.95 + 0.10 * feed_u
	return true


## The game path: exactly one draw from `rng` per feed (spec §17, D-030). Refused when moldy (no draw).
static func apply_feed(s: StarterState, action: FeedAction, rng: RandomNumberGenerator) -> bool:
	if s.moldy:
		return false
	# The float32 draw can round up to exactly 1.0; the spec's range is [0, 1).
	var u: float = minf(rng.randf(), 0.9999999)
	return feed(s, action.kept_g, action.flour_g, action.water_g, u, action.hooch_choice == &"stir_in")

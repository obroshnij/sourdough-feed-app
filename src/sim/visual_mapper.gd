class_name VisualMapper
extends RefCounted
## State to shader uniforms (data-models.md §7, art-direction.md §6 and §8). Pure.
## Every field is a continuous function of the stored variables, so a 60 s step never pops (PROP-10).
## The jar never shows what the sim didn't produce (hard rule 2): mold is nonzero only when moldy.
## v0 mapping toward the art-direction §6 look-dev targets; art-director and the scientist tune it.

## About 0.030 m for 150 g in classic_jar v0 (data-models §7).
const LEVEL_M_PER_G: float = 0.030 / 150.0
const LEVEL_M_MAX: float = 0.042
## Art-direction §6: moldy shows colonies at 0.75. The view fades them in over 2 s.
const MOLD_SHOWN: float = 0.75
const BIG_BUBBLE_U: float = 0.85
## The least crack the jar shows once the top cracks (Inspection.shows_cracks).
const CRACK_FLOOR: float = 0.2


static func from_state(s: StarterState, env: EnvironmentState) -> VisualParams:
	if s.empty:
		return empty_jar(env)
	return from_derived(s, env, StateDeriver.derive(s, env))


## Phase 4: a washed, empty jar. level_m 0 and every look at rest; the view hides the starter (and the band)
## when StarterSnapshot.empty_jar is true.
static func empty_jar(env: EnvironmentState) -> VisualParams:
	var v := VisualParams.new()
	v.level_m = 0.0
	v.rise = 1.0
	v.cover = env.cover if env != null else &"loose_lid"
	return v


static func from_derived(s: StarterState, env: EnvironmentState, d: DerivedState) -> VisualParams:
	var v := VisualParams.new()
	var up: float = clampf((s.rise - 1.0) / 1.3, 0.0, 1.0)
	var fallen: float = clampf((s.peak_rise - s.rise) / 0.4, 0.0, 1.0)
	var fresh: float = exp(-s.since_feed_s / 3600.0)
	var dull: float = clampf((s.mold_risk - SimConstants.MOLD_WATCH) / (SimConstants.MOLD_WARN - SimConstants.MOLD_WATCH), 0.0, 1.0)
	if s.moldy:
		dull = 1.0
	v.level_m = clampf(s.mass_g * LEVEL_M_PER_G, 0.0, LEVEL_M_MAX)
	v.rise = clampf(s.rise, SimConstants.RISE_MIN, SimConstants.RISE_MAX)
	var dome: float = 0.1 + 0.7 * up - 1.2 * fallen * clampf((s.peak_rise - 1.0) / 0.5, 0.0, 1.0)
	var rye: float = s.flour_mix.get(&"rye", 0.0)
	if rye >= 0.5 and s.rise >= 1.3:
		dome *= 0.3
	v.dome = clampf(dome, -1.0, 1.0)
	# Phase 4: rye's cracked top (spec v1.1 §14). Above 0 exactly when Inspection lists `cracked` or
	# `sunken_cracked` (Inspection.shows_cracks), with a visible floor at the thresholds so the jar and the text
	# always agree (tech-architect, hard rule 2). Floor and ramp ends are first values for art-director to tune.
	if Inspection.shows_cracks(s, d):
		v.crack = CRACK_FLOOR + (1.0 - CRACK_FLOOR) * smoothstep(0.5, 0.7, rye) * smoothstep(1.3, 1.45, s.rise)
	v.activity = 0.0 if s.moldy else d.activity
	v.bubble_density = 0.0 if s.moldy else clampf(0.05 + 0.85 * d.activity, 0.0, 1.0)
	v.bubble_size = clampf(0.1 + 0.7 * up + 0.3 * fallen, 0.0, 1.0)
	v.peak_line = s.peak_rise if s.peak_rise > 1.0 else 0.0
	# art-direction §6: about 0.8 while collapsing, 0.5 once hungry (the residue dries over about 6 h from
	# hunger onset, near 5 weighted starved hours at the counter), 0.6 at unhealthy and moldy (crusted).
	# Continuous, so a step never pops (PROP-10).
	var streak: float = 0.8 - 0.3 * clampf((s.starved_h - 5.0) / 6.0, 0.0, 1.0) + 0.1 * dull
	v.streak_amount = streak * clampf((s.peak_rise - s.rise) / 0.3, 0.0, 1.0)
	v.lumps = clampf(0.15 + 0.7 * fresh, 0.0, 1.0)
	v.hooch_depth = clampf(s.hooch, 0.0, 1.0)
	v.surface_dryness = clampf(s.dryness, 0.0, 1.0)
	v.dullness = dull
	v.sheen = clampf((0.35 + 0.35 * up) * (1.0 - 0.85 * dull), 0.0, 1.0)
	v.tint = _tint(s)
	v.fleck = _fleck(s)
	v.mold = MOLD_SHOWN if s.moldy else 0.0
	var big: bool = s.feed_u >= BIG_BUBBLE_U and (d.rise_phase == &"near_peak" or d.rise_phase == &"at_peak")
	v.big_bubble = 1.0 if big else 0.0
	v.time_override = -1.0
	v.cover = env.cover
	return v


static func _tint(s: StarterState) -> Color:
	var c := Color(0.0, 0.0, 0.0, 1.0)
	for k: StringName in s.flour_mix:
		var w: float = s.flour_mix[k]
		var t: Color = SimCatalog.TINTS.get(k, Color(1.0, 1.0, 1.0))
		c.r += t.r * w
		c.g += t.g * w
		c.b += t.b * w
	return c


static func _fleck(s: StarterState) -> float:
	var f: float = 0.0
	for k: StringName in s.flour_mix:
		var x: float = SimCatalog.FLECKS.get(k, 0.0)
		f += x * s.flour_mix[k]
	return clampf(f, 0.0, 1.0)

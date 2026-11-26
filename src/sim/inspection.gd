class_name Inspection
extends RefCounted
## Inspection readouts (spec §14). A thin lookup over the state; the observation never claims something the
## variables don't show. Copy is keyed by state (game-copy.md): INSPECT_<KIND>_<STATE>_OBS, where a
## recovering starter uses its rise phase (spec §14: recovering readouts follow rise_phase).

const CAMERA_TARGETS: Dictionary = {
	&"bubbles": &"bubbles", &"consistency": &"top", &"height": &"height", &"surface": &"surface",
	&"development": &"home",
}
const RISING_RATE: float = 0.02


static func read(s: StarterState, env: EnvironmentState, kind: StringName) -> InspectionReadout:
	var d: DerivedState = StateDeriver.derive(s, env)
	var out := InspectionReadout.new()
	out.inspect_kind = kind
	out.camera_target = CAMERA_TARGETS.get(kind, &"home")
	out.is_warning = d.state == &"unhealthy" or d.state == &"moldy"
	match kind:
		&"bubbles":
			out.observations = _bubbles(s, d)
		&"consistency":
			out.observations = _consistency(s, d)
		&"height":
			out.observations = _height(s, d)
		&"surface":
			out.observations = _surface(s, d)
			if out.observations.has(&"hooch_dark"):
				out.is_warning = true
		&"development":
			out.observations = _development(s)
	out.level = _level(kind, out.observations)
	out.text_key = text_key(kind, s, d)
	return out


static func text_key(kind: StringName, s: StarterState, d: DerivedState) -> StringName:
	var label: StringName = d.state
	if label == &"recovering":
		label = d.rise_phase
	var key: String = "INSPECT_%s_%s" % [String(kind).to_upper(), String(label).to_upper()]
	if kind == &"height" and label == &"at_peak":
		key += "_" + String(peak_word(s.peak_rise))
	return StringName(key + "_OBS")


## Spec §14.1 peak words, from peak_rise.
static func peak_word(peak_rise: float) -> StringName:
	if peak_rise < 1.5:
		return &"SMALL"
	if peak_rise < 1.85:
		return &"NEAR"
	if peak_rise < 2.4:
		return &"DOUBLE"
	return &"BIG"


static func _bubbles(s: StarterState, d: DerivedState) -> Array[StringName]:
	var gas_n: float = d.activity
	var resting: bool = d.state == &"hungry" or d.state == &"dormant" or d.state == &"unhealthy"
	if s.moldy or (gas_n < 0.05 and resting):
		return [&"none"]
	if d.rise_phase == &"collapsing" or d.rise_phase == &"hungry":
		return [&"popped_craters"]
	if d.rise_phase == &"near_peak" or d.rise_phase == &"at_peak":
		return [&"large_at_top"]
	if s.rise < 1.15:
		return [&"few_tiny"]
	return [&"many_small"]


static func _consistency(s: StarterState, d: DerivedState) -> Array[StringName]:
	var ab: float = 0.0
	for k: StringName in s.flour_mix:
		var row: Array = SimConstants.FLOURS[k]
		var f_absorb: float = row[2]
		ab += s.flour_mix[k] * f_absorb
	var h_eff: float = s.culture_hydration / ab
	if h_eff < 75.0:
		return [&"stiff_dough"]
	var slack_phase: bool = d.rise_phase == &"collapsing" or d.rise_phase == &"hungry" \
		or (d.state == &"dormant" and d.dormant_cause == &"starved") or d.state == &"unhealthy"
	if slack_phase and s.acid >= 0.66:
		return [&"slack_soupy"]
	if d.state == &"dormant" and d.dormant_cause == &"cold":
		return [&"firm_cold"]
	if d.rise_phase == &"active" or d.rise_phase == &"near_peak" or d.rise_phase == &"at_peak":
		return [&"airy_webby"]
	if h_eff >= 110.0:
		return [&"loose_batter"]
	return [&"thick_batter"]


static func _height(s: StarterState, d: DerivedState) -> Array[StringName]:
	var out: Array[StringName] = []
	if s.rise < 1.1:
		out.append(&"at_mark")
	elif s.rise < 1.5:
		out.append(&"a_little")
	elif s.rise < 1.85:
		out.append(&"nearly_doubled")
	elif s.rise < 2.4:
		out.append(&"doubled")
	else:
		out.append(&"more_than_doubled")
	if d.rise_rate > RISING_RATE:
		out.append(&"rising")
	elif d.rise_rate < -RISING_RATE:
		out.append(&"falling")
	else:
		out.append(&"steady")
	if s.peak_rise - s.rise >= 0.2:
		out.append(&"streak_line")
	return out


static func _surface(s: StarterState, d: DerivedState) -> Array[StringName]:
	var out: Array[StringName] = []
	var rye: float = s.flour_mix.get(&"rye", 0.0)
	if s.moldy:
		out.append(&"fuzzy_spots")
	elif d.rise_phase == &"collapsing":
		out.append(&"sunken")
	elif rye >= 0.5 and s.rise >= 1.3:
		out.append(&"cracked")
	elif d.rise_phase == &"at_peak":
		out.append(&"flat_bubbly")
	elif d.rise_rate > RISING_RATE and s.rise >= 1.3:
		out.append(&"domed")
	else:
		out.append(&"smooth_flat")
	if s.hooch >= 0.8 or (s.hooch >= 0.1 and s.mold_risk >= SimConstants.MOLD_WATCH):
		out.append(&"hooch_dark")
	elif s.hooch >= 0.4:
		out.append(&"hooch_layer")
	elif s.hooch >= 0.1:
		out.append(&"hooch_thin")
	if s.dryness >= 0.7:
		out.append(&"crust")
	elif s.dryness >= 0.3:
		out.append(&"skin")
	return out


static func _development(s: StarterState) -> Array[StringName]:
	var strength: StringName = &"weakened"
	if s.vigor >= 0.85:
		strength = &"strong"
	elif s.vigor >= 0.6:
		strength = &"steady"
	return [SimConstants.maturity_stage(s.maturity), strength]


## 0..4, a coarse ordinal for the meaning-line fade keys (inspect.<kind>.level_<n>).
static func _level(kind: StringName, obs: Array[StringName]) -> int:
	if obs.is_empty():
		return 0
	var order: Dictionary = {
		&"bubbles": [&"none", &"few_tiny", &"many_small", &"large_at_top", &"popped_craters"],
		&"consistency": [&"stiff_dough", &"thick_batter", &"loose_batter", &"airy_webby", &"slack_soupy"],
		&"height": [&"at_mark", &"a_little", &"nearly_doubled", &"doubled", &"more_than_doubled"],
		&"surface": [&"smooth_flat", &"domed", &"flat_bubbly", &"sunken", &"fuzzy_spots"],
		&"development": [&"young", &"steady", &"mature", &"seasoned"],
	}
	var list: Array = order.get(kind, [])
	return clampi(list.find(obs[0]), 0, 4)

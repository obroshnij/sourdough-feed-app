class_name SmellModel
extends RefCounted
## Smell from state (spec §13). Mirrors smell_intensities() and smells() in sim.py. No randomness.

const SHOW_MIN: float = 0.15
const CLEAR_MIN: float = 0.35
const STRONG_MIN: float = 0.7
const MAX_SHOWN: int = 3


static func tri(x: float, a: float, b: float, c: float) -> float:
	if x <= b:
		return clampf((x - a) / (b - a), 0.0, 1.0)
	return clampf((c - x) / (c - b), 0.0, 1.0)


## Every descriptor's intensity after cold damping (musty is never damped). Moldy: {musty: 1.0} only.
static func intensities(s: StarterState, env: EnvironmentState) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	if s.moldy:
		out[&"musty"] = 1.0
		return out
	var gas_n: float = clampf(Sim.rates(s, env).gas, 0.0, 1.0)
	var p: float = clampf(1.0 - s.food / s.food_at_feed, 0.0, 1.0) if s.food_at_feed > 0.0 else 1.0
	var damp: float = clampf(0.35 + 0.65 * Sim.ferm(s.temp_c), 0.0, 1.0)
	out[&"wet_flour"] = clampf(1.0 - p / 0.3, 0.0, 1.0) * damp
	out[&"mildly_fruity"] = 0.9 * gas_n * tri(p, 0.05, 0.3, 0.7) * damp
	out[&"fresh_yeasty"] = gas_n * clampf(s.yeast / 0.5, 0.0, 1.0) * damp
	out[&"yogurt"] = tri(s.acid, 0.25, 0.45, 0.70) * clampf(0.3 + gas_n, 0.0, 1.0) * damp
	out[&"pleasantly_tangy"] = tri(s.acid, 0.40, 0.58, 0.72) * damp
	out[&"strongly_acidic"] = clampf((s.acid - 0.66) / 0.15, 0.0, 1.0) * damp
	out[&"alcohol"] = (0.8 * clampf(s.starved_h / 10.0, 0.0, 1.0) + 0.2 * s.hooch) * damp
	out[&"acetone"] = clampf((s.starved_h - 14.0) / 24.0, 0.0, 1.0) * damp
	out[&"cheesy"] = clampf((0.33 - s.maturity) / 0.13, 0.0, 1.0) * (0.5 + 0.5 * gas_n) * damp
	if s.mold_risk < 0.3:
		out[&"musty"] = 0.0
	else:
		out[&"musty"] = maxf(0.2, clampf((s.mold_risk - 0.2) / 0.5, 0.0, 1.0))
	return out


## The displayed list: up to 3 with intensity >= 0.15, musty always first, then strongest, ties by
## spec §13 order.
static func shown(values: Dictionary[StringName, float]) -> Array[StringName]:
	var picked: Array[StringName] = []
	for k: StringName in values:
		if values[k] >= SHOW_MIN:
			picked.append(k)
	picked.sort_custom(func(a: StringName, b: StringName) -> bool:
		if (a == &"musty") != (b == &"musty"):
			return a == &"musty"
		if values[a] != values[b]:
			return values[a] > values[b]
		return SimConstants.DESCRIPTORS.find(a) < SimConstants.DESCRIPTORS.find(b))
	if picked.size() > MAX_SHOWN:
		picked.resize(MAX_SHOWN)
	return picked


static func intensity_word(value: float) -> StringName:
	if value >= STRONG_MIN:
		return &"strong"
	if value >= CLEAR_MIN:
		return &"clear"
	if value >= SHOW_MIN:
		return &"faint"
	return &""


static func read(s: StarterState, env: EnvironmentState) -> SmellReadout:
	var out := SmellReadout.new()
	out.intensities = intensities(s, env)
	var list: Array[StringName] = shown(out.intensities)
	if list.is_empty():
		return out
	out.primary = list[0]
	for i: int in range(1, list.size()):
		out.secondary.append(list[i])
	out.intensity_value = out.intensities[out.primary]
	out.intensity = intensity_word(out.intensity_value)
	out.is_warning = list.has(&"musty")
	out.meaning_key = StringName("SMELL_%s_MEANING" % String(out.primary).to_upper())
	return out

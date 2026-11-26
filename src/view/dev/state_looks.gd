class_name StateLooks
extends RefCounted
## Dev only. Two sources of VisualParams for the scrubber and the captures:
## - look_for(): the art-direction.md §6 look-dev targets per state, the values the Blender
##   previews and the §16 reference board were rendered with. "As stored" fields use the
##   values noted per row.
## - sim_states(): real states, reached by running the sim from a fed young starter on the
##   counter, mapped by VisualMapper. These are what the game will actually show.
## The game itself never uses look_for(): hard rule 2, visuals come from VisualMapper.

## rise, dome, lumps, bubble_density, bubble_size, peak_line, streak_amount, hooch_depth,
## surface_dryness, sheen, dullness, mold, activity
const FIELDS: Array[StringName] = [
	&"rise", &"dome", &"lumps", &"bubble_density", &"bubble_size", &"peak_line", &"streak_amount",
	&"hooch_depth", &"surface_dryness", &"sheen", &"dullness", &"mold", &"activity",
]
const LOOKS: Dictionary[StringName, Array] = {
	&"freshly_fed": [1.0, 0.1, 0.85, 0.1, 0.1, 0.0, 0.0, 0.0, 0.0, 0.35, 0.0, 0.0, 0.15],
	&"developing": [1.2, 0.25, 0.5, 0.35, 0.15, 0.0, 0.0, 0.0, 0.0, 0.45, 0.0, 0.0, 0.4],
	&"active": [1.7, 0.45, 0.45, 0.7, 0.35, 0.0, 0.0, 0.0, 0.0, 0.55, 0.0, 0.0, 0.8],
	&"near_peak": [2.1, 0.65, 0.4, 0.75, 0.55, 0.0, 0.0, 0.0, 0.0, 0.6, 0.0, 0.0, 0.7],
	&"at_peak": [2.3, 0.8, 0.5, 0.65, 0.8, 0.0, 0.0, 0.0, 0.0, 0.65, 0.0, 0.0, 0.5],
	&"collapsing": [1.9, -0.4, 0.45, 0.4, 0.75, 2.3, 0.8, 0.0, 0.0, 0.7, 0.0, 0.0, 0.3],
	&"hungry": [1.25, -0.1, 0.15, 0.2, 0.85, 2.3, 0.5, 0.35, 0.1, 0.7, 0.0, 0.0, 0.1],
	# As stored: peak_line and streak_amount 0, so no ring (the dormant preview tell).
	&"dormant": [1.0, 0.0, 0.2, 0.05, 0.2, 0.0, 0.0, 0.5, 0.1, 0.5, 0.0, 0.0, 0.02],
	&"recovering": [1.3, 0.2, 0.4, 0.25, 0.3, 0.0, 0.0, 0.0, 0.0, 0.45, 0.0, 0.0, 0.3],
	# Art lists rise 0.95; VisualParams clamps rise to 1.0..3.0 (data-models.md §7). As stored: peak 2.0.
	&"unhealthy": [1.0, -0.05, 0.35, 0.03, 0.2, 2.0, 0.6, 0.4, 0.85, 0.1, 1.0, 0.0, 0.05],
	&"moldy": [1.0, -0.05, 0.4, 0.02, 0.2, 2.0, 0.6, 0.0, 0.7, 0.1, 1.0, 0.75, 0.0],
}
const PREVIEWED: Array[StringName] = [
	&"freshly_fed", &"active", &"at_peak", &"collapsing", &"hungry", &"dormant", &"unhealthy", &"moldy",
]


static func states() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in LOOKS:
		out.append(k)
	return out


static func look_for(state_id: StringName) -> VisualParams:
	var p := VisualParams.new()
	var row: Array = LOOKS.get(state_id, LOOKS[&"freshly_fed"])
	for i: int in FIELDS.size():
		p.set(FIELDS[i], float(row[i]))
	p.level_m = 0.030
	p.tint = SimCatalog.TINTS[&"white_bread"]
	p.fleck = 0.0
	p.big_bubble = 0.0
	p.time_override = -1.0
	p.cover = &"loose_lid"
	return p


## First VisualParams the sim produces for each state it reaches, walking a fed young starter on
## the counter for up to `max_days`, then into the fridge, which reaches dormant.
static func sim_states(max_days: int = 12) -> Dictionary[StringName, VisualParams]:
	var out: Dictionary[StringName, VisualParams] = {}
	var s: StarterState = SimFixtures.young()
	SimFixtures.feed_ratio(s)
	var counter: EnvironmentState = EnvironmentState.at_location(&"counter")
	for i: int in max_days * 24 * 60:
		var d: DerivedState = StateDeriver.derive(s, counter)
		if not out.has(d.state):
			out[d.state] = VisualMapper.from_derived(s, counter, d)
		Sim.step(s, counter)
	var cold: StarterState = SimFixtures.young()
	SimFixtures.feed_ratio(cold)
	var fridge: EnvironmentState = EnvironmentState.at_location(&"fridge")
	for i: int in 4 * 24 * 60:
		var d2: DerivedState = StateDeriver.derive(cold, fridge)
		if not out.has(d2.state):
			out[d2.state] = VisualMapper.from_derived(cold, fridge, d2)
		Sim.step(cold, fridge)
	return out

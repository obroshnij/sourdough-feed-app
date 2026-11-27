class_name JarGeometry
extends RefCounted
## Mirrors the jar_v0 mesh contract (art-direction.md §12) and the starter shader constants (§5).
## check_extras() compares the GLB extras with these numbers, so a re-export that moves one is
## caught at load instead of showing up as a starter that floats or sinks.

const NODE_GLASS: StringName = &"Jar_Glass"
const NODE_STARTER: StringName = &"Starter_Body"
const NODE_LINER: StringName = &"Starter_Liner"
const NODE_BAND: StringName = &"Rubber_Band"
const NODE_COUNTER: StringName = &"Counter"
const NODE_FLOOR: StringName = &"StarterFloor"
const NODE_RIM: StringName = &"StarterRim"
## VisualParams.cover to the lid node that shows it.
const COVER_NODES: Dictionary[StringName, StringName] = {
	&"loose_lid": &"Jar_Lid_Loose",
	&"tight_lid": &"Jar_Lid_Tight",
	&"cloth": &"Cloth_Cover",
}
const REQUIRED_NODES: Array[StringName] = [
	&"Jar_Glass", &"Starter_Body", &"Starter_Liner", &"Jar_Lid_Loose", &"Jar_Lid_Tight",
	&"Cloth_Cover", &"Rubber_Band", &"Counter", &"StarterFloor", &"StarterRim",
]

const INNER_RADIUS_M: float = 0.0385
const OUTER_RADIUS_M: float = 0.042
const HEIGHT_M: float = 0.170
const FLOOR_Y_M: float = 0.008
const STARTER_RADIUS_M: float = 0.038
const STARTER_AUTHORED_H_M: float = 0.030
const LINER_HEIGHT_M: float = 0.125

## Shader constants (starter_common.gdshaderinc).
const DOME_MAX_M: float = 0.010
const LUMPS_MAX_M: float = 0.003
const BREATH_M: float = 0.0006
const HOOCH_MAX_M: float = 0.010
## VisualParams ranges (data-models.md §7).
const LEVEL_MAX_M: float = 0.042
const RISE_MAX: float = 3.0

## Expected extras per node: key to value.
const EXTRAS: Dictionary[StringName, Dictionary] = {
	&"Jar_Glass": {
		"inner_radius_m": INNER_RADIUS_M, "outer_radius_m": OUTER_RADIUS_M,
		"height_m": HEIGHT_M, "floor_y_m": FLOOR_Y_M,
	},
	&"Starter_Body": {
		"starter_radius_m": STARTER_RADIUS_M, "starter_authored_height_m": STARTER_AUTHORED_H_M,
		"floor_y_m": FLOOR_Y_M,
	},
	&"Starter_Liner": {"liner_height_m": LINER_HEIGHT_M, "floor_y_m": FLOOR_Y_M},
}
const TOLERANCE_M: float = 0.0001


## The starter's bounds in Starter_Body local space (origin on the inner floor), covering the
## highest surface the shader can draw: max level times max rise, plus dome, lumps and breath.
## The low side covers a collapsed dome at level 0. D-010: without this the starter vanishes.
static func starter_aabb() -> AABB:
	var r: float = STARTER_RADIUS_M
	var swell: float = DOME_MAX_M + LUMPS_MAX_M * 0.5 + BREATH_M
	var top: float = LEVEL_MAX_M * RISE_MAX + swell
	var bottom: float = -swell
	return AABB(Vector3(-r, bottom, -r), Vector3(2.0 * r, top - bottom, 2.0 * r))


## Highest surface point the shader can produce for a VisualParams, above the starter floor.
static func surface_top_m(level_m: float, rise: float, dome: float) -> float:
	return level_m * rise + maxf(dome, 0.0) * DOME_MAX_M + LUMPS_MAX_M * 0.5 + BREATH_M


## Mismatches between a node's GLB extras and the contract. Empty when everything matches.
static func check_extras(node_name: StringName, extras: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var want: Dictionary = EXTRAS.get(node_name, {})
	for key: String in want:
		if not extras.has(key):
			out.append("%s: extras has no %s" % [node_name, key])
			continue
		var got: float = float(extras[key])
		var expected: float = float(want[key])
		if absf(got - expected) > TOLERANCE_M:
			out.append("%s: %s is %s, contract says %s" % [node_name, key, got, expected])
	return out

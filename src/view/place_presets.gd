class_name PlacePresets
extends RefCounted
## Where the jar lives (art-direction.md §19, architecture §8.1 "Places"). The view reads
## StarterSnapshot.location; each place is a light preset (§19.5) plus a set. The jar never moves:
## only a transient 18 mm lift while the set changes (§19.4). Pure.

const IDS: Array[StringName] = [&"counter", &"warm_spot", &"fridge", &"window_sill", &"proofing_box"]
const LIFT_M: float = 0.018
const BOUNCE_M: float = 0.0015
## The lift ends here; the jar root is snapped back to the origin (§19.4).
const MOVE_S: float = 1.30
const REDUCED_S: float = 0.4

const KITCHEN_WALL: String = "res://assets/textures/kitchen_wall.png"
const KITCHEN_NIGHT: String = "res://assets/textures/kitchen_wall_night.png"
const WINDOW_WALL: String = "res://assets/textures/place_window_sill.png"
const WINDOW_NIGHT: String = "res://assets/textures/place_window_sill_night.png"


## An unknown or empty id falls back to the counter.
static func resolve(id: StringName) -> StringName:
	return id if id in IDS else &"counter"


## Day values (§19.5), as multipliers on the signed-off ViewLook plus colors and set switches.
static func preset(id: StringName) -> Dictionary:
	var p: Dictionary = {
		"key_color": Color("#FFF6EE"), "key": 1.0, "rim": 1.0, "rim_color": Color("#FFEEDD"), "sky": 1.0,
		"window": 1.0, "glass": 1.0, "fog": 0.0, "sat": 1.0, "window_set": 0.0, "sill": 0.0, "box": 0.0,
		"night_floor": Color("#1A1310"),
	}
	match resolve(id):
		&"warm_spot":
			p["key_color"] = Color("#FFF0E2")
		&"fridge":
			p["key_color"] = Color("#EEF3F8")
			p["key"] = 0.95
			p["rim_color"] = Color("#EEF3F8")
			p["sky"] = 0.9
			p["window"] = 0.6
			p["fog"] = 0.3
			p["sat"] = 0.8
		&"window_sill":
			p["key_color"] = Color("#FBF7F1")
			p["rim"] = 1.6
			p["rim_color"] = Color("#EEF3F8")
			p["sky"] = 1.1
			p["window"] = 1.4
			p["window_set"] = 1.0
			p["sill"] = 1.0
			p["night_floor"] = Color("#15181C")
		&"proofing_box":
			p["key_color"] = Color("#FFF0E2")
			p["key"] = 0.9
			p["rim"] = 0.4
			p["sky"] = 0.8
			p["window"] = 0.3
			p["glass"] = 0.7
			p["box"] = 1.0
	return p


static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out: Dictionary = {}
	for k: String in a:
		var va: Variant = a[k]
		if va is Color:
			out[k] = (va as Color).lerp(b[k] as Color, t)
		else:
			out[k] = lerpf(float(va), float(b[k]), t)
	return out


## Jar root height above the origin at time t of a place change (§19.4). 0 with reduce motion.
static func lift_offset(t: float, reduce_motion: bool) -> float:
	if reduce_motion or t <= 0.0 or t >= MOVE_S:
		return 0.0
	if t < 0.30:
		var a: float = t / 0.30
		return LIFT_M * (1.0 - pow(1.0 - a, 3.0))
	if t < 0.75:
		return LIFT_M
	if t < 1.05:
		var d: float = (t - 0.75) / 0.30
		return LIFT_M * (1.0 - d * d * d)
	var s: float = (t - 1.05) / 0.25
	return BOUNCE_M * sin(PI * s) * (1.0 - s)


## Set and light progress 0..1 at time t: lights over 0.15 to 1.05 s, the set over 0.15 to 0.75 s.
static func set_progress(t: float, reduce_motion: bool) -> float:
	var x: float = clampf(t / REDUCED_S, 0.0, 1.0) if reduce_motion else clampf((t - 0.15) / 0.6, 0.0, 1.0)
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5


static func light_progress(t: float, reduce_motion: bool) -> float:
	var x: float = clampf(t / REDUCED_S, 0.0, 1.0) if reduce_motion else clampf((t - 0.15) / 0.9, 0.0, 1.0)
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5


static func duration(reduce_motion: bool) -> float:
	return REDUCED_S if reduce_motion else MOVE_S

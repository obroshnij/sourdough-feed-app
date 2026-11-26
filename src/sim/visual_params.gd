class_name VisualParams
extends RefCounted
## The sim to view contract (data-models.md §7, architecture.md §14.2). Frozen: T2 requests changes from T1.
## Every name in UNIFORMS is a starter-shader uniform with the same name and type, so the view can do
## `for u in VisualParams.UNIFORMS: material.set_shader_parameter(u, params.get(u))`.

const UNIFORMS: Array[StringName] = [
	&"level_m", &"rise", &"dome", &"activity", &"bubble_density", &"peak_line", &"lumps",
	&"hooch_depth", &"bubble_size", &"streak_amount", &"surface_dryness", &"sheen", &"tint",
	&"fleck", &"dullness", &"mold", &"big_bubble", &"time_override",
]

## 0..0.042 m. Fed level above the starter floor at rise 1.0. Also the rubber band height.
var level_m: float = 0.030
## 1.0..3.0. Surface height is level_m * rise.
var rise: float = 1.0
## -1 collapsed, 0 flat, +1 domed.
var dome: float = 0.0
## 0..1. Breathing and bubble motion speed.
var activity: float = 0.0
## 0..1.
var bubble_density: float = 0.0
## 0 = no streak line, else 1.0..3.0 in rise units.
var peak_line: float = 0.0
## 0..1.
var lumps: float = 0.0
## 0..1. 1 = hooch_max in the shader (about 1 cm).
var hooch_depth: float = 0.0
## 0..1. Small and even to large and irregular.
var bubble_size: float = 0.0
## 0..1. Liner streak opacity below peak_line.
var streak_amount: float = 0.0
## 0..1. Skin or crust look.
var surface_dryness: float = 0.0
## 0..1.
var sheen: float = 0.0
var tint: Color = Color(1.0, 1.0, 1.0)
## 0..1. Bran flecks.
var fleck: float = 0.0
## 0..1. The unhealthy look, before any mold.
var dullness: float = 0.0
## 0..1. Nonzero only when the state is moldy (hard rule 2).
var mold: float = 0.0
## 0..1. The cycle's big bubble (spec §14.1).
var big_bubble: float = 0.0
## -1 = use shader TIME. Tests and captures set a fixed value.
var time_override: float = -1.0
## Not a uniform: which lid node is visible.
var cover: StringName = &"loose_lid"


func copy() -> VisualParams:
	var v := VisualParams.new()
	for u: StringName in UNIFORMS:
		v.set(u, get(u))
	v.cover = cover
	return v


func to_dict() -> Dictionary:
	var d: Dictionary = {}
	for u: StringName in UNIFORMS:
		if u == &"tint":
			d["tint"] = [tint.r, tint.g, tint.b, tint.a]
		else:
			d[String(u)] = get(u)
	d["cover"] = String(cover)
	return d

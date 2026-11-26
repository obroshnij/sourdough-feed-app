class_name StarterViewParams
extends RefCounted
## The spike's one "state to params" script, a stand-in for VisualMapper.from_state().
## Turns a canonical starter state id into the starter shader uniforms.
## Nothing else in the spike writes these uniforms.
## Names and units match docs/data-models.md §7 (rise is the ratio, 1.0 = as fed).
## The values are look-dev guesses, not science. The sim spec owns the real mapping.

var level_m: float = 0.030
var rise: float = 1.0
var dome: float = 0.0
var activity: float = 0.0
var bubble_density: float = 0.0
var hooch_depth: float = 0.0
var peak_line: float = 0.0

const UNIFORMS: Array[StringName] = [&"level_m", &"rise", &"dome", &"activity", &"bubble_density", &"hooch_depth", &"peak_line"]
const STATES: Array[StringName] = [&"freshly_fed", &"developing", &"active", &"near_peak", &"at_peak", &"collapsing", &"hungry", &"dormant"]


static func for_state(state_id: StringName) -> StarterViewParams:
	var p := StarterViewParams.new()
	match state_id:
		&"freshly_fed":
			p.set_values(1.0, 0.0, 0.05, 0.10, 0.0, 0.0)
		&"developing":
			p.set_values(1.3, 0.15, 0.4, 0.35, 0.0, 0.0)
		&"active":
			p.set_values(2.0, 0.45, 0.8, 0.7, 0.0, 0.0)
		&"near_peak":
			p.set_values(2.6, 0.8, 0.85, 0.85, 0.0, 0.0)
		&"at_peak":
			p.set_values(2.9, 1.0, 0.9, 0.95, 0.0, 0.0)
		&"collapsing":
			p.set_values(2.3, -0.7, 0.45, 0.7, 0.0, 2.9)
		&"hungry":
			p.set_values(1.6, -0.3, 0.1, 0.4, 0.6, 2.9)
		&"dormant":
			p.set_values(1.05, 0.0, 0.0, 0.15, 0.0, 0.0)
		_:
			push_warning("Unknown state id: %s" % state_id)
	return p


func set_values(r: float, d: float, a: float, b: float, h: float, pk: float) -> void:
	rise = r
	dome = d
	activity = a
	bubble_density = b
	hooch_depth = h
	peak_line = pk


func get_value(uniform_name: StringName) -> float:
	var v: Variant = get(uniform_name)
	return v as float


func set_value(uniform_name: StringName, value: float) -> void:
	set(uniform_name, value)


func apply(materials: Array[ShaderMaterial]) -> void:
	for m: ShaderMaterial in materials:
		for u: StringName in UNIFORMS:
			m.set_shader_parameter(u, get_value(u))

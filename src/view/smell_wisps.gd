class_name SmellWisps
extends Node3D
## Smell wisps (art-direction.md §9): 3 soft ribbons rise from the jar mouth for 2.5 s during the
## smell moment. The tint follows the smell family the sim reads (SmellReadout.primary), never red,
## orange or pink. Transparent, but above the jar and drawn after the glass (render priority 2).

const LIFE_S: float = 2.5
const FADE_OUT_S: float = 0.4
const COUNT: int = 3
const SHADER: String = "res://src/view/shaders/wisp.gdshader"
## Art-direction.md §9 tints by family.
const WARM_CREAM: Color = Color("#F3E7D2")
const PALE_STRAW: Color = Color("#EFE6C0")
const COOL_GRAY: Color = Color("#DADDDC")
const GRAY_GREEN: Color = Color("#B9C2B0")

var playing: bool = false
var _t: float = 0.0
var _fade: float = 0.0
var _mats: Array[ShaderMaterial] = []


static func tint_for(primary: StringName) -> Color:
	match primary:
		&"pleasantly_tangy", &"strongly_acidic", &"alcohol":
			return PALE_STRAW
		&"acetone":
			return COOL_GRAY
		&"musty", &"cheesy":
			return GRAY_GREEN
	return WARM_CREAM


func _ready() -> void:
	for i: int in COUNT:
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.035, 0.09)
		quad.center_offset = Vector3(0.0, 0.045, 0.0)
		var m := ShaderMaterial.new()
		m.shader = load(SHADER) as Shader
		m.render_priority = 2
		m.set_shader_parameter(&"seed", float(i) * 1.7 + 0.3)
		quad.material = m
		mi.mesh = quad
		mi.position = Vector3((float(i) - 1.0) * 0.012, 0.0, 0.004 * float(i % 2))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_mats.append(m)
	visible = false


func start(primary: StringName) -> void:
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter(&"tint", tint_for(primary))
	playing = true
	_t = 0.0
	_fade = 1.0
	visible = true


func stop() -> void:
	playing = false


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if not playing:
		_fade = maxf(_fade - delta / FADE_OUT_S, 0.0)
		if _fade <= 0.0:
			visible = false
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter(&"life", fmod(_t, LIFE_S) / LIFE_S)
		m.set_shader_parameter(&"fade", _fade)

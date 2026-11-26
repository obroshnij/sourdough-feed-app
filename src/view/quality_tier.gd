class_name QualityTier
extends RefCounted
## Glass quality tiers (D-008, D-009, architecture.md §8.1).
## - Tier B: Mobile renderer and "reduce effects" off. Front faces only, screen-texture refraction.
## - Tier A: Compatibility, or "reduce effects". Back faces (priority -1) then front faces (+1).
##   Never samples the screen (AC-01.7).
## Switching tiers swaps the glass material. There is no bool uniform for it: a runtime bool can't
## turn off the screen copy (spike: Tier B with refraction off still cost 4.52 ms GPU vs 3.63, Mac estimate).

enum Tier { A, B }

const RENDERER_MOBILE: String = "mobile"
const RENDERER_FORWARD_PLUS: String = "forward_plus"
const RENDERER_COMPATIBILITY: String = "gl_compatibility"

const SHADER_BACK: String = "res://src/view/shaders/glass_back.gdshader"
const SHADER_FRONT_A: String = "res://src/view/shaders/glass_front_a.gdshader"
const SHADER_FRONT_B: String = "res://src/view/shaders/glass_front_b.gdshader"
const PRIORITY_BACK: int = -1
const PRIORITY_FRONT: int = 1

var back_a: ShaderMaterial
var front_a: ShaderMaterial
var front_b: ShaderMaterial


## The tier for a renderer and the player's "reduce effects" setting.
static func choose(renderer: String, reduce_effects: bool) -> Tier:
	if supports_b(renderer) and not reduce_effects:
		return Tier.B
	return Tier.A


## Tier B needs the screen texture, which only the RenderingDevice renderers have.
static func supports_b(renderer: String) -> bool:
	return renderer == RENDERER_MOBILE or renderer == RENDERER_FORWARD_PLUS


static func tier_name(tier: Tier) -> String:
	return "B" if tier == Tier.B else "A"


func _init(env_cube: Cubemap) -> void:
	back_a = _make(SHADER_BACK, PRIORITY_BACK, env_cube)
	front_a = _make(SHADER_FRONT_A, PRIORITY_FRONT, env_cube)
	front_b = _make(SHADER_FRONT_B, PRIORITY_FRONT, env_cube)
	back_a.next_pass = front_a


## The material to put on Jar_Glass (material_override) for a tier.
func material_for(tier: Tier) -> ShaderMaterial:
	return front_b if tier == Tier.B else back_a


## Every glass material in both tiers, for shared parameters (light directions, fog).
func all_materials() -> Array[ShaderMaterial]:
	return [back_a, front_a, front_b]


func set_shared(param: StringName, value: Variant) -> void:
	for m: ShaderMaterial in all_materials():
		m.set_shader_parameter(param, value)


func _make(path: String, priority: int, env_cube: Cubemap) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path) as Shader
	m.render_priority = priority
	m.set_shader_parameter(&"env_cube", env_cube)
	return m

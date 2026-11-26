class_name JarView
extends Node3D
## The jar: binds the jar_v0 GLB by its contract node names (art-direction.md §12), owns every
## material on it, and shows a VisualParams. Reads sim types only; never mutates state.
## Everything inside the glass is opaque (D-009): the starter, the liner (alpha scissor) and the band.

const STARTER_SHADER: String = "res://src/view/shaders/starter.gdshader"
const LINER_SHADER: String = "res://src/view/shaders/liner.gdshader"
const LID_WOOD_SHADER: String = "res://src/view/shaders/lid_wood.gdshader"
const COUNTER_SHADER: String = "res://src/view/shaders/counter.gdshader"
const BACKDROP_SHADER: String = "res://src/view/shaders/backdrop.gdshader"
const SIDE_MASK: String = "res://assets/textures/starter_side_bubbles.png"
const TOP_MASK: String = "res://assets/textures/starter_top_pits.png"
const LINER_MASK: String = "res://assets/textures/starter_liner_streaks.png"
const WALL_TEX: String = "res://assets/textures/kitchen_backdrop.png"
const COUNTER_DETAIL: String = "res://assets/textures/counter_oak_detail.png"
const LID_DETAIL: String = "res://assets/textures/lid_oak_detail.png"

## Art #5F7458. Lifted a little: the Cycles reference reads light sage under its soft fill.
const BAND_COLOR: Color = Color("#7A9271")
const ENAMEL_COLOR: Color = Color("#EFE7D8")
const LINEN_COLOR: Color = Color("#E6DCCA")
const TWINE_COLOR: Color = Color("#B79C74")

var glass: MeshInstance3D
var starter: MeshInstance3D
var liner: MeshInstance3D
var band: MeshInstance3D
var counter: MeshInstance3D
var backdrop: MeshInstance3D
var covers: Dictionary[StringName, MeshInstance3D] = {}
var floor_y: float = JarGeometry.FLOOR_Y_M

var starter_mat: ShaderMaterial
var liner_mat: ShaderMaterial
var counter_mat: ShaderMaterial
var backdrop_mat: ShaderMaterial
var lid_mat: ShaderMaterial
var quality: QualityTier
var tier: QualityTier.Tier = QualityTier.Tier.A
var visuals: VisualParams = VisualParams.new()
## Contract problems found at bind time. Empty when the GLB matches.
var contract_errors: PackedStringArray = PackedStringArray()


## Finds the contract nodes under `model` and puts the view materials on them.
func bind(model: Node3D) -> PackedStringArray:
	contract_errors = PackedStringArray()
	for n: StringName in JarGeometry.REQUIRED_NODES:
		if model.find_child(String(n), true, false) == null:
			contract_errors.append("missing node %s" % n)
	glass = model.find_child(String(JarGeometry.NODE_GLASS), true, false) as MeshInstance3D
	starter = model.find_child(String(JarGeometry.NODE_STARTER), true, false) as MeshInstance3D
	liner = model.find_child(String(JarGeometry.NODE_LINER), true, false) as MeshInstance3D
	band = model.find_child(String(JarGeometry.NODE_BAND), true, false) as MeshInstance3D
	counter = model.find_child(String(JarGeometry.NODE_COUNTER), true, false) as MeshInstance3D
	backdrop = model.find_child(String(JarGeometry.NODE_BACKDROP), true, false) as MeshInstance3D
	for cover: StringName in JarGeometry.COVER_NODES:
		var node: MeshInstance3D = model.find_child(String(JarGeometry.COVER_NODES[cover]), true, false) as MeshInstance3D
		if node != null:
			covers[cover] = node
	var floor_node: Node3D = model.find_child(String(JarGeometry.NODE_FLOOR), true, false) as Node3D
	if floor_node != null:
		floor_y = floor_node.position.y
	for mi: MeshInstance3D in [glass, starter, liner]:
		if mi != null:
			var extras: Dictionary = mi.get_meta("extras", {}) as Dictionary
			contract_errors.append_array(JarGeometry.check_extras(StringName(mi.name), extras))
	for e: String in contract_errors:
		push_error("JarView contract: " + e)
	_make_materials()
	return contract_errors


func _make_materials() -> void:
	quality = QualityTier.new(ReflectionCubemap.get_shared())
	starter_mat = ShaderMaterial.new()
	starter_mat.shader = load(STARTER_SHADER) as Shader
	starter_mat.set_shader_parameter(&"side_mask", load(SIDE_MASK) as Texture2D)
	starter_mat.set_shader_parameter(&"top_mask", load(TOP_MASK) as Texture2D)
	liner_mat = ShaderMaterial.new()
	liner_mat.shader = load(LINER_SHADER) as Shader
	liner_mat.set_shader_parameter(&"liner_mask", load(LINER_MASK) as Texture2D)
	if starter != null:
		starter.material_override = starter_mat
		starter.custom_aabb = JarGeometry.starter_aabb()
		var extras: Dictionary = starter.get_meta("extras", {}) as Dictionary
		var authored: float = float(extras.get("starter_authored_height_m", JarGeometry.STARTER_AUTHORED_H_M))
		var radius: float = float(extras.get("starter_radius_m", JarGeometry.STARTER_RADIUS_M))
		for m: ShaderMaterial in starter_materials():
			m.set_shader_parameter(&"authored_h", authored)
			m.set_shader_parameter(&"starter_r", radius)
	if liner != null:
		liner.material_override = liner_mat
		liner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if glass != null:
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var axis: Vector3 = glass.global_position if glass.is_inside_tree() else glass.position
		quality.set_shared(&"jar_axis", Vector2(axis.x, axis.z))
		set_tier(tier)
	if band != null:
		band.material_override = _standard(BAND_COLOR, 0.55)
	if counter != null:
		counter_mat = ShaderMaterial.new()
		counter_mat.shader = load(COUNTER_SHADER) as Shader
		counter_mat.set_shader_parameter(&"jar_radius", JarGeometry.OUTER_RADIUS_M)
		counter_mat.set_shader_parameter(&"oak_detail", load(COUNTER_DETAIL) as Texture2D)
		counter.material_override = counter_mat
	if backdrop != null:
		backdrop_mat = ShaderMaterial.new()
		backdrop_mat.shader = load(BACKDROP_SHADER) as Shader
		backdrop_mat.set_shader_parameter(&"wall_tex", load(WALL_TEX) as Texture2D)
		backdrop.material_override = backdrop_mat
		backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if covers.has(&"loose_lid"):
		lid_mat = ShaderMaterial.new()
		lid_mat.shader = load(LID_WOOD_SHADER) as Shader
		lid_mat.set_shader_parameter(&"grain", load(LID_DETAIL) as Texture2D)
		covers[&"loose_lid"].material_override = lid_mat
	if covers.has(&"tight_lid"):
		var enamel: StandardMaterial3D = _standard(ENAMEL_COLOR, 0.35)
		enamel.clearcoat_enabled = true
		enamel.clearcoat = 0.6
		covers[&"tight_lid"].material_override = enamel
	if covers.has(&"cloth"):
		var cloth: MeshInstance3D = covers[&"cloth"]
		var linen: StandardMaterial3D = _standard(LINEN_COLOR, 0.85)
		linen.cull_mode = BaseMaterial3D.CULL_DISABLED
		linen.rim_enabled = true
		linen.rim = 0.4
		cloth.set_surface_override_material(0, linen)
		if cloth.mesh != null and cloth.mesh.get_surface_count() > 1:
			cloth.set_surface_override_material(1, _standard(TWINE_COLOR, 0.8))


func _standard(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


## The starter-shaped materials that take VisualParams uniforms.
func starter_materials() -> Array[ShaderMaterial]:
	return [starter_mat, liner_mat]


## Shows a VisualParams. The band sits at the fed level; the cover picks the visible lid node.
func apply_visuals(p: VisualParams) -> void:
	visuals = p
	StarterUniforms.apply(p, starter_materials())
	if band != null:
		band.position.y = floor_y + p.level_m
	for cover: StringName in covers:
		covers[cover].visible = cover == p.cover
	if counter_mat != null:
		counter_mat.set_shader_parameter(&"starter_top", floor_y + p.level_m * p.rise)
		counter_mat.set_shader_parameter(&"lid_on", 1.0 if p.cover == &"loose_lid" or p.cover == &"tight_lid" else 0.0)


## Freezes or frees the shader clock (captures and tests use a fixed time).
func set_time_override(t: float) -> void:
	visuals.time_override = t
	for m: ShaderMaterial in starter_materials():
		m.set_shader_parameter(&"time_override", t)


func set_tier(t: QualityTier.Tier) -> void:
	tier = t
	if glass != null and quality != null:
		glass.material_override = quality.material_for(t)


## The per-renderer grade (ViewLook) and the light directions the glass highlights follow.
func apply_look(look: ViewLook, key_dir: Vector3, rim_dir: Vector3) -> void:
	for m: ShaderMaterial in starter_materials():
		m.set_shader_parameter(&"grade_saturation", look.starter_saturation)
		m.set_shader_parameter(&"grade_value", look.starter_value)
	starter_mat.set_shader_parameter(&"backlight_k", look.backlight_k)
	starter_mat.set_shader_parameter(&"clearcoat_on", look.clearcoat_on)
	starter_mat.set_shader_parameter(&"pocket_tilt", look.pocket_tilt)
	starter_mat.set_shader_parameter(&"pocket_k", look.pocket_k)
	starter_mat.set_shader_parameter(&"cap_spec", look.cap_spec)
	starter_mat.set_shader_parameter(&"cap_value", look.cap_value)
	starter_mat.set_shader_parameter(&"hooch_value", look.hooch_value)
	starter_mat.set_shader_parameter(&"hooch_desat", look.hooch_desat)
	starter_mat.set_shader_parameter(&"hooch_dark_lift", look.hooch_dark_lift)
	if backdrop_mat != null:
		backdrop_mat.set_shader_parameter(&"energy", look.backdrop_energy)
	if counter_mat != null:
		counter_mat.set_shader_parameter(&"grade_value", look.dressing_value)
		counter_mat.set_shader_parameter(&"key_dir", key_dir)
	if lid_mat != null:
		lid_mat.set_shader_parameter(&"grade_value", look.dressing_value)
		lid_mat.set_shader_parameter(&"grade_saturation", look.lid_saturation)
	if quality != null:
		quality.set_shared(&"reflection_strength", look.glass_reflection)
		quality.set_shared(&"spec_strength", look.glass_spec)
		quality.set_shared(&"edge_absorb", look.glass_edge_absorb)
		quality.set_shared(&"key_dir", key_dir)
		quality.set_shared(&"rim_dir", rim_dir)


## Dev only: a stock StandardMaterial3D starter, to tell our shader apart from the pipeline.
func use_stock_starter(on: bool) -> void:
	if starter == null:
		return
	if on:
		var stock := StandardMaterial3D.new()
		stock.albedo_color = Color(visuals.tint.r, visuals.tint.g, visuals.tint.b)
		stock.roughness = 0.45
		starter.material_override = stock
	else:
		starter.material_override = starter_mat

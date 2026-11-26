extends TestCase
## VisualParams to starter uniforms (architecture.md §8.1, data-models.md §7): every field maps
## 1:1 to a uniform with the same name, in both shaders that take state.

const U := preload("res://tests/unit/view/view_test_util.gd")
const SHADERS: Array[String] = [
	"res://src/view/shaders/starter.gdshader",
	"res://src/view/shaders/liner.gdshader",
]

var jar: JarView


func before_each() -> void:
	await U.tree_ready()


func after_each() -> void:
	if jar != null:
		jar.queue_free()
		jar = null


func test_every_field_is_a_uniform_with_the_same_name_and_type() -> void:
	for path: String in SHADERS:
		var declared: Dictionary[String, String] = U.uniforms(path)
		for f: StringName in VisualParams.UNIFORMS:
			var want: String = "vec3" if f == &"tint" else "float"
			check_eq(declared.get(String(f), "missing"), want, "%s declares %s" % [path.get_file(), f])


func test_values_are_exactly_the_contract_fields() -> void:
	var p := VisualParams.new()
	p.rise = 2.3
	p.dome = -0.4
	p.tint = Color(0.84, 0.72, 0.56)
	p.mold = 0.75
	var vals: Dictionary[StringName, Variant] = StarterUniforms.values(p)
	check_eq(vals.size(), VisualParams.UNIFORMS.size(), "one value per field")
	for f: StringName in VisualParams.UNIFORMS:
		check(vals.has(f), "has %s" % f)
		check(values_equal(vals.get(f), p.get(f)), "%s carries the field value" % f)


func test_apply_sets_every_uniform_on_starter_and_liner() -> void:
	jar = U.make_jar()
	var p := VisualParams.new()
	var i: int = 0
	for f: StringName in VisualParams.UNIFORMS:
		if f != &"tint" and f != &"time_override":
			p.set(f, 0.01 + 0.03 * float(i))
		i += 1
	p.tint = Color(0.74, 0.62, 0.50)
	p.time_override = 10.0
	jar.apply_visuals(p)
	for m: ShaderMaterial in jar.starter_materials():
		for f: StringName in VisualParams.UNIFORMS:
			check(values_equal(m.get_shader_parameter(f), p.get(f)), "%s on %s" % [f, m.shader.resource_path.get_file()])


func test_band_follows_the_fed_level_and_cover_picks_the_lid() -> void:
	jar = U.make_jar()
	var p := VisualParams.new()
	p.level_m = 0.036
	p.cover = &"cloth"
	jar.apply_visuals(p)
	check_close(jar.band.position.y, JarGeometry.FLOOR_Y_M + 0.036, 0.0, 1e-6, "band at floor + level_m")
	check(jar.covers[&"cloth"].visible, "cloth visible")
	check(not jar.covers[&"loose_lid"].visible, "loose lid hidden")
	check(not jar.covers[&"tight_lid"].visible, "tight lid hidden")


func test_glb_matches_the_mesh_contract() -> void:
	jar = U.make_jar()
	check_eq(jar.contract_errors.size(), 0, "contract errors: %s" % ", ".join(jar.contract_errors))
	check(jar.starter.material_override == jar.starter_mat, "starter uses the starter shader")
	check(jar.liner.material_override == jar.liner_mat, "liner uses the liner shader")


func test_liner_is_alpha_scissor_and_everything_inside_is_opaque() -> void:
	var liner: String = U.source("res://src/view/shaders/liner.gdshader")
	check(liner.contains("ALPHA_SCISSOR_THRESHOLD"), "liner uses alpha scissor (opaque pass)")
	var starter: String = U.source("res://src/view/shaders/starter.gdshader")
	check(not starter.contains("ALPHA ="), "starter writes no alpha")
	check(not starter.contains("blend_"), "starter has no blend mode")


func test_shader_constants_mirror_jar_geometry() -> void:
	var path: String = "res://src/view/shaders/starter_common.gdshaderinc"
	check_close(U.shader_const(path, "DOME_MAX_M"), JarGeometry.DOME_MAX_M, 0.0, 1e-9, "DOME_MAX_M")
	check_close(U.shader_const(path, "LUMPS_MAX_M"), JarGeometry.LUMPS_MAX_M, 0.0, 1e-9, "LUMPS_MAX_M")
	check_close(U.shader_const(path, "BREATH_M"), JarGeometry.BREATH_M, 0.0, 1e-9, "BREATH_M")
	check_close(U.shader_const(path, "HOOCH_MAX_M"), JarGeometry.HOOCH_MAX_M, 0.0, 1e-9, "HOOCH_MAX_M")

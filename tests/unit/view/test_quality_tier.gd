extends TestCase
## Glass quality tiers (D-009, architecture.md §8.1, AC-01.2, AC-01.7): the tier swap is a
## material swap, Tier A never samples the screen, and Compatibility always gets Tier A.

const U := preload("res://tests/unit/view/view_test_util.gd")
const TIER_A_SHADERS: Array[String] = [QualityTier.SHADER_BACK, QualityTier.SHADER_FRONT_A]

var jar: JarView


func before_each() -> void:
	await U.tree_ready()


func after_each() -> void:
	if jar != null:
		jar.queue_free()
		jar = null


func test_choose_by_renderer_and_reduce_effects() -> void:
	check_eq(QualityTier.choose(QualityTier.RENDERER_MOBILE, false), QualityTier.Tier.B, "mobile")
	check_eq(QualityTier.choose(QualityTier.RENDERER_MOBILE, true), QualityTier.Tier.A, "mobile, reduce effects")
	check_eq(QualityTier.choose(QualityTier.RENDERER_COMPATIBILITY, false), QualityTier.Tier.A, "compatibility")
	check_eq(QualityTier.choose(QualityTier.RENDERER_COMPATIBILITY, true), QualityTier.Tier.A, "compatibility, reduce effects")
	check_eq(QualityTier.choose(QualityTier.RENDERER_FORWARD_PLUS, false), QualityTier.Tier.B, "forward_plus (desktop)")


func test_tier_a_never_samples_the_screen() -> void:
	for path: String in TIER_A_SHADERS:
		var src: String = U.source(path)
		check(not src.contains("hint_screen_texture"), "%s has no screen texture" % path.get_file())
		check(not src.contains("SCREEN_TEXTURE"), "%s has no SCREEN_TEXTURE" % path.get_file())
	check(U.source(QualityTier.SHADER_FRONT_B).contains("hint_screen_texture"), "Tier B samples the screen")


func test_no_bool_uniform_switches_glass() -> void:
	for path: String in [QualityTier.SHADER_BACK, QualityTier.SHADER_FRONT_A, QualityTier.SHADER_FRONT_B]:
		for name: String in U.uniforms(path):
			check_ne(U.uniforms(path)[name], "bool", "%s: %s is a bool uniform" % [path.get_file(), name])


func test_tier_a_draws_back_faces_before_front_faces() -> void:
	var q := QualityTier.new(Cubemap.new())
	var a: ShaderMaterial = q.material_for(QualityTier.Tier.A)
	check(a == q.back_a, "Tier A starts with the back pass")
	check(a.next_pass == q.front_a, "then the front pass")
	check(q.back_a.render_priority < q.front_a.render_priority, "back priority < front priority")
	check(U.source(QualityTier.SHADER_BACK).contains("cull_front"), "back pass culls front faces")
	check(U.source(QualityTier.SHADER_FRONT_A).contains("cull_back"), "front pass culls back faces")
	var b: ShaderMaterial = q.material_for(QualityTier.Tier.B)
	check(b == q.front_b, "Tier B is the screen-refraction front pass")
	check(b.next_pass == null, "Tier B has no back pass")


func test_switching_tiers_swaps_the_glass_material() -> void:
	jar = U.make_jar()
	jar.set_tier(QualityTier.Tier.B)
	check(jar.glass.material_override == jar.quality.front_b, "B on the glass")
	jar.set_tier(QualityTier.Tier.A)
	check(jar.glass.material_override == jar.quality.back_a, "A on the glass")
	check(jar.glass.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "glass casts no shadow")

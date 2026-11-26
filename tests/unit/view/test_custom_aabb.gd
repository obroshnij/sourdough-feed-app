extends TestCase
## The starter's custom_aabb (D-010): vertices move in the shader, so the bounds must cover the
## highest surface it can draw (max level x max rise, plus dome, lumps and breath) and a collapsed
## dome at the lowest level. A wrong box made the starter vanish in the spike.

const U := preload("res://tests/unit/view/view_test_util.gd")

var jar: JarView


func before_each() -> void:
	await U.tree_ready()


func after_each() -> void:
	if jar != null:
		jar.queue_free()
		jar = null


func test_box_covers_max_rise_plus_dome() -> void:
	var box: AABB = JarGeometry.starter_aabb()
	var top: float = JarGeometry.surface_top_m(JarGeometry.LEVEL_MAX_M, JarGeometry.RISE_MAX, 1.0)
	check(box.end.y >= top - 1e-6, "box top %s covers rise 3.0 at max level with full dome %s" % [box.end.y, top])
	check_between(top, 0.13, 0.14, "max surface about 13.8 mm under the 170 mm jar top")


func test_box_covers_a_collapsed_dome_at_level_zero() -> void:
	var box: AABB = JarGeometry.starter_aabb()
	var lowest: float = -JarGeometry.DOME_MAX_M - JarGeometry.LUMPS_MAX_M * 0.5 - JarGeometry.BREATH_M
	check(box.position.y <= lowest + 1e-6, "box bottom %s covers %s" % [box.position.y, lowest])


func test_box_covers_the_starter_radius() -> void:
	var box: AABB = JarGeometry.starter_aabb()
	for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, 1)]:
		var p: Vector3 = Vector3(corner.x * JarGeometry.STARTER_RADIUS_M * 0.7071, 0.02, corner.z * JarGeometry.STARTER_RADIUS_M * 0.7071)
		check(box.has_point(p), "rim point %s inside" % p)


func test_every_art_state_fits_the_box() -> void:
	var box: AABB = JarGeometry.starter_aabb()
	for s: StringName in StateLooks.states():
		var p: VisualParams = StateLooks.look_for(s)
		var top: float = JarGeometry.surface_top_m(p.level_m, p.rise, p.dome)
		check(top <= box.end.y + 1e-6, "%s top %s inside" % [s, top])


func test_bound_starter_uses_the_box() -> void:
	jar = U.make_jar()
	check(jar.starter.custom_aabb.is_equal_approx(JarGeometry.starter_aabb()), "custom_aabb set on Starter_Body")
	var mesh_box: AABB = jar.starter.mesh.get_aabb()
	check(jar.starter.custom_aabb.encloses(mesh_box), "custom box encloses the authored mesh %s" % mesh_box)

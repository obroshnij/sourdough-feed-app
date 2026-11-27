extends TestCase
## T2's planned acceptance rows from test-plan.md §3.13 (Phase 3 backfill):
## AC-01.6 jar framing, AC-02.6 reduce motion, AC-03.6 first tap still pokes, AC-03.8 idle return.

const U := preload("res://tests/unit/view/view_test_util.gd")
const DT: float = 1.0 / 60.0

var rig: OrbitCamera
var world: WorldView


func before_each() -> void:
	await U.tree_ready()


func after_each() -> void:
	if rig != null:
		rig.queue_free()
		rig = null
	if world != null:
		world.queue_free()
		world = null


func _rig() -> OrbitCamera:
	rig = OrbitCamera.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	rig.set_process(false)
	return rig


func _step(seconds: float) -> void:
	for i: int in int(ceil(seconds / DT)):
		rig._process(DT)


## Screen fraction from the top for a world point (clip space, includes the frustum shift).
static func _frac_y(cam: Camera3D, p: Vector3) -> float:
	var v: Vector3 = cam.global_transform.affine_inverse() * p
	var clip: Vector4 = cam.get_camera_projection() * Vector4(v.x, v.y, v.z, 1.0)
	return (1.0 - clip.y / clip.w) * 0.5


func _check_centered(region_top: float, region_h: float, screen_h: float, label: String) -> void:
	var r: OrbitCamera = _rig()
	r.reduce_motion = true
	r.set_jar_region(Rect2(0.0, region_top, 375.0, region_h), screen_h)
	r.apply_pose()
	var lo: float = 1e9
	var hi: float = -1e9
	for y: float in [0.0, 0.2035]:
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var f: float = _frac_y(r.camera, Vector3(c.x * 0.042, y, c.y * 0.042))
			lo = minf(lo, f)
			hi = maxf(hi, f)
	var jar_center: float = (lo + hi) * 0.5
	var region_center: float = (region_top + region_h * 0.5) / screen_h
	var jar_h: float = hi - lo
	check(absf(jar_center - region_center) <= 0.04 * jar_h,
			"%s: jar center %.4f vs region center %.4f (jar height %.4f)" % [label, jar_center, region_center, jar_h])
	check(lo >= region_top / screen_h and hi <= (region_top + region_h) / screen_h, "%s: whole jar inside the region" % label)
	r.queue_free()
	rig = null


func test_ac_01_6_jar_centered_in_the_region_at_se_and_pro_max() -> void:
	_check_centered(162.0, 425.0, 667.0, "iPhone SE")
	_check_centered(204.0, 638.0, 956.0, "iPhone 17 Pro Max")


func test_ac_03_8_idle_return_home_and_off_with_reduce_motion() -> void:
	var r: OrbitCamera = _rig()
	r.set_pose(40.0, 30.0, 0.3, OrbitCamera.HOME_TARGET)
	_step(19.0)
	check_close(r.yaw, 40.0, 0.0, 1e-6, "no move before 20 s")
	_step(1.0 + 1.6)
	check_close(r.yaw, OrbitCamera.HOME_YAW, 0.0, 0.1, "home after 20 s idle and the 1.5 s ease")
	check_close(r.pitch, OrbitCamera.HOME_PITCH, 0.0, 0.1, "pitch home")
	r.reduce_motion = true
	r.set_pose(40.0, 30.0, 0.3, OrbitCamera.HOME_TARGET)
	_step(25.0)
	check_close(r.yaw, 40.0, 0.0, 1e-6, "reduce motion: no idle return")


func test_ac_03_6_double_tap_still_reports_the_first_tap() -> void:
	var r: OrbitCamera = _rig()
	var taps: Array[Vector2] = []
	r.tapped.connect(func(p: Vector2) -> void: taps.append(p))
	r.set_pose(40.0, 30.0, 0.3, OrbitCamera.HOME_TARGET)
	r.gestures.press(0, Vector2(200, 400), 1000)
	r.gestures.release(0, Vector2(200, 400), 1060)
	check_eq(taps.size(), 1, "the first tap pokes at once, before any double tap is known")
	r.gestures.press(0, Vector2(204, 402), 1200)
	r.gestures.release(0, Vector2(204, 402), 1260)
	check_eq(taps.size(), 2, "the second tap pokes too")
	check(r.is_animating(), "and the double tap eases home")


func test_ac_02_6_reduce_motion_stops_decoration_not_the_sim() -> void:
	world = (load("res://src/view/world.tscn") as PackedScene).instantiate() as WorldView
	world.follow_session = false
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	world.set_process(false)
	var a := VisualParams.new()
	a.rise = 1.0
	world.set_visuals(a)
	world.set_reduce_motion(true)
	check_eq(world.jar.starter_mat.get_shader_parameter(&"motion_k"), 0.0, "breathing off")
	check(not world.jar.pops.motion_on, "pops off")
	check(world.rig.reduce_motion, "camera inertia, idle return and dollies off")
	var b := VisualParams.new()
	b.rise = 2.3
	world.follow_visuals(b)
	for i: int in 120:
		world._process(DT)
	check(world.jar.visuals.rise > 1.5, "the sim-driven rise still animates, got %s" % world.jar.visuals.rise)
	world.set_reduce_motion(false)
	check_eq(world.jar.starter_mat.get_shader_parameter(&"motion_k"), 1.0, "breathing back on")

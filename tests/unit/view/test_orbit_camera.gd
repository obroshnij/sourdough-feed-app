extends TestCase
## The jar camera (D-036, ux-design.md §6 and §15, test-plan AC-03). Gestures are driven through
## TouchGestures in pt and the rig is stepped with fixed deltas, so nothing depends on the clock.

const U := preload("res://tests/unit/view/view_test_util.gd")
const DT: float = 1.0 / 60.0

var rig: OrbitCamera


func before_each() -> void:
	await U.tree_ready()
	rig = OrbitCamera.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	rig.set_process(false)


func after_each() -> void:
	rig.queue_free()


func _step(seconds: float) -> void:
	for i: int in int(ceil(seconds / DT)):
		rig._process(DT)


func _drag(from: Vector2, delta: Vector2, steps: int) -> void:
	var g: TouchGestures = rig.gestures
	g.press(0, from, 0)
	for i: int in steps:
		g.move(0, from + delta * float(i + 1) / float(steps), 10 * (i + 1))


func test_home_pose_is_the_art_preview_pose() -> void:
	check_eq(rig.yaw, 0.0, "yaw")
	check_eq(rig.pitch, 15.0, "pitch")
	check_close(rig.distance(), 0.58, 0.0, 1e-6, "distance")
	var pos: Vector3 = rig.camera.global_position
	check_close(pos.y, 0.2551, 0.0, 0.0005, "camera y (art-direction §7)")
	check_close(pos.z, 0.5602, 0.0, 0.0005, "camera z (art-direction §7)")


func test_orbit_rates_per_pt() -> void:
	_drag(Vector2(100, 400), Vector2(40, 0), 4)
	check_close(rig.yaw, -40.0 * 0.30, 0.01, 0.0, "yaw 0.30 deg per pt")
	rig.gestures.release(0, Vector2(140, 400), 50)
	rig.stop_inertia()
	var p0: float = rig.pitch
	_drag(Vector2(100, 400), Vector2(0, 30), 3)
	check_close(rig.pitch - p0, 30.0 * 0.20, 0.01, 0.0, "pitch 0.20 deg per pt")


func test_long_drags_stay_inside_limits_plus_band_and_settle() -> void:
	_drag(Vector2(0, 0), Vector2(10000, 0), 200)
	check(rig.yaw >= -70.0 - 8.0 - 1e-6, "yaw >= -78 while held, got %s" % rig.yaw)
	_drag(Vector2(0, 0), Vector2(0, 10000), 200)
	check(rig.pitch <= 35.0 + 5.0 + 1e-6, "pitch <= 40 while held, got %s" % rig.pitch)
	rig.gestures.release(0, Vector2.ZERO, 5000)
	_step(2.0)
	check_between(rig.yaw, -70.0, 70.0, "yaw settles inside")
	check_between(rig.pitch, -5.0, 35.0, "pitch settles inside")


func test_pinch_zoom_range_with_band() -> void:
	var g: TouchGestures = rig.gestures
	g.press(0, Vector2(100, 400), 0)
	g.press(1, Vector2(200, 400), 0)
	for i: int in 40:
		g.move(1, Vector2(200 + 20 * (i + 1), 400), 10 * i)
	check(rig.zoom <= 2.2 * 1.08 + 1e-6, "zoom within 2.2x + 8%% while held, got %s" % rig.zoom)
	check(rig.zoom > 2.2, "a hard pinch reaches the band")
	g.release(1, Vector2(1000, 400), 500)
	g.release(0, Vector2(100, 400), 500)
	_step(1.0)
	check_between(rig.zoom, 1.0, 2.2, "settles inside 1.0 to 2.2")


func test_no_orbit_during_pinch_and_back_to_orbit_after() -> void:
	var g: TouchGestures = rig.gestures
	g.press(0, Vector2(100, 400), 0)
	g.press(1, Vector2(200, 400), 0)
	g.move(0, Vector2(80, 400), 10)
	check_eq(rig.yaw, 0.0, "a pinch never orbits")
	g.release(1, Vector2(200, 400), 20)
	g.move(0, Vector2(90, 400), 30)
	check_close(rig.yaw, -10.0 * 0.30, 0.01, 0.0, "one finger left: orbit resumes without a jump")


func test_double_tap_eases_home() -> void:
	rig.set_pose(40.0, 30.0, 0.3, OrbitCamera.HOME_TARGET)
	var g: TouchGestures = rig.gestures
	g.press(0, Vector2(200, 400), 1000)
	g.release(0, Vector2(200, 400), 1060)
	g.press(0, Vector2(205, 402), 1200)
	g.release(0, Vector2(205, 402), 1260)
	check(rig.is_animating(), "reset animates")
	_step(0.36)
	check_close(rig.yaw, 0.0, 0.0, 0.1, "yaw home")
	check_close(rig.pitch, 15.0, 0.0, 0.1, "pitch home")
	check_close(rig.distance(), 0.58, 0.0, 0.001, "distance home")


func test_inertia_decays_with_tau_250ms() -> void:
	rig.yaw_velocity = 30.0
	_step(1.25)
	check(absf(rig.yaw_velocity) < 0.3, "after 5 tau the speed is under 1%%, got %s" % rig.yaw_velocity)
	_step(10.0)
	var y: float = rig.yaw
	_step(1.0)
	check_close(rig.yaw, y, 0.0, 1e-9, "no drift after 10 s")


func test_reduce_motion_has_no_inertia() -> void:
	rig.reduce_motion = true
	rig.yaw_velocity = 100.0
	var y: float = rig.yaw
	_step(0.5)
	check_close(rig.yaw, y, 0.0, 1e-6, "no coasting")


func test_focus_presets_and_release() -> void:
	rig.set_pose(20.0, 10.0, 0.5, OrbitCamera.HOME_TARGET)
	rig.focus(&"surface")
	_step(0.6)
	check_close(rig.pitch, 76.0, 0.0, 0.01, "surface preset at 76 deg (ux-design §10)")
	rig.release_focus()
	_step(0.6)
	check_close(rig.yaw, 20.0, 0.0, 0.01, "back to the player's yaw")
	check_close(rig.pitch, 10.0, 0.0, 0.01, "back to the player's pitch")


func test_jar_region_shifts_the_frame() -> void:
	rig.reduce_motion = true
	rig.set_jar_region(Rect2(0, 162, 375, 425), 667.0)
	var center: float = (162.0 + 425.0 * 0.5) / 667.0
	check_close(rig.frame_shift, 0.5 - center, 0.0, 1e-6, "target moves to the region center")
	check(rig.frame_shift < 0.0, "the iPhone SE region sits below the middle")

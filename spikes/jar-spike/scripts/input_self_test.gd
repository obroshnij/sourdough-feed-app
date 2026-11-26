class_name InputSelfTest
extends Node
## Injects touch and mouse events with Input.parse_input_event and checks the
## camera and the GUI routing. Run windowed (headless may not dispatch input).
## Prints one PASS or FAIL line per check, then quits.

var orbit: OrbitCamera
var counts: Dictionary[String, int] = {}
var failures: int = 0
var blocker: Panel


func run(main: Node) -> void:
	orbit = main.get("orbit") as OrbitCamera
	Engine.max_fps = 60
	var layer := CanvasLayer.new()
	add_child(layer)
	blocker = Panel.new()
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.position = Vector2.ZERO
	blocker.size = Vector2(get_viewport().get_visible_rect().size.x, 300.0)
	layer.add_child(blocker)
	await _frames(10)
	print("TEST viewport=%s window=%s" % [str(get_viewport().get_visible_rect().size), str(DisplayServer.window_get_size())])
	await _test_orbit_and_inertia()
	await _test_pinch()
	await _test_double_tap()
	await _test_routing()
	await _test_mouse_emulation()
	print("TEST done failures=%d" % failures)
	get_tree().quit()


func _input(event: InputEvent) -> void:
	var k: String = event.get_class()
	counts[k] = counts.get(k, 0) + 1


func _test_orbit_and_inertia() -> void:
	var y0: float = orbit.yaw
	_touch(0, Vector2(270, 800), true)
	await _frames(1)
	for i: int in range(6):
		_drag(0, Vector2(270 + 30 * (i + 1), 800), Vector2(30, 0))
		await _frames(1)
	_touch(0, Vector2(450, 800), false)
	await _frames(1)
	var y_release: float = orbit.yaw
	await _frames(10)
	_check("one-finger drag orbits (yaw %.3f -> %.3f)" % [y0, y_release], absf(y_release - y0) > 0.05)
	_check("inertia keeps turning after release (+%.4f rad in 10 frames)" % absf(orbit.yaw - y_release), absf(orbit.yaw - y_release) > 0.005)
	await _frames(90)


func _test_pinch() -> void:
	orbit.yaw_velocity = 0.0
	var d0: float = orbit.distance
	var y0: float = orbit.yaw
	_touch(0, Vector2(200, 800), true)
	_touch(1, Vector2(340, 800), true)
	await _frames(1)
	for i: int in range(5):
		_drag(1, Vector2(340 + 20 * (i + 1), 800), Vector2(20, 0))
		await _frames(1)
	var d1: float = orbit.distance
	for i: int in range(5):
		_drag(1, Vector2(440 - 30 * (i + 1), 800), Vector2(-30, 0))
		await _frames(1)
	var d2: float = orbit.distance
	_touch(1, Vector2(290, 800), false)
	_touch(0, Vector2(200, 800), false)
	await _frames(2)
	_check("pinch apart zooms in (distance %.3f -> %.3f)" % [d0, d1], d1 < d0 * 0.9)
	_check("pinch together zooms out (distance %.3f -> %.3f)" % [d1, d2], d2 > d1 * 1.1)
	_check("no orbit during a pinch (yaw moved %.4f)" % absf(orbit.yaw - y0), absf(orbit.yaw - y0) < 0.001)


func _test_double_tap() -> void:
	orbit.yaw += 1.0
	orbit.distance = OrbitCamera.MAX_DISTANCE
	var resets: int = orbit.reset_count
	_touch(0, Vector2(270, 900), true)
	await _frames(2)
	_touch(0, Vector2(270, 900), false)
	await _frames(4)
	_touch(0, Vector2(272, 902), true)
	await _frames(2)
	_touch(0, Vector2(272, 902), false)
	await _frames(40)
	var yaw_err: float = absf(wrapf(orbit.yaw - OrbitCamera.DEFAULT_YAW, -PI, PI))
	_check("double tap resets (resets %d -> %d, yaw error %.4f, distance %.3f)" % [
		resets, orbit.reset_count, yaw_err, orbit.distance],
		orbit.reset_count == resets + 1 and yaw_err < 0.01 and absf(orbit.distance - OrbitCamera.DEFAULT_DISTANCE) < 0.005)


func _test_routing() -> void:
	# A drag that starts on a STOP Control never orbits, even after it leaves the Control.
	var e0: int = orbit.orbit_events
	_touch(0, Vector2(270, 150), true)
	await _frames(1)
	for i: int in range(8):
		_drag(0, Vector2(270 + 10 * i, 150 + 80 * (i + 1)), Vector2(10, 80))
		await _frames(1)
	_touch(0, Vector2(340, 790), false)
	await _frames(2)
	_check("drag that starts on a STOP panel never orbits (orbit events +%d)" % (orbit.orbit_events - e0), orbit.orbit_events == e0)
	# A drag that starts on the 3D view keeps orbiting when it slides over the panel.
	_touch(0, Vector2(270, 700), true)
	await _frames(1)
	for i: int in range(5):
		_drag(0, Vector2(270, 700 - 100 * (i + 1)), Vector2(0, -100))
		await _frames(1)
	var e1: int = orbit.orbit_events
	for i: int in range(3):
		_drag(0, Vector2(270 + 20 * (i + 1), 200), Vector2(20, 0))
		await _frames(1)
	_touch(0, Vector2(330, 200), false)
	await _frames(2)
	_check("drag from the 3D view keeps orbiting over the panel (orbit events +%d while over it)" % (orbit.orbit_events - e1), orbit.orbit_events - e1 == 3)
	_check("release over the panel still ends the camera's touch (fingers held: %d)" % orbit.held_fingers(), orbit.held_fingers() == 0)
	orbit.reset_view(false)
	await _frames(2)


func _test_mouse_emulation() -> void:
	counts.clear()
	var e0: int = orbit.orbit_events
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = Vector2(270, 800)
	mb.global_position = mb.position
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(mb)
	await _frames(1)
	for i: int in range(4):
		var mm := InputEventMouseMotion.new()
		mm.position = Vector2(270 + 25 * (i + 1), 800)
		mm.global_position = mm.position
		mm.relative = Vector2(25, 0)
		mm.screen_relative = Vector2(25, 0)
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mm)
		await _frames(1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(370, 800)
	up.global_position = up.position
	Input.parse_input_event(up)
	await _frames(2)
	print("TEST mouse injection event counts: %s" % str(counts))
	_check("emulate_touch_from_mouse orbits (orbit events +%d)" % (orbit.orbit_events - e0), orbit.orbit_events - e0 >= 3)
	_check("one mouse press+release gives exactly 2 ScreenTouch events (got %d)" % counts.get("InputEventScreenTouch", 0),
		counts.get("InputEventScreenTouch", 0) == 2)
	# The other direction: one touch should not loop back into a second touch.
	counts.clear()
	_touch(0, Vector2(270, 900), true)
	await _frames(1)
	_touch(0, Vector2(270, 900), false)
	await _frames(2)
	print("TEST touch injection event counts: %s" % str(counts))
	_check("one touch press+release gives 2 ScreenTouch (got %d) and %d emulated MouseButton" % [
		counts.get("InputEventScreenTouch", 0), counts.get("InputEventMouseButton", 0)],
		counts.get("InputEventScreenTouch", 0) == 2)


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	e.screen_relative = rel
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i: int in range(n):
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print("TEST %s %s" % ["PASS" if ok else "FAIL", label])

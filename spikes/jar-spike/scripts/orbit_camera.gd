class_name OrbitCamera
extends Node
## Touch camera for the jar.
## - One-finger orbit from InputEventScreenDrag.screen_relative, with inertia.
## - Our own two-finger pinch, tracked by finger index (iOS sends no pinch event).
## - Double-tap resets with an ease-out.
## - Reads input in _unhandled_input, so any Control with mouse_filter STOP wins.
## - Desktop: emulate_touch_from_mouse gives one finger; wheel and trackpad
##   magnify zoom only when no touchscreen exists (Android may also send
##   InputEventMagnifyGesture, which would double the pinch).
## - Frame shift: an off-axis frustum keeps the jar between the HUD and the
##   action bar, animated over shift_seconds.

const DEFAULT_YAW: float = 0.35
const DEFAULT_PITCH: float = 0.24
const DEFAULT_DISTANCE: float = 0.34
const MIN_PITCH: float = -0.10
const MAX_PITCH: float = 0.95
const MIN_DISTANCE: float = 0.16
const MAX_DISTANCE: float = 0.55
const ORBIT_PER_SCREEN: float = 3.6
const DAMPING: float = 4.0
const TAP_MAX_MS: int = 250
const TAP_MAX_MOVE: float = 14.0
const DOUBLE_TAP_MS: int = 320
const DOUBLE_TAP_DIST: float = 48.0
const RESET_SECONDS: float = 0.35

var camera: Camera3D
var target: Vector3 = Vector3(0.0, 0.065, 0.0)
var fov_width_deg: float = 30.0
var input_enabled: bool = true
## Follow owned fingers in _input (see _input). Off only to reproduce the bug.
var own_touches_in_input: bool = true
## Optional yaw limit in radians (0 = unlimited) with a rubber band past it.
var yaw_limit: float = 0.0
var rubber_band: float = 0.14

var yaw: float = DEFAULT_YAW
var pitch: float = DEFAULT_PITCH
var distance: float = DEFAULT_DISTANCE
var yaw_velocity: float = 0.0
var pitch_velocity: float = 0.0

var frame_shift: float = 0.0
var frame_shift_target: float = 0.0
var shift_seconds: float = 0.3

## Counters for the input self-test.
var orbit_events: int = 0
var pinch_events: int = 0
var reset_count: int = 0

var _touches: Dictionary[int, Vector2] = {}
var _pinch_span: float = 0.0
var _pinched_this_gesture: bool = false
var _frame_dyaw: float = 0.0
var _frame_dpitch: float = 0.0
var _last_move_ms: int = 0
var _press_ms: int = 0
var _press_pos: Vector2 = Vector2.ZERO
var _moved: float = 0.0
var _last_tap_ms: int = -100000
var _last_tap_pos: Vector2 = Vector2.ZERO
var _reset_t: float = -1.0
var _reset_from: Vector3 = Vector3.ZERO
var _shift_from: float = 0.0
var _shift_t: float = 1.0


func setup(cam: Camera3D) -> void:
	camera = cam
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.near = 0.02
	camera.far = 20.0
	camera.size = 2.0 * camera.near * tan(deg_to_rad(fov_width_deg) * 0.5)
	_apply()


func reset_view(animated: bool) -> void:
	reset_count += 1
	yaw_velocity = 0.0
	pitch_velocity = 0.0
	if not animated:
		yaw = DEFAULT_YAW
		pitch = DEFAULT_PITCH
		distance = DEFAULT_DISTANCE
		_reset_t = -1.0
		return
	var wrapped_yaw: float = DEFAULT_YAW + wrapf(yaw - DEFAULT_YAW, -PI, PI)
	_reset_from = Vector3(wrapped_yaw, pitch, distance)
	_reset_t = 0.0


## Shift the jar up (+) or down (-) by a fraction of the viewport height.
func set_frame_shift(fraction: float, animated: bool = true) -> void:
	frame_shift_target = fraction
	if animated:
		_shift_from = frame_shift
		_shift_t = 0.0
	else:
		frame_shift = fraction
		_shift_t = 1.0


## A finger the camera already owns (its press reached _unhandled_input) keeps
## driving the camera even over a STOP Control. Godot routes a ScreenDrag to the
## Control under the finger, so without this the orbit stops on the action bar.
## (The release still arrives, so no stuck finger.) Found by the self-test,
## reproduce with `-- --selftest --no-own-touches`.
func _input(event: InputEvent) -> void:
	if not input_enabled or camera == null or not own_touches_in_input:
		return
	if event is InputEventScreenDrag and _touches.has((event as InputEventScreenDrag).index):
		_on_drag(event as InputEventScreenDrag)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed and _touches.has(st.index):
			_on_touch(st)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or camera == null:
		return
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not DisplayServer.is_touchscreen_available():
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance * 0.93, MIN_DISTANCE, MAX_DISTANCE)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance / 0.93, MIN_DISTANCE, MAX_DISTANCE)
	elif event is InputEventMagnifyGesture and not DisplayServer.is_touchscreen_available():
		var mg := event as InputEventMagnifyGesture
		distance = clampf(distance / maxf(mg.factor, 0.01), MIN_DISTANCE, MAX_DISTANCE)


func _on_touch(e: InputEventScreenTouch) -> void:
	var now: int = Time.get_ticks_msec()
	if e.pressed:
		_touches[e.index] = e.position
		_reset_t = -1.0
		if _touches.size() == 1:
			_press_ms = now
			_press_pos = e.position
			_moved = 0.0
			_pinched_this_gesture = false
			yaw_velocity = 0.0
			pitch_velocity = 0.0
		elif _touches.size() == 2:
			_pinch_span = _current_span()
			_pinched_this_gesture = true
			yaw_velocity = 0.0
			pitch_velocity = 0.0
		return
	_touches.erase(e.index)
	if _touches.size() < 2:
		_pinch_span = 0.0
	if _touches.is_empty():
		var was_tap: bool = not _pinched_this_gesture and now - _press_ms <= TAP_MAX_MS and _moved <= TAP_MAX_MOVE
		if was_tap:
			if now - _last_tap_ms <= DOUBLE_TAP_MS and e.position.distance_to(_last_tap_pos) <= DOUBLE_TAP_DIST:
				_last_tap_ms = -100000
				reset_view(true)
			else:
				_last_tap_ms = now
				_last_tap_pos = e.position
		# A finger that rests before lifting should not fling the jar.
		if now - _last_move_ms > 80 or _pinched_this_gesture:
			yaw_velocity = 0.0
			pitch_velocity = 0.0


func _on_drag(e: InputEventScreenDrag) -> void:
	_touches[e.index] = e.position
	_moved += e.screen_relative.length()
	_last_move_ms = Time.get_ticks_msec()
	if _touches.size() >= 2:
		var span: float = _current_span()
		if _pinch_span > 1.0 and span > 1.0:
			distance = clampf(distance * _pinch_span / span, MIN_DISTANCE, MAX_DISTANCE)
			pinch_events += 1
		_pinch_span = span
		return
	if _pinched_this_gesture:
		return
	var width: float = maxf(float(DisplayServer.window_get_size().x), 1.0)
	var dyaw: float = -e.screen_relative.x / width * ORBIT_PER_SCREEN
	var dpitch: float = e.screen_relative.y / width * ORBIT_PER_SCREEN
	yaw = _limit_yaw(yaw + dyaw * _rubber_factor(dyaw))
	pitch = clampf(pitch + dpitch, MIN_PITCH, MAX_PITCH)
	_frame_dyaw += dyaw
	_frame_dpitch += dpitch
	orbit_events += 1


func _process(delta: float) -> void:
	if camera == null:
		return
	var dragging: bool = _touches.size() == 1 and not _pinched_this_gesture
	if dragging:
		var dt: float = maxf(delta, 0.001)
		yaw_velocity = lerpf(yaw_velocity, _frame_dyaw / dt, 0.5)
		pitch_velocity = lerpf(pitch_velocity, _frame_dpitch / dt, 0.5)
	elif _touches.is_empty():
		yaw = _limit_yaw(yaw + yaw_velocity * delta)
		pitch = clampf(pitch + pitch_velocity * delta, MIN_PITCH, MAX_PITCH)
		var decay: float = exp(-DAMPING * delta)
		yaw_velocity *= decay
		pitch_velocity *= decay * decay
		_spring_yaw(delta)
	_frame_dyaw = 0.0
	_frame_dpitch = 0.0
	if _reset_t >= 0.0:
		_reset_t = minf(_reset_t + delta / RESET_SECONDS, 1.0)
		var k: float = 1.0 - pow(1.0 - _reset_t, 3.0)
		yaw = lerpf(_reset_from.x, DEFAULT_YAW, k)
		pitch = lerpf(_reset_from.y, DEFAULT_PITCH, k)
		distance = lerpf(_reset_from.z, DEFAULT_DISTANCE, k)
		if _reset_t >= 1.0:
			_reset_t = -1.0
	if _shift_t < 1.0:
		_shift_t = minf(_shift_t + delta / shift_seconds, 1.0)
		var ks: float = 1.0 - pow(1.0 - _shift_t, 3.0)
		frame_shift = lerpf(_shift_from, frame_shift_target, ks)
	_apply()


func _apply() -> void:
	var dir := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	var pos: Vector3 = target + dir * distance
	camera.look_at_from_position(pos, target, Vector3.UP)
	var vp_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var aspect: float = vp_size.x / maxf(vp_size.y, 1.0)
	var near_height: float = camera.size / maxf(aspect, 0.01)
	camera.frustum_offset = Vector2(0.0, -frame_shift * near_height)


func held_fingers() -> int:
	return _touches.size()


func _current_span() -> float:
	var pts: Array[Vector2] = []
	for k: int in _touches:
		pts.append(_touches[k])
		if pts.size() == 2:
			break
	if pts.size() < 2:
		return 0.0
	return pts[0].distance_to(pts[1])


func _rubber_factor(dyaw: float) -> float:
	if yaw_limit <= 0.0:
		return 1.0
	var over: float = absf(yaw - DEFAULT_YAW) - yaw_limit
	var pushing_out: bool = signf(dyaw) == signf(yaw - DEFAULT_YAW)
	if over > 0.0 and pushing_out:
		return clampf(1.0 - over / rubber_band, 0.0, 1.0) * 0.5
	return 1.0


func _limit_yaw(y: float) -> float:
	if yaw_limit <= 0.0:
		return y
	return clampf(y, DEFAULT_YAW - yaw_limit - rubber_band, DEFAULT_YAW + yaw_limit + rubber_band)


func _spring_yaw(delta: float) -> void:
	if yaw_limit <= 0.0:
		return
	var rel: float = yaw - DEFAULT_YAW
	if absf(rel) > yaw_limit:
		var edge: float = DEFAULT_YAW + signf(rel) * yaw_limit
		yaw = lerpf(yaw, edge, 1.0 - exp(-12.0 * delta))
		yaw_velocity = 0.0

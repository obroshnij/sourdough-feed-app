class_name OrbitCamera
extends Node3D
## The jar camera rig (D-036, ux-design.md §6 and §15, art-direction.md §7).
## - Claims a finger when its press reaches _unhandled_input (no Control took it), then follows
##   that finger in _input until release, so an orbit keeps going over the action bar.
## - One finger orbits (yaw 0.30 deg/pt, pitch 0.20 deg/pt) with inertia (tau 250 ms).
## - Our own pinch zooms 1.0x (home distance) to 2.2x, with an 8% rubber band while held.
## - Double tap eases home over 350 ms. 20 s idle eases home over 1.5 s.
## - Home: yaw -12 deg (toward the key side), pitch 15 deg, the art preview distance and target.
## - Free orbit: yaw +-70 deg from the front (8 deg band), pitch -5 to +35 deg (5 deg band). Focus presets
##   (inspection) may go past these.
## - Frame shift: an off-axis frustum centers the jar in the region the UI leaves free.
## Pose angles are in degrees.

signal tapped(screen_pos: Vector2)
signal zoom_limit_reached()

const HOME_TARGET: Vector3 = Vector3(0.0, 0.105, 0.0)
const HOME_DISTANCE: float = 0.58
## In game the home pose turns 12 degrees toward the key side (director, after the art review).
## Captures for sign-off use yaw 0, the reference pose.
const HOME_YAW: float = -12.0
## Free-orbit yaw limits are measured from the front (ux-design §6), not from home.
const FRONT_YAW: float = 0.0
const HOME_PITCH: float = 15.0
const FOV_DEG: float = 33.4
const NEAR: float = 0.01

const YAW_PER_PT: float = 0.30
const PITCH_PER_PT: float = 0.20
const YAW_LIMIT: float = 70.0
const YAW_BAND: float = 8.0
const PITCH_MIN: float = -5.0
const PITCH_MAX: float = 35.0
const PITCH_BAND: float = 5.0
const ZOOM_MAX: float = 2.2
const ZOOM_BAND: float = 0.08
const INERTIA_TAU: float = 0.25
const REST_MS: int = 80
const RESET_S: float = 0.35
const FOCUS_S: float = 0.5
const IDLE_S: float = 20.0
const IDLE_RETURN_S: float = 1.5
const SETTLE_RATE: float = 14.0
const SURFACE_PITCH: float = 76.0
## Jar bounds for framing: floor to the loose lid top, centered. At the home pitch the projected
## height (0.2035 m tall, 0.084 m wide) is about 0.22 m.
const JAR_CENTER: Vector3 = Vector3(0.0, 0.1018, 0.0)
const JAR_EXTENT_M: float = 0.22
const FRAME_MARGIN: float = 0.06

## Pose (degrees and meters).
var yaw: float = HOME_YAW
var pitch: float = HOME_PITCH
var zoom: float = 1.0
var target: Vector3 = HOME_TARGET
## Fraction of the viewport height to move the target up (+) or down (-).
var frame_shift: float = 0.0
## Vertical field of view. Captures widen it to cut a close-up from the middle of the window.
var fov_deg: float = FOV_DEG

## Home distance and target. The defaults are the art preview pose; set_jar_region() replaces them
## so the whole jar fits the free region with even margins.
var home_dist: float = HOME_DISTANCE
var home_target: Vector3 = HOME_TARGET
var yaw_velocity: float = 0.0
var pitch_velocity: float = 0.0
var input_enabled: bool = true
var reduce_motion: bool = false
## Where the starter surface is, so focus presets frame the real starter (world y, meters).
var starter_top_y: float = 0.098
var starter_level_m: float = 0.030
var focus_target: StringName = &""

var camera: Camera3D
var gestures := TouchGestures.new()

var _anim_from: Pose
var _anim_to: Pose
var _anim_t: float = -1.0
var _anim_s: float = 0.0
var _anim_ease: int = 0
var _free_pose: Pose = null
var _interacting: bool = false
var _nudge_from: float = -1.0
var _idle_s: float = 0.0
var _frame_dyaw: float = 0.0
var _frame_dpitch: float = 0.0
var _last_move_ms: int = 0
var _region_shift: float = 0.0
var _sheet_shift: float = 0.0
var _shift_from: float = 0.0
var _shift_t: float = 1.0
var _zoom_at_limit: bool = false

enum Ease { OUT_CUBIC, IN_OUT_CUBIC, IN_OUT_SINE }


## A camera pose: angles in degrees, zoom as home distance / distance.
class Pose:
	var yaw: float
	var pitch: float
	var zoom: float
	var target: Vector3

	func _init(p_yaw: float, p_pitch: float, p_zoom: float, p_target: Vector3) -> void:
		yaw = p_yaw
		pitch = p_pitch
		zoom = p_zoom
		target = p_target


func home_pose() -> Pose:
	return Pose.new(HOME_YAW, HOME_PITCH, 1.0, home_target)


func current_pose() -> Pose:
	return Pose.new(yaw, pitch, zoom, target)


func _ready() -> void:
	camera = get_node_or_null(^"Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = NEAR
	camera.far = 20.0
	camera.current = true
	gestures.orbited.connect(_on_orbited)
	gestures.pinched.connect(_on_pinched)
	gestures.tapped.connect(_on_tapped)
	gestures.double_tapped.connect(_on_double_tapped)
	gestures.began.connect(_on_began)
	gestures.ended.connect(_on_ended)
	apply_pose()


func home_distance() -> float:
	return home_dist


func distance() -> float:
	return home_dist / zoom


## Snaps to a pose. Used by captures, tests and the scrubber.
func set_pose(p_yaw: float, p_pitch: float, p_distance: float, p_target: Vector3) -> void:
	_anim_t = -1.0
	yaw = p_yaw
	pitch = p_pitch
	zoom = home_dist / maxf(p_distance, 0.001)
	target = p_target
	yaw_velocity = 0.0
	pitch_velocity = 0.0
	apply_pose()


func go_home(animated: bool) -> void:
	focus_target = &""
	_free_pose = null
	_move_to(home_pose(), RESET_S if animated and not reduce_motion else 0.0, Ease.OUT_CUBIC)


## Inspection and event presets (Bus.camera_focus_requested): bubbles, surface, height, top, home.
func focus(what: StringName) -> void:
	if what == &"home":
		go_home(true)
		return
	if focus_target == &"":
		_free_pose = current_pose()
	focus_target = what
	var pose: Pose = focus_pose(what)
	gestures.cancel_all()
	yaw_velocity = 0.0
	pitch_velocity = 0.0
	_move_to(pose, 0.0 if reduce_motion else FOCUS_S, Ease.IN_OUT_CUBIC)


## Smell moment dolly: 12% closer over 600 ms, back over 400 ms (ux-design.md §15). Off with reduce motion.
func nudge(on: bool) -> void:
	if reduce_motion or focus_target != &"":
		return
	if on and _nudge_from < 0.0:
		_nudge_from = zoom
		_move_to(Pose.new(yaw, pitch, zoom * 1.12, target), 0.6, Ease.IN_OUT_SINE)
	elif not on and _nudge_from >= 0.0:
		_move_to(Pose.new(yaw, pitch, _nudge_from, target), 0.4, Ease.IN_OUT_SINE)
		_nudge_from = -1.0


## Back to where the player left the orbit.
func release_focus() -> void:
	if focus_target == &"":
		return
	focus_target = &""
	var back: Pose = _free_pose if _free_pose != null else home_pose()
	_free_pose = null
	_move_to(back, 0.0 if reduce_motion else FOCUS_S, Ease.IN_OUT_CUBIC)


## The pose for a focus preset. Close-ups match art-direction.md §16.2.
func focus_pose(what: StringName) -> Pose:
	var floor_y: float = JarGeometry.FLOOR_Y_M
	match what:
		&"bubbles":
			var y: float = floor_y + 0.55 * starter_level_m
			var off := Vector3(-0.0737, 0.012, 0.1386)
			return Pose.new(rad_to_deg(atan2(off.x, off.z)), rad_to_deg(asin(off.y / off.length())), home_dist / off.length(), Vector3(0.0, y, 0.0))
		&"surface":
			var off_s := Vector3(0.0, 0.194, 0.0524)
			return Pose.new(0.0, SURFACE_PITCH, home_dist / off_s.length(), Vector3(0.0, starter_top_y, -0.004))
		&"height":
			var band_y: float = floor_y + starter_level_m
			return Pose.new(0.0, 4.0, home_dist / 0.30, Vector3(0.0, (band_y + starter_top_y) * 0.5, 0.0))
		&"top":
			return Pose.new(0.0, 50.0, home_dist / 0.36, Vector3(0.0, 0.15, 0.0))
	return home_pose()


## The free region (Bus.jar_region_changed) in pt, and the screen height in pt.
func set_jar_region(region: Rect2, screen_h_pt: float) -> void:
	if screen_h_pt <= 1.0 or region.size.y <= 1.0:
		return
	var center: float = (region.position.y + region.size.y * 0.5) / screen_h_pt
	_region_shift = 0.5 - center
	# Fit the jar's projected height into the region, with FRAME_MARGIN of it top and bottom.
	var frac: float = clampf(region.size.y / screen_h_pt, 0.2, 1.0)
	var fit: float = JAR_EXTENT_M / (2.0 * tan(deg_to_rad(fov_deg) * 0.5) * frac * (1.0 - 2.0 * FRAME_MARGIN))
	home_dist = clampf(fit, 0.35, 1.5)
	home_target = JAR_CENTER
	if focus_target == &"" and not gestures.active():
		target = home_target
		apply_pose()
	_start_shift()


## A sheet covers the bottom `cover_fraction` of the screen: lift the jar into the space above it.
func set_sheet_cover(cover_fraction: float) -> void:
	_sheet_shift = 0.0 if cover_fraction <= 0.0 else clampf(cover_fraction * 0.5, 0.0, 0.3)
	_start_shift()


func _start_shift() -> void:
	_shift_from = frame_shift
	_shift_t = 1.0 if reduce_motion else 0.0
	if reduce_motion:
		frame_shift = _region_shift + _sheet_shift


func stop_inertia() -> void:
	yaw_velocity = 0.0
	pitch_velocity = 0.0


func set_input_enabled(on: bool) -> void:
	input_enabled = on
	if not on:
		gestures.cancel_all()
		stop_inertia()


func _pt_per_unit() -> float:
	var ss: float = maxf(DisplayServer.screen_get_scale(), 0.01)
	var cs: float = get_window().content_scale_factor if is_inside_tree() else 1.0
	return cs / ss


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or camera == null:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and not gestures.is_claimed(st.index):
			gestures.press(st.index, st.position * _pt_per_unit(), Time.get_ticks_msec())
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not DisplayServer.is_touchscreen_available():
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.07, false)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / 1.07, false)
	elif event is InputEventMagnifyGesture and not DisplayServer.is_touchscreen_available():
		_zoom_by((event as InputEventMagnifyGesture).factor, false)


## Follows claimed fingers even over STOP Controls (architecture.md §9, AC-03.10).
func _input(event: InputEvent) -> void:
	if not input_enabled or camera == null:
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if gestures.is_claimed(sd.index):
			_last_move_ms = Time.get_ticks_msec()
			gestures.move(sd.index, sd.position * _pt_per_unit(), _last_move_ms)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed and gestures.is_claimed(st.index):
			gestures.release(st.index, st.position * _pt_per_unit(), Time.get_ticks_msec(), st.canceled)
			get_viewport().set_input_as_handled()


func _on_began() -> void:
	_idle_s = 0.0
	_anim_t = -1.0
	stop_inertia()
	_set_interacting(true)


func _on_ended() -> void:
	_idle_s = 0.0
	if reduce_motion or Time.get_ticks_msec() - _last_move_ms > REST_MS:
		stop_inertia()
	if yaw_velocity == 0.0 and pitch_velocity == 0.0:
		_set_interacting(false)


func _on_orbited(delta_pt: Vector2) -> void:
	if focus_target != &"":
		return
	var dyaw: float = -delta_pt.x * YAW_PER_PT
	var dpitch: float = delta_pt.y * PITCH_PER_PT
	yaw = _banded(yaw, dyaw, FRONT_YAW - YAW_LIMIT, FRONT_YAW + YAW_LIMIT, YAW_BAND)
	pitch = _banded(pitch, dpitch, PITCH_MIN, PITCH_MAX, PITCH_BAND)
	_frame_dyaw += dyaw
	_frame_dpitch += dpitch


func _on_pinched(scale: float) -> void:
	if focus_target != &"":
		return
	_zoom_by(scale, true)


func _zoom_by(scale: float, held: bool) -> void:
	var lo: float = 1.0
	var hi: float = ZOOM_MAX
	var band_lo: float = lo / (1.0 + ZOOM_BAND) if held else lo
	var band_hi: float = hi * (1.0 + ZOOM_BAND) if held else hi
	var z: float = zoom * scale
	if z > hi:
		z = hi + (z - hi) * 0.5
	elif z < lo:
		z = lo - (lo - z) * 0.5
	zoom = clampf(z, band_lo, band_hi)
	var at_limit: bool = zoom >= hi or zoom <= lo
	if at_limit and not _zoom_at_limit:
		zoom_limit_reached.emit()
		if OS.get_name() == "Android":
			Input.vibrate_handheld(10, 0.3)
	_zoom_at_limit = at_limit


func _on_tapped(pos_pt: Vector2) -> void:
	tapped.emit(pos_pt / maxf(_pt_per_unit(), 0.0001))


func _on_double_tapped(_pos_pt: Vector2) -> void:
	go_home(true)


## A drag past a limit meets resistance that grows to a hard stop at limit + band.
static func _banded(value: float, delta: float, lo: float, hi: float, band: float) -> float:
	var v: float = value + delta
	if delta > 0.0 and value > hi:
		v = value + delta * clampf(1.0 - (value - hi) / band, 0.0, 1.0)
	elif delta < 0.0 and value < lo:
		v = value + delta * clampf(1.0 - (lo - value) / band, 0.0, 1.0)
	return clampf(v, lo - band, hi + band)


func _process(delta: float) -> void:
	if camera == null:
		return
	var dragging: bool = gestures.fingers.size() == 1
	if dragging:
		var dt: float = maxf(delta, 0.001)
		yaw_velocity = lerpf(yaw_velocity, _frame_dyaw / dt, 0.5)
		pitch_velocity = lerpf(pitch_velocity, _frame_dpitch / dt, 0.5)
	elif not gestures.active():
		_coast(delta)
	_frame_dyaw = 0.0
	_frame_dpitch = 0.0
	_animate(delta)
	_idle(delta)
	if _shift_t < 1.0:
		_shift_t = minf(_shift_t + delta / 0.3, 1.0)
		var k: float = 1.0 - pow(1.0 - _shift_t, 3.0)
		frame_shift = lerpf(_shift_from, _region_shift + _sheet_shift, k)
	apply_pose()


## Inertia after release, then settle back inside the limits.
func _coast(delta: float) -> void:
	if reduce_motion:
		stop_inertia()
	var moving: bool = yaw_velocity != 0.0 or pitch_velocity != 0.0
	yaw += yaw_velocity * delta
	pitch += pitch_velocity * delta
	var decay: float = exp(-delta / INERTIA_TAU)
	yaw_velocity *= decay
	pitch_velocity *= decay
	if absf(yaw_velocity) < 0.05:
		yaw_velocity = 0.0
	if absf(pitch_velocity) < 0.05:
		pitch_velocity = 0.0
	if focus_target == &"" and _anim_t < 0.0:
		var k: float = 1.0 - exp(-SETTLE_RATE * delta)
		var y_lo: float = FRONT_YAW - YAW_LIMIT
		var y_hi: float = FRONT_YAW + YAW_LIMIT
		if yaw > y_hi or yaw < y_lo:
			yaw_velocity = 0.0
			yaw = _settle(clampf(yaw, y_lo - YAW_BAND, y_hi + YAW_BAND), y_lo, y_hi, k)
		if pitch > PITCH_MAX or pitch < PITCH_MIN:
			pitch_velocity = 0.0
			pitch = _settle(pitch, PITCH_MIN, PITCH_MAX, k)
		if zoom > ZOOM_MAX or zoom < 1.0:
			zoom = _settle(zoom, 1.0, ZOOM_MAX, k)
	if moving and yaw_velocity == 0.0 and pitch_velocity == 0.0:
		_set_interacting(false)


## One spring step back inside [lo, hi], snapping the last hair so it ends exactly on the limit.
static func _settle(value: float, lo: float, hi: float, k: float) -> float:
	var inside: float = clampf(value, lo, hi)
	var v: float = lerpf(value, inside, k)
	return inside if absf(v - inside) < 1e-3 else v


func _idle(delta: float) -> void:
	if gestures.active() or focus_target != &"" or _anim_t >= 0.0 or reduce_motion:
		_idle_s = 0.0
		return
	_idle_s += delta
	if _idle_s >= IDLE_S:
		_idle_s = 0.0
		var at_home: bool = absf(yaw - HOME_YAW) < 0.1 and absf(pitch - HOME_PITCH) < 0.1 and absf(zoom - 1.0) < 0.001
		if not at_home:
			_move_to(home_pose(), IDLE_RETURN_S, Ease.IN_OUT_SINE)


func _move_to(pose: Pose, seconds: float, ease_kind: int) -> void:
	stop_inertia()
	if seconds <= 0.0:
		yaw = pose.yaw
		pitch = pose.pitch
		zoom = pose.zoom
		target = pose.target
		_anim_t = -1.0
		apply_pose()
		return
	_anim_from = current_pose()
	_anim_to = pose
	_anim_s = seconds
	_anim_ease = ease_kind
	_anim_t = 0.0


func _animate(delta: float) -> void:
	if _anim_t < 0.0:
		return
	_anim_t = minf(_anim_t + delta / _anim_s, 1.0)
	var x: float = _anim_t
	var k: float
	match _anim_ease:
		Ease.IN_OUT_CUBIC:
			k = 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5
		Ease.IN_OUT_SINE:
			k = -(cos(PI * x) - 1.0) * 0.5
		_:
			k = 1.0 - pow(1.0 - x, 3.0)
	yaw = lerpf(_anim_from.yaw, _anim_to.yaw, k)
	pitch = lerpf(_anim_from.pitch, _anim_to.pitch, k)
	zoom = lerpf(_anim_from.zoom, _anim_to.zoom, k)
	target = _anim_from.target.lerp(_anim_to.target, k)
	if _anim_t >= 1.0:
		_anim_t = -1.0


func is_animating() -> bool:
	return _anim_t >= 0.0


func apply_pose() -> void:
	if camera == null:
		return
	var y: float = deg_to_rad(yaw)
	var p: float = deg_to_rad(pitch)
	var dir := Vector3(cos(p) * sin(y), sin(p), cos(p) * cos(y))
	var pos: Vector3 = target + dir * distance()
	var up: Vector3 = Vector3.UP if absf(pitch) < 89.0 else Vector3.FORWARD
	camera.look_at_from_position(pos, target, up)
	camera.size = 2.0 * NEAR * tan(deg_to_rad(fov_deg) * 0.5)
	camera.frustum_offset = Vector2(0.0, -frame_shift * camera.size)


func _set_interacting(on: bool) -> void:
	if on == _interacting:
		return
	_interacting = on
	var bus: Node = get_node_or_null(^"/root/Bus")
	if bus == null:
		return
	if on:
		bus.emit_signal(&"interaction_started")
	else:
		bus.emit_signal(&"interaction_ended")

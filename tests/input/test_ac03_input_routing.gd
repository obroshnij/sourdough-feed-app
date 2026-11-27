extends TestCase
## AC-03.2b, 03.10, 03.11 and 03.12: touch routing between the jar camera and the UI, through the real
## viewport. Events go in with Viewport.push_input, so GUI routing decides who sees them, as on a phone:
## the camera (OrbitCamera) claims a finger in _unhandled_input and follows it in _input (D-036,
## architecture §9), and STOP Controls stand in for the action bar and a sheet's scrim.
## Limits are the AC's own numbers (yaw ±70° + 8°, pitch -5° to 35° + 5°, zoom 1.0 to 2.2 + 8%).

const YAW_OUTER: float = 70.0 + 8.0
const PITCH_LOW: float = -5.0 - 5.0
const PITCH_HIGH: float = 35.0 + 5.0
const ZOOM_LOW: float = 1.0 / 1.08
const ZOOM_HIGH: float = 2.2 * 1.08
const FUZZ_EVENTS: int = 10000

var _tree: SceneTree = null
var _rig: OrbitCamera = null
var _nodes: Array[Node] = []
var _size: Vector2 = Vector2.ZERO


func before_each() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	await _tree.process_frame
	_rig = OrbitCamera.new()
	_tree.root.add_child(_rig)
	_rig.set_process(false)
	_nodes = [_rig]
	_size = _tree.root.get_visible_rect().size


func after_each() -> void:
	_release_all()
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


## AC-03.10 and 03.2b: a finger that starts on the jar and slides over the action bar keeps orbiting for
## the whole drag; its release over the bar reaches the camera (no finger left claimed), and the bar's
## button never fires.
func test_ac_03_10_a_jar_drag_crosses_the_bar_and_ends_cleanly() -> void:
	var bar: Button = _bar()
	var pressed: Array[int] = [0]
	bar.pressed.connect(func() -> void: pressed[0] += 1)
	var start := Vector2(_size.x * 0.2, _size.y * 0.2)
	_touch(0, start, true)
	check(_rig.gestures.is_claimed(0), "the camera claims a finger that starts on the jar")
	var yaw_at_bar: float = 0.0
	var pos: Vector2 = start
	for i: int in 24:
		pos += Vector2(_size.x * 0.025, _size.y * 0.03)
		_drag(0, pos)
		if yaw_at_bar == 0.0 and bar.get_global_rect().has_point(pos):
			yaw_at_bar = _rig.yaw
	check(bar.get_global_rect().has_point(pos), "the finger ends over the bar")
	check(yaw_at_bar != 0.0 and _rig.yaw != yaw_at_bar, "the orbit continues over the bar (%.2f then %.2f)" % [yaw_at_bar, _rig.yaw])
	_touch(0, pos, false)
	check(not _rig.gestures.is_claimed(0), "the release over the bar reaches the camera: no finger stays claimed")
	check_eq(pressed[0], 0, "the bar's button never fires")


## AC-03.11 and 03.9's camera side: touches that start on a STOP Control (a sheet's scrim, a bar button)
## never move the camera, even when they drag across the jar.
func test_ac_03_11_a_scrim_drag_never_moves_the_camera() -> void:
	var scrim := Control.new()
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.position = Vector2.ZERO
	scrim.size = _size
	_tree.root.add_child(scrim)
	_nodes.append(scrim)
	var before := Vector3(_rig.yaw, _rig.pitch, _rig.zoom)
	var pos := Vector2(_size.x * 0.5, _size.y * 0.5)
	_touch(0, pos, true)
	check(not _rig.gestures.is_claimed(0), "a touch on the scrim is not the camera's")
	for i: int in 20:
		pos += Vector2(_size.x * 0.02, -_size.y * 0.02)
		_drag(0, pos)
	_touch(0, pos, false)
	check_eq(Vector3(_rig.yaw, _rig.pitch, _rig.zoom), before, "the camera never moved")
	_nodes.erase(scrim)
	scrim.free()
	var bar: Button = _bar()
	var on_bar := bar.get_global_rect().get_center()
	_touch(1, on_bar, true)
	check(not _rig.gestures.is_claimed(1), "a press on a bar button is not the camera's")
	pos = on_bar
	for i: int in 20:
		pos += Vector2(0.0, -_size.y * 0.03)
		_drag(1, pos)
	_touch(1, pos, false)
	check_eq(Vector3(_rig.yaw, _rig.pitch, _rig.zoom), before, "dragging from the bar over the jar never orbits")


## AC-03.12: 10,000 random touch events (1 to 3 fingers, random indices, out-of-order and canceled
## releases, some over the bar). No NaN, the pose stays inside the limits plus bands, and once every finger
## is up, a one-finger drag orbits normally.
func test_ac_03_12_ten_thousand_random_touches() -> void:
	var bar: Button = _bar()
	bar.pressed.connect(func() -> void: pass)
	var gen := RandomNumberGenerator.new()
	gen.seed = 3012
	var down: Dictionary[int, Vector2] = {}
	var bad: PackedStringArray = PackedStringArray()
	for i: int in FUZZ_EVENTS:
		var roll: float = gen.randf()
		var index: int = gen.randi_range(0, 4)
		var pos := Vector2(gen.randf() * _size.x, gen.randf() * _size.y)
		if roll < 0.25 and down.size() < 3 and not down.has(index):
			down[index] = pos
			_touch(index, pos, true)
		elif roll < 0.4 and not down.is_empty():
			var k: int = down.keys()[gen.randi_range(0, down.size() - 1)]
			down.erase(k)
			_touch(k, pos, false, gen.randf() < 0.2)
		elif not down.is_empty():
			var k: int = down.keys()[gen.randi_range(0, down.size() - 1)]
			var to: Vector2 = down[k] + Vector2(gen.randf_range(-12.0, 12.0), gen.randf_range(-12.0, 12.0))
			down[k] = to
			_drag(k, to)
		if i % 50 == 0:
			_rig._process(1.0 / 60.0)
		if is_nan(_rig.yaw) or is_nan(_rig.pitch) or is_nan(_rig.zoom):
			bad.append("NaN at event %d" % i)
		elif absf(_rig.yaw) > YAW_OUTER + 1e-6 or _rig.pitch < PITCH_LOW - 1e-6 or _rig.pitch > PITCH_HIGH + 1e-6 \
				or _rig.zoom < ZOOM_LOW - 1e-6 or _rig.zoom > ZOOM_HIGH + 1e-6:
			bad.append("event %d: yaw %.2f, pitch %.2f, zoom %.3f" % [i, _rig.yaw, _rig.pitch, _rig.zoom])
		if bad.size() > 5:
			break
	check(bad.is_empty(), "the pose stayed inside the limits and bands: " + "; ".join(bad))
	for k: int in down.keys():
		_touch(k, down[k], false)
	_release_all()
	check(_rig.gestures.fingers.is_empty(), "no finger is left claimed")
	for i: int in 240:
		_rig._process(1.0 / 60.0)
	var yaw_before: float = _rig.yaw
	var start := Vector2(_size.x * 0.3, _size.y * 0.2)
	_touch(0, start, true)
	for i: int in 10:
		_drag(0, start + Vector2(_size.x * 0.03 * (i + 1), 0.0))
	_touch(0, start + Vector2(_size.x * 0.3, 0.0), false)
	check(absf(_rig.yaw - yaw_before) > 0.5, "afterwards a one-finger drag orbits normally (%.2f to %.2f)" % [yaw_before, _rig.yaw])


# ------------------------------------------------------------------ helpers

## A STOP button across the bottom fifth of the window: the action bar.
func _bar() -> Button:
	var b := Button.new()
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.position = Vector2(0.0, _size.y * 0.8)
	b.size = Vector2(_size.x, _size.y * 0.2)
	_tree.root.add_child(b)
	_nodes.append(b)
	return b


func _touch(index: int, pos: Vector2, pressed: bool, canceled: bool = false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	e.canceled = canceled
	_tree.root.push_input(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	_tree.root.push_input(e)


## Lifts every finger index the fuzz may have used, so no test leaves a claimed finger behind.
func _release_all() -> void:
	if _rig == null or not is_instance_valid(_rig):
		return
	for k: int in range(0, 5):
		if _rig.gestures.is_claimed(k):
			_touch(k, Vector2.ZERO, false, true)

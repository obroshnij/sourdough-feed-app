class_name TouchGestures
extends RefCounted
## Finger tracking for the jar camera (ux-design.md §6, D-036). Pure: positions in pt, time in ms,
## no engine input, so tests drive it directly. OrbitCamera feeds it only fingers it claimed
## (a press that reached _unhandled_input), so a second finger that landed on a plate is never here.
## - One claimed finger: orbit by its relative motion.
## - Two claimed fingers: our own pinch (iOS sends no pinch event). Lifting one goes back to orbit.
## - A short press that stays inside the tap slop is a tap. Two taps close in time and place are
##   a double tap; the first tap is still reported, so a poke never waits.

signal orbited(delta_pt: Vector2)
signal pinched(scale: float)
signal tapped(pos_pt: Vector2)
signal double_tapped(pos_pt: Vector2)
signal began()
signal ended()

const TAP_SLOP_PT: float = 10.0
const TAP_MAX_MS: int = 500
const DOUBLE_TAP_MS: int = 300
const DOUBLE_TAP_PT: float = 24.0

## Claimed finger index to its last position (pt).
var fingers: Dictionary[int, Vector2] = {}
var _press_ms: int = 0
var _press_pos: Vector2 = Vector2.ZERO
var _moved_pt: float = 0.0
var _multi: bool = false
var _span: float = 0.0
var _last_tap_ms: int = -100000
var _last_tap_pos: Vector2 = Vector2.ZERO


func is_claimed(index: int) -> bool:
	return fingers.has(index)


func active() -> bool:
	return not fingers.is_empty()


func press(index: int, pos_pt: Vector2, now_ms: int) -> void:
	if fingers.has(index):
		return
	fingers[index] = pos_pt
	if fingers.size() == 1:
		_press_ms = now_ms
		_press_pos = pos_pt
		_moved_pt = 0.0
		_multi = false
		began.emit()
	elif fingers.size() == 2:
		_multi = true
		_span = _current_span()


func move(index: int, pos_pt: Vector2, now_ms: int) -> void:
	if not fingers.has(index):
		return
	var delta: Vector2 = pos_pt - fingers[index]
	fingers[index] = pos_pt
	_moved_pt += delta.length()
	if fingers.size() >= 2:
		var span: float = _current_span()
		if _span > 1.0 and span > 1.0:
			pinched.emit(span / _span)
		_span = span
		return
	orbited.emit(delta)


## A lift. `canceled` (the OS took the touch) never counts as a tap.
func release(index: int, pos_pt: Vector2, now_ms: int, canceled: bool = false) -> void:
	if not fingers.has(index):
		return
	fingers.erase(index)
	if fingers.size() == 1:
		_span = 0.0
	if not fingers.is_empty():
		return
	var was_tap: bool = not canceled and not _multi and now_ms - _press_ms <= TAP_MAX_MS and _moved_pt <= TAP_SLOP_PT
	if was_tap:
		tapped.emit(pos_pt)
		if now_ms - _last_tap_ms <= DOUBLE_TAP_MS and pos_pt.distance_to(_last_tap_pos) <= DOUBLE_TAP_PT:
			_last_tap_ms = -100000
			double_tapped.emit(pos_pt)
		else:
			_last_tap_ms = now_ms
			_last_tap_pos = pos_pt
	ended.emit()


## Drops every finger, for example when a sheet opens over the jar.
func cancel_all() -> void:
	var had: bool = not fingers.is_empty()
	fingers.clear()
	_span = 0.0
	_multi = false
	if had:
		ended.emit()


func _current_span() -> float:
	var pts: Array[Vector2] = []
	for k: int in fingers:
		pts.append(fingers[k])
		if pts.size() == 2:
			break
	if pts.size() < 2:
		return 0.0
	return pts[0].distance_to(pts[1])

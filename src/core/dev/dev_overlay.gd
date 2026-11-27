class_name DevOverlay
extends CanvasLayer
## The development overlay (architecture §3.2 "Dev", mvp-scope "A development overlay"). Debug builds only:
## Main adds it when OS.is_debug_build(), so a release build has no node, no input and no time controls.
## F3 (the `dev_overlay` action) shows and hides it, and so does a three-finger hold of HOLD_S anywhere (a phone
## has no F3 key, D-063). Hidden by default.
##
## It also shows a frame-time line (p50 and p95 over the last 10 s, the FPS cap and the renderer), so the iPhone
## checklist can read device numbers without Xcode. Every number from it is a measurement on that device only.
##
## It drives Session's debug time: a time scale, and jumps that play the return flow, so mold_found and the
## memorial can be reached in one sitting (D-017). Session moves every save of a time-traveling run to a
## sandbox folder, so the real save never gets a scaled timestamp.
##
## Its labels are plain developer text, not tr() keys: the overlay is never shown to players.

const SCALES: Array[float] = [1.0, 60.0, 600.0, 3600.0]
const JUMPS_S: Array[int] = [3600, 86400, 3 * 86400]
## The touch toggle: this many fingers held this long.
const HOLD_FINGERS: int = 3
const HOLD_S: float = 1.0
## The frame-time window.
const FRAME_WINDOW_S: float = 10.0

## The session to drive. Main leaves it null, which means the Session autoload; tests set their own.
var session: GameSession = null

var _status: Label = null
var _since_refresh: float = 0.0
var _fingers: Dictionary[int, bool] = {}
## Seconds the fingers have been held, -1 when fewer than HOLD_FINGERS are down. One toggle per hold.
var _hold_s: float = -1.0
var _hold_done: bool = false
var _frames: Array[float] = []
var _frames_sum: float = 0.0


func _ready() -> void:
	layer = 100
	visible = false
	if session == null:
		session = get_node_or_null("/root/Session") as GameSession
	var panel := PanelContainer.new()
	panel.position = Vector2(8.0, 120.0)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_status = Label.new()
	box.add_child(_status)
	var scales := HBoxContainer.new()
	box.add_child(scales)
	for s: float in SCALES:
		scales.add_child(_button("%dx" % int(s), set_scale_to.bind(s)))
	var jumps := HBoxContainer.new()
	box.add_child(jumps)
	for j: int in JUMPS_S:
		var text: String = "+%d h" % roundi(j / 3600.0) if j < 86400 else "+%d d" % roundi(j / 86400.0)
		jumps.add_child(_button(text, jump.bind(j)))
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dev_overlay"):
		toggle()
		get_viewport().set_input_as_handled()


## Touches are only watched here, never consumed, so the game sees them as usual.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		note_touch(t.index, t.pressed)


func toggle() -> void:
	visible = not visible
	refresh()


## A finger went down or up (tests call it directly).
func note_touch(index: int, pressed: bool) -> void:
	if pressed:
		_fingers[index] = true
	else:
		_fingers.erase(index)
	if _fingers.size() >= HOLD_FINGERS:
		if _hold_s < 0.0 and not _hold_done:
			_hold_s = 0.0
	else:
		_hold_s = -1.0
		if _fingers.is_empty():
			_hold_done = false


## Advances the hold by `delta` seconds and toggles once it lasts HOLD_S. Returns true when it toggled.
func advance_hold(delta: float) -> bool:
	if _hold_s < 0.0 or _hold_done:
		return false
	_hold_s += delta
	if _hold_s < HOLD_S:
		return false
	_hold_done = true
	_hold_s = -1.0
	toggle()
	return true


## Keeps the last FRAME_WINDOW_S seconds of frame times.
func record_frame(delta: float) -> void:
	_frames.append(delta)
	_frames_sum += delta
	while _frames.size() > 1 and _frames_sum - _frames[0] >= FRAME_WINDOW_S:
		_frames_sum -= _frames[0]
		_frames.remove_at(0)


## Vector2(p50, p95) frame time in ms over the window. Zero before the first frame.
func frame_stats() -> Vector2:
	if _frames.is_empty():
		return Vector2.ZERO
	var sorted: Array[float] = _frames.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	return Vector2(sorted[(n - 1) / 2] * 1000.0, sorted[mini(n - 1, int(ceil(0.95 * n)) - 1)] * 1000.0)


func _process(delta: float) -> void:
	record_frame(delta)
	advance_hold(delta)
	if not visible:
		return
	_since_refresh += delta
	if _since_refresh >= 0.5:
		_since_refresh = 0.0
		refresh()


## Sets Session's debug time scale. Returns false outside debug builds (no DebugClock).
func set_scale_to(scale: float) -> bool:
	var ok: bool = session != null and session.set_debug_time_scale(scale)
	refresh()
	return ok


## Jumps `seconds` ahead as an absence, so the time-lapse and the return summary play.
func jump(seconds: int) -> CatchUpResult:
	var r: CatchUpResult = session.debug_advance(seconds) if session != null else CatchUpResult.new()
	refresh()
	return r


func refresh() -> void:
	if _status == null or session == null:
		return
	var snap: StarterSnapshot = session.get_snapshot()
	var f: Vector2 = frame_stats()
	_status.text = "Dev  time %sx%s\n%s  %s  (sim %s)\nframe p50 %.1f ms  p95 %.1f ms (10 s)  cap %d fps  %s" % [
		session.get_debug_time_scale(), "  SANDBOX SAVE" if session.is_time_traveling() else "",
		snap.state, snap.location, Time.get_datetime_string_from_unix_time(session.get_starter().sim_time_unix),
		f.x, f.y, Engine.max_fps, RenderingServer.get_current_rendering_method(),
	]


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(56.0, 44.0)
	b.pressed.connect(func() -> void: action.call())
	return b

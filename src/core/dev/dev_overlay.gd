class_name DevOverlay
extends CanvasLayer
## The development overlay (architecture §3.2 "Dev", mvp-scope "A development overlay"). Debug builds only:
## Main adds it when OS.is_debug_build(), so a release build has no node, no input and no time controls.
## F3 (the `dev_overlay` action) shows and hides it. Hidden by default.
##
## It drives Session's debug time: a time scale, and jumps that play the return flow, so mold_found and the
## memorial can be reached in one sitting (D-017). Session moves every save of a time-traveling run to a
## sandbox folder, so the real save never gets a scaled timestamp.
##
## Its labels are plain developer text, not tr() keys: the overlay is never shown to players.

const SCALES: Array[float] = [1.0, 60.0, 600.0, 3600.0]
const JUMPS_S: Array[int] = [3600, 86400, 3 * 86400]

## The session to drive. Main leaves it null, which means the Session autoload; tests set their own.
var session: GameSession = null

var _status: Label = null
var _since_refresh: float = 0.0


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
		visible = not visible
		refresh()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
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
	_status.text = "Dev  time %sx%s\n%s  %s  (sim %s)" % [
		session.get_debug_time_scale(), "  SANDBOX SAVE" if session.is_time_traveling() else "",
		snap.state, snap.location, Time.get_datetime_string_from_unix_time(session.get_starter().sim_time_unix),
	]


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(56.0, 44.0)
	b.pressed.connect(func() -> void: action.call())
	return b

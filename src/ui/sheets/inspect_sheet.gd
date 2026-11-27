class_name InspectSheet
extends Sheet
## Inspect (ux-design §10, game-copy §6, D-021): a peek sheet with the P0 chips, 48 tall, two columns.
## A chip applies InspectAction, sends Bus.camera_focus_requested(readout.camera_target), holds on the cue
## for 1.0 s (reduce motion: 0.2 s), then shows the observation and the meaning. All text comes from the
## readout's keys, never from UI logic (CLAUDE.md rule 2). Meaning lines show the first 3 views, except
## warning and mold lines, which never fade. Opened from warning_signs ("Look first"), it goes straight to
## `surface` and offers "Feed now".

signal feed_requested()
signal camera_focus(target: StringName)
signal camera_release()

const KINDS: Array[StringName] = [&"bubbles", &"height", &"surface"]
const HOLD_S: float = 1.0
const HOLD_REDUCED_S: float = 0.2
const MEANING_VIEWS: int = 3

var chips: Dictionary[StringName, Chip] = {}
var current_kind: StringName = &""
var readout: InspectionReadout = null
var from_warning: bool = false

var _grid: GridContainer = null
var _result: VBoxContainer = null
var _back: SdButton = null
var _obs: Label = null
var _mean: Label = null
var _feed_now: SdButton = null
var _pending_kind: StringName = &""
var _token: int = 0


func _init() -> void:
	sheet_id = &"inspect"
	title_key = &"INSPECT_SHEET_TITLE"
	height_kind = Sheet.Height.PEEK


func _build_content(box: VBoxContainer) -> void:
	_grid = GridContainer.new()
	_grid.name = "Chips"
	_grid.columns = 2
	_grid.add_theme_constant_override(&"h_separation", 8)
	_grid.add_theme_constant_override(&"v_separation", 8)
	box.add_child(_grid)
	for k: StringName in KINDS:
		var chip := Chip.new(StringName("INSPECT_CHIP_%s" % Keys.up(k)))
		chip.name = "Chip_" + String(k)
		chip.icon_id = StringName("inspect_%s" % k)
		chip.toggles = false
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.pressed.connect(show_kind.bind(k))
		_grid.add_child(chip)
		chips[k] = chip
	_result = VBoxContainer.new()
	_result.name = "Result"
	_result.visible = false
	box.add_child(_result)
	_back = SdButton.new(&"", SdButton.Variant.TEXT)
	_back.name = "Back"
	_back.icon = UiIcon.texture(&"ui_back")
	_back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.pressed.connect(show_grid)
	_result.add_child(_back)
	_obs = _text(&"BodyLabel")
	_mean = _text(&"HintLabel")
	_feed_now = SdButton.new(&"EVENT_WARNING_SIGNS_BTN_FEED", SdButton.Variant.PRIMARY)
	_feed_now.name = "FeedNow"
	_feed_now.visible = false
	_feed_now.pressed.connect(func() -> void: feed_requested.emit())
	_result.add_child(_feed_now)


func _on_open() -> void:
	if _pending_kind != &"":
		var k: StringName = _pending_kind
		_pending_kind = &""
		show_kind(k)
	else:
		show_grid()


## Opens straight to one kind's result ("Show me", "Look first").
func open_to(kind: StringName, warning: bool = false) -> void:
	from_warning = warning
	_pending_kind = kind
	if is_open():
		_on_open()
	else:
		open()


func close() -> void:
	if is_open() and current_kind != &"":
		camera_release.emit()
	current_kind = &""
	from_warning = false
	super.close()


func show_grid() -> void:
	_token += 1
	if current_kind != &"":
		camera_release.emit()
	current_kind = &""
	_grid.visible = true
	_result.visible = false


func show_kind(kind: StringName) -> void:
	if session == null:
		return
	_token += 1
	var token: int = _token
	var result: ActionResult = session.apply(InspectAction.new(kind))
	readout = result.readout as InspectionReadout
	if not result.ok or readout == null:
		return
	current_kind = kind
	camera_focus.emit(readout.camera_target)
	_grid.visible = false
	_result.visible = true
	_back.text = tr(StringName("INSPECT_CHIP_%s" % Keys.up(kind)))
	_back.accessibility_name = tr(&"UI_BACK_A11Y")
	_obs.visible = false
	_mean.visible = false
	_feed_now.visible = false
	await get_tree().create_timer((HOLD_REDUCED_S if UiMotion.reduce else HOLD_S) * UiMotion.time_scale).timeout
	if token != _token or not is_open():
		return
	_show_text()


func _show_text() -> void:
	_obs.text = session.format_text(readout.text_key)
	_obs.visible = true
	var seen: int = session.get_history().seen_counts.get(
		StringName("inspect.%s.level_%d" % [readout.inspect_kind, readout.level]), 0)
	var show_mean: bool = readout.meaning_key != &"" and (readout.is_warning or seen <= MEANING_VIEWS)
	_mean.visible = show_mean
	_mean.text = session.format_text(readout.meaning_key) if show_mean else ""
	_feed_now.visible = from_warning and session.get_snapshot().can_feed


func _text(type: StringName) -> Label:
	var l := Label.new()
	l.theme_type_variation = type
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.add_child(l)
	return l

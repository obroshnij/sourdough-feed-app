class_name UiRoot
extends Control
## The UI layer (architecture.md §3.2 and §9.1). Owns the one Theme, the safe areas, text size, reduce
## motion and the night palette, and wires the HUD, overlays and sheets to the Session and the Bus.
## It reads Session outputs only and changes the game only through Session.apply() (later phases).
## Tests drive it without a Session: apply_snapshot(), set_insets_override(), set_text_scale(),
## set_night_blend().

const SHEET_FOR_ACTION: Dictionary[StringName, StringName] = {
	&"feed": &"feed", &"inspect": &"inspect", &"environment": &"environment", &"journal": &"journal",
}
const CARD_GAP: float = 12.0
const TOAST_GAP: float = 8.0
## The night palette follows the local clock; checked once a minute.
const CLOCK_CHECK_S: float = 60.0

@onready var hud: Hud = $Hud
@onready var card_slot: Control = $Overlays/CardSlot
@onready var explainer: Card = $Overlays/CardSlot/Explainer
@onready var toast_slot: Control = $Overlays/ToastSlot
@onready var toast: Toast = $Overlays/ToastSlot/Toast
@onready var sheets: SheetHost = $Sheets
@onready var settings_sheet: SettingsSheet = $Sheets/Settings

var session: GameSession = null
var settings: SettingsStore = SettingsStore.new("")
var palette: UiPalette = UiPalette.new()
var text_scale: float = 1.0

var _insets: SafeInsets = SafeInsets.new()
var _insets_override: SafeInsets = null
var _night_override: float = -1.0
var _region: Rect2 = Rect2()
var _show_me: SdButton = null
var _clock: Timer = null


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if theme == null:
		theme = load(ThemeBuilder.THEME_PATH) as Theme
	_build_explainer_buttons()
	hud.action_requested.connect(_on_action)
	hud.locked_pressed.connect(func(key: StringName) -> void: toast.show_key(key))
	hud.status_pressed.connect(_on_status_pressed)
	hud.settings_pressed.connect(func() -> void: _open_sheet(&"settings"))
	hud.layout_changed.connect(_place_overlays)
	sheets.sheet_opened.connect(_on_sheet_opened)
	sheets.sheet_closed.connect(_on_sheet_closed)
	settings_sheet.text_scale_chosen.connect(_on_text_scale_chosen)
	settings_sheet.reduce_motion_toggled.connect(_on_reduce_motion_toggled)
	explainer.dismissed.connect(func() -> void: _bus_emit(&"camera_focus_released"))
	resized.connect(_relayout)
	settings_sheet.sync_from(text_scale, UiMotion.reduce)
	_clock = Timer.new()
	_clock.wait_time = CLOCK_CHECK_S
	_clock.timeout.connect(_refresh_night)
	add_child(_clock)
	var bus: Node = get_node_or_null(^"/root/Bus")
	if bus != null and bus.has_signal(&"starter_tapped"):
		bus.connect(&"starter_tapped", func(_where: StringName) -> void: explainer.dismiss())
	var s: GameSession = get_node_or_null(^"/root/Session") as GameSession
	if s != null:
		bind_session(s)
	_relayout()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_RESUMED:
			if is_node_ready():
				_relayout()
				_refresh_night()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back: closes the open sheet first; with none open, save and quit (AC-12.11).
			if sheets.has_open_sheet():
				sheets.close_current()
			elif session != null and session.is_booted():
				session.save_and_quit()


# ------------------------------------------------------------------ session
func bind_session(s: GameSession) -> void:
	session = s
	s.state_changed.connect(_on_state_changed)
	s.session_ready.connect(_on_session_ready)
	s.resumed.connect(_on_session_ready)
	s.save_failed.connect(func(reason: StringName) -> void: toast.show_key(reason))
	if s.is_booted():
		_on_session_ready(s.get_last_catch_up())


func _on_session_ready(_summary: CatchUpResult) -> void:
	var store: SettingsStore = session.get_settings()
	if store != null:
		settings = store
	apply_settings()
	apply_snapshot(session.get_snapshot())
	_refresh_night()
	_clock.start()


func _on_state_changed(snapshot: StarterSnapshot, _visuals: VisualParams) -> void:
	apply_snapshot(snapshot)


# ------------------------------------------------------------------ test and driver seams
func apply_snapshot(snapshot: StarterSnapshot) -> void:
	hud.set_snapshot(snapshot)
	if explainer.is_shown():
		_show_explainer()


func set_insets_override(insets: SafeInsets) -> void:
	_insets_override = insets
	_relayout()


func set_text_scale(value: float) -> void:
	text_scale = TypeScale.SCALES[TypeScale.index_of(value)]
	settings_sheet.sync_from(text_scale, UiMotion.reduce)
	_rebuild_theme()


## 0 day to 1 night. A negative value goes back to following the clock.
func set_night_blend(value: float) -> void:
	_night_override = value
	_refresh_night()


func set_reduce_motion(on: bool) -> void:
	UiMotion.reduce = on
	settings_sheet.sync_from(text_scale, on)


func insets() -> SafeInsets:
	return _insets


## The space between the HUD plate and the action bar, where the camera frames the jar (ux-design §2).
func jar_region() -> Rect2:
	return _region


func apply_settings() -> void:
	UiMotion.reduce = settings.reduce_motion
	set_text_scale(settings.text_scale)


# ------------------------------------------------------------------ layout
func _relayout() -> void:
	if not is_node_ready():
		return
	if _insets_override != null:
		_insets = _insets_override
	else:
		_insets = SafeInsets.from_display(get_window().content_scale_factor)
	hud.apply_insets(_insets)
	sheets.set_insets(_insets)
	_place_overlays()


func _place_overlays() -> void:
	if not is_node_ready():
		return
	var top: float = hud.plate_bottom()
	var bottom: float = hud.bar_top()
	toast_slot.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_slot.offset_left = _insets.gutter_left()
	toast_slot.offset_right = -_insets.gutter_right()
	toast_slot.offset_top = top + TOAST_GAP
	toast_slot.offset_bottom = top + TOAST_GAP
	card_slot.set_anchors_preset(Control.PRESET_TOP_WIDE)
	card_slot.offset_left = _insets.gutter_left()
	card_slot.offset_right = -_insets.gutter_right()
	card_slot.offset_top = top + CARD_GAP
	card_slot.offset_bottom = bottom - CARD_GAP
	var region := Rect2(Vector2(0.0, top), Vector2(size.x, maxf(bottom - top, 0.0)))
	if region != _region:
		_region = region
		_bus_emit(&"jar_region_changed", region)


# ------------------------------------------------------------------ theme
func _rebuild_theme() -> void:
	var t: Theme = theme
	if t == null:
		return
	t.merge_with(ThemeBuilder.build(palette, text_scale))


func _refresh_night() -> void:
	var blend: float = _night_override
	if blend < 0.0:
		blend = 0.0
		if session != null and session.is_booted():
			var minute: int = LocalDay.minute_of_day(session.now_unix(), session.local_utc_offset_s())
			blend = UiPalette.night_blend_at(minute)
	if is_equal_approx(blend, palette.night):
		return
	palette = UiPalette.new(blend)
	_rebuild_theme()


# ------------------------------------------------------------------ actions, sheets, explainer
func _on_action(action_id: StringName) -> void:
	explainer.dismiss()
	if SHEET_FOR_ACTION.has(action_id):
		_open_sheet(SHEET_FOR_ACTION[action_id])
	# smell runs its moment and card in Phase 3 (Bus.smell_moment_started).


func _open_sheet(sheet_id: StringName) -> void:
	explainer.dismiss()
	toast.dismiss()
	sheets.open(sheet_id)


func _on_sheet_opened(sheet_id: StringName) -> void:
	hud.set_open_action(sheet_id if SHEET_FOR_ACTION.values().has(sheet_id) else &"")
	_bus_emit(&"sheet_opened", sheet_id)


func _on_sheet_closed(sheet_id: StringName) -> void:
	if not sheets.has_open_sheet():
		hud.set_open_action(&"")
	_bus_emit(&"sheet_closed", sheet_id)


func _on_status_pressed() -> void:
	if explainer.is_shown():
		explainer.dismiss()
		return
	_show_explainer()


func _show_explainer() -> void:
	var snap: StarterSnapshot = hud.snapshot
	if snap == null:
		return
	explainer.show_keys(Keys.status_word(snap.state, snap.dormant_cause), Keys.status_tap(snap.state, snap.dormant_cause))


func _build_explainer_buttons() -> void:
	_show_me = SdButton.new(&"STATUS_SHOW_ME_BTN", SdButton.Variant.TEXT)
	_show_me.name = "ShowMe"
	_show_me.pressed.connect(_on_show_me)
	explainer.buttons.add_child(_show_me)


func _on_show_me() -> void:
	var snap: StarterSnapshot = hud.snapshot
	if snap != null:
		_bus_emit(&"camera_focus_requested", StatusStyle.show_me_target(snap.state))


func _on_text_scale_chosen(value: float) -> void:
	settings.text_scale = TypeScale.SCALES[TypeScale.index_of(value)]
	_save_settings()
	set_text_scale(value)


func _on_reduce_motion_toggled(on: bool) -> void:
	settings.reduce_motion = on
	_save_settings()
	set_reduce_motion(on)


func _save_settings() -> void:
	if settings.path != "":
		settings.save_settings()


func _bus_emit(signal_name: StringName, arg: Variant = null) -> void:
	var bus: Node = get_node_or_null(^"/root/Bus")
	if bus == null or not bus.has_signal(signal_name):
		return
	if arg == null:
		bus.emit_signal(signal_name)
	else:
		bus.emit_signal(signal_name, arg)

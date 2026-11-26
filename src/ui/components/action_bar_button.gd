class_name ActionBarButton
extends Button
## ActionBarButton (ux-design §4 and §17): icon 28 over a 14 pt semibold label, at least 64 x 64.
## The button lays out its own icon and label in the 72 pt slot: 10 top, icon 28, gap 4, one label line
## (at most 20 at the 16 pt cap), and at least 10 below. Godot's own icon-over-text layout made the slot
## 76 to 80 tall, which pushed the bar to 84 and took that height from the jar.
## States: open (filled icon plus a 4 pt accent pill under the label), emphasized (halo ring plus a 10 pt dot
## badge, a shape and not just color), locked (disabled look; a tap shows the reason instead of acting).
## Long-press (500 ms) shows the label at 200% for low vision and doesn't act.

signal activated(action_id: StringName)
signal locked_pressed(reason_key: StringName)

const MIN_SIZE := Vector2(64, 64)
const SLOT_HEIGHT: float = 72.0
const PAD_TOP: float = 10.0
const GAP: float = 4.0
const ICON: float = 28.0
const DOT: float = 10.0
const OPEN_PILL := Vector2(16, 4)
## Tap slop (ux-design §6): a finger that moves more than this before release cancels the long-press.
const SLOP: float = 10.0

@export var action_id: StringName = &"feed"

var is_open: bool = false:
	set(v):
		is_open = v
		_refresh_icon()
		queue_redraw()
var emphasized: bool = false:
	set(v):
		emphasized = v
		queue_redraw()
## Non-empty while locked: the tr() key of the reason shown on tap.
var locked_reason_key: StringName = &"":
	set(v):
		locked_reason_key = v
		theme_type_variation = &"ActionBarButtonLocked" if v != &"" else &"ActionBarButton"
		_refresh_text()

var _label: String = ""
var _icon: Texture2D = null
var _hold_timer: Timer = null
var _popup: PanelContainer = null
var _popup_label: Label = null
var _long_pressed: bool = false
var _press_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = &"ActionBarButton" if locked_reason_key == &"" else &"ActionBarButtonLocked"
	custom_minimum_size = MIN_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	text = ""
	icon = null
	_refresh_icon()
	_refresh_text()
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = UiMotion.LONG_PRESS
	_hold_timer.timeout.connect(_on_hold)
	add_child(_hold_timer)
	_build_popup()
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(_on_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()


func label_key() -> StringName:
	return StringName("ACTION_%s" % Keys.up(action_id))


func a11y_key() -> StringName:
	return StringName("ACTION_%s_A11Y" % Keys.up(action_id))


func is_popup_visible() -> bool:
	return _popup != null and _popup.visible


## The drawn label (the Button's own text stays empty).
func label_text() -> String:
	return _label


## Where the icon and the label's line box are drawn, in local coordinates.
func icon_rect() -> Rect2:
	return Rect2(Vector2((size.x - ICON) * 0.5, PAD_TOP), Vector2(ICON, ICON))


func label_rect() -> Rect2:
	var font: Font = get_theme_font(&"font")
	var fsize: int = get_theme_font_size(&"font_size")
	var w: float = font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	return Rect2(Vector2((size.x - w) * 0.5, PAD_TOP + ICON + GAP), Vector2(w, font.get_height(fsize)))


func _refresh_icon() -> void:
	if is_node_ready():
		_icon = UiIcon.action(action_id, is_open)
		queue_redraw()


func _refresh_text() -> void:
	if not is_node_ready():
		return
	_label = tr(label_key())
	accessibility_name = tr(a11y_key())
	accessibility_description = tr(locked_reason_key) if locked_reason_key != &"" else ""
	if _popup_label != null:
		_popup_label.text = _label
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	var pos: Vector2 = Vector2.INF
	if drag != null:
		pos = drag.position
	elif motion != null and button_pressed:
		pos = motion.position
	if pos != Vector2.INF and _hold_timer != null and not _hold_timer.is_stopped():
		if pos.distance_to(_press_pos) > SLOP:
			_hold_timer.stop()


func _on_down() -> void:
	_long_pressed = false
	_press_pos = get_local_mouse_position()
	_hold_timer.start()
	UiMotion.press(self, true)


func _on_up() -> void:
	_hold_timer.stop()
	_popup.hide()
	UiMotion.press(self, false)


func _on_hold() -> void:
	_long_pressed = true
	_popup_label.text = _label
	_popup.reset_size()
	_popup.show()
	var popup_size: Vector2 = _popup.get_combined_minimum_size()
	var rect: Rect2 = get_global_rect()
	var view: Rect2 = get_viewport_rect()
	var x: float = clampf(rect.get_center().x - popup_size.x * 0.5, 16.0, view.size.x - 16.0 - popup_size.x)
	_popup.global_position = Vector2(x, rect.position.y - popup_size.y - 12.0)


func _on_pressed() -> void:
	if _long_pressed:
		_long_pressed = false
		return
	if locked_reason_key != &"":
		locked_pressed.emit(locked_reason_key)
		return
	activated.emit(action_id)


func _build_popup() -> void:
	_popup = PanelContainer.new()
	_popup.name = "LabelPopup"
	_popup.theme_type_variation = &"PopupPlate"
	_popup.top_level = true
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.visible = false
	_popup_label = Label.new()
	_popup_label.theme_type_variation = &"BarPopupLabel"
	_popup_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup.add_child(_popup_label)
	add_child(_popup)


func _draw() -> void:
	var down: bool = is_pressed() and get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED]
	var ink: Color = get_theme_color(&"font_pressed_color" if down else &"font_color")
	var ir: Rect2 = icon_rect()
	if _icon != null:
		draw_texture_rect(_icon, ir, false, get_theme_color(&"icon_pressed_color" if down else &"icon_normal_color"))
	var font: Font = get_theme_font(&"font")
	var fsize: int = get_theme_font_size(&"font_size")
	var lr: Rect2 = label_rect()
	draw_string(font, Vector2(lr.position.x, lr.position.y + font.get_ascent(fsize)), _label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, ink)
	var icon_center: Vector2 = ir.get_center()
	var accent: Color = get_theme_color(&"accent", ThemeBuilder.PALETTE_TYPE)
	if emphasized:
		draw_arc(icon_center, ICON * 0.5 + 4.0, 0.0, TAU, 48, Color(accent, 0.45), 3.0, true)
		draw_circle(icon_center + Vector2(ICON * 0.5 + 2.0, -ICON * 0.5 + 1.0), DOT * 0.5, accent)
	if is_open:
		var r := Rect2(Vector2(size.x * 0.5 - OPEN_PILL.x * 0.5, size.y - OPEN_PILL.y - 1.0), OPEN_PILL)
		draw_rect(r, accent)

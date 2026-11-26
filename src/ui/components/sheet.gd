class_name Sheet
extends Control
## Sheet (ux-design §3, §6, §15, §17): peek 42%, half 60% or full (screen - safe top - 12) of the screen
## height. Surface, top radius 24, a 36 x 5 grabber, a title with a 48 pt Close, scrolling content, and a
## Done pinned to the bottom (the E-zone twin of Close). A full-screen scrim (ink at 30%, STOP) blocks the
## 3D view while the sheet is open; tapping it closes the sheet unless `dismiss_on_scrim` is off.
## Swipe down on the header closes it at 25% of its height or 700 pt/s.
## Open 300 ms cubic out, close 220 ms cubic in; reduce motion fades in 150 / out 120 ms.
## Subclasses fill `content` in `_build_content()`.

signal opened(sheet_id: StringName)
signal closed(sheet_id: StringName)

enum Height { PEEK, HALF, FULL }

const SHARES: Dictionary[Height, float] = {Height.PEEK: 0.42, Height.HALF: 0.60}
## A non-full sheet's top edge never rises above 40% of the screen, so the jar's top half stays visible.
const MAX_SHARE: float = 0.60
const FULL_TOP_GAP: float = 12.0
const GRABBER := Vector2(36, 5)

@export var sheet_id: StringName = &""
@export var title_key: StringName = &""
@export var height_kind: Height = Height.HALF
@export var dismiss_on_scrim: bool = true

var content: VBoxContainer = null
var scrim: ColorRect = null
var panel: PanelContainer = null
var title_label: Label = null
var close_button: IconButton = null
var done_button: SdButton = null

var _insets: SafeInsets = SafeInsets.new()
var _footer_pad: Control = null
var _header: Control = null
var _slide: float = 1.0
var _open: bool = false
var _tween: Tween = null
var _drag_active: bool = false
var _drag_start_y: float = 0.0
var _drag_offset: float = 0.0
var _drag_last_y: float = 0.0
var _drag_last_t: float = 0.0
var _drag_speed: float = 0.0


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	_build_content(content)
	_refresh_text()
	resized.connect(_layout)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()


func is_open() -> bool:
	return _open


func set_insets(insets: SafeInsets) -> void:
	_insets = insets
	if is_node_ready():
		_layout()


## The sheet's height for the current screen, before any drag.
func sheet_height() -> float:
	var h: float = size.y
	if height_kind == Height.FULL:
		return h - _insets.top - FULL_TOP_GAP
	return h * minf(SHARES[height_kind], MAX_SHARE)


func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	_layout()
	_animate(0.0, UiMotion.sheet_open(), Tween.EASE_OUT)
	opened.emit(sheet_id)


func close() -> void:
	if not _open:
		return
	_open = false
	_animate(1.0, UiMotion.sheet_close(), Tween.EASE_IN)
	closed.emit(sheet_id)


## Override to add rows to `box`.
func _build_content(_box: VBoxContainer) -> void:
	pass


func _refresh_text() -> void:
	if title_label != null:
		title_label.text = tr(title_key) if title_key != &"" else ""


func _build() -> void:
	scrim = ColorRect.new()
	scrim.name = "Scrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.color = get_theme_color(&"scrim", ThemeBuilder.PALETTE_TYPE)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = &"SheetPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	add_child(panel)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override(&"separation", 8)
	panel.add_child(body)

	_header = VBoxContainer.new()
	_header.name = "Header"
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.add_theme_constant_override(&"separation", 4)
	_header.gui_input.connect(_on_header_input)
	body.add_child(_header)

	var grabber := Control.new()
	grabber.name = "Grabber"
	grabber.custom_minimum_size = Vector2(0, 13)
	grabber.mouse_filter = Control.MOUSE_FILTER_PASS
	grabber.draw.connect(_draw_grabber.bind(grabber))
	_header.add_child(grabber)

	var row := HBoxContainer.new()
	row.name = "TitleRow"
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_header.add_child(row)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.theme_type_variation = &"TitleLabel"
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_label)
	close_button = IconButton.new(&"ui_close", &"UI_CLOSE_A11Y")
	close_button.name = "Close"
	close_button.pressed.connect(close)
	row.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(&"separation", 12)
	scroll.add_child(content)

	done_button = SdButton.new(&"UI_DONE_BTN", SdButton.Variant.SECONDARY)
	done_button.name = "Done"
	done_button.pressed.connect(close)
	body.add_child(done_button)
	_footer_pad = Control.new()
	_footer_pad.name = "BottomInset"
	_footer_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_footer_pad)


func _layout() -> void:
	if panel == null:
		return
	_footer_pad.custom_minimum_size = Vector2(0, _insets.bar_gap() - 8.0)
	var h: float = sheet_height()
	# Reduce motion: the sheet fades in place instead of sliding.
	var shift: float = (0.0 if UiMotion.reduce else _slide * h) + _drag_offset
	panel.offset_left = _insets.left
	panel.offset_right = -_insets.right
	panel.offset_top = -h + shift
	panel.offset_bottom = shift
	panel.modulate.a = 1.0 - _slide if UiMotion.reduce else 1.0
	scrim.color = get_theme_color(&"scrim", ThemeBuilder.PALETTE_TYPE)
	scrim.modulate.a = 1.0 - _slide


func _set_slide(v: float) -> void:
	_slide = v
	_layout()


func _set_drag(v: float) -> void:
	_drag_offset = v
	_layout()


func _animate(target: float, duration: float, ease_type: Tween.EaseType) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_drag_offset = 0.0
	_tween = create_tween()
	_tween.tween_method(_set_slide, _slide, target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	if target >= 1.0:
		_tween.tween_callback(func() -> void: visible = false)


func _on_scrim_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and dismiss_on_scrim:
		close()


func _on_header_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	var now: float = Time.get_ticks_msec() / 1000.0
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_drag_active = true
			_drag_start_y = mb.global_position.y
			_drag_last_y = _drag_start_y
			_drag_last_t = now
			_drag_speed = 0.0
		elif _drag_active:
			_drag_active = false
			_finish_drag()
	elif mm != null and _drag_active:
		var dt: float = maxf(now - _drag_last_t, 0.001)
		_drag_speed = (mm.global_position.y - _drag_last_y) / dt
		_drag_last_y = mm.global_position.y
		_drag_last_t = now
		_drag_offset = maxf(mm.global_position.y - _drag_start_y, 0.0)
		_layout()


func _finish_drag() -> void:
	if _drag_offset > sheet_height() * UiMotion.SWIPE_FRACTION or _drag_speed > UiMotion.SWIPE_SPEED:
		_slide = _drag_offset / maxf(sheet_height(), 1.0)
		_drag_offset = 0.0
		close()
		return
	var back: Tween = create_tween()
	back.tween_method(_set_drag, _drag_offset, 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw_grabber(grabber: Control) -> void:
	var c: Color = get_theme_color(&"outline", ThemeBuilder.PALETTE_TYPE)
	var r := Rect2(Vector2((grabber.size.x - GRABBER.x) * 0.5, 4.0), GRABBER)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(c, 0.6)
	box.set_corner_radius_all(3)
	grabber.draw_style_box(box, r)

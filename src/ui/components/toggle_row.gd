class_name ToggleRow
extends Button
## Toggle row (ux-design §17, settings): a row at least 52 tall with the label on the left and a 51 x 31
## switch on the right. On: accent track with a check in the knob. Off: outline track. The check makes "on"
## readable without color.

const MIN_HEIGHT: float = 52.0
const SWITCH := Vector2(51, 31)
const KNOB: float = 25.0

@export var text_key: StringName = &"":
	set(v):
		text_key = v
		_refresh_text()


func _init(key: StringName = &"") -> void:
	text_key = key


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = &"ToggleRow"
	toggle_mode = true
	custom_minimum_size = Vector2(0, MIN_HEIGHT)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_text()
	toggled.connect(func(_on: bool) -> void: queue_redraw())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()


func _refresh_text() -> void:
	if not is_node_ready():
		return
	text = tr(text_key) if text_key != &"" else ""
	accessibility_name = text


func _draw() -> void:
	var accent: Color = get_theme_color(&"accent", ThemeBuilder.PALETTE_TYPE)
	var outline: Color = get_theme_color(&"outline", ThemeBuilder.PALETTE_TYPE)
	var knob_c: Color = get_theme_color(&"on_accent", ThemeBuilder.PALETTE_TYPE)
	var r := Rect2(Vector2(size.x - 16.0 - SWITCH.x, (size.y - SWITCH.y) * 0.5), SWITCH)
	var track := StyleBoxFlat.new()
	track.set_corner_radius_all(int(SWITCH.y * 0.5))
	track.anti_aliasing = true
	track.corner_detail = 12
	if button_pressed:
		track.bg_color = accent
	else:
		track.bg_color = get_theme_color(&"surface_alt", ThemeBuilder.PALETTE_TYPE)
		track.border_color = outline
		track.set_border_width_all(2)
	draw_style_box(track, r)
	var pad: float = (SWITCH.y - KNOB) * 0.5
	var cx: float = r.end.x - pad - KNOB * 0.5 if button_pressed else r.position.x + pad + KNOB * 0.5
	var center := Vector2(cx, r.get_center().y)
	draw_circle(center, KNOB * 0.5, knob_c if button_pressed else outline)
	if button_pressed:
		var check: Texture2D = UiIcon.texture(&"ui_check")
		if check != null:
			var s: float = 16.0
			draw_texture_rect(check, Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), false, accent)

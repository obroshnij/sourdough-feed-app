class_name ChoiceButton
extends Button
## OptionRow and OptionCard (ux-design §17): one choice of a radio group, with a title and a sub-line.
## - ROW (the feed sheet's schedule question): full width, at least 64 tall, radio ring 22, title 17
##   semibold, sub 16 ink_muted. Selected: filled ring plus a check.
## - CARD (the place sheet): at least 104 x 112, title and sub centered. Selected: 3 pt accent border plus a
##   check badge.
## Selection never relies on color alone: the check shape always marks it. Text comes from the owner, through
## tr() keys (the sub-line may carry digits on these dedicated screens, ux-design §4).

enum Style { ROW, CARD }

const ROW_MIN_H: float = 64.0
const CARD_MIN := Vector2(104, 112)
const RING: float = 22.0
const PAD: float = 12.0
const LINE_GAP: float = 2.0
const BADGE: float = 22.0

var style: Style = Style.ROW
var choice_id: StringName = &""
var title_text: String = "":
	set(v):
		title_text = v
		_resize()
var sub_text: String = "":
	set(v):
		sub_text = v
		_resize()
## CARD only: an optional third line (the place's temperature, AC-06.4).
var detail_text: String = "":
	set(v):
		detail_text = v
		_resize()


func _init(id: StringName = &"", kind: Style = Style.ROW) -> void:
	choice_id = id
	style = kind


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = &"ChoiceButton"
	toggle_mode = true
	text = ""
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggled.connect(func(_on: bool) -> void: queue_redraw())
	button_down.connect(UiMotion.press.bind(self, true))
	button_up.connect(UiMotion.press.bind(self, false))
	_resize()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_resize()


func set_texts(title: String, sub: String) -> void:
	title_text = title
	sub_text = sub
	accessibility_name = title
	accessibility_description = sub


func _fonts() -> Array:
	var tf: Font = get_theme_font(&"title_font", &"ChoiceButton")
	var sf: Font = get_theme_font(&"sub_font", &"ChoiceButton")
	return [tf, get_theme_font_size(&"title_size", &"ChoiceButton"), sf, get_theme_font_size(&"sub_size", &"ChoiceButton")]


## The width the text needs, so a row never clips (tests check it).
func text_width() -> float:
	var f: Array = _fonts()
	var tf: Font = f[0]
	var sf: Font = f[2]
	return maxf(tf.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, f[1]).x,
		maxf(sf.get_string_size(sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, f[3]).x,
		sf.get_string_size(detail_text, HORIZONTAL_ALIGNMENT_LEFT, -1, f[3]).x))


func _text_left() -> float:
	return PAD + RING + PAD if style == Style.ROW else PAD


func _text_room() -> float:
	if style == Style.ROW:
		return size.x - _text_left() - PAD - BADGE - PAD
	return size.x - 2.0 * PAD


func text_fits() -> bool:
	return text_width() <= _text_room() + 0.5


func _resize() -> void:
	if not is_node_ready():
		return
	var f: Array = _fonts()
	var tf: Font = f[0]
	var sf: Font = f[2]
	var h: float = PAD * 2.0 + tf.get_height(f[1]) + LINE_GAP + sf.get_height(f[3])
	if detail_text != "":
		h += LINE_GAP + sf.get_height(f[3])
	if style == Style.ROW:
		custom_minimum_size = Vector2(0, maxf(ROW_MIN_H, h))
	else:
		var w: float = text_width() + 2.0 * PAD
		custom_minimum_size = Vector2(maxf(CARD_MIN.x, w), maxf(CARD_MIN.y, h + BADGE))
	queue_redraw()


func _draw() -> void:
	var f: Array = _fonts()
	var tf: Font = f[0]
	var sf: Font = f[2]
	var ts: int = f[1]
	var ss: int = f[3]
	var ink: Color = get_theme_color(&"ink", ThemeBuilder.PALETTE_TYPE)
	var muted: Color = get_theme_color(&"ink_muted", ThemeBuilder.PALETTE_TYPE)
	var accent: Color = get_theme_color(&"accent", ThemeBuilder.PALETTE_TYPE)
	var outline: Color = get_theme_color(&"outline", ThemeBuilder.PALETTE_TYPE)
	var on_accent: Color = get_theme_color(&"on_accent", ThemeBuilder.PALETTE_TYPE)
	var block_h: float = tf.get_height(ts) + LINE_GAP + sf.get_height(ss)
	if detail_text != "" and style == Style.CARD:
		block_h += LINE_GAP + sf.get_height(ss)
	if style == Style.ROW:
		var y0: float = (size.y - block_h) * 0.5
		var c := Vector2(PAD + RING * 0.5, size.y * 0.5)
		draw_arc(c, RING * 0.5 - 1.0, 0.0, TAU, 40, accent if button_pressed else outline, 2.0, true)
		if button_pressed:
			draw_circle(c, RING * 0.5 - 5.0, accent)
			_draw_check(Vector2(size.x - PAD - BADGE, (size.y - BADGE) * 0.5), accent)
		var x: float = _text_left()
		draw_string(tf, Vector2(x, y0 + tf.get_ascent(ts)), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, ink)
		draw_string(sf, Vector2(x, y0 + tf.get_height(ts) + LINE_GAP + sf.get_ascent(ss)), sub_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, ss, muted)
	else:
		var y1: float = (size.y - block_h) * 0.5 + BADGE * 0.35
		draw_string(tf, Vector2(PAD, y1 + tf.get_ascent(ts)), title_text, HORIZONTAL_ALIGNMENT_CENTER,
			size.x - 2.0 * PAD, ts, ink)
		draw_string(sf, Vector2(PAD, y1 + tf.get_height(ts) + LINE_GAP + sf.get_ascent(ss)), sub_text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x - 2.0 * PAD, ss, muted)
		if detail_text != "":
			var y2: float = y1 + tf.get_height(ts) + 2.0 * LINE_GAP + sf.get_height(ss) + sf.get_ascent(ss)
			draw_string(sf, Vector2(PAD, y2), detail_text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 2.0 * PAD, ss, ink)
		if button_pressed:
			var badge := Vector2(size.x - BADGE - 8.0, 8.0)
			draw_circle(badge + Vector2(BADGE, BADGE) * 0.5, BADGE * 0.5, accent)
			_draw_check(badge, on_accent)


func _draw_check(at: Vector2, color: Color) -> void:
	var tex: Texture2D = UiIcon.texture(&"ui_check")
	if tex != null:
		draw_texture_rect(tex, Rect2(at + Vector2(3, 3), Vector2(BADGE - 6.0, BADGE - 6.0)), false, color)

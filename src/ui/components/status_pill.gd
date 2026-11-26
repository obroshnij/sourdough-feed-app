class_name StatusPill
extends Button
## StatusPill (ux-design §11 and §17): a tone icon (24), the status word in ink (17 semibold) and a tone
## border. The word is always ink, so contrast never depends on the tone, and the icon shape and the word
## carry the meaning, never the color alone.
## Kinds: normal (2 pt tone border), peak (adds a soft glow), care (3 pt border, filled icon, honey fill),
## stop (stop fill, cream word and filled icon). Tap opens the explainer. A 10 pt dot marks a state the
## player hasn't tapped yet.

## ux-design §17 says 40, but §16 makes 44 the absolute touch minimum, so the pill is 44 (flagged to ux).
const MIN_HEIGHT: float = 44.0
const DOT: float = 10.0

var state_id: StringName = &""
var dormant_cause: StringName = &""
var _styling: bool = false
var show_new_dot: bool = false:
	set(v):
		show_new_dot = v
		queue_redraw()


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = &"StatusPill"
	custom_minimum_size = Vector2(0, MIN_HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	clip_text = false
	button_down.connect(UiMotion.press.bind(self, true))
	button_up.connect(UiMotion.press.bind(self, false))
	if state_id != &"":
		_apply()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			_apply_text()
		NOTIFICATION_THEME_CHANGED:
			# Our own overrides also send THEME_CHANGED; the guard stops that loop.
			if is_node_ready() and state_id != &"" and not _styling:
				_apply_style()


## Shows `new_state`. A change after the first one crossfades with a 1.06 pulse (reduce motion: fade only).
func set_status(new_state: StringName, cause: StringName = &"") -> void:
	var changed: bool = state_id != &"" and (new_state != state_id or cause != dormant_cause)
	state_id = new_state
	dormant_cause = cause
	if not is_node_ready():
		return
	_apply()
	if changed:
		_animate_change()


func word_key() -> StringName:
	return Keys.status_word(state_id, dormant_cause)


func hint_key() -> StringName:
	return Keys.status_hint(state_id, dormant_cause)


func _apply() -> void:
	icon = UiIcon.status(state_id, StatusStyle.filled_icon(state_id))
	_apply_text()
	_apply_style()


func _apply_text() -> void:
	if state_id == &"":
		return
	text = tr(word_key())
	# The name stays short (40 max); STATUS_A11Y is a 120-character description slot (game-copy §1.2).
	accessibility_name = text
	accessibility_description = tr(&"STATUS_A11Y").format({"word": text, "hint": tr(hint_key())})


func _apply_style() -> void:
	_styling = true
	begin_bulk_theme_override()
	var tone: Color = get_theme_color(StringName("tone_%s" % StatusStyle.tone(state_id)), ThemeBuilder.PALETTE_TYPE)
	# The override would shadow the Theme's own box for this type, so drop it before reading the base.
	remove_theme_stylebox_override(&"normal")
	var base: StyleBoxFlat = get_theme_stylebox(&"normal", &"StatusPill") as StyleBoxFlat
	var box: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	var down: StyleBoxFlat
	var word: Color = get_theme_color(&"ink", ThemeBuilder.PALETTE_TYPE)
	var icon_color: Color = tone
	box.border_color = tone
	match StatusStyle.kind(state_id):
		StatusStyle.Kind.PEAK:
			box.shadow_color = Color(tone, 0.35)
			box.shadow_size = 8
		StatusStyle.Kind.CARE:
			box.bg_color = get_theme_color(&"care_fill", ThemeBuilder.PALETTE_TYPE)
			box.set_border_width_all(3)
		StatusStyle.Kind.STOP:
			box.bg_color = tone
			word = get_theme_color(&"on_accent", ThemeBuilder.PALETTE_TYPE)
			icon_color = word
	down = box.duplicate() as StyleBoxFlat
	down.bg_color = UiPalette.pressed(box.bg_color)
	for slot: StringName in [&"normal", &"hover", &"disabled", &"normal_mirrored", &"hover_mirrored"]:
		add_theme_stylebox_override(slot, box)
	for slot: StringName in [&"pressed", &"hover_pressed", &"pressed_mirrored", &"hover_pressed_mirrored"]:
		add_theme_stylebox_override(slot, down)
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
			&"font_focus_color", &"font_disabled_color"]:
		add_theme_color_override(slot, word)
	for slot: StringName in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color",
			&"icon_hover_pressed_color", &"icon_focus_color", &"icon_disabled_color"]:
		add_theme_color_override(slot, icon_color)
	end_bulk_theme_override()
	_styling = false


func _animate_change() -> void:
	var tw: Tween = create_tween().set_parallel(true)
	modulate.a = 0.0
	tw.tween_property(self, "modulate:a", 1.0, UiMotion.STATUS_FADE)
	if not UiMotion.reduce:
		pivot_offset = size * 0.5
		var pulse: Tween = create_tween()
		pulse.tween_property(self, "scale", Vector2.ONE * UiMotion.STATUS_PULSE, UiMotion.STATUS_FADE * 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pulse.tween_property(self, "scale", Vector2.ONE, UiMotion.STATUS_FADE * 0.5)


func _draw() -> void:
	if show_new_dot:
		var c: Color = get_theme_color(&"accent", ThemeBuilder.PALETTE_TYPE)
		draw_circle(Vector2(size.x - DOT * 0.5, DOT * 0.5), DOT * 0.5, c)

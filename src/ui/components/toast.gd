class_name Toast
extends PanelContainer
## Toast (ux-design §12 and §17): an ink plate with surface text 16, an optional 24 pt icon, radius 16,
## under the HUD plate. In 220 ms, out 180 ms, with a 12 pt slide and a fade (reduce motion: fade only).
## Stays 2.5 s + 70 ms per character, at most 7 s, or until tapped when "keep messages" is on.
## A tap dismisses it. It blocks touches only inside its own rect.

signal dismissed()
## A tap on a toast that links to its journal entry (ux §12).
signal link_opened()

## Set by UiRoot from the "Keep messages on screen" setting (not stored yet; Phase 3).
static var keep_messages: bool = false

var label: Label = null
var icon_rect: TextureRect = null

var _shown: bool = false
var _tween: Tween = null
var _timer: Timer = null
var _link: bool = false
var _chevron: TextureRect = null


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = &"ToastPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_vertical = Control.GROW_DIRECTION_END
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 12)
	add_child(row)
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(24, 24)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon_rect.visible = false
	row.add_child(icon_rect)
	label = Label.new()
	label.name = "Text"
	label.theme_type_variation = &"ToastLabel"
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_chevron = TextureRect.new()
	_chevron.name = "Chevron"
	_chevron.texture = UiIcon.texture(&"ui_chevron_right")
	_chevron.custom_minimum_size = Vector2(20, 20)
	_chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chevron.visible = false
	row.add_child(_chevron)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(dismiss)
	add_child(_timer)


func is_shown() -> bool:
	return _shown


func show_key(key: StringName, args: Dictionary = {}, icon_id: StringName = &"") -> void:
	show_text(tr(key).format(args), icon_id)


## Text already rendered (Session.format_text() for event toasts with a {time}). With `link`, a › chevron
## shows and a tap opens the journal entry instead of only dismissing.
func show_text(text: String, icon_id: StringName = &"", link: bool = false) -> void:
	label.text = text
	_link = link
	_chevron.visible = link
	_chevron.modulate = get_theme_color(&"surface", ThemeBuilder.PALETTE_TYPE)
	accessibility_description = tr(&"TOAST_A11Y_MORE") if link else ""
	icon_rect.visible = icon_id != &""
	if icon_id != &"":
		icon_rect.texture = UiIcon.texture(icon_id)
		icon_rect.modulate = get_theme_color(&"surface", ThemeBuilder.PALETTE_TYPE)
	if not keep_messages:
		_timer.start(UiMotion.toast_duration(label.text))
	if _shown:
		return
	_shown = true
	visible = true
	_animate(true)


func dismiss() -> void:
	if not _shown:
		return
	_shown = false
	_timer.stop()
	_animate(false)
	dismissed.emit()


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		var linked: bool = _link
		dismiss()
		accept_event()
		if linked:
			link_opened.emit()


func _animate(entering: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var slide: float = 0.0 if UiMotion.reduce else -UiMotion.TOAST_SLIDE
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
	if entering:
		modulate.a = 0.0
		_tween.set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "modulate:a", 1.0, UiMotion.TOAST_IN)
		_tween.tween_method(_set_slide, slide, 0.0, UiMotion.TOAST_IN)
	else:
		_tween.set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "modulate:a", 0.0, UiMotion.TOAST_OUT)
		_tween.tween_method(_set_slide, 0.0, slide, UiMotion.TOAST_OUT)
		_tween.chain().tween_callback(hide)


func _set_slide(v: float) -> void:
	offset_top = v
	offset_bottom = v

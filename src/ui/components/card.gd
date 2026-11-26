class_name Card
extends PanelContainer
## Card (ux-design §12 and §17): full width - 32, padding 20, surface, radius 20, a soft shadow. It rises
## above the action bar: in 280 ms, out 200 ms, with a 24 pt slide and a fade (reduce motion: fade only).
## It blocks touches only inside its own rect. A tap on the card body dismisses it.
## Text is set with tr() keys: show_keys(title_key, body_key, args).

signal dismissed()

var title_label: Label = null
var body_label: Label = null
var buttons: HBoxContainer = null

var _shown: bool = false
var _tween: Tween = null


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = &"CardPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	_set_slide(0.0)
	var box := VBoxContainer.new()
	box.name = "Rows"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	title_label = _label(&"TitleLabel", "Title")
	box.add_child(title_label)
	body_label = _label(&"BodyLabel", "Body")
	box.add_child(body_label)
	buttons = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.visible = false
	box.add_child(buttons)


func is_shown() -> bool:
	return _shown


func show_keys(title_key: StringName, body_key: StringName, args: Dictionary = {}) -> void:
	title_label.text = tr(title_key)
	body_label.text = tr(body_key).format(args) if body_key != &"" else ""
	body_label.visible = body_key != &""
	buttons.visible = buttons.get_child_count() > 0
	if _shown:
		return
	_shown = true
	visible = true
	_animate(true)


func dismiss() -> void:
	if not _shown:
		return
	_shown = false
	_animate(false)
	dismissed.emit()


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		dismiss()
		accept_event()


func _animate(entering: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var slide: float = 0.0 if UiMotion.reduce else UiMotion.CARD_SLIDE
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
	if entering:
		modulate.a = 0.0
		_tween.set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "modulate:a", 1.0, UiMotion.CARD_IN)
		_tween.tween_method(_set_slide, slide, 0.0, UiMotion.CARD_IN)
	else:
		_tween.set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "modulate:a", 0.0, UiMotion.CARD_OUT)
		_tween.tween_method(_set_slide, 0.0, slide, UiMotion.CARD_OUT)
		_tween.chain().tween_callback(hide)


## The card is anchored to the bottom of its slot and grows upward; the slide moves that bottom edge down.
func _set_slide(v: float) -> void:
	offset_top = v
	offset_bottom = v


func _label(type: StringName, label_name: String) -> Label:
	var l := Label.new()
	l.name = label_name
	l.theme_type_variation = type
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

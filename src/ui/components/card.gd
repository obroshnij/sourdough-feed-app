class_name Card
extends PanelContainer
## Card (ux-design §12 and §17): full width - 32, padding 20, surface, radius 20, a soft shadow. It rises
## above the action bar: in 280 ms, out 200 ms, with a 24 pt slide and a fade (reduce motion: fade only).
## It blocks touches only inside its own rect. A tap on the card body dismisses it, unless the card is not
## `dismissable` (the moldy discard card stays until acted on).
## One card at a time (ux-design §1.4): present() replaces whatever was shown. `kind` says what it is
## (explainer, smell, feed_result, nudge, away, discard, notice), so the UI knows what to dismiss.
## Text arrives already translated (through tr() or Session.format_text()).

signal dismissed(kind: StringName)

var title_label: Label = null
var body_label: Label = null
var extra_label: Label = null
var ribbon_label: Label = null
var buttons: HBoxContainer = null
var kind: StringName = &""
var dismissable: bool = true

var _shown: bool = false
var _tween: Tween = null
var _hide_timer: Timer = null


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
	ribbon_label = _label(&"SectionLabel", "Ribbon")
	ribbon_label.visible = false
	box.add_child(ribbon_label)
	title_label = _label(&"TitleLabel", "Title")
	box.add_child(title_label)
	body_label = _label(&"BodyLabel", "Body")
	box.add_child(body_label)
	extra_label = _label(&"HintLabel", "Extra")
	extra_label.visible = false
	box.add_child(extra_label)
	buttons = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.visible = false
	box.add_child(buttons)
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(dismiss)
	add_child(_hide_timer)


func is_shown() -> bool:
	return _shown


## Shows a card. `extra` is the optional ink_muted line (a smell meaning). `hold_s` > 0 auto-hides it after
## that long unless "keep messages on screen" is on.
func present(card_kind: StringName, title: String, body: String, extra: String = "",
		card_buttons: Array[Button] = [], can_dismiss: bool = true, hold_s: float = 0.0, ribbon: String = "") -> void:
	kind = card_kind
	dismissable = can_dismiss
	title_label.text = title
	body_label.text = body
	body_label.visible = body != ""
	extra_label.text = extra
	extra_label.visible = extra != ""
	ribbon_label.text = ribbon
	ribbon_label.visible = ribbon != ""
	for child: Node in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	for b: Button in card_buttons:
		buttons.add_child(b)
	buttons.visible = not card_buttons.is_empty()
	_hide_timer.stop()
	if hold_s > 0.0 and not Toast.keep_messages:
		_hide_timer.start(hold_s)
	if _shown:
		return
	_shown = true
	visible = true
	_animate(true)


## The explainer form: a title key and a body key, translated here.
func show_keys(title_key: StringName, body_key: StringName, args: Dictionary = {}) -> void:
	var keep: Array[Button] = []
	for child: Node in buttons.get_children():
		var b: Button = child as Button
		if b != null:
			keep.append(b)
			buttons.remove_child(b)
	present(&"explainer", tr(title_key), tr(body_key).format(args) if body_key != &"" else "", "", keep)


## Hides the card unless it is a card that must stay (pass force to remove it anyway).
func dismiss(force: bool = false) -> void:
	if not _shown or (not dismissable and not force):
		return
	_shown = false
	_hide_timer.stop()
	_animate(false)
	var was: StringName = kind
	dismissed.emit(was)


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and dismissable:
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

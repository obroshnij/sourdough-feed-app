class_name Stepper
extends HBoxContainer
## Stepper (ux-design §17): [-] value [+], each button 48, outline buttons, value 20 semibold.
## At a limit the button disables. Holding repeats at 8 per second after 400 ms. The value text comes from
## the owner (format_key with {value}), so the stepper never builds player-facing text itself.
## Used by the P1 proofing box dial; built now so the inventory is complete.

signal value_changed(value: int)

const BUTTON: float = 48.0
const REPEAT_DELAY: float = 0.4
const REPEAT_RATE: float = 1.0 / 8.0

@export var min_value: int = 24
@export var max_value: int = 30
@export var value: int = 26:
	set(v):
		value = clampi(v, min_value, max_value)
		_refresh()
## A key whose text holds {value}, for example "{value} °C".
@export var format_key: StringName = &""

var minus: StepButton = null
var plus: StepButton = null
var value_label: Label = null

var _repeat: Timer = null
var _repeat_dir: int = 0


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 12)
	minus = StepButton.new(-1)
	minus.name = "Minus"
	add_child(minus)
	value_label = Label.new()
	value_label.name = "Value"
	value_label.theme_type_variation = &"ValueLabel"
	value_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(72, BUTTON)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(value_label)
	plus = StepButton.new(1)
	plus.name = "Plus"
	add_child(plus)
	_repeat = Timer.new()
	_repeat.timeout.connect(_on_repeat)
	add_child(_repeat)
	for b: StepButton in [minus, plus]:
		b.button_down.connect(_on_down.bind(b.direction))
		b.button_up.connect(_on_up)
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh()


func step(direction: int) -> void:
	var before: int = value
	value = value + direction
	if value != before:
		value_changed.emit(value)


func _on_down(direction: int) -> void:
	step(direction)
	_repeat_dir = direction
	_repeat.start(REPEAT_DELAY)


func _on_up() -> void:
	_repeat.stop()
	_repeat_dir = 0


func _on_repeat() -> void:
	if _repeat_dir == 0:
		_repeat.stop()
		return
	step(_repeat_dir)
	_repeat.start(REPEAT_RATE)


func _refresh() -> void:
	if value_label == null:
		return
	value_label.text = tr(format_key).format({"value": value}) if format_key != &"" else str(value)
	minus.disabled = value <= min_value
	plus.disabled = value >= max_value
	if minus.disabled or plus.disabled:
		_on_up()

class_name StepButton
extends Button
## A stepper's 48 pt [-] or [+] button. The sign is drawn as a shape, so there is no literal text.

const SIZE: float = 48.0
const ARM: float = 7.0

var direction: int = 1


func _init(dir: int = 1) -> void:
	direction = dir


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = &"StepButton"
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text = ""
	accessibility_name = tr(&"UI_INCREASE_A11Y" if direction > 0 else &"UI_DECREASE_A11Y")
	button_down.connect(UiMotion.press.bind(self, true))
	button_up.connect(UiMotion.press.bind(self, false))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		accessibility_name = tr(&"UI_INCREASE_A11Y" if direction > 0 else &"UI_DECREASE_A11Y")


func _draw() -> void:
	var c: Color = get_theme_color(&"font_disabled_color" if disabled else &"font_color")
	var mid: Vector2 = size * 0.5
	draw_line(mid - Vector2(ARM, 0), mid + Vector2(ARM, 0), c, 2.0, true)
	if direction > 0:
		draw_line(mid - Vector2(0, ARM), mid + Vector2(0, ARM), c, 2.0, true)

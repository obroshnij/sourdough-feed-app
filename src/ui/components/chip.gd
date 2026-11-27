class_name Chip
extends Button
## Chip (ux-design §17): at least 48 tall, surface_alt fill, outline border, ink 16 semibold. Selected chips
## turn accent with an on_accent label and a check icon, so selection never relies on color alone.
## Chips in one ButtonGroup act as radio choices.

const MIN_HEIGHT: float = 48.0
const MIN_WIDTH: float = 64.0

@export var text_key: StringName = &"":
	set(v):
		text_key = v
		_refresh_text()
@export var icon_id: StringName = &""
## Labels stay on one line unless the slot allows two (inspect chips at 150%, ux-design §18).
@export var wrap: bool = false
## False for action chips (inspect kinds) that act on tap instead of staying selected.
@export var toggles: bool = true


func _init(key: StringName = &"") -> void:
	text_key = key


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = &"ChipButton"
	toggle_mode = toggles
	custom_minimum_size = Vector2(MIN_WIDTH, MIN_HEIGHT)
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_refresh_text()
	_refresh_icon()
	toggled.connect(func(_on: bool) -> void: _refresh_icon())
	button_down.connect(UiMotion.press.bind(self, true))
	button_up.connect(UiMotion.press.bind(self, false))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()


func _refresh_icon() -> void:
	if button_pressed:
		icon = UiIcon.texture(&"ui_check")
	elif icon_id != &"":
		icon = UiIcon.texture(icon_id)
	else:
		icon = null


func _refresh_text() -> void:
	if not is_node_ready():
		return
	text = tr(text_key) if text_key != &"" else ""
	accessibility_name = text

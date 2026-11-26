class_name IconButton
extends Button
## IconButton (ux-design §17): a 48 pt circle on a plate, a 24 pt ink icon. Used for settings, close and back.
## Icon-only, so the accessibility name is required.

const SIZE: float = 48.0

@export var icon_id: StringName = &"ui_settings":
	set(v):
		icon_id = v
		if is_node_ready():
			icon = UiIcon.texture(icon_id)
@export var a11y_key: StringName = &""


func _init(id: StringName = &"ui_settings", key: StringName = &"") -> void:
	icon_id = id
	a11y_key = key


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = &"IconButton"
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expand_icon = false
	text = ""
	icon = UiIcon.texture(icon_id)
	_refresh_text()
	button_down.connect(UiMotion.press.bind(self, true))
	button_up.connect(UiMotion.press.bind(self, false))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()


func _refresh_text() -> void:
	if is_node_ready():
		accessibility_name = tr(a11y_key) if a11y_key != &"" else ""

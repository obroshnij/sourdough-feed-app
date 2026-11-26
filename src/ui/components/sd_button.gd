class_name SdButton
extends Button
## PrimaryButton (56 tall, accent), SecondaryButton (52, outline) and TextButton (44, no fill), ux-design §17.
## Text and the accessibility name come only from tr() keys. Whoever disables one also shows the reason
## (AC-12.9), for example with a ReasonLabel under it.

enum Variant { PRIMARY, SECONDARY, TEXT }

const MIN_HEIGHTS: Dictionary[Variant, float] = {Variant.PRIMARY: 56.0, Variant.SECONDARY: 52.0, Variant.TEXT: 44.0}
const MIN_WIDTH: float = 64.0
const TYPES: Dictionary[Variant, StringName] = {
	Variant.PRIMARY: &"PrimaryButton", Variant.SECONDARY: &"SecondaryButton", Variant.TEXT: &"TextButton",
}

@export var variant: Variant = Variant.SECONDARY:
	set(v):
		variant = v
		_apply_variant()
@export var text_key: StringName = &"":
	set(v):
		text_key = v
		_refresh_text()
## Defaults to text_key.
@export var a11y_key: StringName = &""


func _init(key: StringName = &"", kind: Variant = Variant.SECONDARY) -> void:
	text_key = key
	variant = kind


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	focus_mode = Control.FOCUS_ALL
	clip_text = false
	text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_apply_variant()
	_refresh_text()
	button_down.connect(UiMotion.press.bind(self, true))
	button_up.connect(UiMotion.press.bind(self, false))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_text()


func _apply_variant() -> void:
	theme_type_variation = TYPES[variant]
	custom_minimum_size = Vector2(MIN_WIDTH, MIN_HEIGHTS[variant])


func _refresh_text() -> void:
	if not is_node_ready():
		return
	text = tr(text_key) if text_key != &"" else ""
	var key: StringName = a11y_key if a11y_key != &"" else text_key
	accessibility_name = tr(key) if key != &"" else ""

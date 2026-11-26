class_name FitLabel
extends Label
## A one-line label that shrinks its font down to 85% to fit its width, then ellipsizes (ux-design §17,
## the starter's name row). Text is set by the owner (a player-typed name is not a tr() key).

const MIN_FIT: float = 0.85

var _base_size: int = 0
var _fitting: bool = false


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	autowrap_mode = TextServer.AUTOWRAP_OFF
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	resized.connect(_fit)
	_fit()


func set_fit_text(value: String) -> void:
	text = value
	_fit()


## The font size in use after fitting.
func fitted_font_size() -> int:
	return get_theme_font_size(&"font_size")


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and not _fitting:
		_fit()


func _fit() -> void:
	if not is_node_ready() or _fitting:
		return
	_fitting = true
	remove_theme_font_size_override(&"font_size")
	_base_size = get_theme_font_size(&"font_size")
	var font: Font = get_theme_font(&"font")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _base_size).x
	if size.x > 0.0 and width > size.x:
		var target: int = maxi(floori(_base_size * size.x / width), ceili(_base_size * MIN_FIT))
		add_theme_font_size_override(&"font_size", mini(target, _base_size))
	_fitting = false

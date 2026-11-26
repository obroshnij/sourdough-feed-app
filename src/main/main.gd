extends Node
## Main (architecture.md §3.2). Composes World (T2) and UI (T3) by path, sets the content scale, and
## starts the session after both have connected their signals (children are ready before the parent).


func _ready() -> void:
	# Stretch mode is disabled: 1 UI unit = 1 pt or dp at the real logical size (architecture §13).
	get_window().content_scale_factor = DisplayServer.screen_get_scale()
	Session.start()

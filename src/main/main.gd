extends Node
## Main (architecture.md §3.2). Composes World (T2) and UI (T3) by path, sets the content scale, and
## starts the session after both have connected their signals (children are ready before the parent).


func _ready() -> void:
	# Stretch mode is disabled: 1 UI unit = 1 pt or dp at the real logical size (architecture §13).
	var scale: float = DisplayServer.screen_get_scale()
	var win: Window = get_window()
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless" and scale > 1.0:
		# Desktop test window: the project size is in pt, so a 2x screen needs a 2x window
		# (otherwise 390 x 844 px shows only 195 x 422 pt). On phones the window is the screen.
		var w: int = ProjectSettings.get_setting("display/window/size/viewport_width", 390)
		var h: int = ProjectSettings.get_setting("display/window/size/viewport_height", 844)
		win.size = Vector2i(roundi(w * scale), roundi(h * scale))
	win.content_scale_factor = scale
	Session.start()
	# Debug builds only (architecture §3.2): the F3 dev overlay with the debug time scale.
	if OS.is_debug_build():
		add_child(DevOverlay.new())

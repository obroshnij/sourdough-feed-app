extends SceneTree
## Regenerates src/ui/theme/sourdough_theme.tres from ThemeBuilder at 100% text by day.
##   Godot --headless --path . -s res://tests/unit/ui/tools/build_theme.gd
## test_theme.gd fails while the committed file differs from a fresh build.


func _initialize() -> void:
	var t: Theme = ThemeBuilder.build(UiPalette.new(0.0), 1.0)
	var err: Error = ResourceSaver.save(t, ThemeBuilder.THEME_PATH)
	print("build_theme: saved %s (%s)" % [ThemeBuilder.THEME_PATH, error_string(err)])
	quit(0 if err == OK else 1)

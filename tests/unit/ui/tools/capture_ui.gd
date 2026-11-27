extends SceneTree
## UI captures for review, rendered windowed (the headless renderer draws nothing):
##   Godot --path . -s res://tests/unit/ui/tools/capture_ui.gd
## Writes captures/ui/<device>_<state>_<day|night>[_<extra>].png at 2x (a 390 x 844 pt screen is a
## 780 x 1688 px image), with the device's safe areas applied.
## The 3D scene is not in these: the background is art-director's Blender preview for the same state
## (art/previews/jar_v0_<state>.png), cover-fitted. Night darkens that preview as a stand-in for the
## evening lighting preset, which T2 owns. Neither background is a Godot render.

const H := preload("res://tests/unit/ui/ui_harness.gd")
const OUT_DIR: String = "res://captures/ui"
const SCALE: float = 2.0
const NIGHT_TINT := Color(0.42, 0.37, 0.34)

## [device, state, night, text scale, extra: "" | "settings" | "explainer" | "toast"]
const SHOTS: Array[Array] = [
	["iphone_17e_390x844", &"at_peak", false, 1.0, ""],
	["iphone_17e_390x844", &"at_peak", true, 1.0, ""],
	["iphone_se_375x667", &"hungry", false, 1.0, ""],
	["iphone_se_375x667", &"hungry", true, 1.0, ""],
	["iphone_17_pro_max_440x956", &"unhealthy", false, 1.0, ""],
	["iphone_17_pro_max_440x956", &"unhealthy", true, 1.0, ""],
	["iphone_se_375x667", &"moldy", false, 1.5, "largest"],
	["iphone_17e_390x844", &"collapsing", false, 1.0, "explainer"],
	["iphone_17e_390x844", &"at_peak", false, 1.5, "settings"],
	["android_360x640", &"active", false, 1.0, ""],
	# Phase 3, driven by a real Session booted from tests/unit/ui/fixtures/<state>.json.
	["iphone_17e_390x844", &"at_peak", false, 1.0, "feed"],
	["iphone_se_375x667", &"dormant_starved", false, 1.0, "feed"],
	["iphone_17e_390x844", &"active", false, 1.0, "place"],
	["iphone_17e_390x844", &"at_peak", false, 1.0, "smell"],
	["iphone_17e_390x844", &"active", false, 1.0, "inspect"],
	["iphone_se_375x667", &"at_peak", false, 1.5, "feed"],
]
const SESSION_EXTRAS: Array[String] = ["feed", "place", "smell", "inspect"]


func _initialize() -> void:
	I18nLoader.load_all()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run.call_deferred()


func _run() -> void:
	UiMotion.reduce = true
	for shot: Array in SHOTS:
		await _capture(shot)
	print("capture_ui: done, %d images in %s" % [SHOTS.size(), OUT_DIR])
	quit(0)


func _capture(shot: Array) -> void:
	var device: String = shot[0]
	var state: StringName = shot[1]
	var night: bool = shot[2]
	var text_scale: float = shot[3]
	var extra: String = shot[4]
	var pt: Vector2 = H.device_size(device)
	var vp := SubViewport.new()
	vp.size = Vector2i(pt * SCALE)
	vp.size_2d_override = Vector2i(pt)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var bg := TextureRect.new()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = _preview(state)
	bg.position = Vector2.ZERO
	bg.size = pt
	bg.modulate = NIGHT_TINT if night else Color.WHITE
	vp.add_child(bg)
	var ui: UiRoot = H.mount(vp, device, text_scale, 1.0 if night else 0.0)
	var session: GameSession = null
	if SESSION_EXTRAS.has(extra):
		session = GameSession.new()
		root.add_child(session)
		var dir: String = "user://capture_tmp/%d" % Time.get_ticks_usec()
		session.setup(FakeClock.new(), SaveStore.new(dir), SettingsStore.new(dir + "/settings.cfg"))
		session.boot_from_fixture("res://tests/unit/ui/fixtures/%s.json" % state)
		ui.bind_session(session)
		ui.set_text_scale(text_scale)
		ui.set_night_blend(1.0 if night else 0.0)
	else:
		ui.apply_snapshot(H.snapshot(state, "Bramble"))
	await H.settle(self, 4)
	match extra:
		"settings":
			ui.hud.settings_button.pressed.emit()
		"explainer":
			ui.hud.status_pill.pressed.emit()
		"feed":
			ui.open_sheet(&"feed")
		"place":
			ui.open_sheet(&"environment")
		"smell":
			UiMotion.time_scale = 0.05
			ui.start_smell()
			await create_timer(0.5).timeout
			UiMotion.time_scale = 1.0
		"inspect":
			ui.open_sheet(&"inspect")
			UiMotion.time_scale = 0.05
			ui.inspect_sheet.show_kind(&"bubbles")
			await create_timer(0.5).timeout
			UiMotion.time_scale = 1.0
	await create_timer(0.8).timeout
	var img: Image = vp.get_texture().get_image()
	var name: String = "%s_%s_%s%s.png" % [device, state, "night" if night else "day",
		"" if extra == "" else "_" + extra]
	var path: String = ProjectSettings.globalize_path(OUT_DIR + "/" + name)
	var err: Error = img.save_png(path)
	print("capture_ui: %s %s (%dx%d, %s)" % [name, error_string(err), img.get_width(), img.get_height(),
		"jar region %s" % ui.jar_region()])
	vp.queue_free()
	if session != null:
		session.queue_free()
	await H.settle(self, 2)


func _preview(state: StringName) -> Texture2D:
	var p: String = ProjectSettings.globalize_path("res://art/previews/jar_v0_%s.png" % String(state).trim_suffix("_starved").trim_suffix("_cold"))
	if not FileAccess.file_exists(p):
		p = ProjectSettings.globalize_path("res://art/previews/jar_v0_at_peak.png")
	var img: Image = Image.load_from_file(p)
	return ImageTexture.create_from_image(img)

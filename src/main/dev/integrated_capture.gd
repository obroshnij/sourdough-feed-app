extends Node
## Dev only: captures the full game (main.tscn, the 3D world plus the HUD) from a fixture save, then quits.
## Never instanced by main.tscn, so normal runs are unchanged. Windowed only (the headless renderer draws
## nothing). Modeled on the scrubber's capture mode (src/view/dev/scrubber.gd).
##
##   Godot --path . [--rendering-method gl_compatibility] res://src/main/dev/integrated_capture.tscn --
##     --fixture=res://tests/unit/ui/fixtures/at_peak.json  (read by Session, DevFlags)
##     --capture=captures/integrated   output folder
##     --local-time=13:00              local wall time the DebugClock starts at (drives the night palette)
##     --insets=iphone_17e|iphone_se|none   safe areas in pt (ux-design §2): 17e 47/34, SE 20/0
##     --size=375x667                  diagnostic: another screen size in pt (default 390 x 844)
##     --settle=2.0                    seconds before the shot (camera framing eases in over 0.3 s)
##
## It injects the real seams before Main calls Session.start(): a DebugClock moved to --local-time, a
## SaveStore in its own folder, and default settings that are never loaded or saved, so a teammate's
## user:// settings can't change the shot. Session then boots the fixture exactly as --fixture= does.

const MAIN_SCENE: String = "res://src/main/main.tscn"
const SAVE_DIR: String = "user://integrated_capture_saves"
const DEFAULT_DIR: String = "captures/integrated"
## Safe areas, top and bottom in pt (the iOS rows of tests/unit/ui/ui_harness.gd).
const INSETS: Dictionary[String, Vector2] = {
	"iphone_17e": Vector2(47.0, 34.0), "iphone_se": Vector2(20.0, 0.0), "none": Vector2.ZERO,
}
const RIM_SAMPLES: int = 32

var args: Dictionary[String, String] = {}


func _ready() -> void:
	_parse_args()
	# A hidden or sleeping display can block vsync forever; captures don't need it (T2 finding).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var session: GameSession = get_node(^"/root/Session") as GameSession
	var clock := DebugClock.new(1.0)
	var target_min: int = _minutes(_arg("local-time", "13:00"))
	var cur_min: int = LocalDay.minute_of_day(clock.now_unix(), clock.local_utc_offset_s())
	clock.advance(float(posmod(target_min - cur_min, 24 * 60) * 60))
	session.setup(clock, SaveStore.new(SAVE_DIR), SettingsStore.new(""))
	var size_pt: PackedStringArray = _arg("size", "").split("x")
	if size_pt.size() == 2 and size_pt[0].is_valid_int() and size_pt[1].is_valid_int():
		# Read by Main._ready for the desktop window size; runtime only, never saved.
		ProjectSettings.set_setting("display/window/size/viewport_width", size_pt[0].to_int())
		ProjectSettings.set_setting("display/window/size/viewport_height", size_pt[1].to_int())
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await main.ready
	var ui: UiRoot = main.get_node(^"UI/Root") as UiRoot
	var world: WorldView = main.get_node(^"World") as WorldView
	var inset: Vector2 = INSETS.get(_arg("insets", "iphone_17e"), INSETS["iphone_17e"])
	ui.set_insets_override(SafeInsets.make(inset.x, inset.y))
	await get_tree().create_timer(float(_arg("settle", "2.0"))).timeout
	for i: int in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_shoot(session, ui, world)
	get_tree().quit()


func _shoot(session: GameSession, ui: UiRoot, world: WorldView) -> void:
	var snap: StarterSnapshot = session.get_snapshot()
	var renderer: String = world.renderer
	var r_name: String = "compat" if renderer == QualityTier.RENDERER_COMPATIBILITY else renderer
	var night: bool = ui.palette.night >= 0.5
	var fixture: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fixture="):
			fixture = a.trim_prefix("--fixture=").get_file().get_basename()
	var dir: String = _arg("capture", DEFAULT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var w: int = ProjectSettings.get_setting("display/window/size/viewport_width", 390)
	var h: int = ProjectSettings.get_setting("display/window/size/viewport_height", 844)
	var pt := Vector2i(w, h)
	var suffix: String = "" if pt == Vector2i(390, 844) else "_%dx%d" % [pt.x, pt.y]
	var path: String = "%s/%s_%s_%s%s.png" % [dir, r_name, snap.state, "night" if night else "day", suffix]
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(path)
	var win: Window = get_window()
	print("ENV renderer=%s driver=%s adapter=%s godot=%s screen_scale=%.2f content_scale=%.2f window_px=%s visible_pt=%s scale3d=%.2f" % [
		renderer, RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(),
		Engine.get_version_info()["string"], DisplayServer.screen_get_scale(), win.content_scale_factor,
		str(DisplayServer.window_get_size()), str(get_viewport().get_visible_rect().size),
		get_viewport().scaling_3d_scale])
	print("STATE fixture=%s state=%s tier=%s local=%s night_blend=%.2f insets=%s" % [
		fixture, snap.state, "B" if world.tier == QualityTier.Tier.B else "A",
		_hhmm(LocalDay.minute_of_day(session.now_unix(), session.local_utc_offset_s())), ui.palette.night,
		_arg("insets", "iphone_17e")])
	if fixture != "" and StringName(fixture) != snap.state:
		print("MISMATCH fixture %s booted as %s" % [fixture, snap.state])
	var region: Rect2 = ui.jar_region()
	var jar: Vector2 = _jar_extent_pt(world)
	var inside: bool = jar.x >= region.position.y and jar.y <= region.end.y
	print("FRAME region_pt=[%.1f..%.1f] jar_pt=[%.1f..%.1f] region_mid=%.1f jar_mid=%.1f frame_shift=%.3f inside=%s" % [
		region.position.y, region.end.y, jar.x, jar.y, region.get_center().y, (jar.x + jar.y) * 0.5,
		world.rig.frame_shift, inside])
	var expected: Vector2i = pt * 2
	var size_note: String = "" if img.get_size() == expected else " WARN expected 2x: %s" % str(expected)
	print("SHOT %s %dx%d err=%s%s" % [path, img.get_width(), img.get_height(), error_string(err), size_note])


## Top and bottom of the jar on screen, in pt: the glass cylinder rims plus any visible cover.
func _jar_extent_pt(world: WorldView) -> Vector2:
	var cam: Camera3D = world.rig.camera
	var xf: Transform3D = world.jar.global_transform
	var pts: Array[Vector3] = []
	for i: int in range(RIM_SAMPLES):
		var a: float = TAU * float(i) / float(RIM_SAMPLES)
		var p := Vector3(sin(a) * JarGeometry.OUTER_RADIUS_M, 0.0, cos(a) * JarGeometry.OUTER_RADIUS_M)
		pts.append(xf * p)
		pts.append(xf * (p + Vector3(0.0, JarGeometry.HEIGHT_M, 0.0)))
	for cover: MeshInstance3D in world.jar.covers.values():
		if cover.is_visible_in_tree():
			var box: AABB = cover.global_transform * cover.get_aabb()
			for c: int in range(8):
				pts.append(box.get_endpoint(c))
	var lo: float = INF
	var hi: float = -INF
	for p: Vector3 in pts:
		var s: Vector2 = cam.unproject_position(p)
		lo = minf(lo, s.y)
		hi = maxf(hi, s.y)
	return Vector2(lo, hi)


func _parse_args() -> void:
	for a: String in OS.get_cmdline_user_args():
		var clean: String = a.trim_prefix("--")
		var eq: int = clean.find("=")
		if eq >= 0:
			args[clean.substr(0, eq)] = clean.substr(eq + 1)
		else:
			args[clean] = "1"


func _arg(key: String, fallback: String) -> String:
	return args[key] if args.has(key) else fallback


static func _minutes(hhmm: String) -> int:
	var parts: PackedStringArray = hhmm.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_warning("integrated_capture: bad --local-time %s, using 13:00" % hhmm)
		return 13 * 60
	return posmod(parts[0].to_int() * 60 + parts[1].to_int(), 24 * 60)


static func _hhmm(minute: int) -> String:
	@warning_ignore("integer_division")
	return "%02d:%02d" % [minute / 60, minute % 60]

extends Node
## Dev only: the VisualParams scrubber (roadmap Phase 2, T2) and the look capture tool.
## Not part of the game: never instanced by main.tscn. Labels show field ids, not player text.
##
## Interactive:
##   Godot --path . res://src/view/dev/scrubber.tscn [-- --source=art|sim --state=<id> --tier=a|b]
## Captures (windowed, the headless renderer draws nothing), then quits:
##   Godot --path . --resolution 720x1280 res://src/view/dev/scrubber.tscn -- --capture=captures/view
##     --states=a,b|all  --views=pose,side,top  --tiers=a,b  --source=art|sim  --prefix=<text>
## Diagnostics: --stock-starter (StandardMaterial3D starter), --no-glass, --look-<field>=<value>
## (ViewLook overrides), --scale3d=<f> (default 1.0 in captures).

const POSE_SIZE: Vector2i = Vector2i(720, 1280)
const CLOSE_SIZE: Vector2i = Vector2i(640, 800)
const CAPTURE_TIME: float = 10.0
const RANGES: Dictionary[StringName, Vector2] = {
	&"level_m": Vector2(0.0, 0.042), &"rise": Vector2(1.0, 3.0), &"dome": Vector2(-1.0, 1.0),
	&"activity": Vector2(0.0, 1.0), &"bubble_density": Vector2(0.0, 1.0), &"peak_line": Vector2(0.0, 3.0),
	&"lumps": Vector2(0.0, 1.0), &"hooch_depth": Vector2(0.0, 1.0), &"bubble_size": Vector2(0.0, 1.0),
	&"streak_amount": Vector2(0.0, 1.0), &"surface_dryness": Vector2(0.0, 1.0), &"sheen": Vector2(0.0, 1.0),
	&"fleck": Vector2(0.0, 1.0), &"dullness": Vector2(0.0, 1.0), &"mold": Vector2(0.0, 1.0),
	&"big_bubble": Vector2(0.0, 1.0),
}

@onready var world: WorldView = $World

var args: Dictionary[String, String] = {}
var params: VisualParams = VisualParams.new()
var sim_looks: Dictionary[StringName, VisualParams] = {}
var source: String = "art"
var state_id: StringName = &"at_peak"
var info: Label
var sliders: Dictionary[StringName, HSlider] = {}


func _ready() -> void:
	_parse_args()
	source = _arg("source", "art")
	state_id = StringName(_arg("state", "at_peak"))
	var look: ViewLook = ViewLook.for_renderer(world.renderer)
	look.apply_overrides(args)
	world.apply_look(look)
	print("ENV renderer=%s driver=%s adapter=%s godot=%s window=%s screen_scale=%.2f" % [
		world.renderer, RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), Engine.get_version_info()["string"],
		str(DisplayServer.window_get_size()), DisplayServer.screen_get_scale()])
	print("LOOK " + look.describe())
	if not world.jar.contract_errors.is_empty():
		print("CONTRACT " + ", ".join(world.jar.contract_errors))
	if source == "sim":
		sim_looks = StateLooks.sim_states()
		print("SIM states reached: %s" % ", ".join(PackedStringArray(sim_looks.keys())))
	if args.has("tier"):
		world.set_tier(QualityTier.Tier.B if args["tier"] == "b" else QualityTier.Tier.A)
	if args.has("no-glass"):
		world.jar.glass.visible = false
	set_state(state_id)
	if args.has("stock-starter"):
		world.jar.use_stock_starter(true)
	if args.has("capture"):
		_run_captures()
	else:
		_build_ui()


func _arg(key: String, fallback: String) -> String:
	return args[key] if args.has(key) else fallback


func _parse_args() -> void:
	for a: String in OS.get_cmdline_user_args():
		var clean: String = a.trim_prefix("--")
		var eq: int = clean.find("=")
		if eq >= 0:
			args[clean.substr(0, eq)] = clean.substr(eq + 1)
		else:
			args[clean] = "1"


func params_for(id: StringName) -> VisualParams:
	if source == "sim":
		if sim_looks.has(id):
			return sim_looks[id].copy()
		push_warning("scrubber: the sim walk never reached %s, showing the art look" % id)
	return StateLooks.look_for(id)


func set_state(id: StringName) -> void:
	state_id = id
	params = params_for(id)
	world.set_visuals(params)
	_sync_sliders()


# ------------------------------------------------------------------ captures

func _run_captures() -> void:
	# A hidden or sleeping display can block vsync forever; captures don't need it.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_viewport().scaling_3d_scale = float(_arg("scale3d", "1.0"))
	var dir: String = args["capture"]
	DirAccess.make_dir_recursive_absolute(dir)
	var states: Array[StringName] = StateLooks.states() if _arg("states", "all") == "all" else _names(args["states"])
	var views: PackedStringArray = _arg("views", "pose").split(",")
	var tiers: PackedStringArray = _arg("tiers", "a,b" if QualityTier.supports_b(world.renderer) else "a").split(",")
	var r_name: String = "compat" if world.renderer == QualityTier.RENDERER_COMPATIBILITY else world.renderer
	var prefix: String = _arg("prefix", r_name)
	world.rig.set_process(false)
	for t: String in tiers:
		world.set_tier(QualityTier.Tier.B if t == "b" else QualityTier.Tier.A)
		for s: StringName in states:
			set_state(s)
			world.jar.set_time_override(CAPTURE_TIME)
			for v: String in views:
				_pose_for_view(v)
				var path: String = "%s/%s_tier%s_%s_%s.png" % [dir, prefix, t.to_upper(), s, v]
				await _capture(path, v != "pose")
	get_tree().quit()


func _names(csv: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for n: String in csv.split(","):
		out.append(StringName(n))
	return out


## The §7 preview pose, or the §16.2 close-ups (640 x 800 at a 33.4 degree vertical FOV,
## cut from the middle of the window with a wider FOV).
func _pose_for_view(view: String) -> void:
	var rig: OrbitCamera = world.rig
	var win: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	if view == "pose":
		rig.fov_deg = OrbitCamera.FOV_DEG
		rig.set_pose(0.0, 15.0, OrbitCamera.HOME_DISTANCE, OrbitCamera.HOME_TARGET)
		return
	var crop_h: float = win.x * float(CLOSE_SIZE.y) / float(CLOSE_SIZE.x)
	var half: float = atan(tan(deg_to_rad(OrbitCamera.FOV_DEG) * 0.5) * win.y / crop_h)
	rig.fov_deg = rad_to_deg(2.0 * half)
	var level: float = params.level_m * params.rise
	var cam_pos: Vector3
	var look_at: Vector3
	if view == "side":
		var y: float = 0.008 + 0.55 * level
		cam_pos = Vector3(-0.0737, y + 0.012, 0.1386)
		look_at = Vector3(0.0, y, 0.0)
	else:
		var y2: float = 0.008 + level + 0.6 * maxf(params.dome * 0.010, 0.0)
		cam_pos = Vector3(0.0, y2 + 0.194, 0.0484)
		look_at = Vector3(0.0, y2, -0.004)
	var off: Vector3 = cam_pos - look_at
	rig.set_pose(rad_to_deg(atan2(off.x, off.z)), rad_to_deg(asin(off.y / off.length())), off.length(), look_at)
	if view == "top":
		world.jar.covers[&"loose_lid"].visible = false


func _capture(path: String, crop: bool) -> void:
	for i: int in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var w: int = img.get_width()
	var h: int = img.get_height()
	if crop:
		var ch: int = int(round(float(w) * float(CLOSE_SIZE.y) / float(CLOSE_SIZE.x)))
		img = img.get_region(Rect2i(0, (h - ch) / 2, w, ch))
		img.resize(CLOSE_SIZE.x, CLOSE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	elif w != POSE_SIZE.x:
		img.resize(POSE_SIZE.x, int(round(float(h) * float(POSE_SIZE.x) / float(w))), Image.INTERPOLATE_LANCZOS)
	var err: Error = img.save_png(path)
	print("SHOT %s %dx%d err=%d" % [path, img.get_width(), img.get_height(), err])
	world.jar.covers[&"loose_lid"].visible = params.cover == &"loose_lid"


# ------------------------------------------------------------------ interactive UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(4, 4)
	scroll.size = Vector2(300, 640)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(scroll)
	var box := VBoxContainer.new()
	scroll.add_child(box)
	info = Label.new()
	box.add_child(info)
	var src_row := HBoxContainer.new()
	box.add_child(src_row)
	for src: String in ["art", "sim"]:
		var sb := Button.new()
		sb.text = src
		sb.pressed.connect(_set_source.bind(src))
		src_row.add_child(sb)
	var flow := HFlowContainer.new()
	flow.custom_minimum_size = Vector2(290, 0)
	box.add_child(flow)
	for s: StringName in StateLooks.states():
		var b := Button.new()
		b.text = String(s)
		b.pressed.connect(set_state.bind(s))
		flow.add_child(b)
	var tier_row := HBoxContainer.new()
	box.add_child(tier_row)
	for t: String in ["a", "b"]:
		var tb := Button.new()
		tb.text = "tier " + t
		tb.pressed.connect(_set_tier.bind(t))
		tier_row.add_child(tb)
	for focus: StringName in [&"home", &"bubbles", &"surface", &"height", &"top"]:
		var fb := Button.new()
		fb.text = String(focus)
		fb.pressed.connect(world.rig.focus.bind(focus))
		tier_row.add_child(fb)
	for u: StringName in RANGES:
		var row := HBoxContainer.new()
		box.add_child(row)
		var l := Label.new()
		l.text = String(u)
		l.custom_minimum_size = Vector2(120, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = RANGES[u].x
		sl.max_value = RANGES[u].y
		sl.step = 0.001
		sl.custom_minimum_size = Vector2(160, 0)
		sl.value_changed.connect(_on_slider.bind(u))
		row.add_child(sl)
		sliders[u] = sl
	_sync_sliders()


func _set_source(src: String) -> void:
	source = src
	if source == "sim" and sim_looks.is_empty():
		sim_looks = StateLooks.sim_states()
	set_state(state_id)


func _set_tier(t: String) -> void:
	if t == "b" and not QualityTier.supports_b(world.renderer):
		print("Tier B needs the Mobile renderer")
		return
	world.set_tier(QualityTier.Tier.B if t == "b" else QualityTier.Tier.A)


func _on_slider(value: float, u: StringName) -> void:
	params.set(u, value)
	world.set_visuals(params)


func _sync_sliders() -> void:
	for u: StringName in sliders:
		sliders[u].set_value_no_signal(float(params.get(u)))


func _process(_delta: float) -> void:
	if info != null:
		info.text = "%s %s tier %s %s %d fps" % [world.renderer, source, QualityTier.tier_name(world.tier),
			state_id, Engine.get_frames_per_second()]

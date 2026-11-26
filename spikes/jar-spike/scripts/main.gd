extends Node
## Jar spike entry point. Builds the whole scene in code so every value is in
## one place. The 3D scene renders in a SubViewport at a fixed phone-sized
## resolution (default 1206x2622, iPhone 16/17 Pro pixel count), shown scaled
## in a smaller Mac window.
##
## User args (after "--"):
##   --bench                run the scripted orbit benchmark, then quit
##   --shots                save screenshots to res://screenshots/, then quit
##   --selftest             inject touch and mouse events, check the camera and routing, then quit
##   --glbcheck=<res path>  print an art GLB's nodes, normals and extras, then quit
##   --glb=<res path>       swap the art GLB in for the primitives
##   --tier=a|b             glass tier (default a)
##   --state=<state_id>     starter state (default at_peak)
##   --res=WxH              3D render size (default 1206x2622)
##   --msaa=0|2|4|8         3D MSAA (default 4)
##   --seconds=N            benchmark length (default 60)
##   --yaw-limit=DEG        limit orbit yaw (default unlimited)
##   --uniforms             print glass Tier B's compiled uniforms (proves the CURRENT_RENDERER branch)
## Shots only:   --only=<substring>  --shot-dir=<path>  --force-b (Tier B shots on Compatibility)
## Bench only:   --no-bubbles  --refraction-off  --label-suffix=<text>
## Self-test:    --no-own-touches (reproduces the drag-over-a-Control bug)
## Color parity: --tonemap=agx|filmic|linear --exposure=F --white=F --key=F --ambient=F
##               --ambient-source=color --ambient-color=r,g,b --sky-contribution=F
##               --saturation=F (turns adjustments on) --reflections=off
##               --set-colors --no-translucency --no-glass
## Measure with: -s res://scripts/patch_probe.gd -- <png> ...

const KEY_DIR: Vector3 = Vector3(-0.5, 0.75, 0.5)
const RIM_DIR: Vector3 = Vector3(0.75, 0.2, -0.62)
const HORIZON: Color = Color(0.93, 0.88, 0.80)
const DOME_HEIGHT: float = 0.008

var args: Dictionary[String, String] = {}
var renderer: String = ""
var tier: String = "a"
var state_id: StringName = &"at_peak"
var render_size: Vector2i = Vector2i(1206, 2622)
var msaa: int = 4

var builder := JarBuilder.new()
var sub: SubViewport
var world: Node3D
var orbit: OrbitCamera
var glass_mi: MeshInstance3D
var starter_mi: MeshInstance3D
var liner_mi: MeshInstance3D
var starter_mat: ShaderMaterial
var liner_mat: ShaderMaterial
var glass_back_mat: ShaderMaterial
var glass_front_a_mat: ShaderMaterial
var glass_front_b_mat: ShaderMaterial
var params: StarterViewParams
var ui_layer: CanvasLayer
var info_label: Label
var sliders: Dictionary[StringName, HSlider] = {}


func _ready() -> void:
	_parse_args()
	renderer = RenderingServer.get_current_rendering_method()
	_print_env()
	if args.has("glbcheck"):
		GlbCheck.report(args["glbcheck"])
		get_tree().quit()
		return
	_build_viewport()
	_build_world()
	if args.has("glb"):
		_swap_in_art(args["glb"])
	set_tier(tier)
	set_state(state_id)
	if args.has("set-colors"):
		# Same values as the shader defaults, but set from GDScript (source_color test).
		starter_mat.set_shader_parameter(&"starter_color", Color(0.93, 0.87, 0.76))
		starter_mat.set_shader_parameter(&"cavity_color", Color(0.50, 0.41, 0.31))
		starter_mat.set_shader_parameter(&"hooch_color", Color(0.46, 0.40, 0.29))
	if args.has("no-glass"):
		glass_mi.visible = false
	if args.has("no-translucency"):
		starter_mat.set_shader_parameter(&"translucency", 0.0)
	if args.has("no-bubbles"):
		starter_mat.set_shader_parameter(&"bubbles_on", false)
	if args.has("refraction-off"):
		glass_front_b_mat.set_shader_parameter(&"refraction_on", false)
	if args.has("uniforms"):
		_print_uniforms()
		get_tree().quit()
		return
	if args.has("bench"):
		_run_bench()
	elif args.has("shots"):
		_run_shots()
	elif args.has("selftest"):
		var test := InputSelfTest.new()
		add_child(test)
		test.run(self)
	else:
		_build_debug_ui()


## Proves the CURRENT_RENDERER branch: the uniform list comes from the
## preprocessed shader for the running renderer.
func _print_uniforms() -> void:
	var names: PackedStringArray = PackedStringArray()
	for u: Dictionary in glass_front_b_mat.shader.get_shader_uniform_list():
		names.append(str(u["name"]))
	print("UNIFORMS glass_front_b on %s: %s" % [renderer, ", ".join(names)])


func _parse_args() -> void:
	for a: String in OS.get_cmdline_user_args():
		var clean: String = a.trim_prefix("--")
		var eq: int = clean.find("=")
		if eq >= 0:
			args[clean.substr(0, eq)] = clean.substr(eq + 1)
		else:
			args[clean] = "1"
	tier = args.get("tier", "a").to_lower()
	state_id = StringName(args.get("state", "at_peak"))
	msaa = int(args.get("msaa", "4"))
	if args.has("res"):
		var parts: PackedStringArray = args["res"].split("x")
		render_size = Vector2i(int(parts[0]), int(parts[1]))


func _print_env() -> void:
	print("ENV renderer=%s driver=%s adapter=%s vendor=%s api=%s os=%s godot=%s" % [
		renderer, RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version(),
		OS.get_name(), Engine.get_version_info()["string"]])
	print("ENV screen_scale=%.2f screen_dpi=%d touchscreen=%s" % [
		DisplayServer.screen_get_scale(), DisplayServer.screen_get_dpi(), str(DisplayServer.is_touchscreen_available())])


func _build_viewport() -> void:
	sub = SubViewport.new()
	sub.size = render_size
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.msaa_3d = _msaa_enum(msaa)
	sub.own_world_3d = true
	add_child(sub)
	var view := TextureRect.new()
	view.texture = sub.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)


func _msaa_enum(n: int) -> Viewport.MSAA:
	match n:
		2:
			return Viewport.MSAA_2X
		4:
			return Viewport.MSAA_4X
		8:
			return Viewport.MSAA_8X
		_:
			return Viewport.MSAA_DISABLED


func _build_world() -> void:
	world = Node3D.new()
	world.name = "World"
	sub.add_child(world)

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/backdrop_sky.gdshader") as Shader
	sky_mat.set_shader_parameter(&"horizon_color", HORIZON)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	_apply_tone_args(env)
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var key := DirectionalLight3D.new()
	key.transform = Transform3D(Basis.looking_at(-KEY_DIR.normalized(), Vector3.UP), KEY_DIR)
	key.light_color = Color(1.0, 0.94, 0.86)
	key.light_energy = 1.6 * float(args.get("key", "1.0"))
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 1.2
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.transform = Transform3D(Basis.looking_at(-RIM_DIR.normalized(), Vector3.UP), RIM_DIR)
	rim.light_color = Color(0.85, 0.9, 1.0)
	rim.light_energy = 0.5
	world.add_child(rim)

	var table := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.0, 4.0)
	table.mesh = plane
	var table_mat := ShaderMaterial.new()
	table_mat.shader = load("res://shaders/table.gdshader") as Shader
	table_mat.set_shader_parameter(&"far_color", HORIZON)
	table_mat.set_shader_parameter(&"jar_radius", builder.outer_radius)
	table.material_override = table_mat
	world.add_child(table)

	var cube: Cubemap = EnvCubemap.build(128)
	glass_back_mat = _glass_material("res://shaders/glass_back.gdshader", cube, -1)
	glass_front_a_mat = _glass_material("res://shaders/glass_front_a.gdshader", cube, 1)
	glass_front_b_mat = _glass_material("res://shaders/glass_front_b.gdshader", cube, 1)
	glass_mi = MeshInstance3D.new()
	glass_mi.name = "Jar_Glass"
	glass_mi.mesh = builder.build_glass()
	glass_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(glass_mi)

	starter_mat = ShaderMaterial.new()
	starter_mat.shader = load("res://shaders/starter.gdshader") as Shader
	liner_mat = ShaderMaterial.new()
	liner_mat.shader = load("res://shaders/streaks.gdshader") as Shader
	_set_starter_geometry(builder.bottom, builder.starter_radius(), builder.bottom + JarBuilder.FED_LEVEL)
	starter_mi = MeshInstance3D.new()
	starter_mi.name = "Starter_Body"
	starter_mi.mesh = builder.build_starter()
	starter_mi.material_override = starter_mat
	starter_mi.custom_aabb = builder.starter_max_aabb(DOME_HEIGHT)
	world.add_child(starter_mi)
	liner_mi = MeshInstance3D.new()
	liner_mi.name = "Starter_Liner"
	liner_mi.mesh = builder.build_liner()
	liner_mi.material_override = liner_mat
	world.add_child(liner_mi)

	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	orbit = OrbitCamera.new()
	orbit.name = "OrbitCamera"
	add_child(orbit)
	orbit.setup(cam)
	if args.has("no-own-touches"):
		orbit.own_touches_in_input = false
	if args.has("yaw-limit"):
		orbit.yaw_limit = deg_to_rad(float(args["yaw-limit"]))


func _glass_material(path: String, cube: Cubemap, priority: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path) as Shader
	m.render_priority = priority
	m.set_shader_parameter(&"env_cube", cube)
	m.set_shader_parameter(&"key_dir", KEY_DIR)
	m.set_shader_parameter(&"rim_dir", RIM_DIR)
	return m


## Tonemap overrides for the per-tier color check (art-direction.md §3):
## --tonemap=agx|filmic|linear --exposure=F --white=F --ambient=F --saturation=F
func _apply_tone_args(env: Environment) -> void:
	match args.get("tonemap", "agx"):
		"filmic":
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		"linear":
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		_:
			env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = float(args.get("exposure", "1.0"))
	if args.has("white"):
		env.tonemap_white = float(args["white"])
	if args.has("ambient"):
		env.ambient_light_energy = float(args["ambient"])
	if args.get("reflections", "") == "off":
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	if args.get("ambient-source", "") == "color":
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	if args.has("ambient-color"):
		var rgb: PackedStringArray = args["ambient-color"].split(",")
		env.ambient_light_color = Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
	if args.has("sky-contribution"):
		env.ambient_light_sky_contribution = float(args["sky-contribution"])
	if args.has("saturation"):
		env.adjustment_enabled = true
		env.adjustment_saturation = float(args["saturation"])
	print("TONE tonemap=%d exposure=%.2f white=%.2f ambient=%.2f adjustments=%s saturation=%.2f" % [
		env.tonemap_mode, env.tonemap_exposure, env.tonemap_white, env.ambient_light_energy,
		str(env.adjustment_enabled), env.adjustment_saturation])


## floor_y and authored_top are in the starter mesh's local space.
func _set_starter_geometry(floor_y: float, radius: float, authored_top: float) -> void:
	for m: ShaderMaterial in _starter_mats():
		m.set_shader_parameter(&"floor_y", floor_y)
		m.set_shader_parameter(&"inner_radius", radius)
		m.set_shader_parameter(&"dome_height", DOME_HEIGHT)
	starter_mat.set_shader_parameter(&"authored_top", authored_top)


func _starter_mats() -> Array[ShaderMaterial]:
	return [starter_mat, liner_mat]


func set_tier(t: String) -> void:
	tier = t
	glass_back_mat.next_pass = null
	if tier == "b":
		glass_mi.material_override = glass_front_b_mat
	else:
		glass_back_mat.next_pass = glass_front_a_mat
		glass_mi.material_override = glass_back_mat


func set_state(id: StringName) -> void:
	state_id = id
	params = StarterViewParams.for_state(id)
	params.apply(_starter_mats())
	_sync_sliders()


func set_time_override(t: float) -> void:
	starter_mat.set_shader_parameter(&"time_override", t)
	liner_mat.set_shader_parameter(&"time_override", t)


func _run_bench() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var bench := SpikeBenchmark.new()
	bench.viewport_rid = sub.get_viewport_rid()
	bench.orbit = orbit
	bench.seconds = float(args.get("seconds", "60"))
	bench.label = "%s_%s_tier%s_%dx%d_msaa%d%s" % [renderer, RenderingServer.get_current_rendering_driver_name(), tier.to_upper(),
		render_size.x, render_size.y, msaa, args.get("label-suffix", "")]
	bench.meta = {
		"renderer": renderer,
		"adapter": RenderingServer.get_video_adapter_name(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"tier": tier.to_upper(),
		"resolution": "%dx%d" % [render_size.x, render_size.y],
		"msaa": str(msaa),
	}
	add_child(bench)
	bench.finished.connect(_quit_soon)
	bench.start()


func _quit_soon() -> void:
	get_tree().quit()


func _run_shots() -> void:
	set_time_override(10.0)
	var dir: String = args.get("shot-dir", "res://screenshots")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var tiers: Array[String] = ["a"]
	if renderer == "mobile" or args.has("force-b"):
		tiers.append("b")
	var states: Array[StringName] = [&"freshly_fed", &"at_peak", &"collapsing", &"hungry"]
	var prefix: String = "compat" if renderer == "gl_compatibility" else renderer
	if args.has("glb"):
		prefix += "_artglb"
	for t: String in tiers:
		set_tier(t)
		for s: StringName in states:
			set_state(s)
			_pose(OrbitCamera.DEFAULT_YAW, OrbitCamera.DEFAULT_PITCH, OrbitCamera.DEFAULT_DISTANCE, 0.0)
			await _capture("%s/%s_tier%s_%s.png" % [dir, prefix, t.to_upper(), s])
	# Extra views on Tier A: top-down surface check, side close-up, frame shift.
	set_tier("a")
	set_state(&"at_peak")
	_pose(0.35, 1.05, 0.30, 0.0)
	await _capture("%s/%s_tierA_at_peak_surface_view.png" % [dir, prefix])
	_pose(0.35, 0.12, 0.17, 0.0)
	await _capture("%s/%s_tierA_at_peak_side_closeup.png" % [dir, prefix])
	set_state(&"collapsing")
	_pose(OrbitCamera.DEFAULT_YAW, OrbitCamera.DEFAULT_PITCH, OrbitCamera.DEFAULT_DISTANCE, 0.18)
	await _capture("%s/%s_tierA_collapsing_frame_shift.png" % [dir, prefix])
	# custom_aabb check: frame only the risen top, looking slightly up, so the
	# authored mesh box (the fed level) is outside the frustum.
	set_state(&"at_peak")
	orbit.target = Vector3(0.0, 0.105, 0.0)
	_pose(0.35, -0.08, 0.10, 0.0)
	await _capture("%s/%s_aabb_with_custom_aabb.png" % [dir, prefix])
	_report_aabb("custom_aabb (rise 3 + dome)")
	var keep: AABB = starter_mi.custom_aabb
	starter_mi.custom_aabb = starter_mi.mesh.get_aabb()
	await _capture("%s/%s_aabb_without_custom_aabb.png" % [dir, prefix])
	_report_aabb("mesh AABB only (authored at the fed level)")
	starter_mi.custom_aabb = AABB(Vector3(-0.04, -1.0, -0.04), Vector3(0.08, 0.01, 0.08))
	await _capture("%s/%s_aabb_wrong_box_below_table.png" % [dir, prefix])
	_report_aabb("deliberately wrong box 1 m below the table")
	starter_mi.custom_aabb = keep
	get_tree().quit()


func _report_aabb(label: String) -> void:
	var box: AABB = starter_mi.mesh.get_aabb()
	var inside: int = 0
	for i: int in range(8):
		if orbit.camera.is_position_in_frustum(starter_mi.global_transform * box.get_endpoint(i)):
			inside += 1
	var objects: int = RenderingServer.viewport_get_render_info(sub.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
	print("AABB %s: mesh box corners in frustum=%d/8, objects_in_frame=%d, custom_aabb=%s" % [
		label, inside, objects, str(starter_mi.custom_aabb)])


func _pose(yaw: float, pitch: float, dist: float, shift: float) -> void:
	orbit.yaw = yaw
	orbit.pitch = pitch
	orbit.distance = dist
	orbit.yaw_velocity = 0.0
	orbit.pitch_velocity = 0.0
	orbit.set_frame_shift(shift, false)


func _capture(path: String) -> void:
	if args.has("only") and not path.contains(args["only"]):
		return
	for i: int in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = sub.get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	var err: Error = img.save_png(ProjectSettings.globalize_path(path))
	print("SHOT %s err=%d" % [ProjectSettings.globalize_path(path), err])


## Swap in art-director's GLB, following the jar_v0 contract.
func _swap_in_art(path: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("Could not load %s" % path)
		return
	var art: Node3D = packed.instantiate() as Node3D
	world.add_child(art)
	art.visible = false
	var art_glass: MeshInstance3D = art.find_child("Jar_Glass", true, false) as MeshInstance3D
	var art_starter: MeshInstance3D = art.find_child("Starter_Body", true, false) as MeshInstance3D
	var art_liner: MeshInstance3D = art.find_child("Starter_Liner", true, false) as MeshInstance3D
	var floor_node: Node3D = art.find_child("StarterFloor", true, false) as Node3D
	var rim_node: Node3D = art.find_child("StarterRim", true, false) as Node3D
	print("ART glass=%s starter=%s liner=%s floor=%s rim=%s" % [art_glass != null, art_starter != null,
		art_liner != null, floor_node != null, rim_node != null])
	if art_glass != null:
		glass_mi.mesh = art_glass.mesh
		glass_mi.transform = art_glass.global_transform
	if art_starter != null and floor_node != null and rim_node != null:
		var floor_y: float = floor_node.global_position.y
		var radius: float = rim_node.global_position.x - JarBuilder.STARTER_GAP
		var extras: Dictionary = art_starter.get_meta("extras", {}) as Dictionary
		var authored: float = float(extras.get("starter_authored_height_m", JarBuilder.FED_LEVEL))
		starter_mi.mesh = art_starter.mesh
		starter_mi.transform = art_starter.global_transform
		var local_floor: float = floor_y - art_starter.global_position.y
		_set_starter_geometry(local_floor, radius, local_floor + authored)
		var aabb: AABB = builder.starter_max_aabb(DOME_HEIGHT)
		aabb.position.y -= art_starter.global_position.y
		starter_mi.custom_aabb = aabb
		if art_liner != null:
			liner_mi.mesh = art_liner.mesh
			liner_mi.transform = art_liner.global_transform
			liner_mat.set_shader_parameter(&"floor_y", floor_y - art_liner.global_position.y)
	set_tier(tier)


func _build_debug_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.position = Vector2(6, 6)
	ui_layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	info_label = Label.new()
	box.add_child(info_label)
	var states := HFlowContainer.new()
	states.custom_minimum_size = Vector2(360, 0)
	box.add_child(states)
	for s: StringName in StarterViewParams.STATES:
		var b := Button.new()
		b.text = String(s)
		b.pressed.connect(set_state.bind(s))
		states.add_child(b)
	var tiers := HBoxContainer.new()
	box.add_child(tiers)
	for t: String in ["a", "b"]:
		var tb := Button.new()
		tb.text = "tier_" + t
		tb.pressed.connect(set_tier.bind(t))
		tiers.add_child(tb)
	var ranges: Dictionary[StringName, Vector2] = {
		&"rise": Vector2(1.0, 3.0), &"dome": Vector2(-1.0, 1.0), &"activity": Vector2(0.0, 1.0),
		&"bubble_density": Vector2(0.0, 1.0), &"hooch_depth": Vector2(0.0, 1.0), &"peak_line": Vector2(0.0, 3.0),
	}
	for u: StringName in ranges:
		var row := HBoxContainer.new()
		box.add_child(row)
		var l := Label.new()
		l.text = String(u)
		l.custom_minimum_size = Vector2(120, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = ranges[u].x
		sl.max_value = ranges[u].y
		sl.step = 0.01
		sl.custom_minimum_size = Vector2(220, 0)
		sl.value_changed.connect(_on_slider.bind(u))
		row.add_child(sl)
		sliders[u] = sl
	_sync_sliders()


func _on_slider(value: float, u: StringName) -> void:
	params.set_value(u, value)
	params.apply(_starter_mats())


func _sync_sliders() -> void:
	for u: StringName in sliders:
		sliders[u].set_value_no_signal(params.get_value(u))


func _process(_delta: float) -> void:
	if info_label != null:
		info_label.text = "%s  tier %s  %s  %d fps" % [renderer, tier.to_upper(), state_id, Engine.get_frames_per_second()]

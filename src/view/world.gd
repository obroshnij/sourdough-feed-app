class_name WorldView
extends Node3D
## The 3D world (architecture.md §3.2): environment, lights, camera rig and the jar.
## Shows Session's VisualParams and talks to the UI only through Bus (architecture.md §1).
## Lighting per art-direction.md §3: a warm key from 60 degrees left of front, 50 degrees up, a warm rim
## from behind-right, ambient from the kitchen sky. Both are directional lights without shadow
## maps on both renderers (see ViewLook.key_shadow); the counter shader draws the drop shadow.

const KEY_DIR: Vector3 = Vector3(-0.557, 0.766, 0.321)
## Night (art-direction.md §18.6): the drop shadow points toward the under-cabinet lamp.
const NIGHT_SHADOW_DIR: Vector3 = Vector3(-0.23, 0.77, -0.59)
const RIM_DIR: Vector3 = Vector3(0.7, 0.3, -0.65)
const SKY_SHADER: String = "res://src/view/shaders/kitchen_sky.gdshader"
## How much of the screen each sheet covers from the bottom (ux-design.md §3).
const SHEET_COVER: Dictionary[StringName, float] = {
	&"feed": 0.60, &"inspect": 0.42, &"environment": 0.45, &"smell": 0.0,
}

## Off for the dev scrubber, which drives the jar directly.
@export var follow_session: bool = true

@onready var jar: JarView = $Jar
@onready var rig: OrbitCamera = $CameraRig
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var key_light: DirectionalLight3D = $KeyLight
@onready var rim_light: DirectionalLight3D = $RimLight
@onready var night_lamp: OmniLight3D = $NightLamp

var renderer: String = ""
var look: ViewLook
var tier: QualityTier.Tier = QualityTier.Tier.A
var reduce_effects: bool = false
var reduce_motion: bool = false
## Live easing toward Session's VisualParams, and the feed sequence on top of it.
var easer := VisualEaser.new()
var feed := FeedMoment.new()
var wisps: SmellWisps
var dust: CPUParticles3D
var _band_from: float = -1.0
var _lid_tween: Tween
## Shared night factor (D-043), 0 day to 1 night. Lights, wall and sky follow it.
var night: float = 0.0
var time_lapse: TimeLapsePlayer
var _night_poll: float = 0.0
var _sky_mat: ShaderMaterial
var audio: JarAudio
var _smelling: bool = false
var _sheets_open: int = 0


func _ready() -> void:
	renderer = RenderingServer.get_current_rendering_method()
	look = ViewLook.for_renderer(renderer)
	jar.bind($Jar/Model as Node3D)
	jar.bind_wall($Wall as Node3D)
	_place_lights()
	apply_look(look)
	set_reduce_effects(false)
	rig.tapped.connect(_on_tapped)
	_make_vfx()
	audio = JarAudio.new()
	audio.name = "Audio"
	add_child(audio)
	jar.pops.popped.connect(audio.play_pop)
	jar.lid_moved.connect(_on_lid_moved)
	var bus: Node = get_node_or_null(^"/root/Bus")
	if bus != null:
		bus.connect(&"sheet_opened", _on_sheet_opened)
		bus.connect(&"sheet_closed", _on_sheet_closed)
		bus.connect(&"camera_focus_requested", rig.focus)
		bus.connect(&"camera_focus_released", rig.release_focus)
		bus.connect(&"jar_region_changed", _on_jar_region_changed)
		bus.connect(&"settings_changed", _read_settings)
		bus.connect(&"feed_moment", _on_feed_moment)
		bus.connect(&"feedback", audio.on_feedback)
		bus.connect(&"event_presented", audio.on_event)
		bus.connect(&"starter_tapped", _on_starter_tapped)
		bus.connect(&"smell_moment_started", _on_smell_started)
		bus.connect(&"smell_moment_finished", _on_smell_finished)
		if bus.has_signal(&"time_lapse_skip_requested"):
			bus.connect(&"time_lapse_skip_requested", skip_time_lapse)
	if follow_session:
		var session: GameSession = get_node_or_null(^"/root/Session") as GameSession
		if session != null:
			session.state_changed.connect(_on_state_changed)
			session.session_ready.connect(_on_session_ready)
			session.resumed.connect(_on_resumed)
			if session.is_booted():
				_on_session_ready(null)


func _place_lights() -> void:
	key_light.transform = Transform3D(Basis.looking_at(-KEY_DIR.normalized(), Vector3.UP), KEY_DIR)
	key_light.directional_shadow_max_distance = 1.5
	rim_light.transform = Transform3D(Basis.looking_at(-RIM_DIR.normalized(), Vector3.UP), RIM_DIR)
	rim_light.shadow_enabled = false


func apply_look(p_look: ViewLook) -> void:
	look = p_look
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load(SKY_SHADER) as Shader
	world_env.environment = look.make_environment(_sky_mat)
	key_light.light_energy = look.key_energy
	key_light.light_color = look.key_color
	key_light.shadow_blur = look.shadow_blur
	key_light.shadow_enabled = look.key_shadow > 0.5
	key_light.directional_shadow_mode = look.key_shadow_mode as DirectionalLight3D.ShadowMode
	rim_light.light_energy = look.rim_energy
	rim_light.light_color = look.rim_color
	jar.apply_look(look, KEY_DIR.normalized(), RIM_DIR.normalized())
	set_night(night)


## Day to night on one factor (art-direction.md §18.6). The darkness comes from the lights, never
## the exposure: key to 15%, rim to 35%, sky to 30% with the window off, glass reflection to 50%,
## the lamp on, and the drop shadow turned toward the lamp. The jar stays lit.
func set_night(n: float) -> void:
	night = clampf(n, 0.0, 1.0)
	# Art's night ruling: the key stays front-left at 45% and warms to #FFE6CC, so the camera-facing
	# paste is lit from the front; the lamp behind the jar only adds the warm pool and the cap glow.
	key_light.light_energy = look.key_energy * lerpf(1.0, look.night_key, night)
	key_light.light_color = look.key_color.lerp(look.night_key_color, night)
	rim_light.light_energy = look.rim_energy * lerpf(1.0, 0.35, night)
	night_lamp.visible = night > 0.001
	night_lamp.light_energy = look.lamp_energy * night
	night_lamp.light_color = look.lamp_color
	if _sky_mat != null:
		_sky_mat.set_shader_parameter(&"energy", look.sky_energy * lerpf(1.0, look.night_sky, night))
		_sky_mat.set_shader_parameter(&"window_energy", 0.6 * (1.0 - night))
	if jar.quality != null:
		jar.quality.set_shared(&"reflection_strength", look.glass_reflection * lerpf(1.0, 0.5, night))
	if jar.counter_mat != null:
		jar.counter_mat.set_shader_parameter(&"grade_value", look.dressing_value * lerpf(1.0, look.night_counter, night))
		jar.counter_mat.set_shader_parameter(&"key_dir", KEY_DIR.normalized().lerp(NIGHT_SHADOW_DIR.normalized(), night).normalized())
	jar.set_wall_night(night)
	if audio != null:
		audio.night = night
	# Under the warm lamp the tonemapper lifts the cream's saturation in the darker range (N1, §18.6).
	for m: ShaderMaterial in jar.starter_materials():
		if m != null:
			m.set_shader_parameter(&"grade_saturation", look.starter_saturation * (1.0 - look.night_desat * night))
	# Night pockets stay cream cavities, not a dark sponge (N7): less cavity contrast at night.
	if jar.starter_mat != null:
		jar.starter_mat.set_shader_parameter(&"pocket_k", look.pocket_k * lerpf(1.0, look.night_pocket, night))
		jar.starter_mat.set_shader_parameter(&"pocket_tilt", look.pocket_tilt * lerpf(1.0, look.night_pocket, night))


func set_reduce_effects(on: bool) -> void:
	reduce_effects = on
	set_tier(QualityTier.choose(renderer, on))


func set_tier(t: QualityTier.Tier) -> void:
	tier = t
	jar.set_tier(t)


func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	if audio != null:
		audio.reduce_motion = on
	rig.reduce_motion = on
	jar.set_motion(not on)


## Shows a VisualParams at once (first show, scrubber, captures), with no easing.
func set_visuals(p: VisualParams) -> void:
	easer.set_goal(p)
	easer.snap()
	_show(easer.shown)


## Eases toward a VisualParams (art-direction.md §8). During a feed, the fed fields snap instead.
func follow_visuals(p: VisualParams) -> void:
	easer.set_goal(p)
	if feed.active():
		# The fed fields jump; the band snap and the lid wait for T1's settle beat (or the timeout).
		if _band_from < 0.0:
			_band_from = easer.shown.level_m
		easer.snap_fields([&"level_m", &"rise", &"lumps", &"peak_line", &"streak_amount", &"hooch_depth"])


func _process(delta: float) -> void:
	audio.pops_muted = _sheets_open > 0 or feed.active() or _smelling or time_lapse != null
	if time_lapse != null:
		_play_time_lapse(delta)
		return
	_poll_night(delta)
	var was_active: bool = feed.active()
	feed.step(delta)
	if feed.dust and dust != null and not reduce_effects:
		dust.restart()
	if easer.is_settled() and not feed.active() and not was_active:
		return
	_show(easer.step(delta))


func _show(p: VisualParams) -> void:
	var shown: VisualParams = p
	var band_level: float = -1.0
	if feed.active():
		shown = p.copy()
		shown.rise = p.rise * feed.rise_mul
		shown.lumps = clampf(p.lumps + feed.lumps_add, 0.0, 1.0)
		if _band_from >= 0.0:
			band_level = lerpf(_band_from, p.level_m, feed.band_t)
		jar.set_lid_lift(feed.lid)
	else:
		_band_from = -1.0
	jar.apply_visuals(shown, band_level)
	_set_starter_for_camera(shown)


func _set_starter_for_camera(p: VisualParams) -> void:
	rig.starter_level_m = p.level_m
	rig.starter_mid_y = jar.floor_y + 0.55 * p.level_m * p.rise
	rig.starter_top_y = jar.floor_y + JarGeometry.surface_top_m(p.level_m, p.rise, p.dome)


## Reduce effects swaps the glass tier, reduce motion stops camera inertia. Read at session_ready
## (no signal fires at launch) and on every Bus.settings_changed.
func _read_settings() -> void:
	var session: GameSession = get_node_or_null(^"/root/Session") as GameSession
	if session == null:
		return
	var settings: SettingsStore = session.get_settings()
	if settings != null:
		set_reduce_effects(settings.reduce_effects)
		set_reduce_motion(settings.reduce_motion)
		audio.apply_settings(settings.sound, settings.master_volume)


func _on_session_ready(summary: CatchUpResult) -> void:
	_read_settings()
	var session: GameSession = get_node(^"/root/Session") as GameSession
	var v: VisualParams = session.get_visuals()
	if v != null:
		set_visuals(v)
	set_night(session.get_night_factor())
	audio.room_fade(true, 2.0)
	start_time_lapse(summary)


func _on_resumed(summary: CatchUpResult) -> void:
	audio.room_fade(true, 1.5)
	start_time_lapse(summary)


## Plays the catch-up time-lapse if the sim asks for one (CatchUpResult.play_time_lapse).
## 3D input is off while it plays; Bus.time_lapse_started and time_lapse_finished bracket it.
func start_time_lapse(summary: CatchUpResult) -> bool:
	if not TimeLapsePlayer.can_play(summary):
		return false
	time_lapse = TimeLapsePlayer.new(summary.keyframes, summary.time_lapse_duration_s(), reduce_motion)
	rig.set_input_enabled(false)
	_bus_emit(&"time_lapse_started")
	_play_time_lapse(0.0)
	return true


## Skip (T3's SkipPill or a tap): jump to the end, which restores the live visuals and night and
## emits time_lapse_finished.
func skip_time_lapse() -> void:
	if time_lapse != null:
		time_lapse.t = time_lapse.duration


func _play_time_lapse(delta: float) -> void:
	time_lapse.advance(delta)
	var session: GameSession = get_node_or_null(^"/root/Session") as GameSession
	var offset: int = session.local_utc_offset_s() if session != null else 0
	set_night(NightFade.at_unix(time_lapse.unix_now(), offset))
	jar.apply_visuals(time_lapse.sample())
	if time_lapse.done():
		time_lapse = null
		if session != null and session.get_visuals() != null:
			set_visuals(session.get_visuals())
			set_night(session.get_night_factor())
		rig.set_input_enabled(true)
		_bus_emit(&"time_lapse_finished")


func _poll_night(delta: float) -> void:
	_night_poll -= delta
	if _night_poll > 0.0 or not follow_session:
		return
	_night_poll = 1.0
	var session: GameSession = get_node_or_null(^"/root/Session") as GameSession
	if session != null and session.is_booted():
		var n: float = session.get_night_factor()
		if absf(n - night) > 0.001:
			set_night(n)


func _bus_emit(sig: StringName) -> void:
	var bus: Node = get_node_or_null(^"/root/Bus")
	if bus != null and bus.has_signal(sig):
		bus.emit_signal(sig)


func _on_state_changed(_snapshot: StarterSnapshot, visuals: VisualParams) -> void:
	follow_visuals(visuals)


func _on_feed_moment(step: StringName) -> void:
	if not feed.active():
		_band_from = easer.shown.level_m
	feed.begin(step)
	audio.on_feed(step)


## The smell moment: lid up, wisps tinted by what the sim smells like, a small camera dolly.
func _on_smell_started() -> void:
	_smelling = true
	audio.on_smell(true)
	_tween_lid(1.0)
	rig.nudge(true)
	var session: GameSession = get_node_or_null(^"/root/Session") as GameSession
	if session == null or reduce_motion or session.get_starter() == null:
		return
	var smell: SmellReadout = SmellModel.read(session.get_starter(), session.get_environment())
	wisps.start(smell.primary)


func _on_smell_finished() -> void:
	_smelling = false
	audio.on_smell(false)
	wisps.stop()
	rig.nudge(false)
	_tween_lid(0.0)


func _tween_lid(to: float) -> void:
	if _lid_tween != null:
		_lid_tween.kill()
	var from: float = (jar.covers[&"loose_lid"].position.y - jar.lid_rest_y) / 0.008 if jar.covers.has(&"loose_lid") else 0.0
	_lid_tween = create_tween()
	_lid_tween.tween_method(jar.set_lid_lift, from, to, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _make_vfx() -> void:
	var vfx: Node3D = get_node_or_null(^"Vfx") as Node3D
	if vfx == null:
		vfx = self
	wisps = SmellWisps.new()
	wisps.name = "SmellWisps"
	wisps.position = Vector3(0.0, JarGeometry.HEIGHT_M + 0.012, 0.0)
	vfx.add_child(wisps)
	# Flour dust on the pour (art-direction.md §9): 30 beige flecks, 2 to 4 mm, falling and fading in 1.2 s.
	dust = CPUParticles3D.new()
	dust.name = "FlourDust"
	dust.position = Vector3(0.0, JarGeometry.HEIGHT_M + 0.03, 0.0)
	dust.emitting = false
	dust.one_shot = true
	dust.amount = 30
	dust.lifetime = 1.2
	dust.explosiveness = 0.7
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 0.015
	dust.direction = Vector3(0.0, -1.0, 0.0)
	dust.spread = 25.0
	dust.initial_velocity_min = 0.02
	dust.initial_velocity_max = 0.06
	dust.gravity = Vector3(0.0, -0.25, 0.0)
	dust.scale_amount_min = 0.002
	dust.scale_amount_max = 0.004
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.render_priority = 2
	quad.material = m
	dust.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.91, 0.86, 0.77, 0.9))
	ramp.set_color(1, Color(0.91, 0.86, 0.77, 0.0))
	dust.color_ramp = ramp
	vfx.add_child(dust)


func _on_starter_tapped(where: StringName) -> void:
	audio.play("glass_tink" if where == &"glass" else "starter_poke")


var _last_lid: float = 0.0


## Lid sounds: lid_lift as it starts rising, lid_set once it is back within 5% of rest (§3).
func _on_lid_moved(k: float) -> void:
	if _last_lid <= 0.001 and k > 0.001:
		audio.play("lid_lift")
	elif _last_lid >= 0.05 and k < 0.05:
		audio.play("lid_set")
	_last_lid = k


func _on_sheet_opened(sheet_id: StringName) -> void:
	_sheets_open += 1
	audio.on_sheet(true)
	rig.set_input_enabled(false)
	rig.set_sheet_cover(SHEET_COVER.get(sheet_id, 0.5))


func _on_sheet_closed(_sheet_id: StringName) -> void:
	_sheets_open = maxi(_sheets_open - 1, 0)
	audio.on_sheet(false)
	rig.set_input_enabled(true)
	rig.set_sheet_cover(0.0)


func _on_jar_region_changed(region: Rect2) -> void:
	var screen_h_pt: float = float(DisplayServer.window_get_size().y) / maxf(DisplayServer.screen_get_scale(), 0.01)
	rig.set_jar_region(region, screen_h_pt)


## A tap on the jar: starter or glass, by intersecting the tap ray with the two cylinders.
func _on_tapped(screen_pos: Vector2) -> void:
	var cam: Camera3D = rig.camera
	var origin: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var where: StringName = hit_test(origin, dir)
	if where == &"":
		return
	var bus: Node = get_node_or_null(^"/root/Bus")
	if bus != null:
		bus.emit_signal(&"starter_tapped", where)


## &"starter", &"glass" or &"" for a world-space ray. No physics: analytic cylinders.
func hit_test(origin: Vector3, dir: Vector3) -> StringName:
	var top: float = jar.floor_y + JarGeometry.surface_top_m(jar.visuals.level_m, jar.visuals.rise, jar.visuals.dome)
	var t_starter: float = _ray_cylinder(origin, dir, JarGeometry.STARTER_RADIUS_M, jar.floor_y, top)
	var t_glass: float = _ray_cylinder(origin, dir, JarGeometry.OUTER_RADIUS_M, 0.0, JarGeometry.HEIGHT_M)
	if t_glass < 0.0:
		return &""
	return &"starter" if t_starter >= 0.0 else &"glass"


## Distance to the first hit on a vertical cylinder around the y axis (side or caps), or -1.
static func _ray_cylinder(o: Vector3, d: Vector3, r: float, y0: float, y1: float) -> float:
	var best: float = -1.0
	var a: float = d.x * d.x + d.z * d.z
	if a > 1e-9:
		var b: float = 2.0 * (o.x * d.x + o.z * d.z)
		var c: float = o.x * o.x + o.z * o.z - r * r
		var disc: float = b * b - 4.0 * a * c
		if disc >= 0.0:
			var t: float = (-b - sqrt(disc)) / (2.0 * a)
			var y: float = o.y + d.y * t
			if t > 0.0 and y >= y0 and y <= y1:
				best = t
	if absf(d.y) > 1e-9:
		for cap_y: float in [y0, y1]:
			var t: float = (cap_y - o.y) / d.y
			var p: Vector3 = o + d * t
			if t > 0.0 and p.x * p.x + p.z * p.z <= r * r and (best < 0.0 or t < best):
				best = t
	return best

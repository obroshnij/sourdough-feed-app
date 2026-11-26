class_name WorldView
extends Node3D
## The 3D world (architecture.md §3.2): environment, lights, camera rig and the jar.
## Shows Session's VisualParams and talks to the UI only through Bus (architecture.md §1).
## Lighting per art-direction.md §3: a warm key from 60 degrees left of front, 50 degrees up, a warm rim
## from behind-right, ambient from the kitchen sky. Both are directional lights without shadow
## maps on both renderers (see ViewLook.key_shadow); the counter shader draws the drop shadow.

const KEY_DIR: Vector3 = Vector3(-0.557, 0.766, 0.321)
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

var renderer: String = ""
var look: ViewLook
var tier: QualityTier.Tier = QualityTier.Tier.A
var reduce_effects: bool = false


func _ready() -> void:
	renderer = RenderingServer.get_current_rendering_method()
	look = ViewLook.for_renderer(renderer)
	jar.bind($Jar/Model as Node3D)
	_place_lights()
	apply_look(look)
	set_reduce_effects(false)
	rig.tapped.connect(_on_tapped)
	var bus: Node = get_node_or_null(^"/root/Bus")
	if bus != null:
		bus.connect(&"sheet_opened", _on_sheet_opened)
		bus.connect(&"sheet_closed", _on_sheet_closed)
		bus.connect(&"camera_focus_requested", rig.focus)
		bus.connect(&"camera_focus_released", rig.release_focus)
		bus.connect(&"jar_region_changed", _on_jar_region_changed)
		bus.connect(&"settings_changed", _read_settings)
	if follow_session:
		var session: GameSession = get_node_or_null(^"/root/Session") as GameSession
		if session != null:
			session.state_changed.connect(_on_state_changed)
			session.session_ready.connect(_on_session_ready)
			if session.is_booted():
				_on_session_ready(null)


func _place_lights() -> void:
	key_light.transform = Transform3D(Basis.looking_at(-KEY_DIR.normalized(), Vector3.UP), KEY_DIR)
	key_light.directional_shadow_max_distance = 1.5
	rim_light.transform = Transform3D(Basis.looking_at(-RIM_DIR.normalized(), Vector3.UP), RIM_DIR)
	rim_light.shadow_enabled = false


func apply_look(p_look: ViewLook) -> void:
	look = p_look
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SKY_SHADER) as Shader
	world_env.environment = look.make_environment(sky_mat)
	key_light.light_energy = look.key_energy
	key_light.light_color = look.key_color
	key_light.shadow_blur = look.shadow_blur
	key_light.shadow_enabled = look.key_shadow > 0.5
	key_light.directional_shadow_mode = look.key_shadow_mode as DirectionalLight3D.ShadowMode
	rim_light.light_energy = look.rim_energy
	rim_light.light_color = look.rim_color
	jar.apply_look(look, KEY_DIR.normalized(), RIM_DIR.normalized())


func set_reduce_effects(on: bool) -> void:
	reduce_effects = on
	set_tier(QualityTier.choose(renderer, on))


func set_tier(t: QualityTier.Tier) -> void:
	tier = t
	jar.set_tier(t)


func set_reduce_motion(on: bool) -> void:
	rig.reduce_motion = on


## Shows a VisualParams and tells the camera where the starter is, for the focus presets.
func set_visuals(p: VisualParams) -> void:
	jar.apply_visuals(p)
	rig.starter_level_m = p.level_m
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


func _on_session_ready(_summary: CatchUpResult) -> void:
	_read_settings()
	var session: GameSession = get_node(^"/root/Session") as GameSession
	var v: VisualParams = session.get_visuals()
	if v != null:
		set_visuals(v)


func _on_state_changed(_snapshot: StarterSnapshot, visuals: VisualParams) -> void:
	set_visuals(visuals)


func _on_sheet_opened(sheet_id: StringName) -> void:
	rig.set_input_enabled(false)
	rig.set_sheet_cover(SHEET_COVER.get(sheet_id, 0.5))


func _on_sheet_closed(_sheet_id: StringName) -> void:
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

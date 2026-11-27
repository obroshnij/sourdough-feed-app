class_name BubblePops
extends MultiMeshInstance3D
## Bubble pops on the starter's top (art-direction.md §8): a pit that opens into a ring and fades in
## LIFE_S. Everything comes from VisualParams: the rate from activity and bubble_density, the size from
## bubble_size, the height from the surface shape. Spots come from an integer hash of the pop's serial
## number, never from a random call, so the same params and time give the same pops (hard rule 2).
## None under hooch, none at mold. Opaque (alpha scissor), so it never sorts against the glass (D-009).
## Child of the Jar: positions are in jar space (floor at JarGeometry.FLOOR_Y_M).

const MAX_POPS: int = 8
const LIFE_S: float = 0.25
const RATE_PER_ACTIVITY: float = 0.4
const SIZE_MIN_M: float = 0.0006
const SIZE_MAX_M: float = 0.0022
const SHADER: String = "res://src/view/shaders/pop_ring.gdshader"

var params: VisualParams = VisualParams.new()
var motion_on: bool = true
var floor_y: float = JarGeometry.FLOOR_Y_M
var serial: int = 0
var _acc: float = 0.0
var _serials: PackedInt32Array = PackedInt32Array()
var _ages: PackedFloat32Array = PackedFloat32Array()
var _mat: ShaderMaterial


func _ready() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER) as Shader
	mesh.material = _mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.instance_count = MAX_POPS
	multimesh.mesh = mesh
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-0.04, 0.0, -0.04), Vector3(0.08, 0.15, 0.08))


func set_params(p: VisualParams) -> void:
	params = p
	if _mat != null:
		_mat.set_shader_parameter(&"tint", Color(p.tint.r, p.tint.g, p.tint.b))


## Pops per second for a VisualParams. 0 under hooch, at mold, or when the starter is still.
static func pop_rate(p: VisualParams) -> float:
	if p.mold > 0.0 or p.hooch_depth > 0.15 or p.activity <= 0.0:
		return 0.0
	return p.activity * RATE_PER_ACTIVITY * (0.3 + 0.7 * clampf(p.bubble_density, 0.0, 1.0))


## Where and how big pop `n` is: (radius fraction 0..0.85, angle, size 0..1). Integer hash, no RNG.
static func pop_spot(n: int) -> Vector3:
	var h1: int = _hash(n * 3 + 1)
	var h2: int = _hash(n * 3 + 2)
	var h3: int = _hash(n * 3 + 3)
	var u1: float = float(h1 & 0xFFFF) / 65535.0
	var u2: float = float(h2 & 0xFFFF) / 65535.0
	var u3: float = float(h3 & 0xFFFF) / 65535.0
	return Vector3(0.85 * sqrt(u1), TAU * u2, u3)


## Height of the top surface above the jar origin at radius fraction r (mirrors cap_height, no lumps).
static func surface_y(p: VisualParams, r: float, floor_y: float) -> float:
	var flat: float = smoothstep(0.0, 0.15, p.hooch_depth)
	return floor_y + p.level_m * p.rise + (1.0 - r * r) * p.dome * JarGeometry.DOME_MAX_M * (1.0 - flat)


static func pop_radius_m(p: VisualParams, size_u: float) -> float:
	return lerpf(SIZE_MIN_M, SIZE_MAX_M, clampf(p.bubble_size, 0.0, 1.0)) * (0.7 + 0.6 * size_u)


static func _hash(x: int) -> int:
	var h: int = (x * 747796405 + 2891336453) & 0xFFFFFFFF
	h = ((h >> ((h >> 28) + 4)) ^ h) * 277803737 & 0xFFFFFFFF
	return ((h >> 22) ^ h) & 0xFFFFFFFF


func _process(delta: float) -> void:
	advance(delta)


## Moves time on by dt: spawns due pops, ages the live ones, updates the MultiMesh.
func advance(dt: float) -> void:
	if multimesh == null:
		return
	if motion_on:
		_acc += pop_rate(params) * dt
		while _acc >= 1.0:
			_acc -= 1.0
			_spawn()
	var i: int = 0
	while i < _ages.size():
		_ages[i] += dt
		if _ages[i] >= LIFE_S:
			_ages.remove_at(i)
			_serials.remove_at(i)
		else:
			i += 1
	_write()


func live_count() -> int:
	return _ages.size()


func _spawn() -> void:
	if _ages.size() >= MAX_POPS:
		_ages.remove_at(0)
		_serials.remove_at(0)
	_serials.append(serial)
	_ages.append(0.0)
	serial += 1


func _write() -> void:
	multimesh.visible_instance_count = _ages.size()
	for i: int in _ages.size():
		var spot: Vector3 = pop_spot(_serials[i])
		var r_m: float = spot.x * JarGeometry.STARTER_RADIUS_M
		var pos := Vector3(cos(spot.y) * r_m, surface_y(params, spot.x, floor_y) + 0.0003, sin(spot.y) * r_m)
		var s: float = pop_radius_m(params, spot.z)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, 1.0, s)), pos))
		multimesh.set_instance_custom_data(i, Color(_ages[i] / LIFE_S, 0.0, 0.0, 0.0))

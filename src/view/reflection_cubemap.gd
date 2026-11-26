class_name ReflectionCubemap
extends RefCounted
## The small kitchen cubemap the glass reflects (art-direction.md §3, lifted from the spike):
## a warm room with a tall window softbox (the key), a thin rim strip and a ceiling panel.
## HDR values, so highlights survive tonemapping. Built once per run and cached.

const KEY_BOX: Vector3 = Vector3(-0.6, 0.12, 0.8)
const RIM_BOX: Vector3 = Vector3(0.78, 0.05, -0.62)
const FILL_BOX: Vector3 = Vector3(0.85, 0.1, 0.5)
const SIZE_PX: int = 64

static var _cached: Cubemap


static func get_shared() -> Cubemap:
	if _cached == null:
		_cached = build(SIZE_PX)
	return _cached


static func build(size: int) -> Cubemap:
	var images: Array[Image] = []
	for face: int in range(6):
		var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBAH)
		for y: int in range(size):
			for x: int in range(size):
				var u: float = 2.0 * (float(x) + 0.5) / float(size) - 1.0
				var v: float = 2.0 * (float(y) + 0.5) / float(size) - 1.0
				img.set_pixel(x, y, env_color(face_dir(face, u, v)))
		img.generate_mipmaps()
		images.append(img)
	var cube := Cubemap.new()
	var err: Error = cube.create_from_images(images)
	if err != OK:
		push_error("ReflectionCubemap: create_from_images failed: %d" % err)
	return cube


## Standard cubemap face order and orientation (+X, -X, +Y, -Y, +Z, -Z).
static func face_dir(face: int, u: float, v: float) -> Vector3:
	match face:
		0:
			return Vector3(1.0, -v, -u).normalized()
		1:
			return Vector3(-1.0, -v, u).normalized()
		2:
			return Vector3(u, 1.0, v).normalized()
		3:
			return Vector3(u, -1.0, -v).normalized()
		4:
			return Vector3(u, -v, 1.0).normalized()
		_:
			return Vector3(-u, -v, -1.0).normalized()


static func env_color(d: Vector3) -> Color:
	var floor_c := Vector3(0.22, 0.20, 0.17)
	var wall_c := Vector3(0.50, 0.52, 0.46)
	var ceil_c := Vector3(0.70, 0.67, 0.62)
	var c: Vector3 = wall_c.lerp(ceil_c, smoothstep(0.1, 0.9, d.y))
	c = c.lerp(floor_c, smoothstep(0.0, -0.3, d.y))
	c += Vector3(1.0, 0.94, 0.85) * 6.0 * _softbox(d, KEY_BOX.normalized(), 0.22, 1.6, 0.06)
	c += Vector3(0.9, 0.95, 1.0) * 4.0 * _softbox(d, RIM_BOX.normalized(), 0.05, 1.6, 0.02)
	c += Vector3(1.0, 0.97, 0.92) * 1.5 * _softbox(d, FILL_BOX.normalized(), 0.08, 1.2, 0.04)
	c += Vector3(1.0, 1.0, 1.0) * 1.5 * _softbox(d, Vector3.UP, 0.4, 0.4, 0.15)
	return Color(c.x, c.y, c.z, 1.0)


## A rectangle facing the center, half sizes in tangent units, soft edge width.
static func _softbox(d: Vector3, center: Vector3, half_w: float, half_h: float, soft: float) -> float:
	var facing: float = d.dot(center)
	if facing <= 0.0:
		return 0.0
	var up_ref: Vector3 = Vector3.UP if absf(center.y) < 0.9 else Vector3.FORWARD
	var right: Vector3 = up_ref.cross(center).normalized()
	var up: Vector3 = center.cross(right).normalized()
	var a: float = d.dot(right) / facing
	var b: float = d.dot(up) / facing
	var wx: float = 1.0 - smoothstep(half_w - soft, half_w + soft, absf(a))
	var wy: float = 1.0 - smoothstep(half_h - soft, half_h + soft, absf(b))
	return wx * wy

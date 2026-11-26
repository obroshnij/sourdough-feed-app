class_name JarBuilder
extends RefCounted
## Builds the spike's stand-in meshes in code: a lathed glass jar with real wall
## thickness, the starter body (rounded foot, side, dense top disk), the streak
## liner and the counter. Meters, Y up, origin at the jar's outer base center.
## Dimensions follow art-director's jar_v0 contract (outer D 84 mm, H 170 mm,
## neck outer r 37.5 mm, inner floor corner r 4 mm, liner top 125 mm above the floor).

const SEGMENTS: int = 96
const STARTER_GAP: float = 0.0005
const FED_LEVEL: float = 0.030
const LINER_TOP: float = 0.125

var outer_radius: float = 0.042
var neck_radius: float = 0.0375
var height: float = 0.170
var shoulder_y: float = 0.140
var neck_y: float = 0.152
var wall: float = 0.0035
var bottom: float = 0.008
var outer_corner: float = 0.006
var inner_corner: float = 0.004

var _front_sign: float = 0.0


func inner_radius() -> float:
	return outer_radius - wall


func starter_radius() -> float:
	return inner_radius() - STARTER_GAP


func starter_floor() -> float:
	return bottom + STARTER_GAP


func starter_corner() -> float:
	return inner_corner - STARTER_GAP


func starter_foot_top() -> float:
	return starter_floor() + starter_corner()


func liner_radius() -> float:
	return inner_radius() - STARTER_GAP * 0.3


func build_glass() -> ArrayMesh:
	var r_in: float = inner_radius()
	var n_in: float = neck_radius - wall
	var pts := PackedVector2Array()
	_line(pts, Vector2(0.0, 0.0), Vector2(outer_radius - outer_corner, 0.0), 6)
	_arc(pts, Vector2(outer_radius - outer_corner, outer_corner), outer_corner, -PI / 2.0, 0.0, 8)
	_line(pts, Vector2(outer_radius, outer_corner), Vector2(outer_radius, shoulder_y), 24)
	_ease(pts, Vector2(outer_radius, shoulder_y), Vector2(neck_radius, neck_y), 10)
	_line(pts, Vector2(neck_radius, neck_y), Vector2(neck_radius, height - wall * 0.5), 6)
	_arc(pts, Vector2(neck_radius - wall * 0.5, height - wall * 0.5), wall * 0.5, 0.0, PI, 10)
	_line(pts, Vector2(n_in, height - wall * 0.5), Vector2(n_in, neck_y), 6)
	_ease(pts, Vector2(n_in, neck_y), Vector2(r_in, shoulder_y), 10)
	_line(pts, Vector2(r_in, shoulder_y), Vector2(r_in, bottom + inner_corner), 24)
	_arc(pts, Vector2(r_in - inner_corner, bottom + inner_corner), inner_corner, 0.0, -PI / 2.0, 8)
	_line(pts, Vector2(r_in - inner_corner, bottom), Vector2(0.0, bottom), 6)
	return _lathe(_dedupe(pts), SEGMENTS)


func build_liner() -> ArrayMesh:
	var pts := PackedVector2Array()
	_line(pts, Vector2(liner_radius(), starter_foot_top()), Vector2(liner_radius(), bottom + LINER_TOP), 4)
	return _lathe(pts, SEGMENTS)


## Starter: rounded foot (fixed), side and a dense top disk. UV2 matches the
## jar_v0 contract as Godot reads it: UV2.y = stretch weight (0 on the foot,
## 1 on the top disk), UV2.x = radial fraction.
func build_starter(top_rings: int = 28, side_rings: int = 24) -> ArrayMesh:
	var r: float = starter_radius()
	var floor_y: float = starter_floor()
	var corner: float = starter_corner()
	var foot_top: float = starter_foot_top()
	var authored_top: float = bottom + FED_LEVEL
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uv2s := PackedVector2Array()
	var rows: Array[PackedInt32Array] = []

	# Foot: from the axis on the floor out and around the corner arc.
	var foot := PackedVector2Array()
	_line(foot, Vector2(0.0, floor_y), Vector2(r - corner, floor_y), 4)
	_arc(foot, Vector2(r - corner, floor_y + corner), corner, -PI / 2.0, 0.0, 6)
	foot = _dedupe(foot)
	var foot_norm: PackedVector2Array = _profile_normals(foot)
	for i: int in range(foot.size()):
		rows.append(_ring(verts, norms, uv2s, foot[i].x, foot[i].y, foot_norm[i], Vector2(foot[i].x / r, 0.0)))
	# Side: a separate ring at the foot top so the side starts with a horizontal normal.
	for i: int in range(side_rings + 1):
		var f: float = float(i) / float(side_rings)
		var y: float = lerpf(foot_top, authored_top, f)
		rows.append(_ring(verts, norms, uv2s, r, y, Vector2(1.0, 0.0), Vector2(1.0, f)))
	var indices := PackedInt32Array()
	for i: int in range(rows.size() - 1):
		_stitch(indices, verts, norms, rows[i], rows[i + 1])
	# Top disk: concentric rings, split from the side so it keeps its own normal.
	var top_rows: Array[PackedInt32Array] = []
	for i: int in range(top_rings + 1):
		var rr: float = r * (1.0 - float(i) / float(top_rings))
		top_rows.append(_ring(verts, norms, uv2s, rr, authored_top, Vector2(0.0, 1.0), Vector2(rr / r, 1.0)))
	for i: int in range(top_rows.size() - 1):
		_stitch(indices, verts, norms, top_rows[i], top_rows[i + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Largest box the starter can reach, for custom_aabb (vertices move in the
## shader): rise 3.0 at the 0.042 m maximum fed level, plus the dome.
func starter_max_aabb(dome_height: float) -> AABB:
	var r: float = starter_radius()
	var top: float = bottom + 0.042 * 3.0 + dome_height * 1.2
	return AABB(Vector3(-r, 0.0, -r), Vector3(r * 2.0, top, r * 2.0))


## Smooth S-curve between two profile points (for the shoulder).
func _ease(pts: PackedVector2Array, a: Vector2, b: Vector2, steps: int) -> void:
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var k: float = 0.5 - 0.5 * cos(PI * t)
		pts.append(Vector2(lerpf(a.x, b.x, k), lerpf(a.y, b.y, t)))


func _ring(verts: PackedVector3Array, norms: PackedVector3Array, uv2s: PackedVector2Array,
		radius: float, y: float, n2: Vector2, uv2: Vector2) -> PackedInt32Array:
	var row := PackedInt32Array()
	for j: int in range(SEGMENTS + 1):
		var a: float = TAU * float(j) / float(SEGMENTS)
		var c: float = cos(a)
		var s: float = sin(a)
		row.append(verts.size())
		verts.append(Vector3(radius * c, y, radius * s))
		norms.append(Vector3(n2.x * c, n2.y, n2.x * s).normalized())
		uv2s.append(uv2)
	return row


func _stitch(indices: PackedInt32Array, verts: PackedVector3Array, norms: PackedVector3Array,
		a: PackedInt32Array, b: PackedInt32Array) -> void:
	for j: int in range(a.size() - 1):
		_add_tri(indices, verts, norms, a[j], b[j], a[j + 1])
		_add_tri(indices, verts, norms, a[j + 1], b[j], b[j + 1])


func _lathe(profile: PackedVector2Array, segments: int) -> ArrayMesh:
	var count: int = profile.size()
	var normals2d: PackedVector2Array = _profile_normals(profile)
	var vcoord := PackedFloat32Array()
	var total: float = 0.0
	for i: int in range(count):
		if i > 0:
			total += profile[i].distance_to(profile[i - 1])
		vcoord.append(total)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i: int in range(count):
		for j: int in range(segments + 1):
			var a: float = TAU * float(j) / float(segments)
			var c: float = cos(a)
			var s: float = sin(a)
			var p: Vector2 = profile[i]
			var n: Vector2 = normals2d[i]
			verts.append(Vector3(p.x * c, p.y, p.x * s))
			norms.append(Vector3(n.x * c, n.y, n.x * s).normalized())
			uvs.append(Vector2(float(j) / float(segments), vcoord[i] / maxf(total, 0.000001)))
	var indices := PackedInt32Array()
	var stride: int = segments + 1
	for i: int in range(count - 1):
		for j: int in range(segments):
			var a0: int = i * stride + j
			var b0: int = a0 + stride
			_add_tri(indices, verts, norms, a0, b0, a0 + 1)
			_add_tri(indices, verts, norms, a0 + 1, b0, b0 + 1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Profile normals: the tangent turned clockwise. Walking the profile outward
## along the base and up the outside gives normals that point out of the material.
func _profile_normals(profile: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count: int = profile.size()
	for i: int in range(count):
		var prev: Vector2 = profile[maxi(i - 1, 0)]
		var next: Vector2 = profile[mini(i + 1, count - 1)]
		var t: Vector2 = (next - prev).normalized()
		out.append(Vector2(t.y, -t.x))
	return out


## Adds a triangle wound the way Godot treats as front-facing for the intended
## normal. The winding convention is read from a Godot primitive, not assumed.
func _add_tri(indices: PackedInt32Array, verts: PackedVector3Array, norms: PackedVector3Array,
		a: int, b: int, c: int) -> void:
	var face: Vector3 = (verts[b] - verts[a]).cross(verts[c] - verts[a])
	if face.length_squared() < 1e-16:
		return
	var expected: Vector3 = norms[a] + norms[b] + norms[c]
	if signf(face.dot(expected)) == front_sign():
		indices.append_array(PackedInt32Array([a, b, c]))
	else:
		indices.append_array(PackedInt32Array([a, c, b]))


func front_sign() -> float:
	if _front_sign != 0.0:
		return _front_sign
	var arrays: Array = BoxMesh.new().get_mesh_arrays()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var face: Vector3 = (v[idx[1]] - v[idx[0]]).cross(v[idx[2]] - v[idx[0]])
	_front_sign = signf(face.dot(n[idx[0]]))
	return _front_sign


func _line(pts: PackedVector2Array, a: Vector2, b: Vector2, steps: int) -> void:
	for i: int in range(steps + 1):
		pts.append(a.lerp(b, float(i) / float(steps)))


func _arc(pts: PackedVector2Array, center: Vector2, radius: float, a0: float, a1: float, steps: int) -> void:
	for i: int in range(steps + 1):
		var a: float = lerpf(a0, a1, float(i) / float(steps))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)


func _dedupe(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 1e-7:
			out.append(p)
	return out

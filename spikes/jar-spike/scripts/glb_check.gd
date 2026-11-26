class_name GlbCheck
extends RefCounted
## Prints what the spike needs to know about an art GLB: node names and types,
## positions, extras metadata, surfaces, attributes and whether the glass
## normals point out of the material (outer wall away from the axis, inner wall
## toward it).


static func report(path: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		print("GLB could not load %s" % path)
		return
	var root: Node = packed.instantiate()
	print("GLB %s" % path)
	_walk(root, root, 0)
	root.free()


static func _walk(node: Node, root: Node, depth: int) -> void:
	var pad: String = "  ".repeat(depth)
	var line: String = "%sNODE %s (%s)" % [pad, node.name, node.get_class()]
	if node is Node3D:
		line += " pos=%s" % str((node as Node3D).position)
	for key: StringName in node.get_meta_list():
		line += " meta.%s=%s" % [key, str(node.get_meta(key))]
	print("GLB " + line)
	if node is MeshInstance3D:
		_mesh(node as MeshInstance3D, pad)
	for child: Node in node.get_children():
		_walk(child, root, depth + 1)


static func _mesh(mi: MeshInstance3D, pad: String) -> void:
	var mesh: Mesh = mi.mesh
	if mesh == null:
		print("GLB %s  no mesh" % pad)
		return
	print("GLB %s  aabb=%s surfaces=%d" % [pad, str(mesh.get_aabb()), mesh.get_surface_count()])
	for s: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var has_uv: bool = arrays[Mesh.ARRAY_TEX_UV] != null
		var has_uv2: bool = arrays[Mesh.ARRAY_TEX_UV2] != null
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var mat: Material = mesh.surface_get_material(s)
		var mat_name: String = mat.resource_name if mat != null else "<none>"
		print("GLB %s  surface %d: verts=%d tris=%d normals=%d uv=%s uv2=%s material=%s" % [
			pad, s, verts.size(), idx.size() / 3, norms.size(), has_uv, has_uv2, mat_name])
		if norms.size() == verts.size() and verts.size() > 0:
			_normal_stats(verts, norms, pad)


## For walls (|normal.y| < 0.3): how many normals point away from the axis.
static func _normal_stats(verts: PackedVector3Array, norms: PackedVector3Array, pad: String) -> void:
	var outward: int = 0
	var inward: int = 0
	var unit: int = 0
	for i: int in range(verts.size()):
		var n: Vector3 = norms[i]
		if absf(n.length() - 1.0) < 0.01:
			unit += 1
		if absf(n.y) > 0.3:
			continue
		var radial := Vector2(verts[i].x, verts[i].z)
		if radial.length() < 0.001:
			continue
		if Vector2(n.x, n.z).dot(radial) > 0.0:
			outward += 1
		else:
			inward += 1
	print("GLB %s    wall normals: away_from_axis=%d toward_axis=%d unit_length=%d/%d" % [
		pad, outward, inward, unit, verts.size()])

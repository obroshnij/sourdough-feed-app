extends SceneTree
## Prints Starter_Body UV2 against height, to check the glTF V flip.
## Run: Godot --headless --path spikes/jar-spike -s res://scripts/uv2_probe.gd


func _initialize() -> void:
	var packed: PackedScene = load("res://art/jar_v0.glb") as PackedScene
	var root: Node = packed.instantiate()
	var mi: MeshInstance3D = root.find_child("Starter_Body", true, false) as MeshInstance3D
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var buckets: Array[float] = [0.0, 0.0015, 0.004, 0.0045, 0.015, 0.029, 0.0301]
	for b: int in range(buckets.size() - 1):
		var lo: float = buckets[b]
		var hi: float = buckets[b + 1]
		var vmin: float = 9.0
		var vmax: float = -9.0
		var xmin: float = 9.0
		var xmax: float = -9.0
		var n_count: int = 0
		var up: int = 0
		var down: int = 0
		for i: int in range(verts.size()):
			if verts[i].y >= lo and verts[i].y < hi:
				n_count += 1
				vmin = minf(vmin, uv2[i].y)
				vmax = maxf(vmax, uv2[i].y)
				xmin = minf(xmin, uv2[i].x)
				xmax = maxf(xmax, uv2[i].x)
				if norms[i].y > 0.7:
					up += 1
				elif norms[i].y < -0.7:
					down += 1
		print("UV2 y in [%.4f, %.4f): verts=%d uv2.y=[%.3f, %.3f] uv2.x=[%.3f, %.3f] normal_up=%d normal_down=%d" % [
			lo, hi, n_count, vmin, vmax, xmin, xmax, up, down])
	root.free()
	quit()

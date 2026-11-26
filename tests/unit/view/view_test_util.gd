extends RefCounted
## Helpers for the T2 view tests. Shader checks read the source text (following #include),
## because the headless renderer doesn't compile shaders, so uniform lists come back empty.


## Shader source with every `#include "res://..."` expanded, recursively.
static func source(path: String) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		var t: String = line.strip_edges()
		if t.begins_with("#include"):
			var inc: String = t.get_slice("\"", 1)
			out.append(source(inc))
		else:
			out.append(line)
	return "\n".join(out)


## Uniform name to its GLSL type, from `uniform <type> <name>` declarations.
static func uniforms(path: String) -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	var re := RegEx.new()
	re.compile("(?m)^\\s*uniform\\s+(\\w+)\\s+(\\w+)")
	for m: RegExMatch in re.search_all(source(path)):
		out[m.get_string(2)] = m.get_string(1)
	return out


## Value of `const float <name> = <value>;` in a shader source, or NAN.
static func shader_const(path: String, name: String) -> float:
	var re := RegEx.new()
	re.compile("const\\s+float\\s+" + name + "\\s*=\\s*([0-9.eE+-]+)")
	var m: RegExMatch = re.search(source(path))
	return float(m.get_string(1)) if m != null else NAN


## The runner starts in SceneTree._initialize, before the root is in the tree. Await this in
## before_each so added nodes get _ready and global transforms.
static func tree_ready() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	while not tree.root.is_inside_tree():
		await tree.process_frame


## A JarView bound to a fresh jar_v0 instance, inside the running SceneTree.
static func make_jar() -> JarView:
	var jar := JarView.new()
	var model: Node3D = (load("res://assets/3d/jar_v0.glb") as PackedScene).instantiate() as Node3D
	model.name = "Model"
	jar.add_child(model)
	(Engine.get_main_loop() as SceneTree).root.add_child(jar)
	jar.bind(model)
	return jar

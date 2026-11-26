class_name StarterUniforms
extends RefCounted
## The one "state to params" step of the view: VisualParams to the starter and liner shader
## uniforms. Every field maps 1:1 to a uniform with the same name (architecture.md §8.1,
## data-models.md §7). Nothing else writes these uniforms. View-only uniforms (geometry, grade)
## use other names, so they can never collide with a state field.


## Uniform name to value, exactly the fields in VisualParams.UNIFORMS.
static func values(p: VisualParams) -> Dictionary[StringName, Variant]:
	var out: Dictionary[StringName, Variant] = {}
	for u: StringName in VisualParams.UNIFORMS:
		out[u] = p.get(u)
	return out


static func apply(p: VisualParams, materials: Array[ShaderMaterial]) -> void:
	var vals: Dictionary[StringName, Variant] = values(p)
	for m: ShaderMaterial in materials:
		for u: StringName in vals:
			m.set_shader_parameter(u, vals[u])


## Uniforms in `shader` named after a VisualParams field. The starter and liner shaders must
## declare every field (tests/unit/view/test_starter_uniforms.gd).
static func declared(shader: Shader) -> PackedStringArray:
	var names := PackedStringArray()
	for u: Dictionary in shader.get_shader_uniform_list():
		names.append(String(u["name"]))
	return names

// Jar_Lid_Loose: oiled oak, kept low-chroma (art-direction.md §2.1, §2.3).
// Horizontal growth rings on the side, cathedral grain on top. Object space.
// Placeholder until the baked 512 px tileable oak maps exist.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/view/shaders/noise.gdshaderinc"

uniform vec3 oak_light : source_color = vec3(0.678, 0.588, 0.439);   // #AD9670
uniform vec3 oak_dark : source_color = vec3(0.431, 0.357, 0.247);    // #6E5B3F
uniform float grade_value = 1.0;

varying vec3 v_pos;
varying vec3 v_nrm;

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	float top = smoothstep(0.5, 0.8, abs(v_nrm.y));
	// Side: rings stacked along y, wobbling around the lid.
	float ang = atan(v_pos.z, v_pos.x);
	float side_g = v_pos.y * 600.0 + 3.0 * fbm3(vec2(ang * 3.0, v_pos.y * 120.0));
	// Top: cathedral arches across x.
	float top_g = v_pos.z * 260.0 + 9.0 * v_pos.x * v_pos.x * 400.0 + 2.0 * fbm3(v_pos.xz * 90.0);
	float g = mix(side_g, top_g, top);
	float rings = 0.5 + 0.5 * sin(g);
	rings = smoothstep(0.25, 0.95, rings);
	float fine = vnoise(vec2(ang * 40.0, v_pos.y * 3000.0)) * (1.0 - top) + vnoise(v_pos.xz * 2500.0) * top;
	vec3 col = mix(oak_light, oak_dark, rings * 0.28 + 0.16 * fine);
	ALBEDO = col * grade_value;
	ROUGHNESS = 0.42 + 0.12 * rings;
	SPECULAR = 0.4;
}

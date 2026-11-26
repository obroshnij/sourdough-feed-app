// Counter top: warm wood-like grain, a soft contact shadow under the jar, and a
// fade into the background color far away so there is no hard horizon.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 table_color : source_color = vec3(0.55, 0.41, 0.29);
uniform vec3 far_color : source_color = vec3(0.93, 0.88, 0.80);
uniform float jar_radius = 0.05;
uniform float fade_start = 0.35;
uniform float fade_end = 1.4;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	float d = length(p);
	float grain = fbm(vec2(p.x * 6.0, p.y * 70.0));
	float fine = vnoise(vec2(p.x * 40.0, p.y * 400.0));
	vec3 col = table_color * (0.82 + 0.28 * grain + 0.06 * fine);
	float contact = 1.0 - 0.55 * (1.0 - smoothstep(jar_radius * 0.85, jar_radius * 1.45, d));
	col *= contact;
	float fade = smoothstep(fade_start, fade_end, d);
	ALBEDO = col * (1.0 - fade);
	EMISSION = far_color * fade;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}

// Jar_Lid_Loose: oiled oak, kept low-chroma (art-direction.md §2.1, §2.3, §17).
// Triplanar in object space: horizontal rings around the side, the cathedral arch on top.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 oak_light : source_color = vec3(0.678, 0.588, 0.439);   // #AD9670
uniform vec3 oak_dark : source_color = vec3(0.431, 0.357, 0.247);    // #6E5B3F
uniform float grade_value = 1.0;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;

varying vec3 v_pos;
varying vec3 v_nrm;

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	vec3 w = pow(abs(v_nrm), vec3(4.0));
	w /= w.x + w.y + w.z;
	float d = texture(grain, v_pos.zy / 0.064).r * w.x
			+ texture(grain, v_pos.xz / 0.064).r * w.y
			+ texture(grain, v_pos.xy / 0.064).r * w.z;
	ALBEDO = mix(oak_dark, oak_light, d) * grade_value;
	ROUGHNESS = mix(0.6, 0.4, d);
	SPECULAR = 0.4;
}

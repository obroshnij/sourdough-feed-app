// One bubble pop on the starter's top: a small pit that opens into a ring and thins out.
// INSTANCE_CUSTOM.x is the pop's age, 0..1. Alpha scissor keeps it in the opaque pass (D-009).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.96, 0.92, 0.84);

varying float v_age;

void vertex() {
	v_age = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	float r = mix(0.25, 0.95, v_age);
	float w = mix(0.22, 0.04, v_age);
	float ring = 1.0 - smoothstep(w * 0.5, w, abs(d - r));
	float pit = (1.0 - smoothstep(0.0, 0.35, d)) * (1.0 - smoothstep(0.0, 0.35, v_age));
	ALPHA = max(ring, pit);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = mix(tint * 1.03, tint * 0.74, pit);
	ROUGHNESS = 0.25;
	SPECULAR = 0.5;
}

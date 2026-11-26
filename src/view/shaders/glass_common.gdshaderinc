// Glass lighting shared by both passes and both tiers (D-009, lifted from the
// Phase 1 spike). Unshaded on purpose: it looks and costs the same in Mobile and
// Compatibility. Output is premultiplied: emit is added, alpha is how much of the
// background the glass hides (reflection plus absorption at grazing angles).

uniform samplerCube env_cube : filter_linear_mipmap;
uniform vec3 key_dir = vec3(-0.55, 0.55, 0.62);      // world space, toward the key light
uniform vec3 key_color : source_color = vec3(1.0, 0.95, 0.88);
uniform vec3 rim_dir = vec3(0.7, 0.25, -0.65);
uniform vec3 rim_color : source_color = vec3(0.92, 0.95, 1.0);
uniform vec3 edge_tint : source_color = vec3(0.16, 0.24, 0.20);
uniform float f0 = 0.04;
uniform float reflection_strength = 1.0;
uniform float spec_strength = 5.0;
// Per-renderer grade (ViewLook): Compatibility's Filmic clips the HDR softbox reflection.
uniform float glass_grade = 1.0;
uniform float spec_power = 900.0;
uniform float base_absorb = 0.03;
uniform float edge_absorb = 0.5;
uniform float edge_power = 4.0;
// Fridge condensation (art-direction.md §3): 0 clear, 0.3 at the fridge.
uniform float fog : hint_range(0.0, 1.0) = 0.0;

void glass_shade(vec3 normal_v, vec3 view_v, mat4 inv_view, float strength,
		out vec3 emit, out float alpha, out vec3 n_v) {
	n_v = normalize(normal_v);
	if (dot(n_v, view_v) < 0.0) {
		n_v = -n_v;
	}
	float ndv = clamp(dot(n_v, view_v), 0.0, 1.0);
	float fres = f0 + (1.0 - f0) * pow(1.0 - ndv, 5.0);
	vec3 n_w = normalize(mat3(inv_view) * n_v);
	vec3 v_w = normalize(mat3(inv_view) * view_v);
	vec3 refl = texture(env_cube, reflect(-v_w, n_w)).rgb * reflection_strength;
	float s_key = pow(max(dot(n_w, normalize(normalize(key_dir) + v_w)), 0.0), spec_power);
	float s_rim = pow(max(dot(n_w, normalize(normalize(rim_dir) + v_w)), 0.0), spec_power * 0.5);
	vec3 spec = (key_color * s_key + rim_color * s_rim * 0.6) * spec_strength * (1.0 - 0.6 * fog);
	float absorb = clamp(base_absorb + edge_absorb * pow(1.0 - ndv, edge_power), 0.0, 1.0);
	float transmit = (1.0 - fres) * (1.0 - absorb) * (1.0 - 0.5 * fog);
	emit = ((refl * fres + spec) * glass_grade + edge_tint * absorb * 0.5 + vec3(0.55) * fog * 0.5) * strength;
	alpha = (1.0 - transmit) * strength;
}

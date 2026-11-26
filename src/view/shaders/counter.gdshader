// Counter: pale oak butcher block (art-direction.md §2.1, §4) with a soft
// contact shadow under the jar (§3: a baked AO decal, done here procedurally).
// Placeholder until the baked 1024 x 512 albedo and roughness maps exist.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/view/shaders/noise.gdshaderinc"

// Art palette #D2C09E / #B19B76, authored here at about half the chroma: the real-time key
// adds warmth the Cycles render doesn't (counter row, art-direction.md §3).
uniform vec3 oak_light : source_color = vec3(0.855, 0.816, 0.745);
uniform vec3 oak_dark : source_color = vec3(0.737, 0.686, 0.596);
uniform float plank_w = 0.045;
uniform float jar_radius = 0.042;
uniform float contact_strength = 0.55;
uniform float grade_value = 1.0;
// Analytic drop shadow of the jar along the key light (world space, toward the light).
// Real shadow maps are off: on Compatibility in 4.7.2 a shadowed DirectionalLight3D lights
// about 5x too hard and clips everything (T2 measurement, Phase 2).
uniform vec3 key_dir = vec3(-0.37, 0.82, 0.44);
uniform float glass_h = 0.170;
uniform float starter_floor = 0.008;
uniform float starter_top = 0.04;
uniform float starter_r = 0.038;
uniform float lid_on = 1.0;
uniform float lid_y0 = 0.163;
uniform float lid_y1 = 0.2035;
uniform float drop_strength = 0.5;
uniform float glass_strength = 0.2;

varying vec3 v_world;

// How much a vertical cylinder (radius r, from height y0 to y1, on the y axis) hides the key
// light from counter point p. Soft edge that widens with height (penumbra).
float cylinder_shadow(vec2 p, vec3 l, float r, float y0, float y1) {
	vec2 step_xz = l.xz / max(l.y, 0.05);
	vec2 a = p + step_xz * y0;
	vec2 b = p + step_xz * y1;
	vec2 ab = b - a;
	float t = clamp(dot(-a, ab) / max(dot(ab, ab), 1e-8), 0.0, 1.0);
	float d = length(a + ab * t);
	float soft = 0.002 + 0.06 * mix(y0, y1, t);
	return 1.0 - smoothstep(r - soft, r + soft, d);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;
	// Planks run left to right (along x), like the preview.
	float plank = floor(p.y / plank_w);
	float ph = hash12(vec2(plank, 3.0));
	vec2 q = vec2(p.x + ph * 3.0, p.y);
	float grain = fbm3(vec2(q.x * 4.0, q.y * 220.0) + vec2(0.0, ph * 10.0));
	float fine = vnoise(vec2(q.x * 30.0, q.y * 900.0));
	float rings = 0.5 + 0.5 * sin(q.y * 900.0 + grain * 9.0 + q.x * 6.0);
	float k = clamp(0.25 + 0.45 * grain + 0.2 * rings * 0.5 + 0.1 * fine + 0.15 * (ph - 0.5), 0.0, 1.0);
	vec3 col = mix(oak_light, oak_dark, k * 0.75);
	// Seam between planks.
	float fy = fract(p.y / plank_w);
	float seam_d = min(fy, 1.0 - fy) * plank_w;
	float seam = 1.0 - 0.15 * (1.0 - smoothstep(0.0, 0.0012, seam_d));
	col *= seam;
	// Contact shadow: soft AO ring under the jar.
	float d = length(p);
	// Contact shadow: a soft ring where the glass meets the wood. Under the base the thick glass
	// passes light, so the counter seen through it stays bright.
	float ring = smoothstep(jar_radius * 0.55, jar_radius * 0.95, d) * (1.0 - smoothstep(jar_radius * 0.95, jar_radius * 1.7, d));
	float contact = 1.0 - contact_strength * ring;
	vec3 l = normalize(key_dir);
	float s_starter = cylinder_shadow(p, l, starter_r, starter_floor, starter_top);
	float s_glass = cylinder_shadow(p, l, jar_radius, 0.0, glass_h);
	float s_lid = cylinder_shadow(p, l, jar_radius, lid_y0, lid_y1) * lid_on;
	float drop = max(max(s_starter, s_lid) * drop_strength, s_glass * glass_strength);
	ALBEDO = col * contact * (1.0 - drop) * grade_value;
	ROUGHNESS = 0.62 - 0.08 * rings;
	SPECULAR = 0.35;
	AO = contact;
	AO_LIGHT_AFFECT = 0.6;
}

// Starter body. One mesh (a cylinder with a dense top disk and a rounded foot),
// shaped entirely here from uniforms. Everything inside the glass is opaque.
//
// Mesh encoding (art-director's Starter_Body contract, jar_v0):
//   UV2.y = 0 at and below the foot top, 1 on the rim arc and the top disk,
//   linear in between. The mesh is authored at the fed level (authored_top).
//   y' = y + w * (surface_height(x, z) - authored_top), so the foot never
//   moves and the rim arc moves rigidly with the surface.
//   w = UV2.y as Godot reads it (1 on the cap, 0 at and below the foot).
//   glTF flips V on export, so art pre-flips this data channel in Blender.
//   The top disk is found by its authored normal (pointing up).
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/starter_shape.gdshaderinc"

uniform float authored_top = 0.038;   // local height of the authored top disk
uniform bool bubbles_on = true;       // benchmark control only (--no-bubbles)
uniform float translucency = 1.0;     // color-parity test only (--no-translucency)
uniform vec3 starter_color : source_color = vec3(0.93, 0.87, 0.76);
uniform vec3 cavity_color : source_color = vec3(0.50, 0.41, 0.31);
uniform vec3 hooch_color : source_color = vec3(0.46, 0.40, 0.29);

varying vec3 v_pos;
varying float v_top;

void vertex() {
	v_top = step(0.7, NORMAL.y);
	float h = surface_height(VERTEX.xz, TIME);
	float w = UV2.y;
	VERTEX.y += w * (h - authored_top);
	if (v_top > 0.5) {
		// Macro normal from the height function (central differences).
		float e = 0.002;
		float hx = surface_height(VERTEX.xz + vec2(e, 0.0), TIME) - surface_height(VERTEX.xz - vec2(e, 0.0), TIME);
		float hz = surface_height(VERTEX.xz + vec2(0.0, e), TIME) - surface_height(VERTEX.xz - vec2(0.0, e), TIME);
		NORMAL = normalize(vec3(-hx, 2.0 * e, -hz));
	}
	v_pos = VERTEX;
}

// Shading of a void seen against the glass: the top of the void is in the
// shadow of the paste above it, the bottom catches light, and a thin bright
// rim sits along the lower edge. Baked look, because the light is always above.
vec3 void_shade(vec3 base, float k, vec2 rel) {
	float inside = smoothstep(0.0, 0.12, k);
	float lower = 1.0 - smoothstep(-0.9, 0.5, rel.y);
	vec3 col = cavity_color * mix(0.55, 1.15, lower);
	float rim = (1.0 - smoothstep(0.0, 0.22, k)) * step(0.0, k) * (1.0 - smoothstep(-0.75, -0.1, rel.y));
	return mix(base, col, inside) + vec3(rim * 0.18);
}

void fragment() {
	float t = shape_time(TIME);
	vec3 p = v_pos;
	float edge_h = edge_height();
	float hooch_th = hooch_depth * hooch_max;
	float flat_amt = hooch_flat();
	float grain = fbm(vec2(p.x + p.y, p.z - p.y) * 700.0);
	vec3 base = starter_color * (0.95 + 0.10 * grain);
	vec3 albedo;
	vec3 n_obj;
	float cavity = 0.0;
	float in_hooch = 0.0;
	float hooch_shade = 1.0;

	if (v_top > 0.5) {
		// Per-pixel normal from the same height function plus bubble craters.
		float e = 0.0008;
		float hx = (surface_height(p.xz + vec2(e, 0.0), t) - surface_height(p.xz - vec2(e, 0.0), t)) / (2.0 * e);
		float hz = (surface_height(p.xz + vec2(0.0, e), t) - surface_height(p.xz - vec2(0.0, e), t)) / (2.0 * e);
		float cluster = 0.45 + 0.9 * smoothstep(0.3, 0.7, fbm(p.xz * 60.0));
		float cell1 = 0.0055;
		float cell2 = 0.0020;
		float k1; vec2 g1; float r1; vec2 rel1;
		float k2; vec2 g2; float r2; vec2 rel2;
		k1 = 0.0; g1 = vec2(0.0); r1 = 0.0; rel1 = vec2(0.0);
		k2 = 0.0; g2 = vec2(0.0); r2 = 0.0; rel2 = vec2(0.0);
		if (bubbles_on) {
			bubble_field(p.xz / cell1, 0.0, bubble_density * 0.7 * cluster, 0.08, 0.46, t * 0.6, 0.08 * activity, k1, g1, r1, rel1);
			bubble_field(p.xz / cell2 + vec2(13.1, 4.7), 0.0, bubble_density * (0.2 + 0.8 * activity) * cluster, 0.10, 0.40, t * 0.9, 0.10 * activity, k2, g2, r2, rel2);
		}
		// Craters: height = -depth * k, so the gradient is -depth * dk/dp / cell.
		vec2 grad_b = -(0.0012 * g1 / cell1) - (0.0005 * g2 / cell2);
		grad_b *= 1.0 - 0.85 * flat_amt;
		n_obj = normalize(vec3(-(hx + grad_b.x), 1.0, -(hz + grad_b.y)));
		cavity = max(smoothstep(0.0, 0.8, k1), 0.8 * smoothstep(0.0, 0.8, k2));
		albedo = mix(base, cavity_color * 0.85, cavity * 0.75);
		in_hooch = flat_amt;
		hooch_shade = mix(1.0, 0.75, cavity);
	} else {
		// Side, pressed against the glass. Bubbles show as voids in the paste.
		float ang = atan(p.z, p.x);
		float circumference = 6.2831853 * inner_radius;
		float cell = 0.0045;
		float period = floor(circumference / cell);
		float cell_x = circumference / period;
		float cell_y = cell * 1.2;
		vec2 q = vec2(ang * inner_radius / cell_x, (p.y - floor_y) / cell_y);
		float hfrac = clamp((p.y - floor_y) / max(edge_h - floor_y, 0.001), 0.0, 1.0);
		vec2 ring = vec2(cos(ang), sin(ang));
		float cluster = 0.4 + 0.9 * smoothstep(0.3, 0.7, fbm(ring * 5.0 + vec2(p.y * 90.0, 3.0)));
		float dens = bubble_density * mix(0.45, 1.0, hfrac) * cluster;
		float k1; vec2 g1; float r1; vec2 rel1;
		float k2; vec2 g2; float r2; vec2 rel2;
		float k3; vec2 g3; float r3; vec2 rel3;
		k1 = 0.0; g1 = vec2(0.0); r1 = 0.0; rel1 = vec2(0.0);
		k2 = 0.0; g2 = vec2(0.0); r2 = 0.0; rel2 = vec2(0.0);
		k3 = 0.0; g3 = vec2(0.0); r3 = 0.0; rel3 = vec2(0.0);
		if (bubbles_on) {
			bubble_field(q, period, dens * 0.8, 0.07, 0.47, t * 0.5, 0.06 * activity, k1, g1, r1, rel1);
			bubble_field(q * 2.0 + vec2(0.0, 7.7), period * 2.0, dens * (0.35 + 0.65 * activity), 0.10, 0.42, t * 0.8, 0.08 * activity, k2, g2, r2, rel2);
			bubble_field(q * 4.0 + vec2(0.0, 3.1), period * 4.0, dens * 0.6, 0.12, 0.35, 0.0, 0.0, k3, g3, r3, rel3);
		}
		vec3 n_r = normalize(vec3(p.x, 0.0, p.z));
		// Gentle concave tilt only near the rim; the void look comes from void_shade.
		vec3 tan_u = vec3(-n_r.z, 0.0, n_r.x);
		vec2 g = -(0.0004 * g1 / vec2(cell_x, cell_y));
		n_obj = normalize(n_r - (g.x * tan_u + g.y * vec3(0.0, 1.0, 0.0)));
		albedo = void_shade(base, k1, rel1);
		albedo = void_shade(albedo, k2, rel2);
		albedo = mix(albedo, cavity_color * 0.9, smoothstep(0.0, 0.3, k3) * 0.6);
		cavity = max(smoothstep(0.0, 0.12, k1), max(smoothstep(0.0, 0.12, k2), 0.6 * smoothstep(0.0, 0.3, k3)));
		in_hooch = smoothstep(edge_h - hooch_th - 0.0005, edge_h - hooch_th + 0.0002, p.y) * step(0.0004, hooch_th);
		// Hooch is darker near its top surface and lets the starter glow through below.
		hooch_shade = mix(1.15, 0.7, clamp((p.y - (edge_h - hooch_th)) / max(hooch_th, 0.0004), 0.0, 1.0));
	}

	// Fresh paste is wetter and shinier, a bubbly mature starter is more matte.
	float rough = mix(0.38, 0.6, bubble_density);
	rough = mix(rough, 0.75, cavity);
	albedo = mix(albedo, hooch_color * hooch_shade, in_hooch);
	rough = mix(rough, 0.05, in_hooch);

	NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * n_obj));
	ALBEDO = albedo;
	ROUGHNESS = rough;
	SPECULAR = mix(mix(0.5, 0.15, cavity), 0.8, in_hooch);
	BACKLIGHT = starter_color * 0.22 * (1.0 - in_hooch) * translucency;
	RIM = 0.12 * (1.0 - in_hooch) * translucency;
	RIM_TINT = 0.6;
}

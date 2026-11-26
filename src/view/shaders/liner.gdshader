// Starter liner (Starter_Liner): residue on the glass between the paste and the
// peak line, and mold colonies on the glass for moldy.
// Alpha scissor with a per-pixel dither threshold keeps it in the opaque pass,
// so it never sorts against the glass (D-009). Mapping: art-direction.md §16.3,
// residue math: §16.5e. Residue age is derived, so no new VisualParams field.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

#include "res://src/view/shaders/noise.gdshaderinc"
#include "res://src/view/shaders/starter_common.gdshaderinc"

uniform sampler2D liner_mask : filter_linear_mipmap, repeat_enable;

const vec3 MOLD_HALO = vec3(0.9047, 0.9047, 0.8550);
const vec3 MOLD_RING = vec3(0.2747, 0.4342, 0.3712);
const vec3 MOLD_CORE = vec3(0.0284, 0.1779, 0.1301);

varying vec3 v_pos;

void vertex() {
	v_pos = VERTEX;
}

// Residue age, derived (§16.5e): about 0.15 collapsing, 0.55 hungry, 0.85 unhealthy.
float residue_age() {
	return clamp(max(surface_dryness, 1.4 * (peak_line - rise) / max(peak_line, 0.01) - 0.1), 0.0, 1.0);
}

void fragment() {
	vec3 p = v_pos;
	float lvl = u_level();
	float peak_h = peak_line * level_m;
	vec2 uv_liner = vec2(UV.x * LINER_REPEATS + 0.5,
			clamp(LINER_EDGE_V + (peak_h - p.y) / LINER_SPAN_M, 0.004, 0.996));
	vec4 ml = texture(liner_mask, uv_liner);
	float age = residue_age();
	float thr = 1.0 - streak_amount;
	float vis = smoothstep(thr - 0.02, thr + 0.02, ml.r)
			* smoothstep(0.55 * age, 0.55 * age + 0.04, ml.a);
	float above = smoothstep(lvl + 0.0003, lvl + 0.0018, p.y);
	float thick = clamp((ml.r - thr) / 0.5, 0.0, 1.0);
	vec3 col = mix(tint, CRUST_COLOR * (tint / vec3(0.9131, 0.8308, 0.6724)), age * 0.6);
	float rough = mix(0.22, 0.8, age);

	// Mold colonies on the glass, up to about 2 cm above the surface (moldy only).
	float colony = 0.0;
	if (mold > 0.0) {
		float f;
		float rank;
		vec2 rel;
		float arc = UV.x * 6.2831853 * 0.03835;
		feature_field(vec2(arc, p.y) / 0.010, floor(6.2831853 * 0.03835 / 0.010), 0.22, 0.42, 5.0, f, rank, rel);
		float zone = above * (1.0 - smoothstep(lvl + 0.014, lvl + 0.022, p.y));
		float show = smoothstep(rank, rank + 0.1, mold * 0.8) * zone;
		float g = f + 0.12 * (vnoise(vec2(arc, p.y) * 2400.0) - 0.5);
		vec3 mc = mix(MOLD_HALO, MOLD_RING, smoothstep(0.35, 0.45, g));
		mc = mix(mc, MOLD_CORE, smoothstep(0.62, 0.72, g));
		colony = smoothstep(0.0, 0.12, g) * show;
		col = mix(col, mc, colony);
		rough = mix(rough, 0.9, colony);
	}

	// Alpha scissor at 0.5 with dither only across the soft edges (art-direction.md §4).
	// Film thickness reads through color: thin film is a little grayer, thick film creamy.
	float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float cover = max(vis * above * step(0.001, streak_amount) * step(0.001, peak_line), colony);
	ALPHA = clamp(cover + (ign - 0.5) * 0.3, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	col *= mix(0.93, 1.0, max(thick, colony));
	// Residue reads cream to near-white (art-direction.md §16.6 R11).
	col = mix(col, vec3(0.84), 0.15 * (1.0 - colony));
	// Double-sided: from outside we see the liner's back faces. Build a radial normal that faces
	// the viewer, so both renderers light the film the same (Compatibility doesn't flip it).
	vec3 n_v = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * normalize(vec3(p.x, 0.0, p.z) + vec3(1e-5, 0.0, 0.0))));
	NORMAL = dot(n_v, VIEW) < 0.0 ? -n_v : n_v;
	ALBEDO = grade(col);
	ROUGHNESS = rough;
	SPECULAR = 0.4;
	// Dried film is thin and lets light through from the room behind it.
	BACKLIGHT = col * 0.4 * (1.0 - colony);
}

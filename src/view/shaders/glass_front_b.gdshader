// Glass Tier B: front faces only, Mobile renderer only (D-009).
// - Samples the screen texture with a small normal-based offset (refraction).
// - Depth check: never pulls in something that sits in front of the glass.
// - The far wall is analytic. The screen copy holds only opaque objects, so a
//   back-face pass drawn before this one would be overwritten.
// QualityTier never assigns this on Compatibility. If it ever is, the
// preprocessor drops the screen reads and it compiles to the Tier A front pass.
// There is no runtime switch for refraction: the tier swap is a material swap.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_back, depth_draw_never, shadows_disabled;

#include "res://src/view/shaders/glass_common.gdshaderinc"

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define TIER_B_FALLBACK
#endif

#ifndef TIER_B_FALLBACK
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float refraction : hint_range(0.0, 0.1) = 0.012;
uniform vec2 jar_axis = vec2(0.0);          // world xz of the jar axis
uniform float far_wall_strength : hint_range(0.0, 1.0) = 0.7;
uniform vec3 glass_tint : source_color = vec3(0.980, 0.992, 0.984);   // #FAFDFB (art-direction.md §2.1)

float view_z_at(vec2 uv, mat4 inv_proj) {
	float d = textureLod(depth_tex, uv, 0.0).r;
	vec4 vp = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return vp.z / vp.w;
}
#endif

void fragment() {
	vec3 emit;
	float alpha;
	vec3 n_v;
	glass_shade(NORMAL, VIEW, INV_VIEW_MATRIX, 1.0, emit, alpha, n_v);
#ifdef TIER_B_FALLBACK
	ALBEDO = emit;
	ALPHA = alpha;
#else
	// Refraction with a depth check.
	vec2 uv = SCREEN_UV - n_v.xy * refraction;
	if (view_z_at(uv, INV_PROJECTION_MATRIX) > VERTEX.z + 0.001) {
		uv = SCREEN_UV;
	}
	vec3 behind = textureLod(screen_tex, uv, 0.0).rgb;
	float scene_z = view_z_at(SCREEN_UV, INV_PROJECTION_MATRIX);

	// Analytic far wall of a vertical cylinder around jar_axis.
	vec3 p_w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n_w = normalize(mat3(INV_VIEW_MATRIX) * n_v);
	vec3 v_w = normalize(mat3(INV_VIEW_MATRIX) * VIEW);
	vec2 rad = p_w.xz - jar_axis;
	float outer = step(0.0, dot(n_w.xz, rad));
	vec2 nh = normalize(rad);
	float vh_len = max(length(v_w.xz), 0.001);
	vec2 vh = v_w.xz / vh_len;
	float cos_h = max(dot(nh, vh), 0.0);
	float chord = 2.0 * length(rad) * cos_h / vh_len;
	vec2 far_out = nh - 2.0 * cos_h * vh;
	vec3 far_in = normalize(vec3(-far_out.x, 0.0, -far_out.y));
	float ndv_f = clamp(dot(far_in, v_w), 0.0, 1.0);
	float fres_f = f0 + (1.0 - f0) * pow(1.0 - ndv_f, 5.0);
	vec3 refl_f = texture(env_cube, reflect(-v_w, far_in)).rgb * reflection_strength;
	float far_z = VERTEX.z - chord * VIEW.z;
	float vis = outer * (1.0 - smoothstep(far_z - 0.002, far_z + 0.002, scene_z)) * far_wall_strength;
	float a_far = fres_f * vis;
	vec3 far_layer = refl_f * a_far + behind * (1.0 - a_far);

	ALBEDO = emit + far_layer * glass_tint * (1.0 - alpha);
	ALPHA = 1.0;
#endif
}

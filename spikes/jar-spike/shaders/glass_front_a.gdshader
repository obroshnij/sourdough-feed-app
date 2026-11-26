// Glass Tier A, pass 2: front faces (material render_priority +1).
// Works in Mobile and Compatibility.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_back, depth_draw_never, shadows_disabled;

#include "res://shaders/glass_common.gdshaderinc"

void fragment() {
	vec3 emit;
	float alpha;
	vec3 n_v;
	glass_shade(NORMAL, VIEW, INV_VIEW_MATRIX, 1.0, emit, alpha, n_v);
	ALBEDO = emit;
	ALPHA = alpha;
}

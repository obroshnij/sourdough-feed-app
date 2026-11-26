// Glass Tier A, pass 1: back faces (material render_priority -1).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_front, depth_draw_never, shadows_disabled;

#include "res://shaders/glass_common.gdshaderinc"

uniform float back_strength : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec3 emit;
	float alpha;
	vec3 n_v;
	glass_shade(NORMAL, VIEW, INV_VIEW_MATRIX, back_strength, emit, alpha, n_v);
	ALBEDO = emit;
	ALPHA = alpha;
}

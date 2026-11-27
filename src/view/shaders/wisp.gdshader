// One smell wisp: a soft, swaying vertical ribbon that rises and fades. Billboarded around Y.
// Outside the jar, after the glass (material render priority 2), so blending is safe.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.953, 0.906, 0.824);
uniform float life = 0.0;   // 0..1 over one rise
uniform float fade = 1.0;
uniform float seed = 0.0;

void vertex() {
	// Cylindrical billboard: face the camera, keep up.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float y = 1.0 - UV.y;
	float rise = life * 0.6;
	float sway = 0.18 * sin((y + life) * 6.0 + seed) * y;
	float x = abs(UV.x - 0.5 - sway) * 2.0;
	float band = 1.0 - smoothstep(0.15, 0.9, x);
	float along = smoothstep(rise, rise + 0.25, y) * (1.0 - smoothstep(0.55 + rise * 0.4, 1.0, y));
	float life_a = smoothstep(0.0, 0.2, life) * (1.0 - smoothstep(0.7, 1.0, life));
	ALBEDO = tint;
	ALPHA = band * along * life_a * fade * 0.35;
}

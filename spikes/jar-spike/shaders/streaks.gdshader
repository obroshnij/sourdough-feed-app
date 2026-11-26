// Streak liner: a thin open cylinder just inside the glass. Shows the film a
// collapsed starter leaves between its current level and its peak line.
// Alpha scissor keeps it in the opaque pass, so it never sorts against the glass.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx, cull_disabled;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/starter_shape.gdshaderinc"

uniform vec3 film_color : source_color = vec3(0.90, 0.85, 0.76);

varying vec3 v_pos;

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	float lo = edge_height();
	float hi = peak_height();
	float span = hi - lo;
	float ang = atan(v_pos.z, v_pos.x);
	vec2 ring = vec2(cos(ang), sin(ang));   // seamless around the jar
	float y = v_pos.y;

	// Ragged line where the dome peaked.
	float top = hi + (fbm(ring * 9.0) - 0.5) * 0.004;
	float below = top - y;
	// Organic film: solid just under the peak line, patchy lower down.
	float n = fbm(ring * 26.0 + vec2(y * 520.0, y * 310.0));
	float near_top = exp(-max(below, 0.0) / 0.003);
	float fade = clamp(below / max(span, 0.001), 0.0, 1.0);
	float film = n + 0.6 * near_top - 0.3 * fade;
	// A few thin drips that slid down and taper off.
	float col = fbm(ring * 44.0 + vec2(11.0, 3.0));
	float drip_len = smoothstep(0.62, 0.8, col) * span * 0.9;
	float drip = smoothstep(0.64, 0.7, col) * (1.0 - smoothstep(drip_len * 0.5, drip_len, below)) + 0.1;

	float zone = step(lo + 0.0004, y) * step(0.0, below) * step(0.002, span);
	float cover = max(film, drip) * zone;

	ALPHA = cover;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = film_color * (0.84 + 0.2 * n);
	ROUGHNESS = 0.35;
	SPECULAR = 0.4;
	BACKLIGHT = film_color * 0.25;
}

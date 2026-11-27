// Place_Proofing_Box (places.glb, art-direction.md §19.3): the open warm box around the jar.
// Unshaded: its day light is baked into box_tex. A place change fades it with an ordered dither,
// so it stays in the opaque pass; the discard runs only while fade < 1.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform sampler2D box_tex : source_color, filter_linear, repeat_disable;
uniform float energy = 1.0;
uniform float night = 0.0;
uniform vec3 night_mult = vec3(0.27, 0.255, 0.24);   // places.glb extras
uniform float fade = 1.0;
// Per-renderer grade (ViewLook), tuned to rows PB3, PB5 and PB8.
uniform float saturation = 1.0;
uniform float night_k = 1.0;

void fragment() {
	if (fade < 1.0) {
		ivec2 q = ivec2(FRAGCOORD.xy) % 4;
		float bayer = float((q.x * 2 + q.y * 3 + (q.x * q.y) % 2 * 5) % 16) / 16.0 + 0.03;
		if (fade <= bayer) {
			discard;
		}
	}
	vec3 c = texture(box_tex, UV).rgb;
	c = mix(vec3(dot(c, vec3(0.2126, 0.7152, 0.0722))), c, saturation);
	ALBEDO = c * mix(vec3(1.0), night_mult * night_k, night) * energy;
}

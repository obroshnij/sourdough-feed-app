// Backdrop_placeholder: the baked soft-focus sage zellige wall (art-direction.md §17).
// The afternoon light and the lens blur are baked into the image, so it is unshaded with only
// the time-of-day tint and a per-renderer energy (ViewLook.backdrop_energy).
// The card's UV0 maps the image 1:1, row 0 is the top of the wall.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform sampler2D wall_tex : source_color, filter_linear, repeat_disable;
uniform vec3 tod_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float energy = 1.0;

void fragment() {
	ALBEDO = texture(wall_tex, UV).rgb * tod_tint * energy;
}

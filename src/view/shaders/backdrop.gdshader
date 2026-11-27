// The kitchen wall (Kitchen_Wall in kitchen_wall.glb; art-direction.md §18.3). The afternoon light
// and the lens blur are baked into wall_tex. At night (the shared night factor, D-043) the wall
// turns to the baked under-cabinet lamp: night_tex is the lamp's light alone, stored as its square
// root. Unshaded, with the time-of-day tint and a per-renderer energy (ViewLook.backdrop_energy).
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform sampler2D wall_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D night_tex : filter_linear, repeat_disable;      // data, not color
uniform vec3 tod_tint : source_color = vec3(1.0);
uniform float energy = 1.0;
uniform float night = 0.0;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.843, 0.659);     // #FFD7A8
uniform vec3 night_floor : source_color = vec3(0.102, 0.075, 0.063);  // #1A1310
uniform float night_gain = 0.5;
uniform float night_keep_hue = 0.5;
// Place change (art-direction.md §19.2): set b fades in over set a; then b is swapped into a.
uniform sampler2D wall_tex_b : source_color, filter_linear, repeat_disable;
uniform sampler2D night_tex_b : filter_linear, repeat_disable;
uniform vec3 night_floor_b : source_color = vec3(0.102, 0.075, 0.063);
uniform float place_mix = 0.0;

void fragment() {
	vec3 day = texture(wall_tex, UV).rgb;
	float m = texture(night_tex, UV).r;
	vec3 nfloor = night_floor;
	if (place_mix > 0.0) {
		day = mix(day, texture(wall_tex_b, UV).rgb, place_mix);
		m = mix(m, texture(night_tex_b, UV).r, place_mix);
		nfloor = mix(night_floor, night_floor_b, place_mix);
	}
	float l = max(dot(day, vec3(0.2126, 0.7152, 0.0722)), 1e-4);
	vec3 hue = mix(vec3(1.0), day / l, night_keep_hue);
	vec3 lamp = hue * lamp_color * (m * m) * night_gain + nfloor;
	ALBEDO = mix(day * tod_tint, lamp, night) * energy;
}

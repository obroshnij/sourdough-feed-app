// Soft warm studio background. Also feeds ambient light and the starter's
// reflections (radiance), so it stays low contrast on purpose.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.80, 0.74, 0.66);
uniform vec3 horizon_color : source_color = vec3(0.93, 0.88, 0.80);
uniform vec3 bottom_color : source_color = vec3(0.50, 0.40, 0.31);
uniform vec3 window_dir = vec3(-0.55, 0.45, 0.70);
uniform vec3 window_color : source_color = vec3(1.0, 0.93, 0.82);

void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(horizon_color, top_color, smoothstep(0.0, 0.7, y));
	c = mix(c, bottom_color, 1.0 - smoothstep(-0.35, 0.0, y));
	float w = pow(max(dot(EYEDIR, normalize(window_dir)), 0.0), 6.0);
	c += window_color * w * 0.8;
	COLOR = c;
}

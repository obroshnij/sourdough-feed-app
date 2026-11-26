// The room around the jar: drives ambient light and the starter's reflections,
// and is what the camera sees past the backdrop at wide yaw.
// Art-direction.md §2.1: world ambient #F3E8D8 top, #5A554E bottom (near-neutral floor).
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.953, 0.910, 0.847);      // #F3E8D8
uniform vec3 horizon_color : source_color = vec3(0.78, 0.80, 0.72);     // sage-gray wall
uniform vec3 bottom_color : source_color = vec3(0.353, 0.333, 0.306);   // #5A554E
uniform vec3 window_dir = vec3(-0.6, 0.35, 0.72);
uniform vec3 window_color : source_color = vec3(1.0, 0.93, 0.84);
uniform float window_energy = 0.6;
uniform float energy = 1.0;

void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(horizon_color, top_color, smoothstep(0.0, 0.7, y));
	c = mix(c, bottom_color, 1.0 - smoothstep(-0.35, 0.0, y));
	float w = pow(max(dot(EYEDIR, normalize(window_dir)), 0.0), 6.0);
	c += window_color * w * window_energy;
	COLOR = c * energy;
}

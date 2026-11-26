// Shared starter shape. Included by the starter and by the streak liner, so the
// streaks always begin exactly where the starter meets the glass.
// Uniform names, units and ranges match docs/data-models.md §7 (VisualParams).
// The state uniforms are written only by scripts/starter_view_params.gd.

uniform float level_m : hint_range(0.0, 0.042) = 0.030;     // fed level above the floor (m)
uniform float rise : hint_range(1.0, 3.0) = 1.0;            // ratio: surface height = level_m * rise
uniform float dome : hint_range(-1.0, 1.0) = 0.0;           // -1 collapsed, +1 domed
uniform float activity : hint_range(0.0, 1.0) = 0.2;        // breathing and bubble pulse
uniform float bubble_density : hint_range(0.0, 1.0) = 0.3;
uniform float hooch_depth : hint_range(0.0, 1.0) = 0.0;     // 1 = hooch_max of liquid on top
uniform float peak_line : hint_range(0.0, 3.0) = 0.0;       // highest rise this cycle (rise units), 0 = none
uniform float time_override = -1.0;                         // -1 = TIME; captures set a fixed value

// Geometry, set once per mesh. floor_y is the inner floor in this mesh's local space.
uniform float floor_y = 0.008;
uniform float inner_radius = 0.038;
uniform float dome_height = 0.008;
uniform float hooch_max = 0.010;

float shape_time(float t) {
	return time_override >= 0.0 ? time_override : t;
}

float hooch_flat() {
	return smoothstep(0.0, 0.15, hooch_depth);
}

// Height of the top surface at local xz. t is TIME.
float surface_height(vec2 xz, float t) {
	float r = clamp(length(xz) / inner_radius, 0.0, 1.0);
	float shape = dome * dome_height * (1.0 - r * r);
	// A collapsed starter stays a little higher where it clings to the glass.
	float cling = max(-dome, 0.0) * dome_height * 0.7 * smoothstep(0.65, 1.0, r);
	float breath = sin(shape_time(t) * 0.7) * 0.0005 * activity * (1.0 - r * r);
	return floor_y + level_m * rise + mix(shape + cling + breath, 0.0, hooch_flat());
}

float edge_height() {
	return surface_height(vec2(inner_radius, 0.0), 0.0);
}

// Height of the streak line; below the starter edge (no streaks) when peak_line is 0.
float peak_height() {
	return peak_line > 0.0 ? floor_y + level_m * peak_line : 0.0;
}

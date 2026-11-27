// Shared by the starter body and the liner, so residue always begins exactly
// where the paste meets the glass.
//
// State uniforms: one per VisualParams field, same name and type
// (data-models.md §7). Only StarterUniforms.apply() writes them.
// View uniforms (geometry, grade) are set by JarView and QualityTier.
// Shape math: art-direction.md §5. Mask mapping: §16.3.

uniform float level_m = 0.030;
uniform float rise = 1.0;
uniform float dome = 0.0;
uniform float activity = 0.0;
uniform float bubble_density = 0.0;
uniform float peak_line = 0.0;
uniform float lumps = 0.0;
uniform float hooch_depth = 0.0;
uniform float bubble_size = 0.0;
uniform float streak_amount = 0.0;
uniform float surface_dryness = 0.0;
uniform float sheen = 0.0;
uniform vec3 tint : source_color = vec3(0.96, 0.92, 0.84);
uniform float fleck = 0.0;
uniform float dullness = 0.0;
uniform float mold = 0.0;
uniform float big_bubble = 0.0;
uniform float time_override = -1.0;
// Phase 4: rye's fissured top (art-direction.md §20.2), 0..1.
uniform float crack = 0.0;

// View only. authored_h comes from the GLB extras (starter_authored_height_m).
uniform float authored_h = 0.030;
uniform float starter_r = 0.038;
// Per-renderer grade (art-direction.md §16.5b allows it, never a palette change).
uniform float grade_saturation = 1.0;
// Decorative motion (breathing): 1, or 0 with reduce motion. View only.
uniform float motion_k = 1.0;
uniform float grade_value = 1.0;

// Art-direction.md §5. Mirror these in jar_geometry.gd.
const float DOME_MAX_M = 0.010;
const float LUMPS_MAX_M = 0.003;
const float HOOCH_MAX_M = 0.010;
const float BREATH_M = 0.0006;

// Art-direction.md §16.3. Mirror art/textures/make_starter_masks.py.
const float SIDE_REPEATS = 4.0;
const float SIDE_TILE_M = 0.059690;
const float TOP_TILE_M = 0.048;
const float TOP_ROT = 0.6;
const float LINER_REPEATS = 2.0;
const float LINER_SPAN_M = 0.060240;
const float LINER_EDGE_V = 0.10;
const float GROW_RAMP = 0.08;
const float SIZE_MIN = 0.12;
const float STRETCH_K = 0.35;

const vec3 POCKET_COLOR = vec3(0.6514, 0.5209, 0.3419);    // #D3BF9E, linear
const vec3 HOOCH_COLOR = vec3(0.2542, 0.1878, 0.1170);     // #8A7860, linear
const vec3 HOOCH_OLD_COLOR = vec3(0.1022, 0.0802, 0.0595); // #5A5045, linear
const vec3 CRUST_COLOR = vec3(0.6105, 0.4969, 0.3185);     // #CDBB98, linear

float shape_time(float t) {
	return time_override >= 0.0 ? time_override : t;
}

// Fed level times rise: the art contract's u_level, above the inner floor.
float u_level() {
	return level_m * rise;
}

float hooch_th() {
	return hooch_depth * HOOCH_MAX_M;
}

// Liquid on top flattens the cap.
float hooch_flat() {
	return smoothstep(0.0, 0.15, hooch_depth);
}

// Height added at the cap center (it fades to 0 at the rim as 1 - r^2).
// Lumps fade out near the pole: the 48-triangle fan shares one center vertex, and lifting it
// alone draws the cap to a point (art review of 293b09c).
float cap_offset(vec2 xz, float t) {
	float lump = lumps * LUMPS_MAX_M * (fbm3(xz * 70.0) - 0.5) * 0.5 * smoothstep(0.0, 0.3, length(xz) / starter_r);
	float breath = motion_k * activity * BREATH_M * sin(t * 0.9 + 1.7);
	return (dome * DOME_MAX_M + lump + breath) * (1.0 - hooch_flat());
}

// Surface height above the floor on the cap.
float cap_height(vec2 xz, float t) {
	float r = clamp(length(xz) / starter_r, 0.0, 1.0);
	return u_level() + (1.0 - r * r) * cap_offset(xz, t);
}

// Height where the paste meets the glass (the rim).
float edge_height() {
	return u_level();
}

// Same stretch as the art contract (web strands at peak).
float stretch_amount() {
	// No web for rye: it rises as a bubbly paste, not a stretchy web (§20.3).
	return bubble_size * smoothstep(1.5, 2.3, rise) * (1.0 - step(0.001, crack));
}

vec3 grade(vec3 c) {
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(l), c, grade_saturation) * grade_value;
}

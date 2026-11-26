// Backdrop_placeholder: sage zellige tiles, out of focus (art-direction.md §2.1,
// §4). Unshaded, already soft, with a time-of-day tint. Placeholder until the
// pre-blurred image baked from Blender exists.
shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://src/view/shaders/noise.gdshaderinc"

// Art palette #A3B69F / #97AB91, grout #DCD4C4. Unshaded, so authored as the warm-lit
// result the preview shows (tile row, art-direction.md §3: hue 45 to 70, #A7A183).
uniform vec3 tile_a : source_color = vec3(0.680, 0.700, 0.540);
uniform vec3 tile_b : source_color = vec3(0.650, 0.672, 0.512);
uniform vec3 grout : source_color = vec3(0.870, 0.845, 0.780);
uniform vec3 tod_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float tile_m = 0.072;
uniform float blur = 0.22;           // edge softness in tile units (fake depth of field)
uniform float energy = 0.62;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xy / tile_m + vec2(0.5, 0.0);
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash12(cell);
	vec3 tile = mix(tile_a, tile_b, h);
	// Zellige glaze: a soft brightness swell per tile.
	vec2 c = f - 0.5;
	tile *= 1.0 + 0.06 * (vnoise(p * 3.0 + cell) - 0.5) - 0.05 * dot(c, c);
	float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float g = 1.0 - smoothstep(0.0, blur, e);
	vec3 col = mix(tile, grout, g * 0.55);
	// Light falls off toward the top and right, away from the window.
	float shade = mix(1.0, 0.86, clamp(v_world.y / 0.7, 0.0, 1.0)) * mix(1.04, 0.94, clamp(v_world.x + 0.5, 0.0, 1.0));
	ALBEDO = col * tod_tint * shade * energy;
}

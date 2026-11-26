// Starter body (Starter_Body). One opaque shader for every state (D-010).
// Vertex: art-direction.md §5. Fragment: the art masks with §16.4 and §16.5.
// Everything inside the glass is opaque (D-009).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/view/shaders/noise.gdshaderinc"
#include "res://src/view/shaders/starter_common.gdshaderinc"

// Masks are data, not color (art-direction.md §16.3): no source_color.
uniform sampler2D side_mask : filter_linear_mipmap, repeat_enable;
uniform sampler2D top_mask : filter_linear_mipmap, repeat_enable;

// Fake translucency (§16.5b). backlight_k is a per-renderer grade.
uniform vec3 scatter_color : source_color = vec3(0.890, 0.749, 0.561);   // #E3BF8F
uniform float backlight_k = 0.35;
uniform float rim_k = 0.10;
// 1 on renderers with clearcoat. 0 drops it and lowers the cap roughness (§16.5c).
uniform float clearcoat_on = 1.0;
// Pocket normal tilt toward the pocket center (§16.4 cue 3). A per-renderer grade.
uniform float pocket_tilt = 0.35;
// Pocket contrast and cap specular: per-renderer grades. Compatibility has no AgX, and its
// Filmic curve shows more contrast in the pockets and clips the cap highlight.
uniform float pocket_k = 1.0;
uniform float cap_spec = 1.0;
uniform float cap_value = 1.0;
// Hooch is mostly sky reflection, which Compatibility draws weaker.
uniform float hooch_value = 1.0;
uniform float hooch_desat = 0.0;

const float TAP = 1.5 / 512.0;
const vec2 LIGHT_UV = vec2(-0.35, 0.94);
const vec3 FLECK_COLOR = vec3(0.2542, 0.1413, 0.0648);   // #8A6A48, linear
const vec3 TINT_WHITE = vec3(0.9131, 0.8308, 0.6724);    // white_bread tint, linear
// Mold, art-direction.md §2.1 (moldy only).
const vec3 MOLD_HALO = vec3(0.9047, 0.9047, 0.8550);
const vec3 MOLD_RING = vec3(0.2747, 0.4342, 0.3712);
const vec3 MOLD_CORE = vec3(0.0284, 0.1779, 0.1301);
const vec3 MOLD_SPORE = vec3(0.0137, 0.0232, 0.0203);

varying vec3 v_pos;
varying vec3 v_nrm;
varying vec3 v_tan;

void vertex() {
	float t = shape_time(TIME);
	float w = UV2.y;
	float cap = w * (1.0 - UV2.x * UV2.x);
	VERTEX.y += w * (u_level() - authored_h) + cap * cap_offset(VERTEX.xz, t);
	vec3 n = NORMAL;
	if (NORMAL.y > 0.7 && w > 0.99) {
		// Macro normal of the displaced cap, from the height function.
		float e = 0.002;
		float hx = cap_height(VERTEX.xz + vec2(e, 0.0), t) - cap_height(VERTEX.xz - vec2(e, 0.0), t);
		float hz = cap_height(VERTEX.xz + vec2(0.0, e), t) - cap_height(VERTEX.xz - vec2(0.0, e), t);
		n = normalize(vec3(-hx, 2.0 * e, -hz));
		NORMAL = n;
	}
	v_pos = VERTEX;
	v_nrm = n;
	v_tan = TANGENT;
}

// m.r = F, m.a = P. Returns (air, depth 0 at the outline to 1 at the center, lip).
vec3 feature(vec4 m, float density, float size) {
	float grow = smoothstep(m.a, m.a + GROW_RAMP, density);
	float frac = (SIZE_MIN + (1.0 - SIZE_MIN) * size) * grow;
	if (frac < 0.002) {
		return vec3(0.0);
	}
	float thr = 1.0 - frac;
	float aa = min(max(fwidth(m.r), 0.01), frac * 0.5);
	float air = smoothstep(thr - aa, thr + aa, m.r);
	float depth = clamp((m.r - thr) / frac, 0.0, 1.0);
	float lip = smoothstep(thr - 0.35 * frac, thr, m.r) * (1.0 - air);
	return vec3(air, depth, lip);
}

// Mold colonies on the cap: frayed white halo, gray-green ring, blue-green core,
// dark spores (art-direction.md §6). Returns color in rgb, coverage in a.
vec4 mold_colony(vec2 xz) {
	if (mold <= 0.0) {
		return vec4(0.0);
	}
	float f;
	float rank;
	vec2 rel;
	feature_field(xz / 0.012, 0.0, 0.22, 0.42, 3.0, f, rank, rel);
	float show = smoothstep(rank, rank + 0.1, mold * 0.9);
	float fray = 0.12 * (vnoise(xz * 2400.0) - 0.5);
	float g = f + fray;
	float halo = smoothstep(0.0, 0.12, g);
	float ring = smoothstep(0.35, 0.45, g);
	float core = smoothstep(0.62, 0.72, g);
	vec3 c = mix(MOLD_HALO, MOLD_RING, ring);
	c = mix(c, MOLD_CORE, core);
	float spores = step(0.78, vnoise(xz * 3000.0)) * ring;
	c = mix(c, MOLD_SPORE, spores * 0.8);
	return vec4(c, halo * show);
}

void fragment() {
	float t = shape_time(TIME);
	vec3 p = v_pos;
	float lvl = u_level();

	// Side vs cap, from the normal of the displaced surface (§16.3).
	vec3 n_obj = normalize(v_nrm);
	// The rounded foot is pressed into the glass corner and lit through the thick base:
	// keep its normals near horizontal so it doesn't go dark.
	if (n_obj.y < 0.0) {
		vec3 radial = normalize(vec3(p.x, 0.0, p.z) + vec3(1e-5, 0.0, 0.0));
		n_obj = normalize(mix(n_obj, radial, 0.8));
	}
	float top_w = smoothstep(0.55, 0.85, n_obj.y);
	if (top_w > 0.0) {
		float e = 0.0006;
		float hx = cap_height(p.xz + vec2(e, 0.0), t) - cap_height(p.xz - vec2(e, 0.0), t);
		float hz = cap_height(p.xz + vec2(0.0, e), t) - cap_height(p.xz - vec2(0.0, e), t);
		vec3 n_cap = normalize(vec3(-hx, 2.0 * e, -hz));
		n_obj = normalize(mix(n_obj, n_cap, top_w));
	}

	// Hooch: a liquid band on the side, a flat disc on the cap.
	float th = hooch_th();
	float band = smoothstep(lvl - th - 0.0003, lvl - th + 0.0003, p.y) * step(0.0004, th);
	float in_hooch = max(band * (1.0 - top_w), top_w * hooch_flat());
	float band_frac = clamp((p.y - (lvl - th)) / max(th, 0.0004), 0.0, 1.0);
	float hooch_mix = mix(mix(0.45, 1.0, band_frac), 1.0, top_w);

	// Side features (bubbles pressed against the glass), §16.4.
	float stretch = stretch_amount();
	vec2 uv_side = vec2(UV.x * SIDE_REPEATS, -p.y / (SIDE_TILE_M * (1.0 + STRETCH_K * stretch)));
	vec4 ms = texture(side_mask, uv_side);
	float hfrac = clamp(p.y / max(lvl, 0.001), 0.0, 1.0);
	float big = big_bubble * (1.0 - smoothstep(0.02, 0.10, ms.a)) * 0.5;
	float size_s = clamp(bubble_size * (0.85 + 0.3 * hfrac) + big, 0.0, 1.0);
	vec3 fs = feature(ms, bubble_density, size_s);
	float gx = texture(side_mask, uv_side + vec2(TAP, 0.0)).r - ms.r;
	float gy = texture(side_mask, uv_side - vec2(0.0, TAP)).r - ms.r;
	float facing = dot(vec2(gx, gy), LIGHT_UV) / max(length(vec2(gx, gy)), 1e-4);
	float cav_s = (0.82 + 0.22 * facing * (1.0 - fs.y * fs.y)) * (1.0 - 0.5 * fs.x * (1.0 - fs.x));
	// Small bubbles are shallow: less cavity shade.
	float depth_k = smoothstep(0.15, 0.6, size_s);
	cav_s = mix(1.0, cav_s, mix(0.55, 1.0, depth_k));

	// Cap features (open pits), §16.4.
	float cr = cos(TOP_ROT);
	float sr = sin(TOP_ROT);
	vec2 uv_top = vec2(p.x * cr + p.z * sr, p.z * cr - p.x * sr) / TOP_TILE_M;
	vec4 mt = texture(top_mask, uv_top);
	vec3 ft = feature(mt, bubble_density * 0.9, bubble_size * 0.8);
	float cav_t = 0.86 - 0.28 * ft.y;

	float air = mix(fs.x, ft.x, top_w) * (1.0 - in_hooch);
	float dep = mix(fs.y, ft.y, top_w);
	float cav = mix(cav_s, cav_t, top_w);

	// Paste: flour tint, a 0.96 to 1.02 tone from fine noise and a low mottle (§16.5a).
	vec2 tone_p = mix(vec2(UV.x * 0.2388, p.y), p.xz, top_w);
	float tone = 0.96 + 0.035 * vnoise(tone_p * 900.0) + 0.025 * vnoise(tone_p * 80.0);
	vec3 paste = tint * tone;
	vec3 flour_ratio = tint / TINT_WHITE;
	float dry = surface_dryness * top_w;
	paste = mix(paste, CRUST_COLOR * flour_ratio, dry * 0.85);
	// Fine crackle on a dry skin.
	float crack = (1.0 - smoothstep(0.02, 0.06, cell_edge(p.xz / 0.0025))) * dry;
	paste *= 1.0 - 0.18 * crack;
	// Bran flecks (whole_wheat, rye).
	float fl = step(1.0 - 0.05 * fleck, vnoise(tone_p * 2600.0)) * step(0.001, fleck);
	paste = mix(paste, FLECK_COLOR, fl * 0.7);
	// Unhealthy: a little grayer and duller, never a new hue.
	float l = dot(paste, vec3(0.2126, 0.7152, 0.0722));
	paste = mix(paste, vec3(l) * 0.94, 0.3 * dullness);

	paste *= mix(1.0, cap_value, top_w);
	vec3 pocket = POCKET_COLOR * flour_ratio;
	pocket = mix(vec3(dot(pocket, vec3(0.2126, 0.7152, 0.0722))), pocket, 1.25);
	vec3 albedo = mix(paste, pocket, air * (0.55 + 0.35 * dep) * pocket_k);
	albedo *= mix(1.0, cav, air * pocket_k);

	vec3 hooch_col = mix(HOOCH_COLOR, HOOCH_OLD_COLOR, dullness) * mix(vec3(1.0), flour_ratio, 0.5);
	hooch_col = mix(hooch_col, vec3(dot(hooch_col, vec3(0.2126, 0.7152, 0.0722))), hooch_desat) * hooch_value;
	albedo = mix(albedo, hooch_col, in_hooch * hooch_mix);

	vec4 colony = mold_colony(p.xz) * top_w;
	albedo = mix(albedo, colony.rgb, colony.a);

	// Gloss (§16.5a and c). The side touches the glass, its gloss lives in the pockets.
	float r_cap = mix(0.55, 0.24, sheen) - 0.06 * (1.0 - clearcoat_on);
	float rough = mix(0.62, r_cap, top_w);
	rough = mix(rough, 0.18, air);
	rough = mix(rough, 0.8, dry);
	rough = mix(rough, 0.04, in_hooch);
	rough = mix(rough, 0.9, colony.a);

	// Pocket normal tilt toward the pocket center (§16.4 cue 3): the glint lands on the lower
	// wall and follows the camera. TANGENT points along +UV.x, the mask's +u.
	float g_len = length(vec2(gx, gy));
	if (top_w < 1.0 && g_len > 1e-4) {
		vec2 g = vec2(gx, gy) / g_len;
		vec3 t_raw = v_tan - n_obj * dot(v_tan, n_obj);
		vec3 tan_u = dot(t_raw, t_raw) > 1e-6 ? normalize(t_raw) : normalize(vec3(-n_obj.z, 0.0, n_obj.x));
		vec3 up_t = normalize(vec3(0.0, 1.0, 0.0) - n_obj * n_obj.y);
		float tilt = pocket_tilt * fs.x * (1.0 - fs.y) * (1.0 - top_w) * (1.0 - in_hooch) * smoothstep(0.0, 0.03, g_len) * mix(0.3, 1.0, depth_k);
		n_obj = normalize(n_obj + (tan_u * g.x + up_t * g.y) * tilt);
	}
	NORMAL = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * n_obj));
	ALBEDO = grade(albedo);
	ROUGHNESS = rough;
	SPECULAR = mix(mix(0.3, 0.5 * cap_spec, top_w), 0.5, max(air, in_hooch));
	CLEARCOAT = clearcoat_on * sheen * mix(0.25, 0.6, top_w) * (1.0 - dry) * (1.0 - colony.a);
	CLEARCOAT_ROUGHNESS = 0.08;
	float thru = (1.0 - 0.75 * air) * (1.0 - in_hooch) * (1.0 - dry) * (1.0 - colony.a);
	BACKLIGHT = scatter_color * backlight_k * thru;
	RIM = rim_k * (1.0 - 0.75 * air) * (1.0 - in_hooch);
	RIM_TINT = 0.5;
}

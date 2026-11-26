// Small hash, noise and feature-field helpers shared by the view shaders.
// 2D only: no 3D noise at runtime (art-direction.md §4).

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm3(vec2 p) {
	float amp = 0.5;
	float sum = 0.0;
	for (int i = 0; i < 3; i++) {
		sum += amp * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		amp *= 0.5;
	}
	return sum / 0.875;
}

// Feature field with the same meaning as the art masks (art-direction.md §16,
// art/textures/make_starter_masks.py), so the masks can replace it 1:1:
//   F = 1 - rho inside a feature (rho 0 at its center, 1 at its full-size edge),
//       0 outside. Thresholding F at 1 - s shows every feature scaled to s.
//   P = presence rank 0.02..0.90. A feature shows when density > P.
//       Big features get low ranks, so they appear first.
// Also returns rel, the position inside the nearest feature (-1..1, irregular),
// used for the concave pocket normal.
// p is in cells. period_x > 0 wraps x (around the cylinder).
// rmin, rmax: radius range in cells (0..0.5). Sizes follow a power law.
void feature_field(vec2 p, float period_x, float rmin, float rmax, float seed,
		out float f_out, out float p_out, out vec2 rel_out) {
	vec2 ip = floor(p);
	vec2 fp = p - ip;
	float best_rho = 9.0;
	f_out = 0.0;
	p_out = 1.0;
	rel_out = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = vec2(float(i), float(j));
			vec2 id = ip + cell;
			if (period_x > 0.0) {
				id.x = mod(id.x, period_x);
			}
			id += vec2(seed * 7.13, seed * 3.71);
			vec2 h = hash22(id);
			vec2 h2 = hash22(id + vec2(41.3, 17.9));
			float size_u = h.y * h.y * h.y;
			float r = mix(rmin, rmax, size_u);
			vec2 c = cell + 0.5 + (h - 0.5) * (1.0 - 2.0 * r);
			vec2 dv = fp - c;
			// Irregular outline: a soft lobed radius and a slight squash.
			float ang = atan(dv.y, dv.x);
			float wob = 1.0 + 0.13 * sin(3.0 * ang + h2.x * 6.2831853) + 0.07 * sin(5.0 * ang + h2.y * 6.2831853);
			vec2 sq = dv * vec2(1.0, 1.0 + 0.35 * (h2.x - 0.5));
			float rho = length(sq) / (r * wob);
			if (rho < best_rho) {
				best_rho = rho;
				rel_out = sq / (r * wob);
				// Rank: mostly random, biased so big features come first.
				p_out = mix(0.02, 0.90, mix(hash12(id + vec2(5.1, 9.7)), 1.0 - size_u, 0.45));
			}
		}
	}
	f_out = max(1.0 - best_rho, 0.0);
}

// Distance to the nearest cell edge of a jittered grid (crackle on a dry skin).
float cell_edge(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = p - ip;
	float d1 = 9.0;
	float d2 = 9.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = vec2(float(i), float(j));
			vec2 c = cell + 0.15 + 0.7 * hash22(ip + cell);
			float d = length(fp - c);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

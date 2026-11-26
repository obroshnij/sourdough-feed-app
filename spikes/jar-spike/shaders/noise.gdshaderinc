// Small hash and noise helpers shared by the spike shaders.

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

float fbm(vec2 p) {
	float amp = 0.5;
	float sum = 0.0;
	for (int i = 0; i < 4; i++) {
		sum += amp * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		amp *= 0.5;
	}
	return sum;
}

// Procedural bubbles: a Voronoi-style field where some cells hold a round
// bubble. p is measured in cells. period_x > 0 wraps x (for the cylinder side).
// Sizes follow a power law (many small, a few large).
// Returns k (1 at a bubble center, 0 at its edge, 0 outside), the gradient of k
// with respect to p, a per-bubble random value, and the position inside the
// bubble (rel, -1..1 on each axis).
void bubble_field(vec2 p, float period_x, float density, float rmin, float rmax,
		float pulse_t, float pulse_amt, out float k_out, out vec2 grad_out, out float rnd_out, out vec2 rel_out) {
	vec2 ip = floor(p);
	vec2 fp = p - ip;
	k_out = 0.0;
	grad_out = vec2(0.0);
	rnd_out = 0.0;
	rel_out = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cell = vec2(float(i), float(j));
			vec2 id = ip + cell;
			if (period_x > 0.0) {
				id.x = mod(id.x, period_x);
			}
			vec2 h = hash22(id);
			if (hash12(id + vec2(31.7, 11.3)) > density) {
				continue;
			}
			float r = mix(rmin, rmax, h.y * h.y * h.y) * (1.0 + pulse_amt * sin(pulse_t + h.x * 6.2831853));
			vec2 c = cell + r + (1.0 - 2.0 * r) * h;
			vec2 dv = fp - c;
			float k = 1.0 - dot(dv, dv) / (r * r);
			if (k > k_out) {
				k_out = k;
				grad_out = -2.0 * dv / (r * r);
				rnd_out = h.x;
				rel_out = dv / r;
			}
		}
	}
}

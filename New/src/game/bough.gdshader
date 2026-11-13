shader_type canvas_item;
// 2026-11-13 (the director: the bare bar of earth high under the vine, row 3: "a great bough of the riverside figs the
// liana hangs from, in the canopy's wood language"): a one-row wall floating high in the air is drawn as a bough of the
// figs (TerrainView), as canopy.png's are: rounded bark lit from the upper left, its grain running along it, knots, a
// warm dark under it, moss on its back, a soft ink line, in the trees' shade (`tint`: CanopyView.SHADE). Painted here in
// its units over one rectangle; where it is solid is the map's, unchanged.

uniform vec2 size = vec2(600.0, 80.0);  // units: the rectangle
uniform float mid = 36.0;  // units from the top to the bough's middle line
uniform float half_t = 13.0;  // units: its half thickness
uniform float reach = 12.0;  // units its rounded ends reach in from the rectangle's sides
uniform float seed = 1.0;
uniform vec4 tint : source_color = vec4(0.66, 0.72, 0.8, 1.0);

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i.x + i.y * 57.0);
	float b = hash(i.x + 1.0 + i.y * 57.0);
	float c = hash(i.x + (i.y + 1.0) * 57.0);
	float d = hash(i.x + 1.0 + (i.y + 1.0) * 57.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 p = UV * size;
	float w = size.x;
	// its line wanders and its girth swells and thins; bulges where a knot is
	float yc = mid + (noise(p.x * 0.005 + seed) - 0.5) * 14.0 + (noise(p.x * 0.019 + seed * 3.0) - 0.5) * 6.0;
	float t = half_t * (0.72 + 0.5 * noise(p.x * 0.009 + seed * 5.0));
	float knot_d = 99.0;
	vec2 knot_q = vec2(0.0);
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float kx = w * (0.08 + 0.84 * hash(seed * 1.3 + fi * 7.7));
		float kr = 5.0 + 5.0 * hash(seed + fi * 3.1);
		vec2 q = (p - vec2(kx, yc - t * (hash(seed + fi * 5.3) - 0.5) * 0.9)) / vec2(1.7, 1.0);
		float d = length(q) - kr;
		if (d < knot_d) {
			knot_d = d;
			knot_q = q / kr;
		}
		t += 3.0 * exp(-pow((p.x - kx) / 14.0, 2.0)) * step(0.5, hash(seed + fi * 9.9));
	}
	// the ends rounded (where the wall stops it ends as a broken-off limb, not a cut)
	float e = min(p.x - reach, w - reach - p.x);
	float end_t = e < 0.0 ? sqrt(max(1.0 - pow(-e / reach, 2.0), 0.0)) : 1.0;
	t *= end_t;
	float top = yc - t + (noise(p.x * 0.17 + seed) - 0.5) * 2.4;
	float bottom = yc + t + (noise(p.x * 0.13 + seed * 2.0) - 0.5) * 3.0;
	float inside = min(p.y - top, bottom - p.y);
	float a = smoothstep(-0.7, 0.7, inside) * step(0.02, end_t);
	if (a <= 0.002) {
		discard;
	}
	float v = clamp((p.y - top) / max(bottom - top, 1.0), 0.0, 1.0);  // 0 on its back, 1 under it
	// the bark: canopy.png's browns, lit from above-left (round), its grain along it, darker grooves
	vec3 dark = vec3(0.3, 0.18, 0.11);
	vec3 midc = vec3(0.5, 0.32, 0.18);
	vec3 lit = vec3(0.78, 0.5, 0.26);
	float light = clamp(1.0 - abs(v - 0.28) * 2.2, 0.0, 1.0);
	vec3 c = mix(mix(dark, midc, smoothstep(0.95, 0.45, v)), lit, pow(light, 2.0) * 0.8);
	float grain = noise2(vec2(p.x * 0.035, v * 9.0 + seed));
	c *= 0.84 + 0.3 * grain;
	float groove = smoothstep(0.62, 0.7, noise2(vec2(p.x * 0.05 + seed, v * 5.0)));
	c = mix(c, dark * 0.75, groove * 0.55);
	// knots: a dark hollow, a lit lip on its upper left
	float k = 1.0 - smoothstep(-0.6, 0.6, knot_d);
	c = mix(c, dark * 0.6, k * smoothstep(0.7, 0.2, length(knot_q)));
	c = mix(c, lit * 1.05, k * smoothstep(0.55, 0.95, length(knot_q)) * smoothstep(0.0, -0.6, knot_q.x + knot_q.y));
	// moss on its back
	float moss = smoothstep(0.55, 0.75, noise(p.x * 0.07 + seed * 4.0)) * (1.0 - smoothstep(0.08, 0.3 + 0.15 * noise(p.x * 0.3), v));
	c = mix(c, mix(vec3(0.33, 0.38, 0.16), vec3(0.52, 0.54, 0.22), light), moss * 0.85);
	// the ink round it (the canopy's soft dark line, not a character's black)
	float line = 1.0 - smoothstep(1.2, 2.2, inside);
	// the light caught along its back, broken
	c = mix(c, min(lit * 1.25, vec3(1.0)), (1.0 - smoothstep(0.0, 0.12, v)) * smoothstep(0.35, 0.6, noise(p.x * 0.05 + seed * 7.0)) * 0.6);
	c = mix(c, vec3(0.2, 0.11, 0.07), line * 0.85);
	COLOR = vec4(c * tint.rgb, a);
}

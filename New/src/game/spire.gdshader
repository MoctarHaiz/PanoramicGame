shader_type canvas_item;
// Round 20 (the judges, j16: "the two river pillars identical chimneys"; round 19's spires.png columns read as
// cardboard with ruled lines): a stack of rock standing in the river or on the plain (TerrainView), painted
// here in its units as the plain's carved pillar is (terrain.gdshader): a cap rock under its grass mat with an
// undercut below it, a shaft of a few big blocks, each cut across in big planes lit from the upper left (a bright
// face, a mid face, a cool violet shadow face with warm bounce light low down), a lit shelf and an overhang's
// shadow at some joints, lighter at the top and darker to its flared foot, moss dripping from the cap. Each one
// its own: width, taper, waist, chips out of its sides, a small ledge on some, its tint (`seed`). In the river its
// foot sinks into the water (murky, then gone) with foam lapping round it.

uniform vec2 size = vec2(96.0, 400.0);  // units: the rectangle (the column is centred in it)
uniform float half_w = 22.0;  // units: the shaft's half width at its middle
uniform float water_y = -1.0;  // units from the top to the waterline (< 0: standing on the ground)
uniform float foot_y = 400.0;  // units from the top to its foot (where it meets the ground or the waterline)
uniform float level_x = 0.0;  // level x of the rectangle's left side (the water's waves)
uniform float seed = 1.0;

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
	float y = p.y;
	float height = foot_y;
	float down = clamp(y / max(height, 1.0), 0.0, 1.0);
	// (each leans its own way a little: its top stays on the walkable cell, its foot drifts)
	float cx = size.x * 0.5 + (hash(seed * 12.7) - 0.5) * 18.0 * down * down;
	// the cap rock and the undercut under it
	float cap_h = 22.0 + 6.0 * hash(seed * 1.3);
	float cap = 1.0 - smoothstep(cap_h - 2.0, cap_h + 2.0, y);
	float tuck = smoothstep(cap_h, cap_h + 6.0, y) * (1.0 - smoothstep(cap_h + 10.0, cap_h + 40.0, y));
	// blocks down the shaft, each its own height and its own step in or out
	float bc = (y - cap_h) / (100.0 + 70.0 * hash(seed * 2.7)) + 0.16 * sin(y * 0.019 + seed)
			+ (p.x - cx) / max(half_w, 1.0) * 0.08 * (hash(seed * 3.9) > 0.5 ? 1.0 : -1.0)  // (joints slant ..
			+ (noise(p.x * 0.11 + seed) - 0.5) * 0.06;  // .. and wander)
	float bk = floor(bc);
	float bfr = fract(bc);
	float step_l = (hash(bk * 7.7 + seed) - 0.5) * 0.24;
	float step_r = (hash(bk * 5.3 + seed * 1.9) - 0.5) * 0.24;
	// its width down its height: a waist, a taper to the top, a flared foot
	float waist = 0.45 + 0.25 * hash(seed * 4.1);
	float prof = 1.0 - 0.14 * hash(seed * 3.3) * exp(-pow((down - waist) / 0.22, 2.0));
	prof *= mix(0.86, 1.0, smoothstep(0.0, 0.6, down));
	prof += (water_y > 0.0 ? 0.28 : 0.45) * pow(smoothstep(0.72, 1.0, down), 2.0);
	float hl = half_w * (prof + step_l * smoothstep(cap_h + 20.0, cap_h + 40.0, y)) - 6.0 * tuck;
	float hr = half_w * (prof + step_r * smoothstep(cap_h + 20.0, cap_h + 40.0, y)) - 6.0 * tuck;
	hl = mix(hl, half_w * 1.12, cap);
	hr = mix(hr, half_w * 1.12, cap);
	// a gentle wobble, and chips knocked out of its sides
	hl += (noise(y * 0.06 + seed * 3.0) - 0.5) * 3.0;
	hr += (noise(y * 0.07 + seed * 5.0) - 0.5) * 3.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float at = (0.22 + 0.6 * hash(seed + fi * 3.7)) * height;
		float chip = max(0.0, 1.0 - abs(y - at) / (6.0 + 6.0 * hash(seed + fi * 1.1))) * (3.0 + 5.0 * hash(seed + fi * 8.3));
		if (hash(seed + fi * 2.2) < 0.5) {
			hl -= chip;
		} else {
			hr -= chip;
		}
	}
	// a small ledge out of one side on some (moss on its top)
	float has_ledge = step(0.45, hash(seed * 6.6));
	float ledge_y = (0.32 + 0.3 * hash(seed * 7.9)) * height;
	float ledge_side = hash(seed * 8.8) < 0.5 ? -1.0 : 1.0;
	float lt = (y - ledge_y) / 20.0;
	float ledge_out = has_ledge * (lt > 0.0 && lt < 1.0 ? (8.0 + 5.0 * hash(seed * 9.4)) * sqrt(max(1.0 - lt * lt, 0.0)) * smoothstep(0.0, 0.12, lt) : 0.0);
	if (ledge_side < 0.0) {
		hl += ledge_out;
	} else {
		hr += ledge_out;
	}
	float left = cx - hl;
	float right = cx + hr;
	float in_l = p.x - left;
	float in_r = right - p.x;
	float body = smoothstep(-0.7, 0.7, min(in_l, in_r));
	// the top: rounded into the grass mat
	body *= smoothstep(-0.5, 1.0, y - 2.0 - 4.0 * pow(abs(p.x - cx) / max(half_w * 1.12, 1.0), 4.0) * 4.0);
	// over a pit: it fades out under the screen
	body *= 1.0 - smoothstep(size.y - 30.0, size.y, y);
	if (body <= 0.002) {
		discard;
	}
	float ue = clamp(in_l / max(hl + hr, 1.0), 0.0, 1.0);
	float j1 = 0.18 + 0.14 * hash(bk * 1.7 + seed * 5.1) + (bfr - 0.5) * (hash(bk * 3.3 + seed) - 0.5) * 0.4;
	float j2 = 0.46 + 0.12 * hash(bk * 2.9 + seed * 1.3);
	float j3 = 0.68 + 0.12 * hash(bk * 4.3 + seed * 2.3) + (bfr - 0.5) * (hash(bk * 8.7 + seed) - 0.5) * 0.36;
	float s1 = smoothstep(j1 - 0.02, j1 + 0.02, ue);
	float s2 = smoothstep(j2 - 0.02, j2 + 0.02, ue);
	float s3 = smoothstep(j3 - 0.02, j3 + 0.02, ue);
	// its tint: a little redder, paler or rosier than the next
	float tint = hash(seed * 11.1);
	vec3 lit_p = mix(vec3(1.0, 0.73, 0.49), vec3(1.0, 0.78, 0.58), step(0.6, tint));
	vec3 mid_p = mix(vec3(0.88, 0.55, 0.41), vec3(0.82, 0.5, 0.44), step(0.35, tint));
	vec3 low_p = mid_p * vec3(0.9, 0.86, 0.94);
	vec3 shd_p = vec3(0.43, 0.29, 0.4);
	vec3 c = mix(mix(mix(lit_p, mid_p, s1), low_p, s2), shd_p, s3);
	c *= 1.0 + 0.1 * (1.0 - s1) * (1.0 - ue / max(j1, 0.01));
	c = mix(c, min(c * 1.25, vec3(1.0)), (1.0 - smoothstep(0.0, 0.03, abs(ue - j1 - 0.02))) * 0.5);
	c = mix(c, c + vec3(0.14, 0.06, 0.0), s3 * smoothstep(0.82, 1.0, ue) * smoothstep(0.45, 1.0, down) * 0.7);
	// the sandstone's beds as soft tone, painted mottling
	float bed_y = y + (noise(p.x * 0.05 + seed) - 0.5) * 4.0;
	float tone_b = noise(bed_y * 0.07 + seed * 3.0);
	c *= mix(vec3(1.0), vec3(1.07, 0.95, 0.92), smoothstep(0.55, 0.85, tone_b));
	c *= mix(vec3(1.0), vec3(0.93, 0.95, 1.03), smoothstep(0.42, 0.15, tone_b));
	c *= 0.93 + 0.09 * noise2(p * vec2(0.06, 0.05) + seed) + 0.04 * noise2(p * vec2(0.3, 0.25));
	// joints: the block above's underside, a lit shelf, the overhang's shadow (most of them)
	float joint_on = step(0.45, hash(bk * 7.31 + seed * 3.7)) * smoothstep(cap_h + 24.0, cap_h + 40.0, y) * (1.0 - smoothstep(0.85, 0.95, down));
	c *= 1.0 - 0.5 * smoothstep(0.955, 0.99, bfr) * joint_on;
	c = mix(c, min(c * 1.25 + vec3(0.05, 0.03, 0.0), vec3(1.0)), (1.0 - smoothstep(0.0, 0.035, bfr)) * joint_on * 0.55);
	c *= 1.0 - 0.28 * smoothstep(0.03, 0.05, bfr) * (1.0 - smoothstep(0.05, 0.3, bfr)) * joint_on;
	// the cap rock: its top lit, its underside dark over the undercut
	c = mix(c, c * 1.12, cap * (1.0 - smoothstep(4.0, cap_h, y)));
	c *= 1.0 - 0.55 * smoothstep(cap_h - 4.0, cap_h + 1.0, y) * exp(-max(y - cap_h, 0.0) / 14.0);
	c = mix(c, c * vec3(0.8, 0.78, 1.0), exp(-max(y - cap_h, 0.0) / 24.0) * smoothstep(cap_h - 4.0, cap_h, y) * 0.6);
	// the ledge: its top lit and mossy, a shadow under it on the shaft
	float ledge_zone = ledge_side < 0.0 ? step(in_l, ledge_out + 2.0) : step(in_r, ledge_out + 2.0);
	float on_ledge = has_ledge * step(0.0, lt) * step(lt, 1.0) * ledge_zone;
	c = mix(c, vec3(0.42, 0.56, 0.2), on_ledge * (1.0 - smoothstep(0.12, 0.32, lt)) * 0.9);
	c *= 1.0 - 0.3 * on_ledge * smoothstep(0.5, 1.0, lt);  // (its rounded underside turning from the light)
	c *= 1.0 - 0.35 * has_ledge * smoothstep(0.9, 1.2, lt) * (1.0 - smoothstep(1.2, 2.6, lt));
	// moss: dripping from under the cap in a few thin tongues
	float tongue = cap_h + 1.0 + 14.0 * pow(noise(p.x * 0.11 + seed * 7.0), 3.0) + 26.0 * pow(noise(p.x * 0.19 + seed), 8.0);
	float moss = (1.0 - smoothstep(tongue - 1.0, tongue + 1.0, y)) * step(cap_h - 3.0, y);
	vec3 moss_c = mix(vec3(0.26, 0.36, 0.13), vec3(0.4, 0.52, 0.18), step(0.5, noise2(p * vec2(0.12, 0.16))));
	c = mix(c, moss_c * mix(1.0, 0.55, s3), moss * 0.85);
	// under the grass mat: its shade (dark earth and roots where the mat's blades part)
	c = mix(c, vec3(0.2, 0.14, 0.1) * (0.8 + 0.4 * noise2(p * 0.3)), (1.0 - smoothstep(10.0, 16.0, y)) * 0.85
			* (1.0 - smoothstep(16.0, 22.0, abs(p.x - cx))));
	// the light falls off down it, cooler toward its foot; a dark foot
	c *= mix(1.04, 0.68, smoothstep(0.0, 1.0, down));
	c = mix(c, c * vec3(0.86, 0.84, 1.0), smoothstep(0.45, 1.0, down) * 0.5);
	c *= 1.0 - 0.4 * smoothstep(height - 50.0, height, y);
	// a thin soft dark line round it, a warm light edge on its sun side
	float edge = min(in_l, in_r);
	c = mix(c, min(c * 1.35 + vec3(0.06, 0.03, 0.0), vec3(1.0)), (1.0 - smoothstep(1.5, 3.0, in_l)) * step(1.2, in_l) * (1.0 - cap) * 0.5);
	c = mix(c, vec3(0.2, 0.1, 0.12), (1.0 - smoothstep(0.6, 1.6, edge)) * 0.75);
	float a = body;
	// in the river: under the waterline murky and bluer, then gone; foam lapping round it
	if (water_y > 0.0) {
		float x = p.x + level_x;
		float surface = water_y + sin(x * 0.045 + TIME * 1.7) * 1.6 + sin(x * 0.13 - TIME * 2.6) * 0.8;
		float d = y - surface;
		// (the water's own colours, as water_front.gdshader tints the cell it stands in: the two agree)
		vec3 murk = mix(vec3(0.1, 0.36, 0.4), vec3(0.02, 0.1, 0.24), clamp((d - 3.0) / 46.0, 0.0, 1.0));
		c = mix(c, murk, smoothstep(0.0, 5.0, d) * 0.92);
		a *= 1.0 - smoothstep(3.0, 22.0, d);
		float lap = (1.0 - smoothstep(0.0, 2.6, abs(d - 0.6))) * (0.65 + 0.35 * sin(x * 0.9 + TIME * 3.1));
		c = mix(c, vec3(0.97, 1.0, 1.0), lap * 0.9);
	}
	COLOR = vec4(c, a);
}

shader_type canvas_item;
// Round 20 (the judges, j16: "the two river pillars identical chimneys"; round 19's spires.png columns read as
// cardboard with ruled lines): a stack of rock standing in the river or on the plain (TerrainView), painted
// here in its units as the plain's carved pillar is (terrain.gdshader): a cap rock under its grass mat with an
// undercut below it, a shaft of a few big blocks, each cut across in big planes lit from the upper left (a bright
// face, a mid face, a cool violet shadow face with warm bounce light low down), a lit shelf and an overhang's
// shadow at some joints, lighter at the top and darker to its flared foot, moss dripping from the cap. Each one
// its own: width, taper, waist, chips out of its sides, a small ledge on some, its tint (`seed`). In the river its
// foot sinks into the water (murky, then gone) with foam lapping round it.
// Round 21 (the judges, j17: "the river pillars thin straight telephone poles / bamboo, no base"): a body that
// tapers from its top (the walkable cell, unchanged) to a foot twice as wide or more (`base_w`), two broken ledges
// jutting from its sides (a lit, mossy top, a dark underside, a jagged end), and a base of fallen boulders heaped
// round its foot, half sunk in the water (or the ground), foam lapping round them.

uniform vec2 size = vec2(96.0, 400.0);  // units: the rectangle (the column is centred in it)
uniform float half_w = 22.0;  // units: the shaft's half width under its cap
uniform float base_w = 40.0;  // round 21: units: its half width at its foot
uniform float rubble = 1.0;  // round 21: 1: boulders heaped round its foot (0: over a pit, none)
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
	// (round 21: its rectangle is wide for its foot and boulders: what lies past the widest it can be at this height,
	// its ledges included, is left at once, before the work)
	float reach_max = half_w * 1.45 + (base_w - half_w) * pow(down, 1.25) + 26.0;
	float base_y = water_y > 0.0 ? water_y : foot_y;
	if (abs(p.x - cx) > reach_max && (rubble < 0.5 || y < base_y - 46.0)) {
		discard;
	}
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
	// its width down its height (round 21): from its cap's width down to base_w at its foot, a waist, a flare
	float waist = 0.45 + 0.25 * hash(seed * 4.1);
	float spread = base_w / max(half_w, 1.0) - 1.0;
	float prof = 1.0 + spread * pow(down, 1.25);
	prof *= 1.0 - 0.1 * hash(seed * 3.3) * exp(-pow((down - waist) / 0.2, 2.0));
	prof += 0.3 * pow(smoothstep(0.8, 1.0, down), 2.0);
	float hl = half_w * (prof + step_l * smoothstep(cap_h + 20.0, cap_h + 40.0, y)) - 6.0 * tuck;
	float hr = half_w * (prof + step_r * smoothstep(cap_h + 20.0, cap_h + 40.0, y)) - 6.0 * tuck;
	hl = mix(hl, half_w * 1.12, cap);
	hr = mix(hr, half_w * 1.12, cap);
	// a gentle wobble, and chips knocked out of its sides
	hl += (noise(y * 0.06 + seed * 3.0) - 0.5) * 4.0;
	hr += (noise(y * 0.07 + seed * 5.0) - 0.5) * 4.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float at = (0.22 + 0.6 * hash(seed + fi * 3.7)) * height;
		float chip = max(0.0, 1.0 - abs(y - at) / (6.0 + 6.0 * hash(seed + fi * 1.1))) * (3.0 + 6.0 * hash(seed + fi * 8.3));
		if (hash(seed + fi * 2.2) < 0.5) {
			hl -= chip;
		} else {
			hr -= chip;
		}
	}
	// round 21: two broken ledges jutting out of its sides (one each side), each a shelf with a rounded underside
	// and a jagged end; their tops lit and mossy
	float on_ledge = 0.0;  // 1 on a ledge's shelf, its depth into it 0..1 in lt_on
	float lt_on = 0.0;
	float under_ledge = 0.0;  // the shadow a ledge casts on the shaft under it
	float first_side = hash(seed * 8.8) < 0.5 ? -1.0 : 1.0;
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float ly = (0.26 + 0.3 * fi + 0.1 * hash(seed * 7.9 + fi)) * height;
		float side = fi < 0.5 ? first_side : -first_side;
		float thick = 16.0 + 8.0 * hash(seed * 2.1 + fi);
		float lt = (y - ly) / thick;
		float reach = (9.0 + 9.0 * hash(seed * 9.4 + fi)) * (0.75 + 0.5 * noise(y * 0.4 + seed + fi * 9.0));
		float jut = (lt > 0.0 && lt < 1.0) ? reach * sqrt(max(1.0 - lt * lt, 0.0)) * smoothstep(0.0, 0.1, lt) : 0.0;
		if (side < 0.0) {
			hl += jut;
		} else {
			hr += jut;
		}
		float zone = side < 0.0 ? step(p.x, cx - hl + jut + 2.0) : step(cx + hr - jut - 2.0, p.x);
		float here = step(0.0, lt) * step(lt, 1.0) * zone;
		on_ledge = max(on_ledge, here);
		lt_on = here > 0.5 ? lt : lt_on;
		under_ledge = max(under_ledge, smoothstep(0.95, 1.15, lt) * (1.0 - smoothstep(1.15, 2.6, lt))
				* (side < 0.0 ? 1.0 - smoothstep(0.0, 0.6, (p.x - (cx - hl)) / max(hl + hr, 1.0)) : smoothstep(0.4, 1.0, (p.x - (cx - hl)) / max(hl + hr, 1.0))));
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
	// round 21: boulders fallen from it, heaped round its foot (half sunk in the water or the ground), each lit
	// from the upper left, dark under, a soft ink rim
	float base_line = water_y > 0.0 ? water_y : foot_y;
	float rub = 0.0;
	vec3 rub_c = vec3(0.0);
	if (rubble > 0.5 && y > base_line - 46.0) {
		for (int i = 0; i < 7; i++) {
			float fi = float(i);
			float u = (fi + 0.2 + 0.6 * hash(seed * 3.1 + fi)) / 7.0;
			float bx = cx + (u * 2.0 - 1.0) * (base_w + 20.0);
			float r = (10.0 + 12.0 * hash(seed * 5.7 + fi * 1.3)) * (1.0 - 0.4 * abs(u * 2.0 - 1.0));
			float by = base_line + 4.0 - r * 0.55;
			vec2 q = (p - vec2(bx, by)) / vec2(1.3, 1.0);
			float d = length(q) - r;
			d += (noise(atan(q.y, q.x) * 1.6 + fi * 7.0 + seed) - 0.5) * r * 0.3;
			float m = 1.0 - smoothstep(-0.7, 0.7, d);
			if (m > 0.001) {
				vec2 n = q / max(r, 1.0);
				float lit = clamp(0.5 - n.x * 0.55 - n.y * 0.75, 0.0, 1.0);
				vec3 bc = mix(vec3(0.24, 0.15, 0.19), vec3(0.8, 0.54, 0.42), lit) * (0.8 + 0.3 * hash(seed + fi * 4.4));
				bc = mix(bc, vec3(0.3, 0.38, 0.16) * (0.7 + 0.6 * lit), smoothstep(0.55, 0.8, noise2(p * 0.16 + fi * 3.0)) * step(n.y, -0.2) * 0.7);  // (moss on some tops)
				bc *= 0.92 + 0.12 * noise2(p * 0.35 + fi);
				bc *= mix(1.0, 0.62, smoothstep(base_line - 5.0, base_line + 1.0, y));  // (wet at the waterline)
				bc = mix(bc, vec3(0.2, 0.1, 0.12), smoothstep(-2.2, -0.2, d) * 0.7);
				rub_c = mix(rub_c, bc, m);
				rub = max(rub, m);
			}
		}
	}
	if (body <= 0.002 && rub <= 0.002) {
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
	c = mix(c, min(c * 1.2 + vec3(0.05, 0.03, 0.0), vec3(1.0)), on_ledge * (1.0 - smoothstep(0.0, 0.2, lt_on)));
	c = mix(c, vec3(0.4, 0.54, 0.19), on_ledge * (1.0 - smoothstep(0.08, 0.26, lt_on)) * 0.85 * step(0.4, hash(seed * 5.5)));
	c *= 1.0 - 0.38 * on_ledge * smoothstep(0.45, 1.0, lt_on);  // (its rounded underside turning from the light)
	c *= 1.0 - 0.4 * under_ledge;
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
	// a warm light edge on its sun side; round 22 (the judges, j18: "the sticker look: no linework on the world"): the
	// characters' ink round it (as thick as theirs), a thin line where its front turns into the shadow face, one under
	// its cap rock
	float edge = min(in_l, in_r);
	c = mix(c, min(c * 1.35 + vec3(0.06, 0.03, 0.0), vec3(1.0)), (1.0 - smoothstep(2.4, 4.0, in_l)) * step(2.2, in_l) * (1.0 - cap) * 0.5);
	float line = 1.0 - smoothstep(1.7, 2.5, edge);
	line = max(line, (1.0 - smoothstep(0.0, 1.0 / max(hl + hr, 1.0), abs(ue - j3))) * 0.7 * smoothstep(cap_h + 4.0, cap_h + 10.0, y));
	line = max(line, (smoothstep(cap_h - 2.0, cap_h - 0.8, y) - smoothstep(cap_h + 0.2, cap_h + 1.4, y)) * 0.85);
	c = mix(c, vec3(0.17, 0.085, 0.06), line * 0.92);
	c = mix(c, rub_c, rub);
	float a = max(body, rub);
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

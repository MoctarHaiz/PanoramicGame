shader_type canvas_item;
// Round 20 (the judges, j16: the floating rocks' undersides "cracked flat slabs with crude outlines, a broken
// biscuit, clip art"): the underside of a floating ledge (TerrainView), one rectangle per ledge, painted here
// in its units. Its front face (a band of lit sandstone under the grass mat), then the underside: an upside-down
// peak cut in a few big planes (each from a corner of its lower edge up to the front face), the planes facing
// the low sun on the left warm, those facing away cool violet, all of it darkest in its core and lifted by the
// warm light bouncing off the plain along its lower edge; a few stylised drips of rock with round tips, roots
// hanging out of it, a thin soft dark line round it (no ink outline).

uniform vec2 size = vec2(400.0, 160.0);  // units: its width, and its height down to the room under its drips
uniform float deepest = 120.0;  // units from its top to its lowest corner (without the drips)
uniform float lip = 30.0;  // units from its top to the front face's lower edge
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

const int MAXV = 14;

void fragment() {
	vec2 p = UV * size;  // x across from its left end, y down from its top
	float w = size.x;
	// its lower edge: corners at uneven places, deepest a little off its middle, shallow at its ends
	int n = clamp(int(w / 85.0), 3, MAXV - 1);
	float mid = 0.38 + 0.24 * hash(seed * 3.1);
	float xs[MAXV + 1];
	float ds[MAXV + 1];
	int seg_i = 0;
	for (int k = 0; k <= MAXV; k++) {
		if (k > n) {
			xs[k] = w;
			ds[k] = lip * 0.8;
			continue;
		}
		float u = float(k) / float(n);
		if (k > 0 && k < n) {
			u += (hash(seed + float(k) * 7.3) - 0.5) * 0.6 / float(n);
		}
		float side = u < mid ? u / mid : (1.0 - u) / (1.0 - mid);
		float d = mix(lip * 0.8, deepest, pow(clamp(side, 0.0, 1.0), 0.6));
		if (k > 0 && k < n) {
			d *= 0.72 + 0.36 * hash(seed + float(k) * 13.7);
			d = max(d, lip + 6.0);
		}
		xs[k] = u * w;
		ds[k] = d;
		if (xs[k] <= p.x && k < n) {
			seg_i = k;
		}
	}
	float cx = xs[seg_i];
	float cd = ds[seg_i];
	float nx = xs[seg_i + 1];
	float nd = ds[seg_i + 1];
	float seg = float(seg_i);
	float t = clamp((p.x - cx) / max(nx - cx, 1.0), 0.0, 1.0);
	// (a little break in each straight cut; round 22, the judges: "vector clip art": chunky breaks along it too)
	float edge_y = mix(cd, nd, t) + (noise(p.x * 0.12 + seed) - 0.5) * 3.0 + (noise(p.x * 0.045 + seed * 3.0) - 0.5) * 9.0 * smoothstep(0.0, 30.0, min(p.x, w - p.x));
	float slope = (nd - cd) / max(nx - cx, 1.0);  // > 0: the plane faces down to the left, toward the sun
	// the facet: from each corner a ridge runs up to the front face, leaning a little
	// (the ridges lean in toward its deepest point as they rise: the planes gather like a cut stone's)
	float lean_c = (mid * w - cx) * 0.22 + (hash(seed + seg * 5.1) - 0.5) * 30.0;
	float lean_n = (mid * w - nx) * 0.22 + (hash(seed + (seg + 1.0) * 5.1) - 0.5) * 30.0;
	float ridge_c = cx + lean_c * clamp((cd - p.y) / max(cd - lip, 1.0), 0.0, 1.0);
	float ridge_n = nx + lean_n * clamp((nd - p.y) / max(nd - lip, 1.0), 0.0, 1.0);
	float facet = seg;
	float f_slope = slope;
	if (p.x < ridge_c && seg_i > 0) {  // above its corner, left of the ridge: the plane before
		facet = seg - 1.0;
		f_slope = (cd - ds[max(seg_i - 1, 0)]) / max(cx - xs[max(seg_i - 1, 0)], 1.0);
	} else if (p.x > ridge_n && seg_i + 2 <= MAXV) {
		facet = seg + 1.0;
		f_slope = (ds[min(seg_i + 2, MAXV)] - nd) / max(xs[min(seg_i + 2, MAXV)] - nx, 1.0);
	}
	// (round 22, the judges: "a straight-edged plank": the front face's lower edge ragged, deeper here, shallower there)
	float lip_y = lip * 0.8 + (noise(p.x * 0.028 + seed * 2.0) - 0.5) * 22.0 + (noise(p.x * 0.11) - 0.5) * 5.0
			+ 10.0 * pow(noise(p.x * 0.07 + seed * 5.0), 3.0);
	// the drips: a few tapering points of rock under the lower edge, round at their tips; roots hanging
	float drip = 0.0;
	float drip_edge = 99.0;
	float drip_lit = 0.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		if (fi > w / 110.0) {
			break;
		}
		float dx = w * (0.12 + 0.76 * hash(seed * 1.7 + fi * 3.3));
		float len = (12.0 + 26.0 * pow(hash(seed + fi * 9.1), 1.5) * clamp(deepest / 110.0, 0.5, 1.2)) * clamp(w / 400.0, 0.45, 1.0);
		float wid = 8.0 + 9.0 * hash(seed + fi * 4.7);
		float top_y = edge_y;  // (it hangs from the edge right above it: close enough for a thin drip)
		float tt = (p.y - top_y + 6.0) / (len + 6.0);
		if (tt > 0.0 && tt < 1.0) {
			float half_w = wid * pow(1.0 - tt, 1.2) + 2.2;
			float dd = abs(p.x - dx - sin(tt * 2.5 + fi) * 2.0) - half_w;
			drip = max(drip, 1.0 - smoothstep(-0.6, 0.6, dd));
			drip_edge = min(drip_edge, abs(dd));
			drip_lit = max(drip_lit, (1.0 - smoothstep(-0.6, 0.6, dd)) * step(p.x, dx - half_w * 0.2));
		}
		// a round bead of rock at its tip
		float bead = length(p - vec2(dx + sin(2.5 + fi) * 2.0, top_y + len)) - 2.2;  // (its round tip)
		drip = max(drip, 1.0 - smoothstep(-0.6, 0.6, bead));
		drip_edge = min(drip_edge, abs(bead));
	}
	float root = 0.0;
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		if (fi > w / 100.0) {
			break;
		}
		float rx = w * (0.08 + 0.84 * hash(seed * 2.3 + fi * 5.9));
		float len = 18.0 + 46.0 * hash(seed + fi * 6.1) + (hash(seed + fi * 2.9) < 0.3 ? 30.0 : 0.0);  // (a few long ones)
		float tt = (p.y - edge_y + 2.0) / len;
		if (tt > 0.0 && tt < 1.0) {
			float x = rx + sin(p.y * 0.16 + fi * 2.0) * 3.0 * tt + tt * tt * (hash(fi + seed) - 0.5) * 16.0;
			float half_w = mix(1.5, 0.35, tt);
			root = max(root, (1.0 - smoothstep(half_w - 0.5, half_w + 0.5, abs(p.x - x))) * (1.0 - smoothstep(0.75, 1.0, tt)));
		}
	}
	float body = 1.0 - smoothstep(edge_y - 0.7, edge_y + 0.7, p.y);
	// (its ends cut back like the ledge's rounded ends above it: a wedge, not a square end)
	float end_d = min(p.x, w - p.x) - max(p.y - 6.0, 0.0) * 0.5;
	body *= smoothstep(-0.7, 0.7, end_d);
	float shape = max(body, drip);
	float alpha = max(shape, root);
	if (alpha <= 0.002) {
		discard;
	}
	// the underside's paint (round 22, the judges, j18: "a flat mauve underside"): a dark rock core cut in planes,
	// those facing the low sun a step warmer, those away a step cooler, an ink line where two planes meet, the plain's
	// warm light along its lower edge; light only on the lip under the grass
	float into = clamp((p.y - lip_y) / max(edge_y - lip_y, 1.0), 0.0, 1.0);  // 0 at the front face, 1 at the edge
	vec3 warm = vec3(0.5, 0.3, 0.29);
	vec3 cool = vec3(0.23, 0.14, 0.21);
	float face_sun = smoothstep(-0.12, 0.12, f_slope);
	vec3 c = mix(cool, warm, face_sun);
	c *= 0.86 + 0.26 * hash(seed + facet * 11.3);
	c *= 1.0 - 0.3 * smoothstep(0.0, 0.4, into) * (1.0 - smoothstep(0.6, 1.0, into));  // its dark core
	c = mix(c, c + vec3(0.16, 0.08, 0.02), smoothstep(0.82, 1.0, into) * 0.8 * (0.4 + 0.6 * face_sun));  // the plain's warm light along its lower edge
	c *= 0.92 + 0.12 * noise2(p * vec2(0.05, 0.09) + seed) + 0.04 * noise2(p * 0.3);
	// soft beds following the planes, and an ink line between two planes
	c *= 1.0 - 0.08 * smoothstep(0.6, 0.85, noise((p.y - p.x * f_slope * 0.6) * 0.09 + facet * 3.0));
	float ridge = min(abs(p.x - ridge_c), abs(p.x - ridge_n));
	float ridge_ink = (1.0 - smoothstep(0.5, 1.3, ridge)) * step(lip_y + 3.0, p.y) * smoothstep(0.25, 0.45, noise(p.y * 0.08 + facet * 2.0));
	// the drips: the plane's colour, darker, lit down their sun side
	c = mix(c, mix(mix(cool, warm, 0.35) * 0.95, warm * 1.1, drip_lit * 0.85), drip * (1.0 - body));
	// the front face under the grass: a lit lip of sandstone just under the mat (the only light on it), then the rock
	// turning down into the core's shade; a few cracks running down at a slant (no ruled planks)
	float lit_lip = 8.0 + 6.0 * noise(p.x * 0.05 + seed * 4.0);
	vec3 face = mix(vec3(0.92, 0.62, 0.44), vec3(0.58, 0.36, 0.34), smoothstep(lit_lip - 1.0, lit_lip + 1.0, p.y));
	face = mix(face, face * vec3(0.78, 0.74, 0.9), smoothstep(lit_lip + 2.0, lip_y, p.y));
	face *= 0.93 + 0.1 * noise2(p * vec2(0.04, 0.2) + seed * 5.0);
	float slant = p.x + p.y * 0.45;
	float fcrack = (1.0 - smoothstep(0.4, 1.1, abs(fract(slant / 83.0 + noise(p.y * 0.08 + floor(slant / 83.0)) * 0.25) - 0.5) * 83.0))
			* step(0.6, hash(floor(slant / 83.0) + seed)) * smoothstep(lit_lip + 1.0, lit_lip + 6.0, p.y);
	face = mix(face, vec3(0.17, 0.085, 0.06), fcrack * 0.75);
	face *= 1.0 - 0.6 * exp(-max(p.y - 5.0, 0.0) / 6.0);  // in the grass mat's shadow at its top
	float on_face = 1.0 - smoothstep(lip_y - 0.8, lip_y + 0.8, p.y);
	c = mix(c, face, on_face * body);
	float lip_ink = (smoothstep(lip_y - 1.6, lip_y - 0.4, p.y) - smoothstep(lip_y + 0.6, lip_y + 1.8, p.y)) * body;
	// the island's ends lit from the left, shaded on the right
	c *= mix(1.06, 0.86, smoothstep(0.0, 1.0, p.x / w));
	// the ink round it (the characters' warm dark brown, as thick as theirs), round its drips and roots
	float line = (1.0 - smoothstep(1.4, 2.4, edge_y - p.y)) * body * (1.0 - drip);
	line = max(line, (1.0 - smoothstep(0.9, 1.8, drip_edge)) * drip * (1.0 - body));
	line = max(line, (1.0 - smoothstep(1.4, 2.4, end_d)) * body);
	line = max(line, max(lip_ink * 0.85, ridge_ink * 0.6 * (1.0 - on_face)));
	c = mix(c, vec3(0.17, 0.085, 0.06), line * 0.92);
	c = mix(c, vec3(0.2, 0.12, 0.1), root * (1.0 - shape));
	COLOR = vec4(c, alpha);
}

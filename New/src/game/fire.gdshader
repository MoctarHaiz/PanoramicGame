shader_type canvas_item;
// Round 20 (the judges, j16: "the campfire flat vector triangles"): the home's campfire painted (HomeView.Fire),
// in its rectangle (UV: x across, y down): a body of flame licking up and breaking into tongues that rise and
// fade, in three soft-edged bands of colour (a white-gold core, orange, a deep red-orange skin), a hot glow at
// its root, flickering. Noise rising through it shapes the tongues; each fire its own `seed`.

uniform float seed = 0.0;
uniform float flare = 0.0;  // 0..1: it flares up (he is home)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float up = 1.0 - UV.y;  // 0 at its root, 1 at the top of its rectangle
	float x = (UV.x - 0.5) * 2.6;  // (room either side: no tongue cut by its rectangle)
	float t = TIME * (1.0 + 0.2 * flare);
	// noise rising through it: it sways the body and cuts it into tongues higher up
	float sway = (fbm(vec2(up * 1.4 - t * 0.9, seed)) - 0.5) * 0.5 * up;
	float n = fbm(vec2(x * 2.2 + seed, up * 2.6 - t * 2.1));
	float n2 = fbm(vec2(x * 4.4 - seed, up * 4.8 - t * 3.3));
	// its tongues: a tall body in the middle, smaller ones beside it, each licking up and falling back on its
	// own beat, bending in an S
	float d = -1.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float side = abs(fi - 2.0) / 2.0;  // 0 in the middle, 1 at the sides
		float cx = (fi - 2.0) * 0.24 + (hash(vec2(fi, seed)) - 0.5) * 0.1;
		float h = mix(0.95, 0.42, side) * (0.85 + 0.25 * hash(vec2(seed, fi * 3.1)));
		h *= 0.84 + 0.16 * sin(t * (4.3 + fi * 0.9) + fi * 2.1) + 0.06 * flare;
		float bend = sin(up * 4.2 - t * 3.6 + fi * 1.3) * 0.14 * pow(up, 1.2) + sway;
		float w = mix(0.36, 0.2, side) * pow(max(1.0 - up / max(h, 0.05), 0.0), 0.55);  // (round, not a spike)
		d = max(d, w - abs(x - cx - bend));
	}
	d = max(d, 0.42 * (1.0 - up * 4.0) - abs(x * 0.7));  // the bed of flame along the logs
	d += (n - 0.5) * 0.22 * smoothstep(0.0, 0.45, up);  // ragged, wavy edges; wisps breaking off
	d += (n2 - 0.5) * 0.08 * up;
	// painted, not cut: the colour runs from a white-gold heart low down through gold and orange to a deep red at
	// the tongues' tips and skin; soft edges, the skin translucent (it glows), the heart's edge soft too
	float skin = smoothstep(-0.01, 0.07, d);
	float inner = smoothstep(0.03, 0.2, d + 0.08 * (1.0 - up));
	float heart = smoothstep(0.1, 0.3, d + 0.16 * (1.0 - up) - 0.1 * up);
	vec3 hot = mix(vec3(1.0, 0.95, 0.72), vec3(1.0, 0.7, 0.24), smoothstep(0.0, 0.6, up));
	vec3 warm = mix(vec3(1.0, 0.56, 0.12), vec3(0.92, 0.26, 0.06), smoothstep(0.15, 0.8, up));
	vec3 c = mix(vec3(0.78, 0.16, 0.05), warm, inner);
	c = mix(c, hot, heart);
	c *= 0.92 + 0.16 * n2;  // (a flicker of brush in it)
	float a = skin * (1.0 - smoothstep(0.7, 1.0, up)) * mix(0.8, 1.0, inner);
	a *= 0.9 + 0.1 * flare;
	// a hot glow round its root
	float glow = exp(-pow(x * 1.1, 2.0) * 3.0) * exp(-up * 5.0);
	c = mix(c, vec3(1.0, 0.7, 0.3), (1.0 - skin) * glow);
	a = max(a, glow * 0.55);
	COLOR = vec4(c, a);
}

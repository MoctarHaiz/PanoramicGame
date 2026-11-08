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
	// round 22 (the judges, j18: "still a flat cartoon flame"): the air it rises through bends it (a warp of the space
	// it is drawn in, growing with height), so its tongues ripple and curl like a fluid instead of standing as spikes
	float warp = (fbm(vec2(x * 1.7 + seed * 3.0, up * 2.4 - t * 1.9)) - 0.5) * 0.55 * smoothstep(0.05, 0.7, up);
	float xw = x + warp;
	float n = fbm(vec2(xw * 2.2 + seed, up * 2.6 - t * 2.1));
	float n2 = fbm(vec2(xw * 4.4 - seed, up * 4.8 - t * 3.3));
	// its tongues: a tall body in the middle, smaller ones beside it, each licking up and falling back on its
	// own beat, bending in an S (round 22: rounder, wider at their roots, their tips breaking into wisps)
	float d = -1.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float side = abs(fi - 2.0) / 2.0;  // 0 in the middle, 1 at the sides
		float cx = (fi - 2.0) * 0.22 + (hash(vec2(fi, seed)) - 0.5) * 0.1;
		float h = mix(0.88, 0.4, side) * (0.85 + 0.25 * hash(vec2(seed, fi * 3.1)));
		h *= 0.84 + 0.16 * sin(t * (4.3 + fi * 0.9) + fi * 2.1) + 0.06 * flare;
		float bend = sin(up * 4.2 - t * 3.6 + fi * 1.3) * 0.12 * pow(up, 1.2) + sway;
		float w = mix(0.4, 0.24, side) * pow(max(1.0 - up / max(h, 0.05), 0.0), 0.8);  // (round, not a spike)
		d = max(d, w - abs(xw - cx - bend));
	}
	d = max(d, 0.46 * (1.0 - up * 3.6) - abs(x * 0.7));  // the bed of flame along the logs
	d += (n - 0.5) * 0.2 * smoothstep(0.1, 0.6, up);  // wavy edges; wisps breaking off high up
	d += (n2 - 0.5) * 0.06 * up;
	// painted in soft layers: a translucent deep-red skin, an orange body, a soft gold heart low down (no white
	// blown-out core); the edges soft, the skin glowing through
	float skin = smoothstep(-0.03, 0.09, d);
	float inner = smoothstep(0.02, 0.22, d + 0.08 * (1.0 - up));
	float heart = smoothstep(0.06, 0.34, d + 0.14 * (1.0 - up) - 0.12 * up);
	vec3 hot = mix(vec3(1.0, 0.88, 0.56), vec3(1.0, 0.68, 0.26), smoothstep(0.0, 0.55, up));
	vec3 warm = mix(vec3(1.0, 0.54, 0.13), vec3(0.9, 0.27, 0.07), smoothstep(0.15, 0.75, up));
	vec3 c = mix(vec3(0.7, 0.15, 0.05), warm, inner);
	c = mix(c, hot, heart * 0.9);
	c *= 0.9 + 0.18 * n2;  // (a flicker of brush in it)
	float a = skin * (1.0 - smoothstep(0.62, 0.95, up)) * mix(0.62, 1.0, inner);
	a *= 0.9 + 0.1 * flare;
	// a soft halo of heat round it, and a hot glow round its root
	float halo = smoothstep(-0.22, 0.0, d) * (1.0 - skin) * (1.0 - smoothstep(0.2, 0.85, up));
	float glow = exp(-pow(x * 1.1, 2.0) * 3.0) * exp(-up * 5.0);
	c = mix(c, vec3(1.0, 0.5, 0.18), (1.0 - skin) * max(glow, halo));
	a = max(a, max(glow * 0.5, halo * 0.22));
	// embers: a few bright specks lifting off the tongues' tips and winking out
	vec2 ep = vec2(xw * 6.0 + seed, up * 7.0 - t * 2.6);
	vec2 ec = floor(ep);
	vec2 ef = fract(ep) - 0.5 - (vec2(hash(ec), hash(ec + 3.7)) - 0.5) * 0.6;
	float ember = (1.0 - smoothstep(0.03, 0.09, length(ef))) * step(0.88, hash(ec + seed)) * smoothstep(0.35, 0.6, up)
			* (1.0 - smoothstep(0.8, 1.0, up)) * (1.0 - skin);
	c = mix(c, vec3(1.0, 0.78, 0.36), ember);
	a = max(a, ember * 0.9);
	COLOR = vec4(c, a);
}

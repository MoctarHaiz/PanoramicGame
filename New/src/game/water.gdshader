shader_type canvas_item;
// Water in a gap, stylised to sit with the painted ground: clear turquoise under a wavy surface
// that reflects the warm evening sky, deep blue below, a bright foam line, a web of light
// (caustics) in the shallows, streaks of sun glitter and a few twinkling sparkles. Darker and
// foamy against the banks (the rectangle reaches 8 units under the soil on each side).

uniform vec2 rect_size = vec2(192.0, 140.0);
uniform float x_offset = 0.0;  // level x of the rect, so neighbouring pools move as one sea
uniform vec4 shallow : source_color = vec4(0.2, 0.72, 0.8, 1.0);
uniform vec4 deep : source_color = vec4(0.03, 0.15, 0.38, 1.0);
uniform vec4 sky_tint : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec4 foam : source_color = vec4(0.97, 0.99, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * rect_size;
	float x = p.x + x_offset;
	float t = TIME;
	float surface = 7.0 + sin(x * 0.045 + t * 1.7) * 1.6 + sin(x * 0.13 - t * 2.6) * 0.8 + sin(x * 0.021 - t * 0.6) * 1.1;
	float d = p.y - surface;  // depth under the surface
	if (d < -1.0) {
		discard;
	}
	float edge_aa = clamp(d + 1.0, 0.0, 1.0);
	// the body: turquoise just under the surface to deep blue within a few units (the gap is
	// only ~60 units deep on screen)
	float depth = clamp((d - 6.0) / 64.0, 0.0, 1.0);
	vec3 c = mix(shallow.rgb, deep.rgb, pow(depth, 0.7));
	// light shafts slanting down from the sun (upper left), drifting, fading with depth
	float shaft = noise(vec2((x - d * 0.55) * 0.05 + t * 0.15, 0.5));
	c += vec3(0.1, 0.2, 0.2) * smoothstep(0.55, 0.85, shaft) * (1.0 - smoothstep(10.0, 56.0, d));
	// caustics: a web of light, fading with depth
	float w1 = sin(x * 0.19 + sin(d * 0.16 + t * 1.1) * 1.6 + t * 0.9);
	float w2 = sin(d * 0.26 - x * 0.11 + sin(x * 0.07 - t * 0.8) * 1.3 - t * 0.7);
	float w3 = sin(x * 0.13 + d * 0.2 + sin(d * 0.1 - t) * 1.2 + t * 0.5);
	float web = 1.0 - smoothstep(0.0, 0.24, abs(w1 + w2 + w3 * 0.6));
	c += vec3(0.12, 0.2, 0.2) * web * (1.0 - smoothstep(8.0, 40.0, d));
	// the surface seen a little from above: a bright sheet reflecting the sky, broken by ripples,
	// over a thin dark line where it meets the body
	float rip = noise(vec2(x * 0.09 + t * 0.6, 3.3));
	float sheet = 1.0 - smoothstep(4.0, 6.5, d);
	vec3 sheet_col = mix(vec3(0.66, 0.95, 1.0), vec3(1.0, 0.96, 0.86), 0.15 + 0.35 * rip);
	c = mix(c, sheet_col, sheet * 0.9);
	c *= 1.0 - (smoothstep(5.0, 6.5, d) - smoothstep(6.5, 10.0, d)) * 0.35;
	// sun glitter on the sheet: short streaks sliding slowly
	float g = noise(vec2(x * 0.06 - t * 0.35, d * 0.7));
	c = mix(c, vec3(1.0, 0.98, 0.88), smoothstep(0.7, 0.9, g) * sheet * 0.8);
	// the lip of foam along the top, its thickness wandering
	float thick = 1.4 + 1.6 * noise(vec2(x * 0.07 - t * 0.8, 1.7));
	c = mix(c, foam.rgb, (1.0 - smoothstep(thick * 0.5, thick, d)) * 0.95);
	// sparkles: rare cells near the surface flash
	vec2 q = vec2(x / 10.0, d / 6.0);
	vec2 cell = floor(q);
	float h = hash(cell + 3.1);
	float flash = pow(max(0.0, sin(t * 2.6 + h * 37.0)), 12.0);
	vec2 fq = fract(q) - 0.5;
	float star = smoothstep(0.32, 0.0, length(fq * vec2(1.0, 1.6))) + smoothstep(0.06, 0.0, abs(fq.y)) * smoothstep(0.45, 0.0, abs(fq.x)) * 0.6;
	c += vec3(1.0, 0.97, 0.85) * step(0.88, h) * flash * star * (1.0 - smoothstep(4.0, 22.0, d));
	// banks: the soil's shade on the water, and froth piled against it (bubbles of foam)
	float bank = min(p.x, rect_size.x - p.x) - 8.0;  // units from the soil's face
	c *= mix(0.6, 1.0, smoothstep(0.0, 22.0, bank));
	float bubbles = noise(vec2(x * 0.35, d * 0.35 - t * 0.4)) * 0.6 + noise(vec2(x * 0.9 + t * 0.3, d * 0.9)) * 0.4;
	float froth = (1.0 - smoothstep(2.0, 22.0, bank + d * 0.35)) * (1.0 - smoothstep(6.0, 24.0, d));
	float puffs = smoothstep(0.36, 0.5, bubbles * (0.55 + froth * 0.7)) * smoothstep(0.05, 0.35, froth);
	c = mix(c, foam.rgb, puffs * 0.95);
	c *= 1.0 - (smoothstep(0.3, 0.36, bubbles * (0.55 + froth * 0.7)) - puffs) * 0.25 * smoothstep(0.05, 0.35, froth);
	COLOR = vec4(c, edge_aa);
}

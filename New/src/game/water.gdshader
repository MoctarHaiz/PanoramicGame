shader_type canvas_item;
// Water in a gap, stylised to sit with the painted ground: clear turquoise under a wavy surface
// that reflects the warm evening sky, deep blue below, a bright foam line, a web of light
// (caustics) in the shallows, streaks of sun glitter and a few twinkling sparkles. Darker and
// foamy against the banks (the rectangle reaches 8 units under the soil on each side).

uniform vec2 rect_size = vec2(192.0, 140.0);
uniform float x_offset = 0.0;  // level x of the rect, so neighbouring pools move as one sea
uniform vec4 shallow : source_color = vec4(0.13, 0.58, 0.66, 1.0);  // round 2: deeper, less candy
uniform vec4 deep : source_color = vec4(0.02, 0.1, 0.26, 1.0);
uniform vec4 sky_tint : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec4 foam : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform sampler2D soil_tex : source_color, repeat_enable, filter_linear_mipmap;  // the banks' earth

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
	// Round 5: water in the hero's style: flat bands (the warm sky reflected in a light band under
	// the surface, a mid teal, the deep blue), ripple dashes drifting in them, a white foam line on
	// top, foam curling at the banks, the banks' earth sloping in under an ink edge
	float ripple = noise(vec2(x * 0.03 + t * 0.35, floor(d / 5.0) * 3.7));
	float band_y = d + (ripple - 0.5) * 5.0;
	vec3 c = deep.rgb;
	c = mix(c, mix(shallow.rgb, deep.rgb, 0.5), step(band_y, 30.0));
	c = mix(c, shallow.rgb * 1.08, step(band_y, 15.0));
	vec3 sky_band = mix(sky_tint.rgb, vec3(0.62, 0.82, 0.9), 0.35);
	c = mix(c, sky_band, step(band_y, 6.0));
	c *= mix(1.0, 0.72, smoothstep(6.0, 60.0, d));  // (round 6: deeper is darker within the bands: it reads small)
	// ripple dashes: short light strokes along the bands, sliding with the current
	float dash_row = fract(d / 7.0);
	float dash = step(0.62, noise(vec2(x * 0.06 - t * 0.5, floor(d / 7.0) * 5.3))) * (1.0 - smoothstep(0.0, 0.18, abs(dash_row - 0.5)));
	c = mix(c, mix(c, vec3(1.0, 0.97, 0.9), 0.5), dash * (1.0 - smoothstep(10.0, 44.0, d)));
	// round 8: the grassy banks mirrored just under the surface near them (the pool reads as water
	// between banks, not a cyan box)
	float near_bank = 1.0 - smoothstep(14.0, 40.0, min(p.x, rect_size.x - p.x) - 8.0);
	float mirror = near_bank * smoothstep(3.0, 5.0, d) * (1.0 - smoothstep(12.0, 16.0, d + (ripple - 0.5) * 4.0));
	c = mix(c, vec3(0.16, 0.3, 0.2), mirror * 0.75);
	// a few glints on the light band
	vec2 q = vec2(x / 10.0, d / 6.0);
	vec2 cell = floor(q);
	float h = hash(cell + 3.1);
	float flash = pow(max(0.0, sin(t * 2.6 + h * 37.0)), 12.0);
	vec2 fq = fract(q) - 0.5;
	float star = smoothstep(0.32, 0.0, length(fq * vec2(1.0, 1.6)));
	c += vec3(1.0, 0.97, 0.85) * step(0.9, h) * flash * star * (1.0 - smoothstep(2.0, 12.0, d));
	// the foam line on top, its thickness wandering
	float thick = 1.6 + 1.6 * noise(vec2(x * 0.07 - t * 0.8, 1.7));
	c = mix(c, foam.rgb, 1.0 - smoothstep(thick - 0.5, thick + 0.5, d));
	// banks: the earth slopes in under the water (flat, lit at its rim, an ink edge), foam curls at it
	float bank = min(p.x, rect_size.x - p.x) - 8.0;  // units from the soil's face
	float reach = 4.0 + 40.0 * (1.0 - exp(-max(d, 0.0) / 24.0)) + (noise(vec2(d * 0.12, x * 0.01)) - 0.5) * 6.0;
	float slope = 1.0 - smoothstep(reach - 0.8, reach + 0.8, bank);
	vec3 earth = mix(vec3(0.42, 0.24, 0.16), vec3(0.62, 0.36, 0.22), step(reach - 5.0, bank));
	vec3 through = mix(earth, deep.rgb, clamp(0.35 + d / 80.0, 0.35, 0.8));
	c = mix(c, through, slope);
	float edge = (1.0 - smoothstep(0.0, 2.2, abs(bank - reach))) * step(3.0, d);
	c = mix(c, vec3(0.12, 0.08, 0.1), edge * 0.75);
	float curl = (1.0 - smoothstep(0.0, 2.0, abs(d - 3.0 - sin(bank * 0.5 - t * 2.0) * 1.5))) * (1.0 - smoothstep(4.0, 16.0, bank));
	c = mix(c, foam.rgb, curl * 0.9);
	COLOR = vec4(c, edge_aa);
}

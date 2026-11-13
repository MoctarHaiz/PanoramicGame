shader_type canvas_item;
// 2026-11-13: the turf along the tops (grass_cap.png: 100 px tall, the walking line 24 px down), lit as ink.gdshader's
// `turf` lit it (round 23: a sunlit top a value lighter, the band in a sage light, its underside in the cool shade,
// inked), but: the blind judge, of the turf, "a neon yellow-lime turf line that reads as a light strip, not a pool of
// firelight", "the lime turf line … read as tiles": its lit top and the lip along the walking line are an olive-gold a
// value lower, broken and uneven along the ground (never one bright stripe), and all of it takes the colour it is drawn
// with (the home's dusk and fire: TerrainView._lit); ink.gdshader mixed its lip to a fixed colour, over that light.

uniform vec4 ink_colour : source_color = vec4(0.14, 0.07, 0.07, 1.0);
uniform float width = 2.6;  // texels

varying vec2 at;
varying vec4 drawn;  // the colour it is drawn with (the home's light), applied after the turf's own light

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void vertex() {
	at = VERTEX;
	drawn = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float around = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float a = tex.a;
	float edge = clamp(a - around, 0.0, 1.0);  // inside, next to the outside
	float v = UV.y + (noise(at.x * 0.045) - 0.5) * 0.02;  // (the walking line's light wanders a little)
	vec3 c = tex.rgb;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	// the fringe above the walking line: its tips trimmed (a cleaner edge), lit
	a *= smoothstep(0.05, 0.13, UV.y);
	// (blind round 21: "a dark earth strip under a serrated turf fringe"; with the plain behind it in the evening's shade
	// its lemon-yellow tips were the brightest row of the picture: the blades over the walking line are an olive, a value
	// under the path's top; it was c * (1.08, 1.06, 0.94) + (0.03, 0.025, 0.0))
	c = mix(c, mix(vec3(lum), c, 0.72) * vec3(0.72, 0.82, 0.66), 1.0 - smoothstep(0.2, 0.26, v));
	// the band under it: a sunlit sage, a little less saturated
	float band = smoothstep(0.22, 0.3, v) * (1.0 - smoothstep(0.5, 0.62, v));
	vec3 sage = mix(vec3(lum), c, 0.6) * vec3(1.02, 1.0, 0.86) + vec3(0.02, 0.02, 0.0);  // (2026-11-13: a value lower, olive)
	c = mix(c, sage, band);
	// the surface he runs on: an olive-gold top, in patches; a broken lip along the walking line
	float patchy = smoothstep(0.25, 0.75, noise(at.x * 0.06 + 3.0)) * (0.55 + 0.45 * noise(at.x * 0.23));
	float top = smoothstep(0.22, 0.25, v) * (1.0 - smoothstep(0.31, 0.4, v));
	// (the picture's own lime-yellow band along the top and its blade tips: an olive-gold a value lower, lighter in patches)
	float upper = 1.0 - smoothstep(0.34, 0.44, v);
	c = mix(c, c * vec3(0.84, 0.8, 0.6) * mix(0.86, 1.04, patchy), upper);
	c = mix(c, vec3(0.74, 0.7, 0.42) * (0.8 + 0.3 * lum), top * 0.42 * (0.4 + 0.6 * patchy));
	float lip = smoothstep(0.235, 0.25, v) * (1.0 - smoothstep(0.262, 0.28, v));
	c = mix(c, c * 1.18 + vec3(0.05, 0.04, 0.0), lip * 0.7 * patchy);
	// toward its underside the sky's cool shade; the drips over the soil a cool dark, not teal
	float under = smoothstep(0.48, 0.66, v);
	c = mix(c, mix(vec3(lum), c, 0.5) * vec3(0.84, 0.88, 0.82) * 0.86, under);  // (blind round 21: a mossy olive, a value up: it was a near-black teal saw)
	c = mix(c, ink_colour.rgb, edge * 0.85);
	COLOR = vec4(c * drawn.rgb, a * drawn.a);
}

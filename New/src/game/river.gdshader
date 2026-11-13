shader_type canvas_item;
// Blind round 18 (under the vine: "the bottom quarter is a featureless mauve fog slab: no river, no gorge, no floor,
// so the swing has no height and no stakes ... a painted drop: a river with real depth and reflections"): the river
// that lies beyond the first ridge (SavannaView._draw_river), seen from above its near bank, in the pool's own cel
// language (water.gdshader): the low sky lying on its far side in a rose-gold sheen, the dusk's violet across its
// middle, the pool's deep teal nearest; the far bank mirrored dark under its waterline and broken by ripples; rows of
// ripple strokes growing toward the viewer; the clouds' pale shapes lying on it; a path of glints. Its far shore is
// no ruled line (small headlands).

uniform float top = 478.0;  // play y of its far waterline
uniform float slide = 0.0;  // how far its layer has scrolled (units)
uniform vec4 far_sky : source_color = vec4(1.0, 0.8, 0.66, 1.0);  // the low sky lying on its far side
uniform vec4 mid_sky : source_color = vec4(0.66, 0.58, 0.88, 1.0);  // the dusk's lilac
uniform vec4 high_sky : source_color = vec4(0.36, 0.42, 0.76, 1.0);  // the sky overhead
uniform vec4 near_deep : source_color = vec4(0.13, 0.31, 0.49, 1.0);  // the water's own depth, nearest
uniform vec4 bank : source_color = vec4(0.4, 0.31, 0.55, 1.0);  // the far bank, mirrored
uniform vec4 crest : source_color = vec4(0.98, 0.78, 0.5, 1.0);  // its gold crest, mirrored

varying vec4 drawn;
varying vec2 at;

void vertex() {
	drawn = COLOR;
	at = VERTEX;
}

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
	float x = at.x + slide;
	float t = TIME;
	float shore = top + (noise(vec2(x * 0.011, 2.0)) - 0.5) * 8.0 + (noise(vec2(x * 0.047, 5.0)) - 0.5) * 2.6;
	float d = at.y - shore;  // units this side of the far waterline
	// rows of the surface, each taller than the one behind it (it lies flat: seen from above its near bank)
	float wr = log(max(d, 1.5) / 1.5) / log(1.3);
	float wk = floor(wr);
	float wt = fract(wr);
	float wob = (noise(vec2(x * 0.02 + wk * 3.3 - t * 0.1, wk)) - 0.5) * (2.0 + d * 0.12);
	float dd = d + wob;
	// the sky on it, in flat bands, mirrored: the low sky's rose gold on its far side, the dusk's lilac, the sky
	// overhead, and nearest the water's own deep teal (seen from above, it is looked into)
	vec3 c = far_sky.rgb;
	c = mix(c, mix(far_sky.rgb, mid_sky.rgb, 0.5), smoothstep(15.0, 17.0, dd));
	c = mix(c, mid_sky.rgb, smoothstep(25.0, 28.0, dd));
	c = mix(c, mix(mid_sky.rgb, high_sky.rgb, 0.5), smoothstep(38.0, 42.0, dd));
	c = mix(c, high_sky.rgb, smoothstep(54.0, 59.0, dd));
	c = mix(c, mix(high_sky.rgb, near_deep.rgb, 0.6), smoothstep(74.0, 80.0, dd));
	c = mix(c, near_deep.rgb, smoothstep(100.0, 108.0, dd));
	// the clouds' pale shapes lying on it, stretched along the rows
	float cl = noise(vec2(x * 0.0052 + 3.0, d * 0.035)) * 0.7 + noise(vec2(x * 0.013 - 1.0, d * 0.08)) * 0.3;
	c = mix(c, mix(c, far_sky.rgb * 1.04, 0.5), smoothstep(0.62, 0.68, cl) * smoothstep(26.0, 40.0, d) * (1.0 - smoothstep(80.0, 120.0, d)));
	// the far bank mirrored under its waterline, its gold crest under that: their lower edges broken into dashes
	// by the ripples
	float low = 7.0 + 4.0 * noise(vec2(x * 0.03, 1.0)) + (noise(vec2(x * 0.26 - t * 0.35, wk)) - 0.5) * 4.0;
	c = mix(c, crest.rgb, (1.0 - smoothstep(low + 1.6, low + 2.8, d)) * 0.8);
	c = mix(c, bank.rgb, (1.0 - smoothstep(low - 0.7, low + 0.7, d)) * 0.9);
	// ripples: on each row short light strokes, and darker troughs under them
	float f = 0.1 / (1.0 + wk * 0.34);
	float seg = noise(vec2(x * f - t * 0.1 + wk * 7.3, wk * 3.1));
	float stroke = smoothstep(0.56, 0.62, seg) * (1.0 - smoothstep(0.08, 0.2, abs(wt - 0.5)));
	float trough = smoothstep(0.58, 0.66, noise(vec2(x * f * 0.8 + t * 0.07 + wk * 2.9, wk * 5.7 + 11.0)))
			* (1.0 - smoothstep(0.1, 0.24, abs(wt - 0.2)));
	float in_water = smoothstep(2.0, 6.0, d);
	c = mix(c, c * vec3(0.7, 0.7, 0.84), trough * 0.7 * in_water);
	c = mix(c, mix(c, vec3(1.0, 0.92, 0.84), 0.6), stroke * in_water);
	// a path of glints where the brightest sky lies on it
	float path = smoothstep(0.56, 0.78, noise(vec2(x * 0.0035, 9.0)));
	vec2 q = vec2(x / (5.0 + wk * 1.4), wr * 2.0);
	float h = hash(floor(q) + 3.1);
	float twinkle = 0.55 + 0.45 * sin(t * 2.2 + h * 40.0);
	float glint = step(0.8, h) * (1.0 - smoothstep(0.1, 0.34, abs(fract(q.y) - 0.5))) * path * twinkle * in_water
			* (1.0 - smoothstep(70.0, 130.0, d));
	c = mix(c, vec3(1.0, 0.95, 0.82), glint * 0.85);
	// the wet line of sky along the far shore
	c = mix(c, far_sky.rgb * 1.06, (1.0 - smoothstep(0.6, 1.6, d)) * 0.7);
	COLOR = vec4(c * drawn.rgb, smoothstep(-0.6, 0.4, d) * drawn.a);
}

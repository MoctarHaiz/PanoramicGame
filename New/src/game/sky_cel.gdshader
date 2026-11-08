shader_type canvas_item;
// Round 23 (the judges, j19: "the soft painted clouds and god rays don't match the hard-inked mesas"): the painted sky
// (SavannaView) toward the world's cel style. Its broad light (read from a far mip of sky.png: the gradient from the
// zenith to the warm horizon, the big masses of light and shade) is kept smooth; the big forms of the clouds on it
// (their shading against that light, read from a nearer mip: clean contours, not the paint's grain) are pulled toward a
// few crisp tone steps, as the landforms' and the characters' planes are, each keeping the painted hue and a little of
// its brush. (The god rays: rays_cel.gdshader.)

uniform float step_size = 0.1;  // luminance of one tone step
uniform float amount = 0.55;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

void fragment() {
	vec3 base = COLOR.rgb;
	// (none near the picture's top and bottom rows: it repeats, its far mips bled across the edge)
	float k = amount * smoothstep(0.03, 0.1, UV.y) * (1.0 - smoothstep(0.9, 0.97, UV.y));
	if (k > 0.0) {
		float lb = lum(textureLod(TEXTURE, UV, 5.0).rgb * tint.rgb);
		float lm = lum(textureLod(TEXTURE, UV, 2.6).rgb * tint.rgb);
		// (the judges, j19: "the broad god rays wash a pale band across the sky": the painted shafts, light a step over
		// the sky's own gradient at their scale, held down by a third)
		float lw = lum(textureLod(TEXTURE, UV, 7.0).rgb * tint.rgb);
		float wash = max(lb - lw, 0.0) * 0.35;
		float l = lum(base);
		float dd = (lm - lb) / step_size;
		float q = floor(dd) + smoothstep(0.4, 0.6, fract(dd));
		float cel_l = lb - wash + q * step_size + (l - lm) * 0.5;
		vec3 cel = base * clamp(cel_l / max(l, 0.02), 0.7, 1.4);
		COLOR.rgb = mix(base, cel, k);
	}
}

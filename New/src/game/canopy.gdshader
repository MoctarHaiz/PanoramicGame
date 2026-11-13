shader_type canvas_item;
// 2026-11-13 (the owner, on the vine: "Some leaves next to the rope that looks cut"): canopy.png's hanging strands all
// fade out in one band across the picture, at one height: a soft straight line along the bottom of every strand and
// leaf. Here each ends at its own height (a slow noise across the canopy in its own units), over a short fade.

uniform float end_hi = 0.4;  // the picture's v where the shortest strands end ..
uniform float end_lo = 0.6;  // .. and the longest (canopy.png has nothing under 0.62)

varying vec2 at;

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
}

void fragment() {
	float n = 0.65 * noise(at.x / 9.0) + 0.35 * noise(at.x / 31.0 + 7.0);
	float end = mix(end_hi, end_lo, n);
	COLOR.a *= 1.0 - smoothstep(end - 0.03, end, UV.y);
	// (round 23's check, under the vine: "the bar and counter still sit on busy leaves": the leaves along the top of the
	// screen fall into the boughs' deep shade, a quiet dark ceiling behind the HUD; the lit leaves start under it)
	float ceiling = 1.0 - smoothstep(0.04, 0.23, SCREEN_UV.y);
	vec3 deep = mix(vec3(dot(COLOR.rgb, vec3(0.3, 0.59, 0.11))), COLOR.rgb, 0.5) * vec3(0.4, 0.45, 0.62);
	COLOR.rgb = mix(COLOR.rgb, deep, ceiling * 0.82);
}

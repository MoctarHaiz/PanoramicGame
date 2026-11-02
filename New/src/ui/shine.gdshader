shader_type canvas_item;
// A band of light that sweeps across a picture now and then (the logo, a medal), only over its
// opaque parts, brightest on the lighter colours.

uniform float period = 4.0;  // seconds between two sweeps
uniform float sweep = 0.9;  // seconds a sweep takes
uniform float width = 0.16;  // band width, in 0..1 of the picture
uniform float strength = 0.55;
uniform float slant = 0.35;
uniform float offset = 0.0;  // seconds: the first sweep

void fragment() {
	vec4 c = COLOR;
	float t = mod(TIME - offset, period);
	float k = t / sweep;
	if (k < 1.0) {
		float x = UV.x + UV.y * slant;
		float centre = mix(-width - 0.1, 1.0 + slant + width, k);
		float band = 1.0 - smoothstep(0.0, width, abs(x - centre));
		float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
		c.rgb += vec3(1.0, 0.97, 0.88) * band * strength * (0.35 + 0.65 * lum);
	}
	COLOR = c;
}

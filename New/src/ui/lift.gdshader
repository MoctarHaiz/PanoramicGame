shader_type canvas_item;
// Lifts a dark picture's shadows and mid-tones (a gamma under 1) and warms it a touch: the HUD's
// portrait of Panoramic reads bright in its gold ring. (Modulate above 1 does not brighten in the
// Compatibility renderer.)

uniform float gamma = 0.7;
uniform float gain = 1.08;

void fragment() {
	vec4 c = COLOR;
	c.rgb = clamp(pow(c.rgb, vec3(gamma)) * gain * vec3(1.03, 1.0, 0.96), 0.0, 1.0);
	COLOR = c;
}

shader_type canvas_item;
// A rubber stamp's ink: the print is uneven, specks of the paper show through it here and there (value
// noise on the screen position, so the border, the crown and the letters share one grain).

uniform float grain = 0.55;  // how much of the print the specks take
uniform float scale = 0.16;  // the specks' size (per screen pixel)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float n = noise(FRAGCOORD.xy * scale) * 0.65 + noise(FRAGCOORD.xy * scale * 3.1) * 0.35;
	COLOR.a *= mix(1.0, smoothstep(0.18, 0.42, n), grain);
}

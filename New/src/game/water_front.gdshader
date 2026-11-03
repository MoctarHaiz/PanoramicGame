shader_type canvas_item;
// The part of a bank or a pole standing in a pool, seen through the water (WorldView draws it over
// the ground): under the surface it is tinted towards the water's blue, deeper further down, and a
// ring of foam laps where it meets the surface. The surface waves are those of water.gdshader (the
// same formula in level x), so the lines meet. `fade_left` / `fade_right`: units over which a side
// fades into the bank (0: a hard side, as a pole standing in the water).

uniform vec2 rect_size = vec2(36.0, 100.0);
uniform float x_offset = 0.0;  // level x of the rect
uniform float fade_left = 0.0;
uniform float fade_right = 0.0;
uniform vec4 shallow : source_color = vec4(0.1, 0.36, 0.4, 1.0);  // round 2: murky, not glass
uniform vec4 deep : source_color = vec4(0.02, 0.1, 0.24, 1.0);

void fragment() {
	vec2 p = UV * rect_size;
	float x = p.x + x_offset;
	float t = TIME;
	float surface = 7.0 + sin(x * 0.045 + t * 1.7) * 1.6 + sin(x * 0.13 - t * 2.6) * 0.8 + sin(x * 0.021 - t * 0.6) * 1.1;
	float d = p.y - surface;  // depth under the surface
	if (d < -2.5) {
		discard;
	}
	float side = 1.0;
	if (fade_left > 0.0) {
		side *= smoothstep(0.0, fade_left, p.x);
	}
	if (fade_right > 0.0) {
		side *= smoothstep(0.0, fade_right, rect_size.x - p.x);
	}
	vec3 c = mix(shallow.rgb, deep.rgb, clamp((d - 3.0) / 46.0, 0.0, 1.0));
	float a = smoothstep(0.0, 3.0, d) * mix(0.38, 0.8, clamp(d / 46.0, 0.0, 1.0));
	// round 4: a bank (it fades into the ground) is muddy at the waterline, and its edge wanders
	// (no straight glassy strip down the pool's side)
	if (fade_left + fade_right > 0.0) {
		c = mix(vec3(0.22, 0.2, 0.15), c, smoothstep(2.0, 18.0, d));
		a *= 0.55 + 0.45 * sin(d * 0.37 + x * 0.21) * sin(d * 0.13 - x * 0.05);
	}
	// the foam lapping round it at the surface, bubbling
	float lap = 1.0 - smoothstep(0.0, 3.2, abs(d - 0.8));
	lap *= 0.65 + 0.35 * sin(x * 0.9 + t * 3.1) * sin(x * 0.37 - t * 1.7);
	c = mix(c, vec3(0.97, 1.0, 1.0), lap);
	a = max(a, lap * 0.95);
	COLOR = vec4(c, a * side);
}

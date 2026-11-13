shader_type canvas_item;
// Blind round 16 ("the fire is a flat cartoon flame: a simpler language than the richly painted thatch"): the
// campfire's inner tongue (HomeView.Fire): the painted flame again, smaller and another of its frames, in the
// fire's hot yellow up to a pale heart, gone before the logs (`fade_from` to `fade_to` down the picture).

uniform float fade_from = 0.5;
uniform float fade_to = 0.66;
uniform vec3 hot = vec3(1.0, 0.86, 0.46);
uniform vec3 heart = vec3(1.0, 0.98, 0.84);

void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	c.rgb = mix(hot * (0.86 + 0.2 * lum), heart, smoothstep(0.6, 0.92, lum));
	c.a *= 1.0 - smoothstep(fade_from, fade_to, UV.y);
	COLOR = c;
}

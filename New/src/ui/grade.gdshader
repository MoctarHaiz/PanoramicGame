shader_type canvas_item;
// The menu's key art graded to sit with the candy interface (j15: "a muddy desaturated backdrop vs a
// candy UI"): a little more colour and contrast, its shadows warmed, its greys lifted out of the mud;
// and a soft shade behind the title column (`shade_at`, `shade_size`: the picture's UV), so the cream
// plaque and the logo hold their edges against the bright sky.

uniform float saturation = 1.2;
uniform float contrast = 1.07;
uniform vec3 shadow_warm = vec3(0.035, 0.012, 0.0);  // added in the shadows
uniform vec2 shade_at = vec2(0.78, 0.5);
uniform vec2 shade_size = vec2(0.2, 0.36);
uniform float shade = 0.18;

void fragment() {
	vec3 c = COLOR.rgb;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(lum), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c += shadow_warm * (1.0 - smoothstep(0.0, 0.6, lum));
	vec2 d = (UV - shade_at) / shade_size;
	c *= 1.0 - shade * (1.0 - smoothstep(0.3, 1.0, length(d)));
	COLOR = vec4(clamp(c, 0.0, 1.0), COLOR.a);
}

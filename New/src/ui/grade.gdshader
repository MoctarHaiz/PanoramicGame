shader_type canvas_item;
// The menu's key art graded to sit with the candy interface (j15: "a muddy desaturated backdrop vs a
// candy UI"): a little more colour and contrast, its shadows warmed, its greys lifted out of the mud;
// and a soft shade behind the title column (`shade_at`, `shade_size`: the picture's UV), deep enough to be
// the column's backing (round 20, the judges: "the column floats on a busy sky"), the sky there calmed
// (a little less colour), so the board and the logo hold their edges against it.

uniform float saturation = 1.2;
uniform float contrast = 1.07;
uniform vec3 shadow_warm = vec3(0.035, 0.012, 0.0);  // added in the shadows
uniform vec2 shade_at = vec2(0.78, 0.5);
uniform vec2 shade_size = vec2(0.2, 0.36);
uniform float shade = 0.5;
// Blind round 22 (the menu: "no value design: even shadowless front light … same high saturation everywhere"; "darken
// and cool the left foreground and upper sky, mute the grass and mesas behind him, and keep the brightest, most
// saturated accent on his upper body and ring"): the picture falls back away from `focus_at` (his chest and the ring,
// the picture's UV; `focus_size`): a value down, cooler, less colour, by `focus` at most. By value and hue only: no
// light is added on him.
uniform vec2 focus_at = vec2(0.36, 0.34);
uniform vec2 focus_size = vec2(0.36, 0.5);
uniform float focus = 0.0;
uniform vec3 away_tint : source_color = vec3(0.62, 0.68, 0.9);

void fragment() {
	vec3 c = COLOR.rgb;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(lum), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c += shadow_warm * (1.0 - smoothstep(0.0, 0.6, lum));
	float away = focus * smoothstep(0.4, 1.3, length((UV - focus_at) / focus_size));
	c = mix(c, mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.7) * away_tint, away);
	vec2 d = (UV - shade_at) / shade_size;
	float k = shade * (1.0 - smoothstep(0.12, 1.0, length(d)));
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), k * 0.4) * (1.0 - k);
	COLOR = vec4(clamp(c, 0.0, 1.0), COLOR.a);
}

shader_type canvas_item;
// Drawn by a SoftShadow (CanvasGroup): its children, plus a soft shadow of their shape below them.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 offset = vec2(12.0, 18.0);  // screen pixels, towards the bottom right
uniform float radius = 9.0;  // blur, screen pixels
uniform vec4 shadow : source_color = vec4(0.11, 0.08, 0.2, 0.32);

const vec2 TAPS[12] = vec2[](
	vec2(0.45, 0.0), vec2(0.225, 0.39), vec2(-0.225, 0.39), vec2(-0.45, 0.0), vec2(-0.225, -0.39), vec2(0.225, -0.39),
	vec2(0.82, 0.47), vec2(0.0, 0.95), vec2(-0.82, 0.47), vec2(-0.82, -0.47), vec2(0.0, -0.95), vec2(0.82, -0.47));

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;  // the group is drawn premultiplied
	}
	vec2 at = SCREEN_UV - offset * SCREEN_PIXEL_SIZE;
	float s = textureLod(screen_texture, at, 0.0).a;
	for (int i = 0; i < 12; i++) {
		s += textureLod(screen_texture, at + TAPS[i] * radius * SCREEN_PIXEL_SIZE, 0.0).a * (i < 6 ? 1.0 : 0.6);
	}
	float shade = shadow.a * (s / 10.6) * (1.0 - c.a);
	float a = c.a + shade;
	COLOR = vec4((c.rgb * c.a + shadow.rgb * shade) / max(a, 0.0001), a);
}

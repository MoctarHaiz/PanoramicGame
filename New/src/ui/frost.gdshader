shader_type canvas_item;
// Behind the pause and game over cards: the game, blurred and tinted, like frosted glass. A few
// taps of a small mipmap of the screen (no full blur pass): soft, without the blocky grid one
// tap of a low mip shows.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.169, 0.153, 0.314, 0.5);
uniform float blur = 4.0;  // mipmap level

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * exp2(blur);
	vec3 c = textureLod(screen_texture, SCREEN_UV, blur).rgb * 0.4;
	c += textureLod(screen_texture, SCREEN_UV + vec2(0.6, 0.35) * px, blur).rgb * 0.15;
	c += textureLod(screen_texture, SCREEN_UV + vec2(-0.6, -0.35) * px, blur).rgb * 0.15;
	c += textureLod(screen_texture, SCREEN_UV + vec2(-0.35, 0.6) * px, blur).rgb * 0.15;
	c += textureLod(screen_texture, SCREEN_UV + vec2(0.35, -0.6) * px, blur).rgb * 0.15;
	COLOR = vec4(mix(c, tint.rgb, tint.a), COLOR.a);
}

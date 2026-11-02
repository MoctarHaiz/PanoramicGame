shader_type canvas_item;
// Characters (Panoramic, the bandits): a flash towards `tint` for a blow, and optionally a thin
// dark outline and a warm rim on the edges facing the light, so they pop from the painted scenery.
// (In Godot 4, COLOR already holds the texture times the modulate: it is not sampled again.)

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float outline_px = 0.0;  // outline thickness, in texture pixels (0: none)
uniform vec4 outline_colour : source_color = vec4(0.12, 0.05, 0.06, 0.85);
uniform float outline_opacity = 1.0;  // set with the node's fade (COLOR's alpha only reaches the picture)
uniform float rim = 0.0;  // 0..1
uniform float rim_px = 3.0;
uniform vec4 rim_colour : source_color = vec4(1.0, 0.82, 0.55, 1.0);
uniform vec2 rim_dir = vec2(0.8, -0.6);  // towards the light, in texture space (x right, y down)
// The stance of a stride: everything below `warp_from` (a height in 0..1 of the picture: the
// hips) slides sideways, more towards the feet, by up to `warp_px` texture pixels (+: back,
// for a picture facing right). The picture is sampled again, so its fade comes from `opacity`.
uniform float warp_px = 0.0;
uniform float warp_from = 0.5;
uniform float opacity = 1.0;

void fragment() {
	vec2 uv = UV;
	vec4 c = COLOR;
	if (warp_px != 0.0) {
		float k = smoothstep(warp_from, 1.0, UV.y);
		uv.x += warp_px * TEXTURE_PIXEL_SIZE.x * k * k;
		c = texture(TEXTURE, uv);
		c.a *= opacity;
	}
	if (rim > 0.0 && c.a > 0.0) {
		// how much of this pixel's alpha is missing a few pixels towards the light: an edge facing it
		float a = texture(TEXTURE, uv + normalize(rim_dir) * TEXTURE_PIXEL_SIZE * rim_px).a;
		float edge = clamp(c.a - a, 0.0, 1.0);
		c.rgb = mix(c.rgb, c.rgb + rim_colour.rgb * 0.75, edge * rim);
	}
	if (outline_px > 0.0 && c.a < 1.0) {
		vec2 px = TEXTURE_PIXEL_SIZE * outline_px;
		float a = 0.0;
		for (int i = 0; i < 8; i++) {
			float t = float(i) * 0.7853982;
			a = max(a, texture(TEXTURE, uv + vec2(cos(t), sin(t)) * px).a);
		}
		float o = a * outline_colour.a * outline_opacity;
		// the outline sits behind the picture
		float out_a = c.a + o * (1.0 - c.a);
		vec3 rgb = (c.rgb * c.a + outline_colour.rgb * o * (1.0 - c.a)) / max(out_a, 0.001);
		c = vec4(rgb, out_a);
	}
	c.rgb = mix(c.rgb, tint.rgb, amount);
	COLOR = c;
}

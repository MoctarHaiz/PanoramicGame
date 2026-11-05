shader_type canvas_item;
// Characters (Panoramic, the bandits): a flash towards `tint` for a blow, and optionally a thin
// dark outline and a warm rim on the edges facing the light, so they pop from the painted scenery, a warm
// bounce from one side and a back rim (home).
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
// A warm bounce from one side (the home fire): the colours multiplied towards `bounce_colour`, more on the
// side `bounce_dir` (texture space) points to; dark pixels (the ink) stay dark, no light fringe.
uniform float bounce = 0.0;
uniform vec4 bounce_colour : source_color = vec4(1.35, 1.0, 0.7, 1.0);
uniform vec2 bounce_dir = vec2(-1.0, 0.0);
uniform vec4 bounce_cool : source_color = vec4(0.72, 0.76, 0.98, 1.0);  // the side away from the fire (round 15)
uniform float bounce_scale = 0.01;  // 1 / (half the frame's width, in local px): the sprite is an atlas region
// A warm back rim (round 10, home: the lit hut behind him): a band just inside the ink on the edges that face
// up and to the sides, the light from behind wrapping his silhouette; the ink line itself stays dark.
// (round 12) the level's light on him: his lit colours raised by up to `light_gain` (the shade less, the ink not at
// all), so he is the brightest figure on screen ("a mid-brown figure against mesas of the same value")
uniform float light_gain = 1.0;
uniform float back_rim = 0.0;  // 0..1
uniform vec4 back_rim_colour : source_color = vec4(1.0, 0.6, 0.22, 1.0);
uniform float back_rim_ink_px = 3.0;  // the ink round the outline, in texture pixels (no light on it)
uniform float back_rim_px = 2.2;  // the band's width inside the ink
varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

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
	if (light_gain != 1.0) {
		float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		c.rgb = min(c.rgb * mix(1.0, light_gain, smoothstep(0.1, 0.42, lum)), vec3(1.0));
	}
	if (back_rim > 0.0 && c.a > 0.5) {
		float lit = 0.0;
		for (int i = 0; i < 6; i++) {
			float t = -1.5708 + (float(i) - 2.5) * 0.45;  // fanned round up: up-left, up-right, down to the sides
			vec2 d = vec2(cos(t), sin(t));
			float near = texture(TEXTURE, uv + d * TEXTURE_PIXEL_SIZE * back_rim_ink_px).a;
			float far = texture(TEXTURE, uv + d * TEXTURE_PIXEL_SIZE * (back_rim_ink_px + back_rim_px)).a;
			lit = max(lit, near * (1.0 - far) * pow(max(-d.y, 0.0), 1.3));  // strongest on top, none below
		}
		// screened onto the colours (a light on the form, not a painted line): the hair and skin glow warm
		vec3 glow = back_rim_colour.rgb * clamp(lit, 0.0, 1.0) * back_rim;
		c.rgb = 1.0 - (1.0 - c.rgb) * (1.0 - glow);
	}
	if (bounce > 0.0) {
		// (round 15, "drenched in uniform orange that flattens all his anatomy: fire key on one side, cooler shadow on
		// the other") the fire on its side only, the far side in a cool shade
		float x = dot(local_pos * bounce_scale, normalize(bounce_dir));
		float side = smoothstep(-0.15, 0.85, x);
		float far = smoothstep(0.1, -0.7, x);
		c.rgb *= mix(vec3(1.0), bounce_colour.rgb, bounce * side);
		c.rgb *= mix(vec3(1.0), bounce_cool.rgb, bounce * far);
	}
	c.rgb = mix(c.rgb, tint.rgb, amount);
	COLOR = c;
}

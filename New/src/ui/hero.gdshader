shader_type canvas_item;
// Panoramic's 3D render in the sunset (the menu, the results): the low sun behind him puts a warm
// rim on every edge (strongest on the side it leans to), the dusk sky a cool one; his front, in his
// own shadow, a little darker and plum; a warm grade over all, so the studio-lit render stands in
// the evening light of the backdrop.

uniform vec4 rim_colour : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform vec2 rim_dir = vec2(0.85, -0.55);  // towards the sun, in texture space (x right, y down)
uniform float rim_px = 5.0;  // how far the rim reaches in, texture pixels
uniform float rim = 1.0;
uniform vec4 sky_colour : source_color = vec4(1.0, 0.62, 0.42, 1.0);
uniform float sky_rim = 0.3;
uniform vec4 shade_tint : source_color = vec4(0.62, 0.38, 0.52, 1.0);
uniform float shade = 0.35;  // how much darker and plum his side away from the sun gets
uniform vec3 grade = vec3(1.07, 0.96, 0.9);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// the ink line around him stays dark: no rim on pixels as dark as the ink (the rim starts inside it)
	float lit_body = smoothstep(0.1, 0.24, dot(c.rgb, vec3(0.299, 0.587, 0.114)));
	c.rgb *= grade;
	// his front is in his own shadow: darker towards the dusk's plum, more so low down and on the
	// side away from the sun
	float away = clamp(smoothstep(0.75, 0.05, UV.x) * 0.6 + smoothstep(0.3, 1.0, UV.y) * 0.6, 0.0, 1.0);
	c.rgb = mix(c.rgb, c.rgb * shade_tint.rgb, away * shade);
	vec2 d = normalize(rim_dir) * TEXTURE_PIXEL_SIZE * rim_px;
	// how much of him is missing a little way off towards each light (TEXTURE is sampled here, not
	// in a function: the phones' renderer can't pass it as an argument)
	vec2 e = vec2(-d.x, d.y) * 0.8;
	float sun_edge = clamp(c.a - min(texture(TEXTURE, UV + d).a, texture(TEXTURE, UV + d * 0.5).a), 0.0, 1.0);
	float sky_edge = clamp(c.a - min(texture(TEXTURE, UV + e).a, texture(TEXTURE, UV + e * 0.5).a), 0.0, 1.0);
	c.rgb = mix(c.rgb, c.rgb * 0.5 + rim_colour.rgb * 0.85, sun_edge * sun_edge * rim * lit_body);
	c.rgb = mix(c.rgb, c.rgb * 0.7 + sky_colour.rgb * 0.4, sky_edge * sky_rim * (1.0 - sun_edge) * lit_body);
	COLOR = vec4(c.rgb, c.a * COLOR.a);
}

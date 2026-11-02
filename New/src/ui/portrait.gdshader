shader_type canvas_item;
// Panoramic's portrait on the menu, lit by the sunset behind him (the user's art, only graded): a
// warm rim where his edges face the low sun on his left, his shadows drawn towards the dusk's plum,
// a warm grade over all, and his chest fading into the dark grass at the bottom of the screen (or
// out, over the results' backdrop).

uniform vec4 rim_colour : source_color = vec4(1.0, 0.62, 0.3, 1.0);
uniform vec2 rim_dir = vec2(-0.9, -0.3);  // towards the sun, in texture space (x right, y down)
uniform float rim_px = 12.0;  // how far the rim reaches in, texture pixels
uniform float rim = 1.0;
uniform vec4 shade_tint : source_color = vec4(0.5, 0.26, 0.46, 1.0);
uniform float shade = 0.42;
uniform float fade_from = 0.78;  // share of the height where the fade into the grass starts
uniform vec4 fade_colour : source_color = vec4(0.11, 0.04, 0.08, 1.0);
uniform bool fade_to_clear = false;  // fade the chest out (over a backdrop) instead of into a colour

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	c.rgb = mix(c.rgb, c.rgb * shade_tint.rgb * 1.7, (1.0 - smoothstep(0.08, 0.5, lum)) * shade);
	c.rgb *= vec3(1.08, 0.95, 0.9);  // the sunset's warmth over him
	// the rim: how much of this pixel's alpha is missing a few pixels towards the sun
	vec2 d = normalize(rim_dir) * TEXTURE_PIXEL_SIZE;
	float a = min(texture(TEXTURE, UV + d * rim_px).a, texture(TEXTURE, UV + d * rim_px * 0.5).a);
	float edge = clamp(c.a - a, 0.0, 1.0);
	c.rgb = mix(c.rgb, c.rgb * 0.6 + rim_colour.rgb * 0.75, edge * rim);
	float fade = smoothstep(fade_from, 1.0, UV.y);
	if (fade_to_clear) {
		c.a *= 1.0 - fade;
	} else {
		c.rgb = mix(c.rgb, fade_colour.rgb, fade * 0.9);
	}
	COLOR = vec4(c.rgb, c.a * COLOR.a);
}

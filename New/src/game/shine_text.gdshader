shader_type canvas_item;
// Big reward numbers (the "+1" of a rescue): the letters, drawn pure white, are filled with a
// gold gradient, pale at the top with a glossy band, deep orange at the bottom, like the candy
// numbers of top games. Outlines and the shadow, drawn in other colours, keep them.

uniform vec4 top_colour : source_color = vec4(1.0, 0.99, 0.88, 1.0);
uniform vec4 mid_colour : source_color = vec4(1.0, 0.84, 0.3, 1.0);
uniform vec4 bottom_colour : source_color = vec4(1.0, 0.52, 0.12, 1.0);
uniform float top_y = -50.0;  // local y of the top and the bottom of the letters
uniform float bottom_y = 40.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (COLOR.r > 0.99 && COLOR.g > 0.99 && COLOR.b > 0.99) {
		float k = clamp((local_y - top_y) / (bottom_y - top_y), 0.0, 1.0);
		vec3 g = k < 0.42 ? mix(top_colour.rgb, mid_colour.rgb, smoothstep(0.0, 0.42, k))
				: mix(mid_colour.rgb, bottom_colour.rgb, (k - 0.42) / 0.58);
		g = mix(g, vec3(1.0), 0.5 * (1.0 - smoothstep(0.16, 0.24, k)));  // the gloss
		COLOR = vec4(g, c.a * COLOR.a);
	} else {
		COLOR = c * COLOR;
	}
}

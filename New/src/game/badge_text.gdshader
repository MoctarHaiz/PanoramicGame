shader_type canvas_item;
// Reward numbers (the "+1" of a knock-out): the letters, drawn pure white, are filled with the Red
// Bob's colours, pale gold at the top with a glossy band, gold, then orange and red at the bottom.
// The dark outlines and the shadow, drawn in other colours, keep theirs. Works with the distance-field
// (MSDF) title font: it never samples TEXTURE itself, it only recolours COLOR, whose alpha Godot has
// already computed from the font.

uniform vec4 top_colour : source_color = vec4(1.0, 0.97, 0.72, 1.0);
uniform vec4 mid_colour : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform vec4 bottom_colour : source_color = vec4(0.93, 0.2, 0.08, 1.0);
uniform float top_y = -50.0;  // local y of the top and the bottom of the letters
uniform float bottom_y = 40.0;

varying float local_y;
varying vec4 vertex_colour;

void vertex() {
	local_y = VERTEX.y;
	vertex_colour = COLOR;
}

void fragment() {
	if (vertex_colour.r > 0.99 && vertex_colour.g > 0.99 && vertex_colour.b > 0.99) {
		float k = clamp((local_y - top_y) / (bottom_y - top_y), 0.0, 1.0);
		vec3 g = k < 0.45 ? mix(top_colour.rgb, mid_colour.rgb, smoothstep(0.0, 0.45, k))
				: mix(mid_colour.rgb, bottom_colour.rgb, smoothstep(0.45, 1.0, k));
		g = mix(g, vec3(1.0), 0.45 * (1.0 - smoothstep(0.14, 0.24, k)));  // the gloss
		COLOR.rgb = g;
	}
}

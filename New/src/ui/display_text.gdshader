shader_type canvas_item;
// Drawn by a DisplayText: glyphs whose colour is `marker` are its fill, and get a top-to-bottom
// gradient in each letter's own frame (VERTEX is the glyph's, before draw_set_transform), so the
// gradient follows every letter along an arc. Outlines and depth keep their colours.

uniform vec4 marker : source_color = vec4(1.0, 0.0, 1.0, 1.0);
uniform vec4 top_colour : source_color = vec4(1.0);
uniform vec4 bottom_colour : source_color = vec4(1.0);
uniform float y_top = -60.0;  // glyph px above the baseline where the gradient starts
uniform float y_bottom = 0.0;

varying float fill;
varying float local_y;

void vertex() {
	vec3 d = abs(COLOR.rgb - marker.rgb);
	fill = (d.r + d.g + d.b) < 0.03 ? 1.0 : 0.0;
	local_y = VERTEX.y;
}

void fragment() {
	if (fill > 0.5) {
		float t = clamp((local_y - y_top) / (y_bottom - y_top), 0.0, 1.0);
		COLOR.rgb = mix(top_colour.rgb, bottom_colour.rgb, t * t * (3.0 - 2.0 * t));
	}
}

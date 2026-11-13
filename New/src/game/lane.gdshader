shader_type canvas_item;
// Blind round 23 (of the fight and the throw: "the ground the fighters stand on is the bottom 9% of the frame: a moss
// strip with a soft blurred top edge ... both figures float on a thin tile", "give them a real lit ground of about 15%
// of the frame"): the ground's painted top (lane.png, tools/art/kie/world.py lane(): a level ribbon of trodden grass
// with a worn track along it, seen a little from above; under its near edge the top of its cut bank), drawn by
// TerrainView._lane() along every top long enough for it (LANE_RUN, LANE_FLOAT: a short ledge keeps its turf mat), in
// the light it is drawn with (COLOR.rgb: the home's dusk and fire, TerrainView._home_light_at).
// Where a top ends at an open side the running strip is cut to an end here: COLOR.a is how far along the end's piece
// the fragment is (0: `end_out` units outside the cell's open side, 1: `end_w` units from there, inside; 1 all along
// a cell with no open side). The top ends in a rounded, uneven outline, inked as the painting is; its bank fades
// out before the corner, where the ground's own earth is rounded off (terrain_shape.png).

uniform vec4 ink_colour : source_color = vec4(0.12, 0.13, 0.19, 1.0);
uniform float far_v = 0.1313;  // of the picture's height: its far edge,
uniform float near_v = 0.7125;  // ... and its near edge (world.py lane() prints them)
uniform float end_w = 38.0;  // units an end's piece is long,
uniform float end_out = 6.0;  // ... of them outside the cell's open side
uniform float bulge = 4.5;  // units the top's end stands out half way between its far and near edges
uniform float line = 0.9;  // units: the ink line along an end

varying float along;
varying vec3 light;

void vertex() {
	along = COLOR.a;
	light = COLOR.rgb;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float x = along * end_w - end_out;  // units inside the cell's open side
	float t = clamp((UV.y - far_v) / (near_v - far_v), 0.0, 1.0);  // 0 on its far edge, 1 on its near edge
	float round_off = sqrt(max(1.0 - (2.0 * t - 1.0) * (2.0 * t - 1.0), 0.0));  // (1 half way, 0 at both edges)
	float outline = 1.5 - bulge * round_off + 0.7 * sin(UV.y * 61.0) * round_off;
	float d = x - outline;  // units inside the end's outline
	float aa = max(fwidth(d), 0.001);
	float inside = smoothstep(-aa, aa, d);
	vec3 c = mix(ink_colour.rgb, tex.rgb, smoothstep(line - aa, line + aa, d));
	float a = tex.a * inside;
	// under the near edge: the bank and the blades hanging over it, from a little inside the corner
	a *= mix(1.0, smoothstep(3.0, 13.0, x), smoothstep(near_v - 0.01, near_v + 0.02, UV.y));
	COLOR = vec4(c * light, a);
}

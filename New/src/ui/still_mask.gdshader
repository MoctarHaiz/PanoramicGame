shader_type canvas_item;
// Fades parts of a hero still's own baked shadow that no longer fit the ground drawn under him (UI r23):
// - `cut`, a band in the picture's UV (x0, y0, x1, y1) with soft edges (`feather`: x, y): the knocked-out
//   still's side-view smudge under the chakram lying on the floor, detached from it ("a decal");
// - `edge_fade`: below `edge_from` (a share of its height), its shadow band fades out towards the picture's
//   left and right sides over that share of its width (the victory still's band ran to its edges: a hard
//   vertical cut on the ground, once hidden by the grass tufts).

uniform vec4 cut = vec4(2.0, 2.0, 2.0, 2.0);
uniform vec2 feather = vec2(0.04, 0.006);
uniform float edge_fade = 0.0;
uniform float edge_from = 1.0;
uniform float edge_fade_low = 0.0;  // a wider fade under `edge_low_from` (under his boots: nothing of him there)
uniform float edge_low_from = 1.0;

void fragment() {
	float m = smoothstep(cut.x - feather.x, cut.x + feather.x, UV.x) * (1.0 - smoothstep(cut.z - feather.x, cut.z + feather.x, UV.x))
			* smoothstep(cut.y - feather.y, cut.y + feather.y, UV.y) * (1.0 - smoothstep(cut.w - feather.y, cut.w + feather.y, UV.y));
	float side = min(UV.x, 1.0 - UV.x);
	float w = mix(edge_fade, max(edge_fade_low, edge_fade), smoothstep(edge_low_from, edge_low_from + 0.012, UV.y));
	float e = edge_fade > 0.0 ? (1.0 - smoothstep(0.0, w, side)) * smoothstep(edge_from, edge_from + 0.012, UV.y) : 0.0;
	COLOR.a *= (1.0 - m) * (1.0 - e);
}

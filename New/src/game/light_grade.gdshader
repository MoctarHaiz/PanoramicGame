shader_type canvas_item;
render_mode blend_premul_alpha;
// Drawn over the whole world (WorldView), under the HUD: the light of the low sun in the upper left
// added as a warm wash, and a cool violet shade towards the edges, the bottom and under the HUD.
// It fuses the sky, the ground and the characters, painted separately, into one lit picture and
// keeps the eye in the middle, on the play.

uniform vec4 warm : source_color = vec4(1.0, 0.78, 0.50, 1.0);
uniform vec4 cool : source_color = vec4(0.17, 0.09, 0.27, 1.0);
uniform float wash = 0.1;  // (round 7: the sun's wash softer)
uniform float vignette = 0.4;  // round 3: deeper darks at the edges (value structure)
uniform float top = 0.22;  // behind the hearts, the progress and the counter
uniform float top_reach = 0.14;  // share of the height
uniform float bottom = 0.42;  // the foreground band along the bottom edge in shade (depth; round 3: deeper)
uniform vec2 sun = vec2(0.09, 0.1);  // where the sun is, in UV
uniform float aspect = 2.2;  // width / height of the view

void fragment() {
	vec2 p = vec2(UV.x * aspect, UV.y);
	float light = 1.0 - smoothstep(0.0, 1.4, distance(p, vec2(sun.x * aspect, sun.y)));
	vec2 c = UV - 0.5;
	c.x *= min(aspect, 2.4) / 1.5;  // oval on wide screens, round-ish on tablets
	float edge = smoothstep(0.42, 1.0, length(c) * 1.3);
	// round 3: the play lane (where the runners and the bandits are, ~60-90 % down) keeps its light:
	// dark threats must not sink into a dark corner; the frame darkens above and below it
	float lane = smoothstep(0.5, 0.66, UV.y) * (1.0 - smoothstep(0.88, 0.95, UV.y));
	edge *= 1.0 - 0.75 * lane;
	float under_ui = top * pow(1.0 - smoothstep(0.0, top_reach, UV.y), 1.5);
	float low = bottom * smoothstep(0.9, 1.0, UV.y);  // (under the ground line: the soil, the near grass)
	float a = clamp(vignette * edge + under_ui + low, 0.0, 0.85);
	COLOR = vec4(warm.rgb * wash * light * light + cool.rgb * a, a);
}

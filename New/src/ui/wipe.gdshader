shader_type canvas_item;
// Screen transition: a disc of colour grows from `center` until it covers the screen (reveal off),
// then a hole grows from `center` to show the next screen (reveal on). The colour reads as a soft
// candy surface: a little lighter in the middle of the screen, a bright rim along its edge, and a
// soft shadow cast on the screen under it.

uniform vec4 color : source_color = vec4(0.596, 0.498, 1.0, 1.0);
uniform vec2 center = vec2(0.5);  // in 0..1 of the screen
uniform vec2 rect_size = vec2(800.0, 1280.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool reveal = false;

const float RIM = 28.0;  // design px
const float SHADOW = 48.0;
const vec3 SHADOW_COLOUR = vec3(0.1, 0.05, 0.28);

void fragment() {
	vec2 c = center * rect_size;
	float far = max(max(distance(c, vec2(0.0)), distance(c, vec2(rect_size.x, 0.0))),
			max(distance(c, vec2(0.0, rect_size.y)), distance(c, rect_size)));
	float r = progress * (far + SHADOW + 8.0);
	float d = distance(UV * rect_size, c);
	float inside = 1.0 - smoothstep(r - 1.5, r + 1.5, d);
	float cover = reveal ? 1.0 - inside : inside;  // where the colour is
	float depth = reveal ? d - r : r - d;  // how far into the colour from its edge
	vec3 surface = color.rgb * mix(1.1, 0.92, clamp(distance(UV, vec2(0.5)) * 1.3, 0.0, 1.0));
	float rim = (1.0 - smoothstep(2.0, RIM, depth)) * cover;
	surface = mix(surface, vec3(1.0), 0.18 * rim);
	// a trim along the edge, like the panels': a gold band, then a dark ink line
	float gold = (smoothstep(1.0, 2.5, depth) - smoothstep(7.0, 8.5, depth)) * cover;
	float ink = (smoothstep(8.5, 10.0, depth) - smoothstep(12.0, 13.5, depth)) * cover;
	surface = mix(surface, vec3(1.0, 0.83, 0.42), gold);
	surface = mix(surface, vec3(0.18, 0.05, 0.02), ink * 0.85);
	float shade = (1.0 - smoothstep(0.0, SHADOW, -depth)) * (1.0 - cover) * 0.3 * min(progress * 12.0, 1.0);
	float a = cover + shade;
	COLOR = vec4(mix(SHADOW_COLOUR, surface, cover / max(a, 0.0001)), a * color.a);
}

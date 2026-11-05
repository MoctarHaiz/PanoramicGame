shader_type canvas_item;
render_mode blend_add;
// A sun's bloom drawn over its rect (added light), worked out per pixel: a smooth radial falloff (an
// ellipse in a wide rect), an optional white-hot disc in its middle, and a dither of half a level
// in screen space, so the 8-bit screen shows no rings (stacked discs and stretched small gradients
// stepped into concentric bands) and no visible grain. The vertex colour tints it, its alpha the
// bloom's strength.

uniform float falloff = 2.2;  // how fast the bloom fades: higher is tighter
uniform float core = 0.0;  // the white-hot disc's strength (0: none)
uniform float core_radius = 0.12;  // the disc's radius, as a share of the rect's half size
uniform vec4 core_colour : source_color = vec4(1.0, 0.97, 0.88, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float bloom = pow(clamp(1.0 - d, 0.0, 1.0), falloff);
	float disc = core * (1.0 - smoothstep(core_radius * 0.55, core_radius, d));
	vec3 light = COLOR.rgb * bloom * COLOR.a + core_colour.rgb * disc;
	float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	COLOR = vec4(light + n / 255.0, 1.0);
}

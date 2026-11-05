shader_type canvas_item;
render_mode blend_premul_alpha;
// A sun's bloom drawn over its rect (added light), worked out per pixel: a smooth radial falloff (an
// ellipse in a wide rect), an optional white-hot disc in its middle, and a dither of half a level
// in screen space, so the 8-bit screen shows no rings (stacked discs and stretched small gradients
// stepped into concentric bands) and no visible grain. The vertex colour tints it, its alpha the
// bloom's strength.
// (key art k6, "a flat white disc": a layered sun) with `paint` on, the disc and a gold corona round it are
// painted over what is behind (premultiplied: the bloom is still added, the disc stays white and the corona
// gold however bright the sky under them), the bloom fading from the corona into the haze. With `paint` off
// it adds everything, as before.

uniform float falloff = 2.2;  // how fast the bloom fades: higher is tighter
uniform float core = 0.0;  // the white-hot disc's strength (0: none)
uniform float core_radius = 0.12;  // the disc's radius, as a share of the rect's half size
uniform vec4 core_colour : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform float paint = 0.0;  // 1: the disc and the corona painted over the sky, not added
uniform float corona = 0.0;  // the gold ring's opacity at the disc's edge (0: none)
uniform float corona_radius = 0.3;  // where it has faded out, a share of the rect's half size
uniform vec4 corona_colour : source_color = vec4(1.0, 0.8, 0.3, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float bloom = pow(clamp(1.0 - d, 0.0, 1.0), falloff);
	float disc = core * (1.0 - smoothstep(core_radius * 0.55, core_radius, d));
	vec3 added = COLOR.rgb * bloom * COLOR.a;
	float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	if (paint > 0.0) {
		float edge = core_radius * 0.82;
		float disc_a = clamp(core, 0.0, 1.0) * (1.0 - smoothstep(edge, core_radius, d));
		float t = clamp((d - edge) / max(corona_radius - edge, 1e-4), 0.0, 1.0);
		float ring_a = corona * pow(1.0 - t, 1.15) * paint;
		// the corona's inner edge a little hotter (gold into white), its outer edge a little redder (into the haze)
		vec3 ring_c = mix(mix(corona_colour.rgb, vec3(1.0, 0.93, 0.62), 1.0 - smoothstep(0.0, 0.14, t)),
				corona_colour.rgb * vec3(1.0, 0.82, 0.75), smoothstep(0.5, 1.0, t));
		vec3 under = ring_c * ring_a;  // premultiplied: the disc over the corona over the sky and its bloom
		float a = ring_a;
		vec3 rgb = core_colour.rgb * disc_a + under * (1.0 - disc_a);
		a = disc_a + a * (1.0 - disc_a);
		COLOR = vec4(rgb + added * (1.0 - a) + n / 255.0, a);
	} else {
		COLOR = vec4(added + core_colour.rgb * disc + n / 255.0, 0.0);
	}
}

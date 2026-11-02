shader_type canvas_item;
// Background of the menu pages: a lavender sky, deep at the top and pale and warm at the horizon,
// with a soft light behind the page's main item, slow light rays turning around it, and a
// gentle vignette.

uniform vec4 top_colour : source_color = vec4(0.392, 0.271, 0.871, 1.0);  // #6445de
uniform vec4 middle_colour : source_color = vec4(0.596, 0.498, 1.0, 1.0);  // #987fff, the brand
uniform vec4 bottom_colour : source_color = vec4(0.851, 0.776, 1.0, 1.0);  // #d9c6ff, the horizon
uniform vec4 glow_colour : source_color = vec4(1.0, 0.851, 0.925, 1.0);  // #ffd9ec, warm light low down
uniform vec2 size = vec2(800.0, 1280.0);
uniform vec2 light_at = vec2(0.5, 0.27);  // UV
uniform float light_radius = 620.0;  // design px
uniform float light_strength = 0.22;
uniform float rays = 0.0;  // strength of the light rays (0: none)
uniform float ray_count = 16.0;
uniform float ray_reach = 900.0;  // design px

void fragment() {
	float y = UV.y;
	vec3 c = y < 0.45 ? mix(top_colour.rgb, middle_colour.rgb, smoothstep(0.0, 0.45, y))
			: mix(middle_colour.rgb, bottom_colour.rgb, smoothstep(0.45, 1.0, y));
	c = mix(c, glow_colour.rgb, 0.45 * smoothstep(0.62, 1.0, y));  // a warm dawn along the horizon
	vec2 p = UV * size - light_at * size;
	float d = length(p);
	if (rays > 0.0) {
		float a = atan(p.y, p.x) + TIME * 0.05;
		float stripe = smoothstep(0.3, 0.62, sin(a * ray_count) * 0.5 + 0.5);
		float fade = (1.0 - smoothstep(ray_reach * 0.2, ray_reach, d)) * smoothstep(40.0, 200.0, d);
		c = mix(c, vec3(1.0), rays * stripe * fade);
	}
	c = mix(c, vec3(1.0), light_strength * (1.0 - smoothstep(0.0, 1.0, d / light_radius)));
	float corner = smoothstep(0.55, 1.2, distance(UV, vec2(0.5, 0.42)));
	c *= 1.0 - 0.14 * corner;
	COLOR = vec4(c, 1.0);
}

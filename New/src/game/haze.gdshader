shader_type canvas_item;
// Background sprites (trees) seen through warm air: their colour drawn towards the haze of the
// horizon, more at their foot (the air is thickest near the ground). One material per depth.

uniform vec4 haze_colour : source_color = vec4(0.96, 0.78, 0.57, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.3;
uniform float foot : hint_range(0.0, 1.0) = 0.25;  // extra haze over the lowest part of the sprite
uniform vec4 tint : source_color = vec4(1.0);  // round 4: near layers darker and richer (haze only far away)
uniform float far_top = 0.0;  // round 10: extra haze over its upper part (a strip's far crests)

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float k = clamp(amount + foot * smoothstep(0.6, 1.0, UV.y) + far_top * (1.0 - smoothstep(0.25, 0.7, UV.y)), 0.0, 1.0);
	COLOR = vec4(mix(t.rgb * tint.rgb, haze_colour.rgb, k), t.a * COLOR.a);
}

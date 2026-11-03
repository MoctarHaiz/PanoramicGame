shader_type canvas_item;
// Round 5: an ink line just inside a picture's silhouette, as round the hero (the playfield's props).
// In Godot 4 COLOR already holds the texture times the modulate.

uniform vec4 ink_colour : source_color = vec4(0.14, 0.07, 0.07, 1.0);
uniform float width = 2.5;  // texels

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float around = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float edge = clamp(COLOR.a - around, 0.0, 1.0);  // inside, next to the outside
	COLOR.rgb = mix(COLOR.rgb, ink_colour.rgb, edge * 0.85);
}

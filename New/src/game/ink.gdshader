shader_type canvas_item;
// Round 5: an ink line just inside a picture's silhouette, as round the hero (the playfield's props).
// In Godot 4 COLOR already holds the texture times the modulate.
// Round 21 (the judges, j17: "a sapling lines up with his forward hand: he carries a twig"): what of a prop would
// show round his arms and hands (`clear`: that box in the props' units, PropView) fades out, softly at its edges.

uniform vec4 ink_colour : source_color = vec4(0.14, 0.07, 0.07, 1.0);
uniform float width = 2.5;  // texels
uniform vec4 clear = vec4(0.0);  // round 21: x0, y0, x1, y1 (units); empty: none
uniform float clear_soft = 16.0;

varying vec2 at;

void vertex() {
	at = VERTEX;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float around = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float edge = clamp(COLOR.a - around, 0.0, 1.0);  // inside, next to the outside
	COLOR.rgb = mix(COLOR.rgb, ink_colour.rgb, edge * 0.85);
	if (clear.z > clear.x) {
		vec2 d = max(max(clear.xy - at, at - clear.zw), vec2(0.0));
		COLOR.a *= smoothstep(0.0, clear_soft, max(d.x, d.y));
	}
}

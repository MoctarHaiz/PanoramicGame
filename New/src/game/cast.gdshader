shader_type canvas_item;
// His shadow thrown on the hut by the fire (HeroView.HOME_CAST): his picture's shape alone, in the colour it is drawn
// with, soft: read from a ring of places round each point (blind round 19: "a faint ring-shaped ghost on the thatch
// right of the door ... like a rendering artefact": the crisp shadow of the chakram in his hand, its hole and all).

uniform float soft = 9.0;  // px of his picture the shadow's edge is spread over

varying vec4 drawn;

void vertex() {
	drawn = COLOR;
}

void fragment() {
	float a = texture(TEXTURE, UV).a * 2.0;
	for (int i = 0; i < 8; i++) {
		float w = float(i) * 0.7854;
		vec2 d = vec2(cos(w), sin(w)) * TEXTURE_PIXEL_SIZE * soft;
		a += texture(TEXTURE, UV + d).a + texture(TEXTURE, UV + d * 0.5).a;
	}
	COLOR = vec4(drawn.rgb, smoothstep(0.1, 0.8, a / 18.0) * drawn.a);
}

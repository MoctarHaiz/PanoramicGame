shader_type canvas_item;
// (round 24) A fighter's shadow cast on the painted ground (HeroView.lay_cast): its picture's shape alone, laid over to
// its right along the ground, flat and hard-edged as the fighters' own shade is, in the colour it is drawn with.

varying vec4 drawn;

void vertex() {
	drawn = COLOR;
}

void fragment() {
	COLOR = vec4(drawn.rgb, smoothstep(0.35, 0.65, texture(TEXTURE, UV).a) * drawn.a);
}

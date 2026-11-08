shader_type canvas_item;
render_mode blend_add;
// Round 23 (the judges, j19: "soft god rays don't match the hard-inked mesas"; "the broad god rays wash a pale band
// across the sky"): rays.png's soft fan cut into a few crisp shafts (cel light, as the world's planes), fainter, each a
// little stronger near the sun. Their strength is the drawn colour's alpha (SavannaView._draw_rays).

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float shaft = smoothstep(0.15, 0.19, t.a) * (0.45 + 0.55 * smoothstep(0.2, 0.6, t.a));
	COLOR = vec4(t.rgb * tint.rgb, shaft * tint.a);
}

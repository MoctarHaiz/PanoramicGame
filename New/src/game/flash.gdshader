shader_type canvas_item;
// A character lit up for an instant (a blow, a catch): its picture blended towards `tint`.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, tint.rgb, amount), c.a);
}

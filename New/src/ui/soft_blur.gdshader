shader_type canvas_item;
// The game behind a panel: a small picture of it (Ui.blurred_snapshot, 1/16 of the screen) drawn
// stretched over the screen. Plain bilinear stretching of so few pixels shows blocks and stair-stepped
// edges; here every pixel is a cubic B-spline sample of it (four bilinear taps, Sigg & Hadwiger): a
// smooth Gaussian-like blur with no block, at the cost of four texture reads, in one draw call.
// `grey` drains its colour (a defeat: the world goes cold and grey behind the panel).

uniform float grey : hint_range(0.0, 1.0) = 0.0;
varying vec4 tint;  // the vertex colour (modulate): COLOR in fragment() already holds the texture

void vertex() {
	tint = COLOR;
}

vec4 cubic(float v) {
	vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
	vec4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return vec4(x, y, z, w) * (1.0 / 6.0);
}

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 p = UV / texel - 0.5;
	vec2 f = fract(p);
	p -= f;
	vec4 xc = cubic(f.x);
	vec4 yc = cubic(f.y);
	vec4 c = p.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 s = vec4(xc.xz + xc.yw, yc.xz + yc.yw);
	vec4 o = (c + vec4(xc.yw, yc.yw) / s) * texel.xxyy;
	vec4 s0 = texture(TEXTURE, o.xz);
	vec4 s1 = texture(TEXTURE, o.yz);
	vec4 s2 = texture(TEXTURE, o.xw);
	vec4 s3 = texture(TEXTURE, o.yw);
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	vec4 blur = mix(mix(s3, s2, sx), mix(s1, s0, sx), sy);
	blur.rgb = mix(blur.rgb, vec3(dot(blur.rgb, vec3(0.3, 0.59, 0.11))), grey);
	COLOR = blur * tint;
}

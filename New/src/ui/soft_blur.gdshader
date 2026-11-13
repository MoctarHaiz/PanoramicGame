shader_type canvas_item;
// The scrim behind a panel over the game: a small, soft picture of the game (Ui.blurred_snapshot: 1/8 of
// the screen; the settings: the menu's key art, small) drawn stretched over the screen through a cubic
// B-spline (four bilinear taps, Sigg & Hadwiger), five times a texel apart (a smooth blur, no blocks, the
// scene still recognisable), then graded into one mood (j15: "a muddy dark blurred screenshot, no mood"):
// - a gradient map of the scene's own values: its shadows mapped to `shadow_tint`, its middle tones
//   to `mid_tint`, its lights to `light_tint` (`duo`: how much of it over the picture's own
//   colours), so the frozen scene reads as one tinted mood (warm dusk for the pause, cold slate for a defeat, gold for a win);
// - a soft light behind the panel (`glow_colour`, its alpha the strength, round on any screen shape);
// - a vignette in `vignette_colour` closing the corners;
// - half a level of dither: the 8-bit screen shows no bands in the smooth gradients.
// `grey` drains the picture before the duotone; `tame` softens its brightest parts (the sun's bloom).

uniform float grey : hint_range(0.0, 1.0) = 0.0;
uniform float tame : hint_range(0.0, 1.0) = 0.0;
uniform vec4 shadow_tint : source_color = vec4(0.12, 0.05, 0.13, 1.0);
uniform vec4 mid_tint : source_color = vec4(0.45, 0.18, 0.3, 1.0);
uniform vec4 light_tint : source_color = vec4(0.92, 0.62, 0.38, 1.0);
uniform float duo : hint_range(0.0, 1.0) = 0.0;
uniform float exposure = 1.0;
uniform vec4 glow_colour : source_color = vec4(1.0, 0.8, 0.5, 0.0);
uniform vec2 glow_at = vec2(0.5, 0.5);  // in the screen's UV
uniform float glow_size = 0.6;  // its radius, a share of the screen's height
uniform vec4 vignette_colour : source_color = vec4(0.04, 0.01, 0.05, 1.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
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

// The picture at `uv` through a cubic B-spline (four bilinear taps).
vec4 spline(sampler2D tex, vec2 uv, vec2 texel) {
	vec2 p = uv / texel - 0.5;
	vec2 f = fract(p);
	p -= f;
	vec4 xc = cubic(f.x);
	vec4 yc = cubic(f.y);
	vec4 c = p.xxyy + vec2(-0.5, 1.5).xyxy;
	vec4 s = vec4(xc.xz + xc.yw, yc.xz + yc.yw);
	vec4 o = (c + vec4(xc.yw, yc.yw) / s) * texel.xxyy;
	vec4 s0 = texture(tex, o.xz);
	vec4 s1 = texture(tex, o.yz);
	vec4 s2 = texture(tex, o.xw);
	vec4 s3 = texture(tex, o.yw);
	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);
	return mix(mix(s3, s2, sx), mix(s1, s0, sx), sy);
}

void fragment() {
	// five of them, the four round the middle one a texel away on the diagonals: the small picture's own texels
	// (each the average of a block of the screen) leave no step along a slanted edge (blind round 12: "the blurred
	// background shows blocky low-resolution artefacts")
	vec2 texel = TEXTURE_PIXEL_SIZE;
	vec2 d = texel * 1.05;
	vec4 blur = spline(TEXTURE, UV, texel) * 0.28
			+ (spline(TEXTURE, UV + d, texel) + spline(TEXTURE, UV - d, texel)
			+ spline(TEXTURE, UV + vec2(d.x, -d.y), texel) + spline(TEXTURE, UV + vec2(-d.x, d.y), texel)) * 0.18;
	float lum = dot(blur.rgb, vec3(0.3, 0.59, 0.11));
	blur.rgb = mix(blur.rgb, vec3(lum), grey);
	blur.rgb *= 1.0 - 0.6 * tame * smoothstep(0.38, 0.9, lum);  // the sun's bloom: no bright smudge
	lum = dot(blur.rgb, vec3(0.3, 0.59, 0.11));
	float t = smoothstep(0.03, 0.85, lum);
	vec3 duotone = t < 0.5 ? mix(shadow_tint.rgb, mid_tint.rgb, t * 2.0) : mix(mid_tint.rgb, light_tint.rgb, t * 2.0 - 1.0);
	vec3 col = mix(blur.rgb, duotone, duo) * exposure;
	float aspect = texel.y / texel.x;  // the picture has the screen's shape
	vec2 q = (UV - glow_at) * vec2(aspect, 1.0);
	float g = 1.0 - smoothstep(0.0, glow_size, length(q));
	col += glow_colour.rgb * glow_colour.a * g * g;
	vec2 e = (UV - 0.5) * 2.0;
	float v = smoothstep(0.45, 1.45, length(e * vec2(1.0, 0.85)));
	col = mix(col, vignette_colour.rgb, vignette * v);
	float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	col += n / 255.0;
	COLOR = vec4(col, blur.a) * tint;
}

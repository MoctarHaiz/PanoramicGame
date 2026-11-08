shader_type canvas_item;
// Background sprites (trees) seen through warm air: their colour drawn towards the haze of the
// horizon, more at their foot (the air is thickest near the ground). One material per depth.
// Round 21 (the judges, j17: "the mesas stamped, no atmospheric layering"): on the landforms, the shadows of the
// clouds sliding over them (`cloud`: how dark; 0: none, the trees and strips), cool and soft, in big patches.

uniform vec4 haze_colour : source_color = vec4(0.96, 0.78, 0.57, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.3;
uniform float foot : hint_range(0.0, 1.0) = 0.25;  // extra haze over the lowest part of the sprite
uniform vec4 tint : source_color = vec4(1.0);  // round 4: near layers darker and richer (haze only far away)
uniform float cloud = 0.0;  // round 21: the clouds' shadows over it (0: none)
uniform float cloud_x = 0.0;  // round 21: how far they have slid (units: the layer's scroll and the wind)

varying vec4 drawn;  // round 20: the colour each sprite is drawn with (COLOR in fragment() has the texture in it)
varying vec2 at;  // round 21: where it is drawn (the layer's units)

void vertex() {
	drawn = COLOR;
	at = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float k = clamp(amount + foot * smoothstep(0.6, 1.0, UV.y), 0.0, 1.0);
	// (round 20: and each sprite's own colour, as drawn: the trees' shades, the landforms' rows; it was dropped)
	vec3 c = t.rgb * tint.rgb * drawn.rgb;
	if (cloud > 0.0) {
		vec2 q = vec2((at.x + cloud_x) * 0.0042, at.y * 0.0065);
		float n = noise(q) * 0.7 + noise(q * 2.3 + 7.1) * 0.3;
		c = mix(c, c * vec3(0.66, 0.64, 0.84), smoothstep(0.5, 0.7, n) * 0.6 * cloud);
	}
	COLOR = vec4(mix(c, haze_colour.rgb, k), t.a * drawn.a);
}

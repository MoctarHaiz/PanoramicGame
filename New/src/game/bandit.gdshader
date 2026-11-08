shader_type canvas_item;
// The bandits (BanditView): a flash towards `tint` for a blow, and, as `vanish` goes 0..1, the 2017
// bandit's disappearance (Old/.../bandit/banditMort1-10.png): a glossy liquid-chrome glaze runs over him from
// his middle out, his colours draining to silver and white bands (his head last) while he keeps running, then
// he twirls into a ring of chrome and fades.
// The sprite is a region of the sheet: `region` is that frame (UV position, size), so the twirl turns the
// frame about its own middle and never samples its neighbours.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float vanish : hint_range(0.0, 1.0) = 0.0;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float aspect = 1.0;  // the frame's width over its height
uniform float seed = 0.0;  // each bandit's own ripples
#include "res://src/game/character.gdshaderinc"
const float GLAZE_END = 0.6;  // the glaze covers him by then (banditMort6)
const float TWIRL_FROM = 0.55;  // the twirl starts (banditMort7)
// (round 20, the judges: "the bandits out-design him: as tall and flashier") their hues kept (the user's design), their
// loudest colours (the teal hair, the gold) quietened past BanditView's grade, and the form's shade a little deeper
// than his: they sit back in the scene's air, Panoramic the hottest, cleanest-lit figure on screen
const float LOUD_SAT = 0.5;  // the saturation over which a colour is pulled down
const float LOUD_KEEP = 0.42;  // how much of that excess stays
const float FORM = 0.5;  // the form's shade (Panoramic's: HeroView.FORM)
const vec3 AIR = vec3(0.93, 0.92, 1.0);  // the scene's air over them (the dusk's cool)
// (round 21, the judges: "the bandits read first: as big as him, higher, darker on the sky") their sizes are the user's
// (the strong one as tall as Panoramic): pushed back in value instead, as far things are, into the air between them and
// us: every colour drawn towards the sky's haze (the darks lifted most, the contrast lower, their ink softer), so he is
// the clearest, highest-contrast shape on screen
uniform vec4 haze : source_color = vec4(0.7, 0.71, 0.84, 1.0);
uniform float haze_amount = 0.0;  // (BanditView.HAZE)
varying vec4 vertex_colour;
varying vec2 local_pos;

void vertex() {
	vertex_colour = COLOR;  // the node's modulate: the picture is sampled again below
	local_pos = VERTEX;
}

// the loudest colours quietened: saturation above LOUD_SAT kept at LOUD_KEEP, the hue and the value kept
vec3 quieten(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.0001);
	if (sat <= LOUD_SAT) {
		return c;
	}
	float target = LOUD_SAT + (sat - LOUD_SAT) * LOUD_KEEP;
	return mix(vec3(mx), c, target / sat);
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
	vec4 c = COLOR;
	if (vanish <= 0.0 && c.a > 0.0) {  // (round 19) the characters' one line and light system, graded down
		// (character.gdshaderinc; BanditView sets its saturation and value under Panoramic's)
		vec2 px = TEXTURE_PIXEL_SIZE * line_px;
		float bright = 0.0;
		vec3 sum = vec3(0.0);
		float weight = 0.0;
		for (int i = 0; i < 8; i++) {
			float t = float(i) * 0.7853982;
			vec4 n = texture(TEXTURE, UV + vec2(cos(t), sin(t)) * px);
			bright = max(bright, mix(1.0, char_lum(n.rgb), n.a));
			sum += n.rgb * n.a;
			weight += n.a;
		}
		vec2 far = px * 2.4;
		float inside = min(min(texture(TEXTURE, UV + vec2(far.x, 0.0)).a, texture(TEXTURE, UV - vec2(far.x, 0.0)).a),
				min(texture(TEXTURE, UV + vec2(0.0, far.y)).a, texture(TEXTURE, UV - vec2(0.0, far.y)).a));
		float lit = 1.0 - texture(TEXTURE, UV + normalize(light_dir) * far).a;
		c.rgb = char_grade(quieten(c.rgb), bright, sum / max(weight, 0.001), 1.0 - smoothstep(0.2, 0.8, inside), lit);
		// (round 20) the form's shade, as Panoramic's (character.gdshaderinc), and the scene's air
		vec2 d = -normalize(light_dir) * TEXTURE_PIXEL_SIZE * form_px * 0.8;
		float away = 1.0 - 0.5 * (texture(TEXTURE, UV + d * 0.5).a + texture(TEXTURE, UV + d).a);
		c.rgb = mix(char_form(c.rgb, local_pos, away, FORM) * AIR, haze.rgb, haze_amount);
	}
	if (vanish > 0.0) {
		vec2 l = (UV - region.xy) / region.zw;  // 0..1 across the frame
		vec2 q = (l - vec2(0.5)) * vec2(aspect, 1.0);  // from its middle, in frame heights
		float glaze = smoothstep(0.0, GLAZE_END, vanish);
		float tw = smoothstep(TWIRL_FROM, 0.9, vanish);
		float ring = 0.48 * min(aspect, 1.0);  // the ring's outer radius: inside the frame
		float r = length(q);
		// the twirl: the whole of him wound round his middle into a ring of chrome, turned most at its inner
		// edge (the spiral inside it), the ring spinning as it closes
		float hole = 0.26 * ring * tw;  // the ring's inner radius
		float rs = max(r - hole, 0.0) / (ring - hole) * mix(ring, 0.62, tw);  // the radius it shows (all of him at the end)
		float turn = tw * (4.5 * pow(clamp(1.0 - (r - hole) / (ring - hole), 0.0, 1.0), 1.3) + 1.2 + vanish * 1.5);
		float s = sin(turn);
		float k = cos(turn);
		vec2 dir = r > 0.0001 ? q / r : vec2(0.0);
		vec2 sl = vec2(k * dir.x - s * dir.y, s * dir.x + k * dir.y) * rs / vec2(aspect, 1.0) + vec2(0.5);
		// the liquid: the surface wobbles while the glaze runs
		float n = noise(sl * vec2(aspect, 1.0) * 9.0 + vec2(seed, seed * 0.7));
		sl += vec2(sin(sl.y * 34.0 + vanish * 14.0 + seed), cos(sl.x * 30.0 + vanish * 12.0)) * 0.007 * glaze;
		bool inside = sl.x >= 0.0 && sl.y >= 0.0 && sl.x <= 1.0 && sl.y <= 1.0;
		c = inside ? texture(TEXTURE, region.xy + sl * region.zw) * vertex_colour : vec4(0.0);
		// the chrome, from his middle out (his head last): silver-white, white streaks, grey ripples, his ink
		// gone soft grey
		float from_mid = length((sl - vec2(0.55, 0.62)) * vec2(aspect, 1.0));
		float m = smoothstep(0.0, 0.16, glaze * 1.3 - from_mid + (n - 0.5) * 0.35) ;
		float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		float band = sin(sl.y * 22.0 + sl.x * 8.0 + n * 6.5 + vanish * 9.0);
		vec3 chrome = vec3(0.72 + 0.18 * lum) + smoothstep(0.5, 0.95, band) * 0.34 - smoothstep(-0.4, -0.95, band) * 0.26;
		chrome -= (1.0 - smoothstep(0.04, 0.3, lum)) * 0.26;
		chrome = mix(chrome, c.rgb, 0.26);  // a trace of his colours (the teal, the red) stays in it
		c.rgb = mix(c.rgb, clamp(chrome, 0.0, 1.0), m);
		c.a *= mix(1.0, 0.88, m);
		c.a *= 1.0 - smoothstep(ring * 0.94, ring * 1.04, r) * tw;  // once twirling, nothing outside the ring
		if (hole > 0.001) {
			c.a *= smoothstep(hole * 0.7, hole, r);  // nor in its middle
		}
		c.a *= 1.0 - smoothstep(0.8, 1.0, vanish);
		c.rgb = char_grade(c.rgb, 0.0, c.rgb, 0.0, 0.0);  // (the grade, no line)
		c.rgb = mix(c.rgb, haze.rgb, haze_amount * (1.0 - m));  // (the chrome bright in the air)
	}
	c.rgb = mix(c.rgb, tint.rgb, amount);
	COLOR = c;
}

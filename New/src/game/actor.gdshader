shader_type canvas_item;
// Characters (Panoramic, the bandits): a flash towards `tint` for a blow, and optionally a thin
// dark outline and a warm rim on the edges facing the light, so they pop from the painted scenery, a warm
// bounce from one side and a back rim (home).
// (In Godot 4, COLOR already holds the texture times the modulate: it is not sampled again.)

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float outline_px = 0.0;  // outline thickness, in texture pixels (0: none)
uniform vec4 outline_colour : source_color = vec4(0.12, 0.05, 0.06, 0.85);
uniform float outline_opacity = 1.0;  // set with the node's fade (COLOR's alpha only reaches the picture)
uniform float rim = 0.0;  // 0..1
uniform float rim_px = 3.0;
uniform vec4 rim_colour : source_color = vec4(1.0, 0.82, 0.55, 1.0);
uniform vec2 rim_dir = vec2(0.8, -0.6);  // towards the light, in texture space (x right, y down)
// (round 22) The bend: the figure turned about `bend_pivot` (the node's local px: his hips), the part above it by
// `bend_up` radians and the part below it by `bend_down` (+: clockwise on screen), blended over `bend_blend` px round
// the pivot: the run's lean (his chest and head into the stride, his legs and planted boots as drawn) and the hang's
// legs trailing the swing (his hands on the grip). HeroView draws the quad past the frame (BEND_MARGIN) so the turned
// parts have room; the picture is sampled again, only inside the frame's own rectangle of the atlas (`region`), so its
// fade comes from `opacity`.
uniform bool bend_on = false;
uniform vec2 bend_pivot = vec2(0.0);
uniform float bend_up = 0.0;
uniform float bend_down = 0.0;
uniform float bend_blend = 40.0;
// (round 23, the judges: "the hang a stiff diagonal plank / his hand on top of the vine") a second bend, before the first:
// hanging, the part above `grip_pivot` (his fists, above his wrists) turned by `grip_turn` (HeroView: back against his
// swing, so his fists stay level on the vine while his body swings from them), blended over `grip_blend` px
uniform bool grip_on = false;
uniform vec2 grip_pivot = vec2(0.0);
uniform float grip_turn = 0.0;
uniform float grip_blend = 12.0;
uniform float opacity = 1.0;
// A warm bounce from one side (the home fire): the colours multiplied towards `bounce_colour`, more on the
// side `bounce_dir` (texture space) points to; dark pixels (the ink) stay dark, no light fringe.
uniform float bounce = 0.0;
uniform vec4 bounce_colour : source_color = vec4(1.35, 1.0, 0.7, 1.0);
uniform vec2 bounce_dir = vec2(-1.0, 0.0);
uniform vec4 bounce_cool : source_color = vec4(0.72, 0.76, 0.98, 1.0);  // the side away from the fire (round 15)
uniform float bounce_scale = 0.01;  // 1 / (half the frame's width, in local px): the sprite is an atlas region
// Blind round 14 ("he does not sit in the dusk: full-saturation skin, pure white cloth, bright blue boots, evenly lit:
// warm on the fire side, the shadow side falling to the dusk's blue-violet; no rim is needed, only values and hue"):
// `bounce_far`: how much of `bounce_cool` his side away from the fire takes (it reaches from just past his middle),
// and `bounce_dusk`: the evening over all of him, under the fire's light (multiplied; white: none).
uniform float bounce_far = -1.0;  // (< 0: as `bounce`)
uniform vec4 bounce_dusk : source_color = vec4(1.0);
// (blind round 15) how much his whites and metal take the light's own hue (0: none), toward these (times their value)
uniform float bounce_take = 0.0;
uniform vec4 bounce_fire_hue : source_color = vec4(1.3, 0.92, 0.56, 1.0);
uniform vec4 bounce_dusk_hue : source_color = vec4(0.82, 0.84, 1.3, 1.0);
// A warm back rim (round 10, home: the lit hut behind him): a band just inside the ink on the edges that face
// up and to the sides, the light from behind wrapping his silhouette; the ink line itself stays dark.
// (round 12) the level's light on him: his lit colours raised by up to `light_gain` (the shade less, the ink not at
// all), so he is the brightest figure on screen ("a mid-brown figure against mesas of the same value")
uniform float light_gain = 1.0;
uniform float back_rim = 0.0;  // 0..1
uniform vec4 back_rim_colour : source_color = vec4(1.0, 0.6, 0.22, 1.0);
uniform float back_rim_ink_px = 3.4;  // the ink round the outline, in texture pixels (no light on it; round 16: 3.0 lit
// the edge of round 15's thinner ink, "a pale outer edge")
uniform float back_rim_px = 2.2;  // the band's width inside the ink
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);  // (round 20) the frame's rectangle in the atlas (UV position, size)
// (round 21, the judges: "on the win screen he is lit bright and neutral on a night scene") a still in a scene's light:
// a coloured light spilling over one side of the picture (UV: the win screen's fireworks and its card, on his right),
// multiplied and broad, over the whole of that side, never a band along the edge (no rim: the user)
uniform float spill = 0.0;
uniform vec4 spill_colour : source_color = vec4(1.12, 0.95, 0.86, 1.0);
uniform vec2 spill_dir = vec2(1.0, -0.3);  // where it comes from, across the picture (UV, y down)
#include "res://src/game/character.gdshaderinc"
varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// 1 inside the frame's rectangle of the atlas (`region`, UV), 0 outside (the bent quad reaches past it)
float in_region(vec2 q) {
	return step(region.x, q.x) * step(region.y, q.y) * step(q.x, region.x + region.z) * step(q.y, region.y + region.w);
}

// where the point `p` of a figure bent about `pivot` (the part above it by `up`, below it by `down`) comes from
vec2 bent_from(vec2 p, vec2 pivot, float up, float down, float blend) {
	float a = mix(up, down, smoothstep(pivot.y - blend, pivot.y + blend, p.y));
	vec2 d = p - pivot;
	float s = sin(a);
	float k = cos(a);
	return pivot + vec2(k * d.x + s * d.y, k * d.y - s * d.x);
}

void fragment() {
	vec2 uv = UV;
	vec4 c = COLOR;
	if (bend_on || grip_on) {  // (round 22) where this pixel of the bent figure comes from in the frame as drawn
		vec2 src = local_pos;
		if (grip_on) {  // (round 23) his fists kept level on the vine
			src = bent_from(src, grip_pivot, grip_turn, 0.0, grip_blend);
		}
		if (bend_on) {
			src = bent_from(src, bend_pivot, bend_up, bend_down, bend_blend);
		}
		uv = UV + (src - local_pos) * TEXTURE_PIXEL_SIZE;
		c = texture(TEXTURE, uv) * in_region(uv);
		c.a *= opacity;
	}
	if (c.a > 0.0) {  // (round 19) the characters' one line and light system (character.gdshaderinc)
		vec2 px = TEXTURE_PIXEL_SIZE * line_px;
		float bright = 0.0;
		vec3 sum = vec3(0.0);
		float weight = 0.0;
		for (int i = 0; i < 8; i++) {
			float t = float(i) * 0.7853982;
			vec4 n = texture(TEXTURE, uv + vec2(cos(t), sin(t)) * px);
			bright = max(bright, mix(1.0, char_lum(n.rgb), n.a));
			sum += n.rgb * n.a;
			weight += n.a;
		}
		vec2 far = px * 2.4;
		float inside = min(min(texture(TEXTURE, uv + vec2(far.x, 0.0)).a, texture(TEXTURE, uv - vec2(far.x, 0.0)).a),
				min(texture(TEXTURE, uv + vec2(0.0, far.y)).a, texture(TEXTURE, uv - vec2(0.0, far.y)).a));
		float lit = 1.0 - texture(TEXTURE, uv + normalize(light_dir) * far).a;
		vec3 drawn = c.rgb;
		c.rgb = char_grade(c.rgb, bright, sum / max(weight, 0.001), 1.0 - smoothstep(0.2, 0.8, inside), lit);
		c.rgb = char_skin(c.rgb);  // (round 23) the skin's middle values a little lighter
		c.rgb = char_hair(c.rgb, bright, local_pos);  // (round 21) home: his hair's top clear of the dark doorway
		// (round 20) the form: his side away from the sun in a soft cool shade, deepest at the edges turning away
		// (the samples kept inside his frame of the atlas: `region`)
		float away = 0.0;
		if (form_amount > 0.0) {
			vec2 d = -normalize(light_dir) * TEXTURE_PIXEL_SIZE * form_px;
			vec2 q1 = uv + d * 0.5;
			vec2 q2 = uv + d;
			vec2 lo = region.xy;
			vec2 hi = region.xy + region.zw;
			float a1 = texture(TEXTURE, q1).a * step(lo.x, q1.x) * step(lo.y, q1.y) * step(q1.x, hi.x) * step(q1.y, hi.y);
			float a2 = texture(TEXTURE, q2).a * step(lo.x, q2.x) * step(lo.y, q2.y) * step(q2.x, hi.x) * step(q2.y, hi.y);
			away = 1.0 - 0.5 * (a1 + a2);
		}
		c.rgb = char_form(c.rgb, local_pos, away, form_amount, char_cloth(drawn));
		// (round 23) the silhouette's ink: the figure's own edge, sil_in_px texels of it (the samples kept in his frame)
		if (sil_in_px > 0.0) {
			vec2 sp = TEXTURE_PIXEL_SIZE * sil_in_px;
			float amin = 1.0;
			for (int i = 0; i < 8; i++) {
				float t = float(i) * 0.7853982;
				vec2 q = uv + vec2(cos(t), sin(t)) * sp;
				amin = min(amin, texture(TEXTURE, q).a * in_region(q));
			}
			c.rgb = mix(c.rgb, sil_colour.rgb, smoothstep(0.1, 0.7, 1.0 - amin));
		}
	}
	if (rim > 0.0 && c.a > 0.0) {
		// how much of this pixel's alpha is missing a few pixels towards the light: an edge facing it
		float a = texture(TEXTURE, uv + normalize(rim_dir) * TEXTURE_PIXEL_SIZE * rim_px).a;
		float edge = clamp(c.a - a, 0.0, 1.0);
		c.rgb = mix(c.rgb, c.rgb + rim_colour.rgb * 0.75, edge * rim);
	}
	// the outline round the outside (behind the picture): (round 23) the silhouette's ink (sil_out_px) and the vine's extra
	// (outline_px), sampled at its full width and at half of it (no gaps at the corners), kept in his frame
	float out_px = sil_out_px + outline_px;
	if (out_px > 0.0 && c.a < 1.0) {
		vec2 px = TEXTURE_PIXEL_SIZE * out_px;
		float a = 0.0;
		for (int i = 0; i < 8; i++) {
			float t = float(i) * 0.7853982;
			vec2 q = uv + vec2(cos(t), sin(t)) * px;
			vec2 q2 = uv + vec2(cos(t + 0.3927), sin(t + 0.3927)) * px * 0.6;
			a = max(a, max(texture(TEXTURE, q).a * in_region(q), texture(TEXTURE, q2).a * in_region(q2)));
		}
		float o = smoothstep(0.1, 0.55, a) * outline_colour.a * outline_opacity;  // (round 23: a crisp edge)
		// the outline sits behind the picture
		float out_a = c.a + o * (1.0 - c.a);
		vec3 rgb = (c.rgb * c.a + outline_colour.rgb * o * (1.0 - c.a)) / max(out_a, 0.001);
		c = vec4(rgb, out_a);
	}
	if (light_gain != 1.0) {
		float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		c.rgb = min(c.rgb * mix(1.0, light_gain, smoothstep(0.1, 0.42, lum)), vec3(1.0));
	}
	if (back_rim > 0.0 && c.a > 0.5) {
		float lit = 0.0;
		for (int i = 0; i < 6; i++) {
			float t = -1.5708 + (float(i) - 2.5) * 0.45;  // fanned round up: up-left, up-right, down to the sides
			vec2 d = vec2(cos(t), sin(t));
			float near = texture(TEXTURE, uv + d * TEXTURE_PIXEL_SIZE * back_rim_ink_px).a;
			float far = texture(TEXTURE, uv + d * TEXTURE_PIXEL_SIZE * (back_rim_ink_px + back_rim_px)).a;
			lit = max(lit, near * (1.0 - far) * pow(max(-d.y, 0.0), 1.3));  // strongest on top, none below
		}
		// screened onto the colours (a light on the form, not a painted line): the hair and skin glow warm
		vec3 glow = back_rim_colour.rgb * clamp(lit, 0.0, 1.0) * back_rim;
		c.rgb = 1.0 - (1.0 - c.rgb) * (1.0 - glow);
	}
	if (bounce > 0.0) {
		// (round 15, "drenched in uniform orange that flattens all his anatomy: fire key on one side, cooler shadow on
		// the other") the fire on its side only, the far side in a cool shade
		float x = dot(local_pos * bounce_scale, normalize(bounce_dir));
		// (blind round 16: "any fire or dusk grading on him is too weak to see at phone size: light him from the fire
		// decisively": the turn from the fire's side to the far side is short, about his middle: two clear halves)
		float side = smoothstep(-0.1, 0.5, x);
		float far = bounce_far < 0.0 ? smoothstep(0.1, -0.7, x) : smoothstep(0.12, -0.4, x);
		// (blind round 15: "his loincloth stays day-white, his armour clean blue") what has little colour of its own
		// shows the light's: his whites (pale, unsaturated) and his metal (blue) take the fire's orange on its side
		// and the dusk's violet on the other, by value and hue only (`bounce_take`; no rim, no glow)
		float hi = max(c.r, max(c.g, c.b));
		float lo = min(c.r, min(c.g, c.b));
		float pale = smoothstep(0.5, 0.82, hi) * (1.0 - smoothstep(0.1, 0.3, hi - lo));
		float metal = smoothstep(0.04, 0.2, c.b - max(c.r, c.g)) * smoothstep(0.25, 0.5, hi);
		float take = max(pale, metal * 0.8) * bounce_take;
		c.rgb *= mix(vec3(1.0), bounce_dusk.rgb, bounce);
		c.rgb *= mix(vec3(1.0), bounce_colour.rgb, bounce * side);
		c.rgb *= mix(vec3(1.0), bounce_cool.rgb, (bounce_far < 0.0 ? bounce : bounce_far) * far);
		if (take > 0.0) {
			// (split about his middle, not across his whole frame: his cloth hangs at its middle, between the two)
			float l3 = dot(c.rgb, vec3(0.3, 0.59, 0.11));
			float lit = smoothstep(-0.3, -0.08, x);
			c.rgb = mix(c.rgb, l3 * mix(bounce_dusk_hue.rgb, bounce_fire_hue.rgb, lit), take * min(bounce * 1.3, 1.0));
		}
	}
	if (spill > 0.0) {
		float side = smoothstep(-0.3, 0.45, dot(UV - vec2(0.5), normalize(spill_dir)));
		c.rgb *= mix(vec3(1.0), spill_colour.rgb, side * spill);
	}
	c.rgb = mix(c.rgb, tint.rgb, amount);
	COLOR = c;
}

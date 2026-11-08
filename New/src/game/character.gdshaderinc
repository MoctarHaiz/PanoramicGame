// (round 19, "the hero, the bandits and the world look like three different games") One line and light
// system for every character, so they sit in the painted world: HeroView (actor.gdshader) and BanditView
// (bandit.gdshader) include it.
// - The ink: a pixel much darker than its brightest neighbour is a line; lines are drawn in a dark warm
//   brown, not black, and on the silhouette's side facing the low sun a lighter, softer brown (the line
//   thins in the light). Lines inside the figure (muscles, folds) are softened towards the colours around
//   them. Big dark masses (his hair) keep their colour: only their edge is line.
// - The shade: the darker values tinted towards the scene's ambient (the dusk's cool violet).
// - The grade: each figure's saturation and value (the bandits graded down so Panoramic stays the hottest
//   shape on screen; their hues kept).
// The neighbours are sampled by the shader that includes this (TEXTURE is not passed to functions: the
// phones' renderer can't).

uniform vec4 line_colour : source_color = vec4(0.17, 0.085, 0.06, 1.0);
uniform vec4 line_lit_colour : source_color = vec4(0.23, 0.135, 0.105, 1.0);  // a touch lighter, never a warm rim (the user)
uniform float line_amount = 1.0;  // 0: the art's own ink
uniform float line_px = 1.6;  // texels to the neighbours that tell a line
uniform float line_inside = 0.5;  // how much the brown lines inside the figure are softened (0: kept)
uniform vec2 light_dir = vec2(-0.6, -0.8);  // towards the sun, texture space (x right, y down)
uniform vec4 shade_colour : source_color = vec4(0.8, 0.8, 1.0, 1.0);  // the ambient the shade is tinted to
uniform float shade_amount = 0.0;
uniform float saturation = 1.0;
uniform float value = 1.0;
// (round 20, the judges: "stickers: the hero lit flat from the front while every scene is back- or side-lit") the form:
// the side of the figure away from the light (lower right: the sun is upper left) in a soft cool shade, deepest
// along the silhouette's edges that face away from it (the form turning from the light), the lit side as drawn. No
// rim, no glow, no glint on the lit side (the user's rule): the light only takes away.
uniform float form_amount = 0.0;  // 0: flat, as drawn
uniform vec4 form_colour : source_color = vec4(0.62, 0.6, 0.86, 1.0);  // the shade side's colour (multiplied): the sky's
uniform float form_px = 9.0;  // texels to the silhouette that tell an edge turning away from the light
// the figure's box in its node's local px (left, top, width, height): the shade side is measured from its middle
// (HeroView sets it every frame; the default: a bandit's frame about its pivot, the ground under its body)
uniform vec4 figure_box = vec4(-116.0, -264.0, 236.0, 250.0);
uniform vec4 ambient : source_color = vec4(1.0);  // the scene's ambient over the whole figure (multiplied)
uniform float ambient_amount = 0.0;
// (round 21, the judges: "lit flat from the front, his skin the same value as the gold grass") a key: the side of the
// figure facing the low sun warmer (multiplied: a warmer, richer skin, its value kept), the side away from it in the
// form's shade above; one broad split across the figure, never a band along its edge (no rim, no glow, no glint: the
// user's rule)
uniform vec4 key_colour : source_color = vec4(1.07, 0.98, 0.86, 1.0);
uniform float key_amount = 0.0;
uniform float form_reach = 0.55;  // how much the half away from the sun is in shade (the edges turning away: 0.75)
// (round 21, home: "his black hair melts into the dark doorway") the top of his dark hair a little lighter and cooler,
// over the mass (a sheen of the dusk sky on it), its outline and the ink inside him kept
uniform float hair_lift = 0.0;
uniform vec4 hair_colour : source_color = vec4(0.36, 0.36, 0.48, 1.0);

float char_lum(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

// c: the pixel (straight alpha); bright: the brightest neighbour's luminance (a transparent one counts as 1);
// mean: the neighbours' mean colour; silhouette: 1 on the figure's outer edge; lit: 1 where that edge faces
// the light.
vec3 char_grade(vec3 c, float bright, vec3 mean, float silhouette, float lit) {
	float lum = char_lum(c);
	if (line_amount > 0.0) {
		float edge = smoothstep(0.06, 0.26, bright - lum);
		float line = edge * mix(1.0 - smoothstep(0.2, 0.45, lum), 1.0 - smoothstep(0.16, 0.34, lum), silhouette);
		vec3 ink = mix(line_colour.rgb, line_lit_colour.rgb, lit * silhouette);
		// the outer line: drawn in the warm brown (its darkest core a touch darker, its antialiased fringe blended)
		vec3 outer = ink * clamp(0.7 + lum * 2.5, 0.7, 1.0);
		// the lines inside: never darker than drawn (the black ones lifted to the brown); the brown grooves of the
		// muscles softened towards the colours round them, the black inks (eyes, overlaps) kept
		vec3 inner = mix(max(c, ink * 0.85), mean, line_inside * smoothstep(0.05, 0.2, lum));
		c = mix(c, mix(inner, outer, silhouette), line * line_amount);
		lum = char_lum(c);
	}
	if (shade_amount > 0.0) {
		float shade = 1.0 - smoothstep(0.12, 0.5, lum);
		c *= mix(vec3(1.0), shade_colour.rgb, shade * shade_amount);
	}
	if (saturation != 1.0 || value != 1.0) {
		c = mix(vec3(char_lum(c)), c, saturation) * value;
	}
	return c;
}

// (round 20) The light on the form. `local`: the pixel in the node's local px; `away`: 0..1, how near the silhouette's
// edge facing away from the light is (1 - the alpha a few texels that way: the shader samples it); `strength`: the
// shade's strength (the hero's form_amount; the bandits' own). (round 21) The key's warmth on the rest (key_amount).
vec3 char_form(vec3 c, vec2 local, float away, float strength) {
	if (strength > 0.0) {
		vec2 mid = figure_box.xy + figure_box.zw * 0.5;
		vec2 p = (local - mid) / max(figure_box.w * 0.5, 1.0);  // -1..1 up his height, the same scale across
		float side = smoothstep(-0.35, 0.75, dot(p, -normalize(light_dir)));  // the half away from the sun
		float shade = clamp(side * form_reach + away * 0.75, 0.0, 1.0);
		c *= mix(vec3(1.0), form_colour.rgb, shade * strength);
		// (round 21) the key: the rest of him in the sun's warmth
		c *= mix(vec3(1.0), key_colour.rgb, (1.0 - shade) * key_amount);
	}
	if (ambient_amount > 0.0) {
		c *= mix(vec3(1.0), ambient.rgb, ambient_amount);
	}
	return c;
}

// (round 21) The top of his hair lifted (hair_lift): `bright`, the brightest neighbour's luminance (an edge: high; inside
// the dark mass: low); `local`, the pixel in the node's local px (figure_box: the upper part of the figure).
vec3 char_hair(vec3 c, float bright, vec2 local) {
	if (hair_lift <= 0.0) {
		return c;
	}
	float lum = char_lum(c);
	float mass = (1.0 - smoothstep(0.1, 0.2, lum)) * (1.0 - smoothstep(0.22, 0.42, bright));  // inside the dark mass
	float up = 1.0 - smoothstep(0.12, 0.42, (local.y - figure_box.y) / max(figure_box.w, 1.0));  // his upper part
	return mix(c, max(c, hair_colour.rgb * (0.55 + 2.2 * lum)), mass * up * hair_lift);
}

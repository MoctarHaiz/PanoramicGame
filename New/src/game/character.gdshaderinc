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

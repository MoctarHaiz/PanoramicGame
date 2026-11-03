shader_type canvas_item;
// The body of the ground (TerrainView). Each cell is drawn from terrain_shape.png (its outline,
// rounded open corners and edge light) while the paint comes from soil.png and rock.png sampled in
// level units, so the soil runs on across cells without seams. Deeper under an open top the soil
// darkens and cools and turns to sandstone; just under the grass a soft shadow.
// depth_tex holds, per cell, how many solid cells stand above it (r * 255) and how many lie
// between it and the open air on its left (g) and right (b), from column first_col: each wall is
// shaded as a rounded form, a warm rim on the sun's side (upper left), cool violet shade on the far
// side.

uniform vec3 soil_colour : source_color = vec3(0.6, 0.31, 0.19);  // round 5: flat cel colours, no texture
uniform vec3 rock_colour : source_color = vec3(0.74, 0.45, 0.27);
uniform vec3 outline_colour : source_color = vec3(0.23, 0.10, 0.07);
uniform vec3 lit_colour : source_color = vec3(1.0, 0.82, 0.58);
uniform vec3 rim_colour : source_color = vec3(1.0, 0.80, 0.55);
uniform vec3 deep_tint : source_color = vec3(0.52, 0.42, 0.56);
uniform vec3 shade_tint : source_color = vec3(0.50, 0.42, 0.62);  // the side away from the sun
uniform vec3 sun_tint : source_color = vec3(1.25, 1.08, 0.86);  // the side facing it
uniform sampler2D depth_tex : filter_nearest;
uniform int first_col = 0;

varying vec2 level_pos;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

// smooth 1-D value noise, 0..1
float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

// smooth 2-D value noise, 0..1
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i.x + i.y * 57.0);
	float b = hash(i.x + 1.0 + i.y * 57.0);
	float c = hash(i.x + (i.y + 1.0) * 57.0);
	float d = hash(i.x + 1.0 + (i.y + 1.0) * 57.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	level_pos = VERTEX;
}

void fragment() {
	vec4 shape = texture(TEXTURE, UV);
	ivec2 cell = ivec2(floor(level_pos / 32.0)) - ivec2(first_col, 0);
	cell = clamp(cell, ivec2(0), textureSize(depth_tex, 0) - 1);
	vec4 cells4 = floor(texelFetch(depth_tex, cell, 0) * 255.0 + 0.5);
	vec3 cells = cells4.rgb;
	float ledge = step(127.5, cells4.a);  // open below: the underside of a ledge
	float to_foot = mod(cells4.a, 128.0) * 32.0 + 32.0 - mod(level_pos.y, 32.0);  // units of wall below
	float depth = cells.r * 32.0 + mod(level_pos.y, 32.0);
	float fx = mod(level_pos.x, 32.0);
	float from_left = cells.g * 32.0 + fx;  // units of solid ground to the open air on the left
	float from_right = cells.b * 32.0 + 32.0 - fx;
	// Round 5: the earth in the hero's style: flat cel colours in three light bands, chunky blocks of
	// rock in beds with ink cracks, soil in wavy strata with lit stones, ink round the silhouette (it
	// was a noise texture: "a noise box with a glued grass strip")
	float width = from_left + from_right;
	float to_rock = smoothstep(-1.0, 1.0, depth - 92.0 - (noise(level_pos.x * 0.013) - 0.5) * 44.0);
	vec3 c = mix(soil_colour, rock_colour, to_rock);
	float ink = 0.0;
	// rock: beds of blocks, each its own tone, a lit top face and a shaded underside, ink between
	float by = level_pos.y + (noise(level_pos.x * 0.017) - 0.5) * 14.0;
	by += sin(by * 0.045 + 1.3) * 11.0;  // (beds of uneven thickness: rock, not brickwork)
	float bed_i = floor(by / 38.0);
	float f = fract(by / 38.0);
	float bw = mix(64.0, 150.0, hash(bed_i + 3.1));
	float slant = (hash(bed_i + 8.7) - 0.5) * 0.9;  // joints lean, each bed its own way
	float jx = level_pos.x + hash(bed_i) * 200.0 + f * 38.0 * slant;
	float g = fract(jx / bw);
	float tone = hash(floor(jx / bw) * 7.3 + bed_i * 1.7);
	float rock_k = to_rock * smoothstep(20.0, 30.0, depth);
	c *= 1.0 + (tone - 0.5) * 0.16 * rock_k;
	c *= 1.0 + 0.16 * (1.0 - smoothstep(0.1, 0.16, f)) * rock_k;  // the top face of a bed, lit
	c *= 1.0 - 0.2 * smoothstep(0.82, 0.88, f) * rock_k;  // its underside, in shade
	c *= 1.0 + 0.1 * (1.0 - smoothstep(0.0, 9.0 / bw, g)) * rock_k;  // a block's side to the sun, lit
	c *= 1.0 - 0.12 * smoothstep(1.0 - 12.0 / bw, 1.0 - 6.0 / bw, g) * rock_k;  // its far side, shaded
	ink = max(ink, (1.0 - smoothstep(0.0, 0.045, f)) * rock_k);  // the crack between two beds
	ink = max(ink, (1.0 - smoothstep(0.0, 1.6 / bw, min(g, 1.0 - g))) * rock_k * step(0.12, f));  // joints
	// soil: wavy strata, and stones (dark below, lit on top) here and there
	float soil_k = (1.0 - to_rock) * smoothstep(14.0, 22.0, depth);
	float sy = level_pos.y + sin(level_pos.x * 0.03) * 4.0 + noise(level_pos.x * 0.05) * 6.0;
	float sf = fract(sy / 21.0);
	c *= 1.0 - 0.12 * (1.0 - smoothstep(0.0, 0.12, sf)) * soil_k;
	c *= 1.0 + (hash(floor(sy / 21.0)) - 0.5) * 0.12 * soil_k;
	vec2 sc = floor(level_pos / 26.0);
	float has_stone = step(0.86, hash(sc.x * 13.1 + sc.y * 71.7)) * soil_k;
	vec2 sp = (fract(level_pos / 26.0) - 0.5 - (vec2(hash(sc.x + sc.y * 3.3), hash(sc.y + sc.x * 5.1)) - 0.5) * 0.4) * vec2(1.0, 1.5);
	float stone = (1.0 - smoothstep(0.17, 0.2, length(sp))) * has_stone;
	vec3 stone_c = mix(vec3(0.42, 0.34, 0.33), vec3(0.78, 0.66, 0.56), step(sp.y, -0.04));
	c = mix(c, stone_c, stone);
	ink = max(ink, (smoothstep(0.17, 0.2, length(sp)) - smoothstep(0.2, 0.24, length(sp))) * has_stone);
	// deeper: a little darker and cooler
	c *= mix(vec3(1.0), deep_tint, smoothstep(40.0, 260.0, depth) * 0.6);
	// cel light from the low sun on the left: the lit band, the mid tone, the shade band
	float lit = 1.0 - smoothstep(0.0, min(40.0, width * 0.36), from_left);
	float away = 1.0 - smoothstep(0.0, min(56.0, width * 0.5), from_right);
	float below_top = smoothstep(4.0, 30.0, depth);
	float band_lit = smoothstep(0.45, 0.52, lit) * below_top;
	float band_shade = smoothstep(0.45, 0.52, away) * below_top;
	c *= mix(vec3(1.0), sun_tint, band_lit);
	c *= mix(vec3(1.0), shade_tint * 0.8, band_shade);
	// under the grass lip: a crisp band of shadow; the foot of a wall darker; a ledge's underside
	float lip = 14.0 + noise(level_pos.x * 0.09) * 6.0;
	c *= 1.0 - 0.45 * (1.0 - smoothstep(lip - 1.0, lip + 1.0, depth));
	if (width < 200.0) {
		c *= 1.0 - 0.28 * (1.0 - smoothstep(26.0, 30.0, to_foot)) * smoothstep(30.0, 40.0, depth);
	}
	float to_bottom = 32.0 - mod(level_pos.y, 32.0);
	c *= 1.0 - 0.38 * (1.0 - smoothstep(9.0, 11.0, to_bottom)) * ledge;
	float taper = 0.0;
	// (round 5: the row over a ledge, at the island's ends, tapers with it: no square upper end)
	vec4 below4 = floor(texelFetch(depth_tex, min(cell + ivec2(0, 1), textureSize(depth_tex, 0) - 1), 0) * 255.0 + 0.5);
	float floating = max(ledge, step(127.5, below4.a));
	if (floating > 0.5) {
		// (round 4: rounder, deeper: a one-cell ledge no longer ends in a straight vertical edge)
		float cut = max(depth - 6.0, 0.0) * 1.3 + noise(level_pos.y * 0.2 + float(cell.x)) * 4.0;
		taper = cells.g < 0.5 ? 1.0 - smoothstep(cut - 0.7, cut + 0.7, from_left) : 0.0;
		taper = max(taper, cells.b < 0.5 ? 1.0 - smoothstep(cut - 0.7, cut + 0.7, from_right) : 0.0);
	}
	// New: a wall's open sides are eroded (bulges and notches along its height, more towards its
	// foot, none under the grass lip): no ruler-straight sides; the new edge gets a dark rim
	float erode = 0.0;
	float side_d = 99.0;
	float lit_d = 99.0;  // units from the eroded edge on the sun's side
	if (depth > 20.0 && width < 200.0) {
		// deepest just under the grass lip (it overhangs) and up the middle, little at the foot
		// (the wall stands wider on the ground)
		float grow = smoothstep(20.0, 46.0, depth) * (0.25 + 0.75 * smoothstep(0.0, 90.0, to_foot));
		// round 2: deeper, slower bulges and notches (chunky breaks in the silhouette)
		float reach = min(28.0, width * 0.17) * grow;
		float wx = level_pos.x - from_left;  // the wall's left side: one pattern per wall, not per cell
		float el = (0.2 + 0.5 * noise(level_pos.y * 0.017 + wx * 0.031) + 0.3 * noise(level_pos.y * 0.09 + 9.0)) * reach;
		float er = (0.2 + 0.5 * noise(level_pos.y * 0.02 + wx * 0.027 + 40.0) + 0.3 * noise(level_pos.y * 0.1 + 3.0)) * reach;
		side_d = min(from_left - el, from_right - er);
		lit_d = cells.g < 0.5 ? from_left - el : 99.0;
		erode = (cells.g < 0.5 ? 1.0 - smoothstep(el - 0.6, el + 0.6, from_left) : 0.0);
		erode = max(erode, cells.b < 0.5 ? 1.0 - smoothstep(er - 0.6, er + 0.6, from_right) : 0.0);
	}
	// edges: the shape's light (R) and rim (B) kept as cel steps; ink (G and the eroded edge) thick
	float l = shape.r - 0.5;
	c = l > 0.0 ? mix(c, c * lit_colour * 1.35, step(0.12, l) * 0.8) : c * (1.0 - step(0.12, -l) * 0.3);
	c = mix(c, min(c * 1.3 + rim_colour * 0.1, vec3(1.0)), step(0.35, shape.b) * 0.5);
	ink = max(ink, step(0.3, shape.g));
	float edge_line = (1.0 - smoothstep(2.4, 3.4, side_d)) * step(side_d, 98.0);
	float sun_edge = (1.0 - smoothstep(4.0, 5.0, lit_d)) * step(lit_d, 98.0) * (1.0 - edge_line);
	c = mix(c, min(c * 1.45 + rim_colour * 0.2, vec3(1.0)), sun_edge * 0.7);
	ink = max(ink, edge_line);
	c = mix(c, outline_colour, ink * 0.92);
	// round 5: a ledge's underside in a wavy line (it was flat as a box), inked
	float bump = 4.0 + 8.0 * noise(level_pos.x * 0.045 + float(cell.y) * 3.1);
	float under_cut = ledge * (1.0 - smoothstep(bump - 0.7, bump + 0.7, to_bottom));
	c = mix(c, outline_colour, ledge * (1.0 - smoothstep(bump + 1.5, bump + 3.0, to_bottom)) * 0.9);
	COLOR = vec4(c, shape.a * (1.0 - erode) * (1.0 - taper) * (1.0 - under_cut));
}

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
	vec3 c = vec3(0.0);
	float ink = 0.0;
	// round 9: rock in boulder blocks (it read as "a chest of drawers": straight beds, ruled light
	// bands): blocks of uneven size staggered in wavy beds (a Voronoi of jittered points), each its
	// own stone colour, rounded by the light (lit upper left, shaded lower right), a lit bevel on
	// its sun side, a dark one and an ink crack on the other; the wall's light bands follow the
	// blocks, not a ruler
	float narrow = 1.0 - step(200.0, width);
	to_rock = max(to_rock, narrow * smoothstep(-1.0, 1.0, depth - 26.0 - (noise(level_pos.x * 0.05) - 0.5) * 10.0));
	c = mix(soil_colour, rock_colour, to_rock);
	float rock_k = to_rock * smoothstep(20.0, 30.0, depth);
	// round 19 ("the central rock pillar toy-like, blocky stone that doesn't match the painted mesas"): a
	// narrow wall is a column of the mesas' sandstone (as the river's pillars): horizontal beds, no blocks
	float strata_k = rock_k * narrow;
	rock_k *= 1.0 - narrow;
	vec2 bsize = vec2(70.0, 30.0);  // (blocks longer than tall, their centres kept near the middle
	// of their bed: the joints between beds run across in wavy strata, the joints in a bed lean)
	vec2 rq = level_pos + vec2((noise(level_pos.y * 0.021) - 0.5) * 30.0, (noise(level_pos.x * 0.011) - 0.5) * 26.0);
	// round 12 ("evenly sized cobbles"): stretched here and squeezed there along each bed (a smooth
	// warp: stones from about half to one and a half times the size, no seams)
	rq.x += 22.0 * sin(level_pos.x * 0.019 + noise(rq.y * 0.025) * 5.0);
	vec2 rp = rq / bsize;
	vec2 ri = floor(rp);
	vec2 rf = fract(rp);
	float f1 = 1e5;
	float f2 = 1e5;
	vec2 to_c = vec2(0.0);  // units from this point to its block's centre
	vec2 bid = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 id = ri + g;
			vec2 o = vec2(hash(id.x * 1.71 + id.y * 31.3) * 0.9 + 0.05, hash(id.x * 7.13 + id.y * 13.9 + 5.0) * 0.36 + 0.32);
			vec2 r = (g + o - rf) * bsize;
			float d = dot(r, r);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				to_c = r;
				bid = id;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	float joint = (sqrt(f2) - sqrt(f1)) * 0.5;  // units to the block's edge (about)
	vec2 sun_dir = vec2(-0.6, -0.8);  // towards the sun: upper left
	float facing = clamp(dot(-to_c, sun_dir) / 24.0, -1.0, 1.0);  // which side of its block
	float tone = hash(bid.x * 3.7 + bid.y * 17.1);
	float bed_tone = hash(bid.y * 5.3 + 1.0);
	vec3 block = rock_colour;
	block = mix(block, vec3(0.66, 0.34, 0.23), step(0.62, bed_tone) * 0.7);  // redder beds
	block = mix(block, vec3(0.84, 0.62, 0.40), step(bed_tone, 0.22) * 0.35);  // paler ones
	block = mix(block, vec3(0.6, 0.5, 0.5), step(0.86, tone) * 0.5);  // a grey stone here and there
	block *= 0.8 + tone * 0.28;  // (round 12: "the same brightness": more each its own)
	c = mix(c, block, rock_k);
	c *= 1.0 + 0.14 * facing * rock_k;  // each block rounded by the light
	float bevel = 1.0 - smoothstep(1.8, 6.0, joint);
	c = mix(c, c * (facing > 0.0 ? 1.32 : 0.6), bevel * smoothstep(0.05, 0.5, abs(facing)) * rock_k);
	float crack_on = smoothstep(0.25, 0.4, noise(level_pos.x * 0.06 + level_pos.y * 0.04 + bid.y * 3.1));
	ink = max(ink, (1.0 - smoothstep(0.7, 1.5, joint)) * rock_k * mix(0.35, 1.0, crack_on) * step(facing, 0.35));
	// round 11: a crisp highlight along each stone's edge on its sun side (round 9's read soft)
	float edge_hi = (1.0 - smoothstep(1.5, 2.3, joint)) * smoothstep(0.2, 0.4, facing) * rock_k;
	c = mix(c, min(c * 1.42 + vec3(0.04, 0.03, 0.0), vec3(1.0)), edge_hi * 0.7);
	// pits and soft patches in the stone
	c *= 1.0 - 0.08 * smoothstep(0.6, 0.75, noise2(level_pos * 0.09 + bid * 3.0)) * rock_k;
	// round 19: the sandstone beds of a narrow wall: uneven thickness, each its own tone (peach, rose,
	// a pale band now and then), a lit lip on top of each, a dark joint under it, a few vertical cracks
	// down a bed, painted mottling
	float by = level_pos.y + (noise(level_pos.x * 0.018 + 4.0) - 0.5) * 7.0;
	float bw = by / 30.0 + 0.32 * sin(by * 0.043 + 1.7);
	float bed = floor(bw);
	float bf = fract(bw);
	float btone = hash(bed * 3.17 + 0.5);
	vec3 sand = mix(vec3(0.84, 0.56, 0.42), vec3(0.74, 0.44, 0.37), step(0.55, btone));
	sand = mix(sand, vec3(0.9, 0.68, 0.5), step(0.84, btone) * 0.8);
	sand *= 0.92 + 0.1 * hash(bed * 7.1 + 2.0);
	sand *= 0.93 + 0.12 * noise2(level_pos * vec2(0.05, 0.11) + bed * 5.0);
	c = mix(c, sand, strata_k);
	float lip_hi = (1.0 - smoothstep(0.0, 0.1, bf)) * strata_k;
	c = mix(c, min(c * 1.25 + vec3(0.05, 0.03, 0.0), vec3(1.0)), lip_hi * 0.7);
	float under = smoothstep(0.78, 0.97, bf) * strata_k;
	c *= 1.0 - 0.28 * under;
	ink = max(ink, (smoothstep(0.955, 0.985, bf)) * strata_k * 0.8);
	float crack_x = hash(bed * 11.3) * 160.0;
	float crack = (1.0 - smoothstep(0.6, 1.4, abs(mod(level_pos.x - crack_x, 160.0) - 80.0 + (bf - 0.5) * 6.0)))
			* step(0.45, hash(bed * 5.9 + 1.0)) * smoothstep(0.1, 0.25, bf) * (1.0 - smoothstep(0.8, 0.9, bf));
	ink = max(ink, crack * strata_k * 0.75);
	// soil: wavy strata, and stones (dark below, lit on top) here and there
	float soil_k = (1.0 - to_rock) * smoothstep(14.0, 22.0, depth);
	float sy = level_pos.y + sin(level_pos.x * 0.03) * 4.0 + noise(level_pos.x * 0.05) * 6.0;
	float sf = fract(sy / 21.0);
	c *= 1.0 - 0.12 * (1.0 - smoothstep(0.0, 0.12, sf)) * soil_k;
	c *= 1.0 + (hash(floor(sy / 21.0)) - 0.5) * 0.12 * soil_k;
	// round 19 (the judges: "a flat thin tiled strip: grass fringe over a pebble band, no lip, depth or
	// shadow, no variation along it"): the main ground's face is an earth bank under the grass's lip: a deep
	// shadow under the overhang, then warm red earth in big soft patches that change along the run (darker
	// clods, a paler dry stretch, rain runnels down it), a sandstone ledge breaking out of it now and then,
	// a few half-buried rocks lit on top with their own shadow under them, darker down to the screen's edge
	float wide = step(200.0, width) * soil_k * step(560.0, level_pos.y);  // (the main ground band only: not a ledge's edge)
	vec2 lp = level_pos;
	float patch_big = noise2(lp * vec2(0.009, 0.02) + 3.0);
	float patch_mid = noise2(lp * vec2(0.035, 0.06) + 11.0);
	vec3 earth = mix(vec3(0.44, 0.22, 0.15), vec3(0.6, 0.33, 0.2), smoothstep(0.25, 0.75, patch_big));
	earth = mix(earth, vec3(0.66, 0.44, 0.3), smoothstep(0.72, 0.9, noise(lp.x * 0.004 + 9.0)) * 0.6);  // a dry stretch
	earth = mix(earth, vec3(0.32, 0.17, 0.14), smoothstep(0.6, 0.78, patch_mid) * 0.55);  // darker clods
	float runnel = (1.0 - smoothstep(0.0, 0.08, abs(fract(lp.x / 23.0 + noise(lp.y * 0.05 + floor(lp.x / 23.0)) * 0.3) - 0.5)))
			* step(0.55, hash(floor(lp.x / 23.0) * 1.7)) * smoothstep(30.0, 44.0, depth);
	earth *= 1.0 - 0.14 * runnel;
	// a sandstone ledge breaking out of the bank (a slow noise along the run picks where)
	float out_on = smoothstep(0.66, 0.7, noise(lp.x * 0.006 + 21.0));
	float out_top = 30.0 + 6.0 * noise(lp.x * 0.04);
	float out_band = smoothstep(out_top - 0.8, out_top + 0.8, depth) * (1.0 - smoothstep(out_top + 15.0, out_top + 17.0, depth + (noise(lp.x * 0.09) - 0.5) * 6.0));
	float outcrop = out_on * out_band;
	vec3 sand_c = mix(vec3(0.82, 0.56, 0.42), vec3(0.62, 0.42, 0.4), smoothstep(out_top + 4.0, out_top + 15.0, depth));
	sand_c = mix(sand_c, sand_c * 1.25, 1.0 - smoothstep(out_top + 0.5, out_top + 2.5, depth));  // its lit top
	earth = mix(earth, sand_c, outcrop);
	earth *= 1.0 - 0.35 * out_on * smoothstep(out_top + 15.0, out_top + 17.0, depth) * (1.0 - smoothstep(out_top + 17.0, out_top + 28.0, depth));  // its shadow
	float wide_ink = out_on * (smoothstep(out_top - 1.2, out_top - 0.2, depth) - smoothstep(out_top + 0.2, out_top + 1.2, depth));
	wide_ink = max(wide_ink, out_on * (smoothstep(out_top + 14.5, out_top + 15.5, depth) - smoothstep(out_top + 16.5, out_top + 17.5, depth)));
	earth *= 1.0 - 0.38 * smoothstep(34.0, 80.0, depth);  // darker down the bank (values: real darks at the bottom)
	c = mix(c, earth, wide * 0.92);
	ink = max(ink, wide_ink * wide * 0.8);
	// stones: in the bank fewer and bigger, half buried, lit on top, a soft shadow under each (no ringed pebbles)
	vec2 sc = floor(level_pos / mix(26.0, 44.0, wide));
	float has_stone = step(mix(0.86, 0.84, wide), hash(sc.x * 13.1 + sc.y * 71.7)) * soil_k * (1.0 - outcrop);
	vec2 sp = (fract(level_pos / mix(26.0, 44.0, wide)) - 0.5 - (vec2(hash(sc.x + sc.y * 3.3), hash(sc.y + sc.x * 5.1)) - 0.5) * 0.4) * vec2(1.0, 1.6);
	float stone_r = mix(0.2, 0.3, wide) * (0.75 + 0.5 * hash(sc.x * 2.1 + sc.y * 9.3));
	float stone = (1.0 - smoothstep(stone_r - 0.03, stone_r, length(sp))) * has_stone;
	vec3 stone_c = mix(vec3(0.4, 0.3, 0.3), vec3(0.8, 0.64, 0.52), smoothstep(0.02, -0.08, sp.y + sp.x * 0.3));
	c *= 1.0 - 0.35 * wide * has_stone * (1.0 - smoothstep(0.0, stone_r * 0.9, length(sp - vec2(0.06, stone_r * 0.7)))) * (1.0 - stone);
	c = mix(c, stone_c, stone);
	ink = max(ink, (smoothstep(stone_r - 0.03, stone_r, length(sp)) - smoothstep(stone_r, stone_r + 0.04, length(sp))) * has_stone * mix(1.0, 0.55, wide));
	// round 9: moss creeping down from under the grass in ragged tongues (the grass sat on the rock
	// "like cake icing"), and on the sunny top of a block here and there
	float lip = 18.0 + noise(level_pos.x * 0.09) * 8.0;  // (round 6: deeper, the grass overhangs)
	float tongue = lip + 2.0 + 24.0 * pow(noise(level_pos.x * 0.05 + 7.0), 2.0) + 6.0 * noise(level_pos.x * 0.31)
			+ 44.0 * pow(noise(level_pos.x * 0.11 + 3.0), 6.0);
	float moss = (1.0 - smoothstep(tongue - 1.0, tongue + 1.0, depth)) * step(lip - 2.0, depth) * narrow;
	vec3 moss_c = mix(vec3(0.24, 0.36, 0.13), vec3(0.42, 0.56, 0.18), step(0.55, noise2(level_pos * vec2(0.08, 0.12))));
	c = mix(c, moss_c, moss * 0.9);
	ink = max(ink, (smoothstep(tongue - 1.0, tongue + 0.6, depth) - smoothstep(tongue + 0.6, tongue + 2.2, depth))
			* step(lip + 4.0, tongue) * 0.6 * narrow);
	// deeper: a little darker and cooler
	c *= mix(vec3(1.0), deep_tint, smoothstep(40.0, 260.0, depth) * 0.6);
	// cel light from the low sun on the left: the lit band, the mid tone, the shade band; (round 9)
	// in rock each block takes the light of its centre, so the bands' edges run along its joints
	float fl = mix(from_left, max(from_left + to_c.x, 0.0), rock_k);
	float fr = mix(from_right, max(from_right - to_c.x, 0.0), rock_k);
	float lit = 1.0 - smoothstep(0.0, min(46.0, width * 0.36) * (1.0 + 0.5 * strata_k), fl);
	// (round 12, "the shading ignores the low sun on the left": a pillar's far face clearly in shade)
	float away = 1.0 - smoothstep(0.0, min(56.0, width * 0.5) * (1.0 + 1.05 * strata_k), fr);
	float below_top = smoothstep(4.0, 30.0, depth);
	float waver = (noise(level_pos.y * 0.035 + float(cell.x)) - 0.5) * 0.3 * (1.0 - rock_k);  // (round 8: band edges follow the rock)
	float band_lit = smoothstep(0.45, 0.52, lit + waver) * below_top;
	float band_shade = smoothstep(0.45, 0.52, away - waver) * below_top;
	c *= mix(vec3(1.0), sun_tint, band_lit);
	c *= mix(vec3(1.0), shade_tint * mix(0.8, 0.7, narrow), band_shade);
	c *= 1.0 + narrow * 0.14 * (0.5 - clamp(from_left / max(width, 1.0), 0.0, 1.0)) * below_top;  // a round column
	// under the grass lip: a crisp band of shadow, then a long soft occlusion (round 9); the foot of a
	// wall darker; a ledge's underside
	c *= 1.0 - 0.55 * (1.0 - smoothstep(lip - 1.0, lip + 1.0, depth));
	c *= 1.0 - mix(mix(0.3, 0.5, wide), 0.42, narrow) * exp(-max(depth - lip, 0.0) / mix(mix(16.0, 12.0, wide), 24.0, narrow)) * step(lip, depth);  // (round 12: the cap's occlusion on a pillar; round 19: deeper under the ground's lip)
	if (width < 200.0) {  // a dark contact where a wall meets the ground (round 9: a soft gradient)
		c *= 1.0 - 0.4 * (1.0 - smoothstep(0.0, 48.0, to_foot - 6.0)) * smoothstep(30.0, 40.0, depth);
	}
	float to_bottom = 32.0 - mod(level_pos.y, 32.0);
	c *= 1.0 - 0.38 * (1.0 - smoothstep(9.0, 11.0, to_bottom)) * ledge;
	float taper = 0.0;
	// (round 5: the row over a ledge, at the island's ends, tapers with it: no square upper end)
	vec4 below4 = floor(texelFetch(depth_tex, min(cell + ivec2(0, 1), textureSize(depth_tex, 0) - 1), 0) * 255.0 + 0.5);
	float floating = max(ledge, step(127.5, below4.a));
	if (floating > 0.5) {
		// round 19: a floating ledge's own row is the sandstone of the rock under it (kie.ai masses), in
		// the shade of its grass mat (it was a red soil slab between the grass and the rock)
		vec3 ledge_rock = mix(vec3(0.74, 0.5, 0.42), vec3(0.6, 0.44, 0.5), smoothstep(10.0, 40.0, depth));
		ledge_rock *= 0.93 + 0.1 * noise2(level_pos * vec2(0.06, 0.15));
		ledge_rock *= 1.0 - 0.45 * (1.0 - smoothstep(lip + 2.0, lip + 18.0, depth));
		c = mix(c, ledge_rock, 0.85);
		// (round 4: rounder, deeper: a one-cell ledge no longer ends in a straight vertical edge)
		float cut = max(depth - 6.0, 0.0) * 1.3 + noise(level_pos.y * 0.2 + float(cell.x)) * 4.0;
		taper = cells.g < 0.5 ? 1.0 - smoothstep(cut - 0.7, cut + 0.7, from_left) : 0.0;
		// (round 6) a warm rim along an island's end on the sun's side
		float end_rim = cells.g < 0.5 ? (1.0 - smoothstep(0.0, 4.0, from_left - cut)) * step(cut, from_left) : 0.0;
		c = mix(c, min(c * 1.5 + rim_colour * 0.22, vec3(1.0)), end_rim * 0.7);
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
		float reach = min(36.0, width * 0.2) * grow;  // (round 8: chunkier)
		float wx = level_pos.x - from_left;  // the wall's left side: one pattern per wall, not per cell
		float el = (0.2 + 0.5 * noise(level_pos.y * 0.017 + wx * 0.031) + 0.3 * noise(level_pos.y * 0.09 + 9.0)) * reach;
		float er = (0.2 + 0.5 * noise(level_pos.y * 0.02 + wx * 0.027 + 40.0) + 0.3 * noise(level_pos.y * 0.1 + 3.0)) * reach;
		// round 11 ("a chimney the same width top to bottom"): a slight taper, narrower higher up
		// (the grass cap overhangs it a little more); its foot stands as wide as the ground under it
		float taper_in = min(width * 0.06, 12.0) * smoothstep(0.0, 260.0, to_foot) * smoothstep(20.0, 46.0, depth);
		// (only up to 31 units in: past the side's own cell the edge would go straight; round 9's
		// bulges and notches are kept as they were)
		el += min(taper_in, max(31.0 - el, 0.0));
		er += min(taper_in, max(31.0 - er, 0.0));
		side_d = min(from_left - el, from_right - er);
		lit_d = cells.g < 0.5 ? from_left - el : 99.0;
		erode = (cells.g < 0.5 ? 1.0 - smoothstep(el - 0.6, el + 0.6, from_left) : 0.0);
		erode = max(erode, cells.b < 0.5 ? 1.0 - smoothstep(er - 0.6, er + 0.6, from_right) : 0.0);
	}
	// round 19 (the judges: "a thin water strip cut off abruptly"): a bank under a pool's surface is seen
	// through the water, murky and bluer deeper down, so the pool runs into its banks (it read as a red
	// block cut square under the waterline); every pit is a pool (Level._flood_pits)
	float surf = 584.0 + sin(level_pos.x * 0.045 + TIME * 1.7) * 1.6;
	float sub = smoothstep(surf, surf + 4.0, level_pos.y) * (1.0 - floating);
	float by_water = 1.0 - smoothstep(4.0, 30.0, min(from_left, from_right));
	vec3 murk = mix(vec3(0.12, 0.3, 0.33), vec3(0.04, 0.08, 0.2), smoothstep(surf, surf + 46.0, level_pos.y));
	c = mix(c, murk * (0.7 + 0.5 * dot(c, vec3(0.33))), sub * by_water * 0.82);
	// edges: the shape's light (R) and rim (B) kept as cel steps; ink (G and the eroded edge) thick
	float l = shape.r - 0.5;
	c = l > 0.0 ? mix(c, c * lit_colour * 1.35, step(0.12, l) * 0.8) : c * (1.0 - step(0.12, -l) * 0.3);
	c = mix(c, min(c * 1.3 + rim_colour * 0.1, vec3(1.0)), step(0.35, shape.b) * 0.5);
	ink = max(ink, step(0.3, shape.g));
	float edge_line = (1.0 - smoothstep(2.4, 3.4, side_d)) * step(side_d, 98.0);
	float sun_edge = (1.0 - smoothstep(4.0, 5.0, lit_d)) * step(lit_d, 98.0) * (1.0 - edge_line);
	c = mix(c, min(c * 1.45 + rim_colour * 0.2, vec3(1.0)), sun_edge * 0.7);
	// round 12: the low sun warms the sun side's edge further in (a pillar's left face)
	float warm_edge = (1.0 - smoothstep(5.0, 13.0, lit_d)) * step(lit_d, 98.0) * (1.0 - edge_line) * (1.0 - sun_edge) * narrow;
	c = mix(c, min(c * vec3(1.22, 1.08, 0.92) + rim_colour * 0.06, vec3(1.0)), warm_edge * 0.75);
	ink = max(ink, edge_line);
	c = mix(c, outline_colour, ink * 0.92);
	// round 5: a ledge's underside in a wavy line (it was flat as a box), inked
	float bump = 4.0 + 8.0 * noise(level_pos.x * 0.045 + float(cell.y) * 3.1);
	float under_cut = ledge * (1.0 - smoothstep(bump - 0.7, bump + 0.7, to_bottom));
	c = mix(c, outline_colour, ledge * (1.0 - smoothstep(bump + 1.5, bump + 3.0, to_bottom)) * 0.9);
	COLOR = vec4(c, shape.a * (1.0 - erode) * (1.0 - taper) * (1.0 - under_cut));
}

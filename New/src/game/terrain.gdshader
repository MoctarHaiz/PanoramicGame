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

// Round 9: rock blocks: a Voronoi of points jittered in rows of `size` cells: units from q to its
// block's centre, the block's id, units to its edge (about)
void blocks(vec2 q, vec2 size, float seed, out vec2 to_c, out vec2 id_out, out float joint) {
	vec2 rp = q / size;
	vec2 ri = floor(rp);
	vec2 rf = fract(rp);
	float f1 = 1e5;
	float f2 = 1e5;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 id = ri + g;
			vec2 o = vec2(hash(id.x * 1.71 + id.y * 31.3 + seed * 7.0) * 0.9 + 0.05,
					hash(id.x * 7.13 + id.y * 13.9 + 5.0 + seed * 3.0) * 0.36 + 0.32);
			vec2 r = (g + o - rf) * size;
			float d = dot(r, r);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				to_c = r;
				id_out = id;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	joint = (sqrt(f2) - sqrt(f1)) * 0.5;
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
	// (blocks longer than tall, their centres kept near the middle of their bed: the joints between
	// beds run across in wavy strata, the joints in a bed lean). Round 10 ("evenly sized stones
	// with even outlines"): big feature blocks, and others split into small fill stones
	vec2 rq = level_pos + vec2((noise(level_pos.y * 0.021) - 0.5) * 30.0, (noise(level_pos.x * 0.011) - 0.5) * 26.0);
	vec2 to_c = vec2(0.0);  // units from this point to its block's centre
	vec2 bid = vec2(0.0);
	float joint = 0.0;  // units to the block's edge (about)
	blocks(rq, vec2(84.0, 40.0), 0.0, to_c, bid, joint);
	float feature = step(0.6, hash(bid.x * 2.3 + bid.y * 9.7 + 4.0));
	if (feature < 0.5) {
		vec2 small_c;
		vec2 small_id;
		float small_joint;
		blocks(rq + bid * 17.0, vec2(38.0, 21.0), 1.0, small_c, small_id, small_joint);
		to_c = small_c;
		bid = small_id + vec2(500.0);
		joint = min(joint, small_joint);
	}
	vec2 sun_dir = vec2(-0.6, -0.8);  // towards the sun: upper left
	float facing = clamp(dot(-to_c, sun_dir) / 24.0, -1.0, 1.0);  // which side of its block
	float tone = hash(bid.x * 3.7 + bid.y * 17.1);
	float bed_tone = hash(bid.y * 5.3 + 1.0);
	vec3 block = rock_colour;
	block = mix(block, vec3(0.66, 0.34, 0.23), step(0.62, bed_tone) * 0.7);  // redder beds
	block = mix(block, vec3(0.84, 0.62, 0.40), step(bed_tone, 0.22) * 0.35);  // paler ones
	block = mix(block, vec3(0.6, 0.5, 0.46), step(0.88, tone) * 0.3);  // a greyer stone here and there
	block *= 0.9 + tone * 0.2;
	c = mix(c, block, rock_k);
	c *= 1.0 + 0.14 * facing * rock_k;  // each block rounded by the light
	float bevel = 1.0 - smoothstep(1.8, mix(4.5, 7.0, feature), joint);  // (round 10: wider on the big blocks)
	c = mix(c, c * (facing > 0.0 ? 1.32 : 0.7), bevel * smoothstep(0.05, 0.5, abs(facing)) * rock_k);
	// (round 10) a block's top face catches the light: a lit plane along its upper edge
	vec2 from_c = -to_c / max(length(to_c), 1.0);
	float top_face = smoothstep(0.5, 0.85, -from_c.y) * (1.0 - smoothstep(2.0, 9.0, joint));
	c = mix(c, min(c * 1.28 + vec3(0.04, 0.03, 0.0), vec3(1.0)), top_face * rock_k * 0.8);
	// the cracks: thicker or thinner by block, broken, mostly on the shaded joints
	float crack_on = smoothstep(0.25, 0.4, noise(level_pos.x * 0.06 + level_pos.y * 0.04 + bid.y * 3.1));
	float crack_w = 0.4 + 1.4 * hash(bid.x * 5.1 + bid.y * 2.9);
	ink = max(ink, (1.0 - smoothstep(crack_w, crack_w + 0.8, joint)) * rock_k * mix(0.25, 1.0, crack_on) * step(facing, 0.35));
	// pits and soft patches in the stone
	c *= 1.0 - 0.08 * smoothstep(0.6, 0.75, noise2(level_pos * 0.09 + bid * 3.0)) * rock_k;
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
	// (round 10: halfway to the centre: a big block in the band's edge is not all in shade)
	float fl = mix(from_left, max(from_left + to_c.x, 0.0), rock_k * 0.6);
	float fr = mix(from_right, max(from_right - to_c.x, 0.0), rock_k * 0.6);
	float lit = 1.0 - smoothstep(0.0, min(46.0, width * 0.36) * (1.0 + 0.5 * rock_k * narrow), fl);
	float away = 1.0 - smoothstep(0.0, min(56.0, width * 0.5) * (1.0 + 0.85 * rock_k * narrow), fr);  // (round 10: a wider shade side)
	float below_top = smoothstep(4.0, 30.0, depth);
	float waver = (noise(level_pos.y * 0.035 + float(cell.x)) - 0.5) * 0.3 * (1.0 - rock_k);  // (round 8: band edges follow the rock)
	float band_lit = smoothstep(0.45, 0.52, lit + waver) * below_top;
	float band_shade = smoothstep(0.45, 0.52, away - waver) * below_top;
	c *= mix(vec3(1.0), sun_tint, band_lit);
	c *= mix(vec3(1.0), shade_tint * 0.8, band_shade);
	c *= 1.0 + narrow * 0.14 * (0.5 - clamp(from_left / max(width, 1.0), 0.0, 1.0)) * below_top;  // a round column
	// under the grass lip: a crisp band of shadow, then a long soft occlusion (round 9); the foot of a
	// wall darker; a ledge's underside
	c *= 1.0 - 0.55 * (1.0 - smoothstep(lip - 1.0, lip + 1.0, depth));
	c *= 1.0 - 0.3 * exp(-max(depth - lip, 0.0) / 16.0) * step(lip, depth);
	if (width < 200.0) {  // a dark contact where a wall meets the ground (round 9: a soft gradient)
		c *= 1.0 - 0.4 * (1.0 - smoothstep(0.0, 48.0, to_foot - 6.0)) * smoothstep(30.0, 40.0, depth);
		c *= mix(0.74, 1.0, smoothstep(20.0, 200.0, to_foot));  // (round 10: darker towards its base)
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
		float reach = min(44.0, width * 0.24) * grow;  // (round 8: chunkier; round 10: more)
		float wx = level_pos.x - from_left;  // the wall's left side: one pattern per wall, not per cell
		float el = (0.2 + 0.5 * noise(level_pos.y * 0.017 + wx * 0.031) + 0.3 * noise(level_pos.y * 0.09 + 9.0)) * reach;
		float er = (0.2 + 0.5 * noise(level_pos.y * 0.02 + wx * 0.027 + 40.0) + 0.3 * noise(level_pos.y * 0.1 + 3.0)) * reach;
		// round 10 ("a box with straight vertical sides"): each bed of rock juts out or stands back
		// its own way, so the sides step like stacked slabs, not one wavy line
		float bed_row = floor(rq.y / 40.0);
		float bed_f = smoothstep(0.7, 1.0, fract(rq.y / 40.0));  // (a slanted step into the next bed)
		float sl = mix(hash(bed_row * 7.3 + wx * 0.13), hash((bed_row + 1.0) * 7.3 + wx * 0.13), bed_f);
		float sr = mix(hash(bed_row * 5.9 + wx * 0.17 + 3.0), hash((bed_row + 1.0) * 5.9 + wx * 0.17 + 3.0), bed_f);
		el = mix(el, (0.08 + 0.92 * sl) * reach + noise(level_pos.y * 0.21) * 3.0, 0.7);
		er = mix(er, (0.08 + 0.92 * sr) * reach + noise(level_pos.y * 0.23 + 5.0) * 3.0, 0.7);
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

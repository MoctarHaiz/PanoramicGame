shader_type canvas_item;
// The body of the ground (TerrainView). Each cell is drawn from terrain_shape.png (its outline,
// rounded open corners and edge light) while the paint comes from soil.png and rock.png sampled in
// level units, so the soil runs on across cells without seams. Deeper under an open top the soil
// darkens and cools and turns to sandstone; just under the grass a soft shadow.
// depth_tex holds, per cell, how many solid cells stand above it (r * 255) and how many lie
// between it and the open air on its left (g) and right (b), from column first_col: each wall is
// shaded as a rounded form, a warm rim on the sun's side (upper left), cool violet shade on the far
// side.

uniform sampler2D soil_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D rock_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform vec3 outline_colour : source_color = vec3(0.23, 0.10, 0.07);
uniform vec3 lit_colour : source_color = vec3(1.0, 0.82, 0.58);
uniform vec3 rim_colour : source_color = vec3(1.0, 0.80, 0.55);
uniform vec3 deep_tint : source_color = vec3(0.52, 0.42, 0.56);
uniform vec3 shade_tint : source_color = vec3(0.50, 0.42, 0.62);  // the side away from the sun
uniform vec3 sun_tint : source_color = vec3(1.25, 1.08, 0.86);  // the side facing it
uniform float repeat_units = 256.0;  // level units covered by one copy of soil.png / rock.png
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
	vec2 uv = level_pos / repeat_units;
	// Round 2: no visible repeat: each texture is read twice, at two scales and turned, and the two
	// blended by a slow noise; big soft patches of lighter and darker stone; beds of rock across
	float patch = noise2(level_pos / 150.0 + vec2(float(first_col) * 0.0, 7.3));
	float blend = smoothstep(0.3, 0.7, noise2(level_pos / 95.0 + vec2(3.1, 1.7)));
	vec2 uv2 = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * uv * 0.71 + vec2(0.53, 0.29);
	vec3 soil = mix(texture(soil_tex, uv, 0.7).rgb, texture(soil_tex, uv2, 0.7).rgb, blend * 0.8);
	vec3 rock = mix(texture(rock_tex, uv * 0.75 + vec2(0.37, 0.11)).rgb, texture(rock_tex, uv2 * 0.9).rgb, blend);
	float wobble = texture(soil_tex, level_pos / 1400.0).r;  // slow variation for the soil-rock line
	float to_rock = smoothstep(84.0, 150.0, depth + (wobble - 0.55) * 110.0);
	vec3 c = mix(soil, rock, to_rock);
	float bed = sin(level_pos.y * 0.085 + noise(level_pos.x * 0.012) * 4.0) * 0.5 + 0.5;
	c *= mix(vec3(0.9, 0.9, 0.95), vec3(1.08, 1.03, 0.96), mix(patch, bed, 0.35 * to_rock));
	// deeper: darker and a little violet (cool shade), as in the hero sheet
	float d = smoothstep(18.0, 200.0, depth);
	c *= mix(vec3(1.0), deep_tint, d);
	c *= 1.06 - 0.1 * smoothstep(40.0, 260.0, depth);  // lit from above: the top of a wall brightest
	// form: the wall turns towards the sun on its left and away on its right; a narrow pillar is
	// a rounded column (lit, then the core shadow, then a little bounce light at its far edge)
	float width = from_left + from_right;
	float lit = 1.0 - smoothstep(0.0, min(44.0, width * 0.42), from_left);
	float away = 1.0 - smoothstep(0.0, min(64.0, width * 0.62), from_right);
	float bounce = (1.0 - smoothstep(0.0, 7.0, from_right)) * 0.35;
	float below_top = smoothstep(4.0, 30.0, depth);  // not on the grass lip
	c *= mix(vec3(1.0), sun_tint, lit * 1.0 * below_top);
	c *= mix(vec3(1.0), shade_tint * 0.82, (away * 0.95 - bounce) * below_top);
	// round 4: the rock of a wall in beds: a dark crack under each bed, its top face lit, each bed
	// its own tone; the foot of a wall darker where it meets the ground (occlusion)
	if (width < 200.0 && depth > 34.0) {
		float by = level_pos.y + (noise(level_pos.x * 0.021) - 0.5) * 10.0;
		float f = fract(by / 38.0);
		float bed_k = smoothstep(34.0, 60.0, depth);
		c *= 1.0 - 0.38 * (1.0 - smoothstep(0.0, 0.06, f)) * bed_k;
		c *= 1.0 + 0.16 * smoothstep(0.06, 0.1, f) * (1.0 - smoothstep(0.12, 0.26, f)) * bed_k;
		c *= 1.0 + (hash(floor(by / 38.0) + float(cell.x)) - 0.5) * 0.12 * bed_k;
		c *= mix(0.62, 1.0, smoothstep(0.0, 48.0, to_foot));
	}
	// under the grass: the overhanging lip's occlusion, deep and soft, then the soil comes back
	float under = 1.0 - smoothstep(4.0, 40.0, depth);
	c *= 1.0 - under * 0.55;
	// New: a ledge's underside in its own shade (it was a flat brown band), and its ends taper
	// under the grass (they were cut square): the earth recedes towards the bottom
	float to_bottom = 32.0 - mod(level_pos.y, 32.0);
	c *= mix(1.0, 0.55 + 0.45 * smoothstep(0.0, 16.0, to_bottom), ledge);
	float taper = 0.0;
	if (ledge > 0.5) {
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
	// edges: R above 0.5 is light (open left side), below is shade (open right, open bottom)
	float l = shape.r - 0.5;
	c = l > 0.0 ? mix(c, c * lit_colour * 1.45, l * 1.6) : c * (1.0 + l * 1.7);
	c = mix(c, min(c * 1.35 + rim_colour * 0.12, vec3(1.0)), shape.b * 0.55);
	c = mix(c, outline_colour, shape.g * 0.92);
	// the new edge: a hot rim where it faces the sun, a dark line where it turns away
	float edge_line = (1.0 - smoothstep(0.0, 2.2, side_d)) * step(side_d, 98.0);
	float sun_edge = (1.0 - smoothstep(0.0, 4.5, lit_d)) * step(lit_d, 98.0);
	c = mix(c, outline_colour, edge_line * 0.8 * (1.0 - sun_edge));
	c = mix(c, min(c * 1.5 + rim_colour * 0.25, vec3(1.0)), sun_edge * 0.75);
	COLOR = vec4(c, shape.a * (1.0 - erode) * (1.0 - taper));
}

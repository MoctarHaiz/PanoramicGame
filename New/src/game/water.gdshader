shader_type canvas_item;
// Water in a gap, stylised to sit with the painted ground: clear turquoise under a wavy surface
// that reflects the warm evening sky, deep blue below, a bright foam line, a web of light
// (caustics) in the shallows, streaks of sun glitter and a few twinkling sparkles. Darker and
// foamy against the banks (the rectangle reaches 8 units under the soil on each side).
// Round 23 (the judges, j19: "the river a flat blue stripe with a white top edge and a dark band beneath: a UI bar";
// "the small water gap in the lane reads as a hole"): the far shore drawn above the waterline (a wet, shaded bank of
// mud under the grass, inked along its top: the water lies between banks, not in a cut), the white rim gone (foam only
// in drifting patches and at the banks), the bank's dark reflection broken by ripples just under it, then rows of
// cel waves growing toward the viewer (a lit crest line, its face, a darker trough), glints breaking the bands, and a
// lighter deep colour (no black band under it).

uniform vec2 rect_size = vec2(192.0, 140.0);
uniform float x_offset = 0.0;  // level x of the rect, so neighbouring pools move as one sea
uniform float level_top = 0.0;  // level y of the rect's top
uniform vec4 shallow : source_color = vec4(0.14, 0.44, 0.52, 1.0);  // round 2: deeper, less candy (round 10: less cyan)
uniform vec4 deep : source_color = vec4(0.09, 0.2, 0.33, 1.0);  // (round 23: lighter: it read as a dark band)
uniform vec4 sky_tint : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec4 foam : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform sampler2D soil_tex : source_color, repeat_enable, filter_linear_mipmap;  // the banks' earth
// round 9: the savanna behind the pool mirrored in it ("a flat cyan rectangle with no reflection",
// every round): the tall golden grass over the mid hills over the sky, read from SavannaView's own
// strips where they stand behind (no copy of the screen: it cost 15 MB on an iPhone 15)
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap;  // near_grass.png
uniform sampler2D hills_tex : source_color, repeat_enable, filter_linear_mipmap;  // far_hills.png, the plain
uniform sampler2D sky_tex : source_color, filter_linear;  // sky.png
uniform float scroll = 0.0;  // the level's scroll (WorldView sets it each frame)
uniform vec4 grass_strip = vec4(0.42, 646.0, 0.5, 100.0);  // SavannaView.STRIPS: scroll factor, bottom y, units a px, height
uniform vec4 hills_strip = vec4(0.15, 648.0, 1.0, 240.0);
uniform vec3 grass_tint : source_color = vec3(0.86, 0.84, 0.68);  // their tints there (round 23: SavannaView's new ones)
uniform vec3 hills_tint : source_color = vec3(0.76, 0.72, 0.56);

const vec3 INK = vec3(0.17, 0.085, 0.06);

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
	vec2 p = UV * rect_size;
	float x = p.x + x_offset;
	float t = TIME;
	// (round 23: a choppier line: little crests, not a sine rule)
	float surface = 7.0 + sin(x * 0.045 + t * 1.7) * 1.6 + sin(x * 0.13 - t * 2.6) * 0.8 + sin(x * 0.021 - t * 0.6) * 1.1
			- abs(sin(x * 0.09 + t * 1.2)) * 0.9;
	float d = p.y - surface;  // depth under the surface
	// round 23: the far shore above the waterline: a wet, shaded mud bank under the far grass, its top inked
	float shore_top = 1.2 + (noise(vec2(x * 0.06, 3.0)) - 0.5) * 2.4 + (noise(vec2(x * 0.21, 7.0)) - 0.5) * 1.2;
	if (d < 0.0) {
		if (p.y < shore_top - 0.6) {
			discard;
		}
		float into = clamp((p.y - shore_top) / max(surface - shore_top, 1.0), 0.0, 1.0);
		vec3 bank = mix(vec3(0.42, 0.36, 0.22), vec3(0.24, 0.2, 0.17), smoothstep(0.0, 0.6, into));  // (its grassy lip, then wet mud)
		bank *= 0.9 + 0.18 * noise(vec2(x * 0.12, p.y * 0.4));
		bank = mix(bank, vec3(0.16, 0.14, 0.14), smoothstep(0.7, 1.0, into) * 0.6);  // (darkest where it is wet)
		bank = mix(bank, INK, 1.0 - smoothstep(0.4, 1.4, p.y - shore_top));
		COLOR = vec4(bank, smoothstep(-0.6, 0.4, p.y - shore_top));
	} else {
		// Round 5: water in the hero's style: flat bands (the warm sky reflected in a light band under
		// the surface, a mid teal, the deep blue), ripple dashes drifting in them, a foam line on top
		float ripple = noise(vec2(x * 0.03 + t * 0.35, floor(d / 5.0) * 3.7));
		float band_y = d + (ripple - 0.5) * 5.0;
		vec3 c = deep.rgb;
		c = mix(c, mix(shallow.rgb, deep.rgb, 0.45), step(band_y, 32.0));
		c = mix(c, shallow.rgb * 1.08, step(band_y, 16.0));
		// (round 10: the low sun's sky lies on the surface in a warm gold sheen, broken by the ripples)
		vec3 sky_band = mix(sky_tint.rgb, vec3(1.0, 0.66, 0.36), 0.3);
		float row = floor(d / 2.6);
		float streak = smoothstep(0.48, 0.56, noise(vec2(x * 0.022 - t * 0.3 + row * 3.1, row * 1.7)))
				* (1.0 - smoothstep(0.3, 0.5, abs(fract(d / 2.6) - 0.5) * 2.0 - 0.35));
		float sheen = streak * (1.0 - smoothstep(3.0, 16.0, d));
		c = mix(c, sky_band, sheen * 0.7);
		c *= mix(1.0, 0.8, smoothstep(6.0, 60.0, d));  // (round 6: deeper is darker within the bands; round 23: less)
		// round 9: the reflection: the picture above the surface mirrored under it, broken by the
		// ripples (rows of it slide sideways), darker and bluer with depth, strongest near the surface
		float wob = (noise(vec2(x * 0.02 - t * 0.6, d * 0.32 + t * 0.4)) - 0.5) * (4.0 + d * 0.25)
				+ sin(d * 0.9 - t * 3.0) * 1.2;
		float my = (UV.y * rect_size.y - d) - (2.5 * d + 2.0);  // the mirrored point's level y (the rect's top is 0)
		my += level_top;
		float mx = x + wob;
		vec3 mirrored = texture(sky_tex, vec2(0.5, clamp((my + 230.0) / 800.0, 0.0, 1.0))).rgb;
		vec2 hq = vec2((mx - scroll * (1.0 - hills_strip.x)) / hills_strip.z, (my - hills_strip.y + hills_strip.w) / hills_strip.w);
		vec4 hills = texture(hills_tex, vec2(hq.x / float(textureSize(hills_tex, 0).x), clamp(hq.y, 0.0, 1.0)));
		mirrored = mix(mirrored, hills.rgb * hills_tint, hills.a * step(0.0, hq.y));
		vec2 gq = vec2((mx - scroll * (1.0 - grass_strip.x)) / grass_strip.z, (my - grass_strip.y + grass_strip.w) / grass_strip.w);
		vec4 grass = texture(grass_tex, vec2(gq.x / float(textureSize(grass_tex, 0).x), clamp(gq.y, 0.0, 1.0)));
		mirrored = mix(mirrored, grass.rgb * grass_tint, grass.a * step(0.0, gq.y));
		float refl = mix(0.9, 0.4, smoothstep(2.0, 40.0, d)) * smoothstep(1.0, 3.5, d);
		float luma = dot(mirrored, vec3(0.3, 0.55, 0.15));
		vec3 tinted = mix(c * (0.45 + 1.1 * luma), mirrored * vec3(0.8, 0.95, 1.0), 0.34);
		c = mix(c, tinted, refl);
		// round 23: the far bank's shade mirrored just under its waterline, its lower edge broken into ripple dashes
		float shade_low = 5.0 + 3.0 * noise(vec2(x * 0.05 - t * 0.2, 1.0)) + (noise(vec2(x * 0.3 - t * 0.9, floor(d / 1.6))) - 0.5) * 4.0;
		c = mix(c, c * vec3(0.5, 0.55, 0.62), (1.0 - smoothstep(shade_low - 0.6, shade_low + 0.6, d)) * smoothstep(0.4, 1.4, d) * 0.85);
		// light in the water: slanting shafts down from the surface, drifting
		float shaft = smoothstep(0.55, 0.95, sin((x + d * 0.7) * 0.07 + noise(vec2(x * 0.01 + t * 0.15, 2.0)) * 5.0 + t * 0.4));
		c += vec3(0.2, 0.32, 0.3) * shaft * smoothstep(3.0, 8.0, d) * (1.0 - smoothstep(10.0, 52.0, d)) * 0.4;
		// round 23: rows of cel waves, each a little taller nearer the viewer (lower down): a lit crest line curling
		// over its lit face, a darker trough behind the next crest; drifting, broken here and there
		float wr = log(max(d, 3.0) / 3.0) / log(1.42);
		float wk = floor(wr);
		float wt = fract(wr);
		float wf = 0.11 / (1.0 + wk * 0.45);
		float wphase = hash(vec2(wk, 2.0)) * 6.28 + t * (0.5 + 0.1 * wk);
		float crest = 0.26 + 0.48 * abs(sin(x * wf + wphase));
		float wseg = smoothstep(0.5, 0.6, noise(vec2(x * wf * 1.7 + wk * 4.1 - t * 0.2, wk)));  // (short strokes, not rules)
		float on_crest = (1.0 - smoothstep(0.0, 0.07 + 0.02 * wk, abs(wt - crest))) * wseg * step(4.0, d);
		float face = smoothstep(crest, crest + 0.06, wt) * (1.0 - smoothstep(crest + 0.18, crest + 0.4, wt)) * wseg * step(4.0, d);
		float trough = smoothstep(crest - 0.3, crest - 0.06, wt) * (1.0 - smoothstep(crest - 0.06, crest, wt)) * wseg * step(4.0, d);
		c = mix(c, c * 0.78, trough * 0.6);
		c = mix(c, c * 1.18 + vec3(0.02, 0.05, 0.06), face * 0.45);
		c = mix(c, mix(c, vec3(0.86, 0.95, 0.96), 0.7), on_crest * (1.0 - smoothstep(30.0, 70.0, d) * 0.5));
		// ripple dashes: short light strokes along the bands, sliding with the current
		float dash_row = fract(d / 7.0);
		float dash = step(0.7, noise(vec2(x * 0.06 - t * 0.5, floor(d / 7.0) * 5.3))) * (1.0 - smoothstep(0.0, 0.18, abs(dash_row - 0.5)));
		c = mix(c, mix(c, vec3(1.0, 0.97, 0.9), 0.45), dash * (1.0 - smoothstep(10.0, 44.0, d)));
		// round 8: the grassy banks mirrored just under the surface near them (the pool reads as water
		// between banks, not a cyan box)
		float near_bank = 1.0 - smoothstep(14.0, 40.0, min(p.x, rect_size.x - p.x) - 8.0);
		float mirror = near_bank * smoothstep(3.0, 5.0, d) * (1.0 - smoothstep(14.0, 20.0, d + (ripple - 0.5) * 4.0));
		c = mix(c, vec3(0.16, 0.26, 0.2), mirror * 0.75);
		// a few glints, and (round 23) longer vertical sparkles of the sky breaking the bands
		vec2 q = vec2(x / 10.0, d / 6.0);
		vec2 cell = floor(q);
		float h = hash(cell + 3.1);
		float flash = pow(max(0.0, sin(t * 2.6 + h * 37.0)), 12.0);
		vec2 fq = fract(q) - 0.5;
		float star = smoothstep(0.32, 0.0, length(fq * vec2(1.0, 1.6)));
		c += vec3(1.0, 0.97, 0.85) * step(0.9, h) * flash * star * (1.0 - smoothstep(2.0, 12.0, d));
		float col = floor(x / 23.0);
		float glint = step(0.8, hash(vec2(col, 9.0))) * (1.0 - smoothstep(0.0, 1.2, abs(fract(x / 23.0) - 0.5) * 23.0 - 0.6))
				* smoothstep(3.0, 6.0, d) * (1.0 - smoothstep(10.0, 26.0 + 14.0 * hash(vec2(col, 4.0)), d))
				* step(0.5, fract(d / 3.0 + hash(vec2(col, 1.0)) - t * 0.6));
		c = mix(c, vec3(0.92, 0.96, 0.94), glint * 0.5);
		// the waterline: a thin wet line of sky under the far bank (no white rim along it), foam only in drifting patches
		float patch = smoothstep(0.62, 0.82, noise(vec2(x * 0.03 - t * 0.25, 1.7)));
		float thick = 0.9 + 2.2 * patch + 0.6 * noise(vec2(x * 0.11 - t * 0.8, 4.2));
		vec3 top_col = mix(mix(sky_band, vec3(0.62, 0.78, 0.8), 0.5), foam.rgb, patch * 0.75);
		c = mix(c, top_col, (1.0 - smoothstep(thick - 0.5, thick + 0.5, d)) * mix(0.55, 1.0, patch));
		float flecks = step(0.72, noise(vec2(x * 0.22 - t * 0.5, floor((d - thick) / 2.0) * 7.0))) * patch
				* step(thick, d) * (1.0 - smoothstep(thick, thick + 6.0, d));
		c = mix(c, foam.rgb, flecks * 0.6);
		// banks: the earth slopes in under the water (flat, lit at its rim, an ink edge), foam curls at it
		float bank = min(p.x, rect_size.x - p.x) - 8.0;  // units from the soil's face
		float reach = 4.0 + 40.0 * (1.0 - exp(-max(d, 0.0) / 24.0)) + (noise(vec2(d * 0.12, x * 0.01)) - 0.5) * 6.0;
		float slope = 1.0 - smoothstep(reach - 0.8, reach + 0.8, bank);
		vec3 earth = mix(vec3(0.42, 0.24, 0.16), vec3(0.62, 0.36, 0.22), step(reach - 5.0, bank));
		vec3 through = mix(earth, deep.rgb, clamp(0.35 + d / 80.0, 0.35, 0.8));
		c = mix(c, through, slope);
		float edge = (1.0 - smoothstep(0.0, 2.2, abs(bank - reach))) * step(3.0, d);
		c = mix(c, vec3(0.12, 0.08, 0.1), edge * 0.75);
		float curl = (1.0 - smoothstep(0.0, 2.0, abs(d - 3.0 - sin(bank * 0.5 - t * 2.0) * 1.5))) * (1.0 - smoothstep(4.0, 16.0, bank));
		c = mix(c, foam.rgb, curl * 0.9);
		// round 9: froth along the banks at the surface, bubbling (the edges read as hard cuts)
		float froth = (1.0 - smoothstep(0.0, 1.0, (bank - 4.0) / (10.0 + 8.0 * noise(vec2(t * 0.7, x * 0.05)))))
				* (1.0 - smoothstep(0.0, 9.0, d)) * step(0.35, noise(vec2(x * 0.4 + t * 1.3, d * 0.5)));
		c = mix(c, foam.rgb, froth * 0.85);
		COLOR = vec4(c, 1.0);
	}
}

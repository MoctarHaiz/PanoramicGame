shader_type canvas_item;
// Water in a gap, stylised to sit with the painted ground: clear turquoise under a wavy surface
// that reflects the warm evening sky, deep blue below, a bright foam line, a web of light
// (caustics) in the shallows, streaks of sun glitter and a few twinkling sparkles. Darker and
// foamy against the banks (the rectangle reaches 8 units under the soil on each side).

uniform vec2 rect_size = vec2(192.0, 140.0);
uniform float x_offset = 0.0;  // level x of the rect, so neighbouring pools move as one sea
uniform float level_top = 0.0;  // level y of the rect's top
uniform vec4 shallow : source_color = vec4(0.12, 0.42, 0.5, 1.0);  // round 2: deeper, less candy (round 10: less cyan)
uniform vec4 deep : source_color = vec4(0.04, 0.07, 0.2, 1.0);
uniform vec4 sky_tint : source_color = vec4(1.0, 0.82, 0.62, 1.0);
uniform vec4 foam : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform sampler2D soil_tex : source_color, repeat_enable, filter_linear_mipmap;  // the banks' earth
// round 9: the savanna behind the pool mirrored in it ("a flat cyan rectangle with no reflection",
// every round): the tall golden grass over the mid hills over the sky, read from SavannaView's own
// strips where they stand behind (no copy of the screen: it cost 15 MB on an iPhone 15)
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap;  // near_grass.png
uniform sampler2D hills_tex : source_color, repeat_enable, filter_linear_mipmap;  // mid_hills.png
uniform sampler2D sky_tex : source_color, filter_linear;  // sky.png
uniform float scroll = 0.0;  // the level's scroll (WorldView sets it each frame)
uniform vec4 grass_strip = vec4(0.42, 646.0, 0.5, 100.0);  // SavannaView.STRIPS: scroll factor, bottom y, units a px, height
uniform vec4 hills_strip = vec4(0.15, 648.0, 1.0, 240.0);
uniform vec3 grass_tint : source_color = vec3(0.84, 0.74, 0.58);  // their tints there
uniform vec3 hills_tint : source_color = vec3(0.66, 0.56, 0.42);

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
	float surface = 7.0 + sin(x * 0.045 + t * 1.7) * 1.6 + sin(x * 0.13 - t * 2.6) * 0.8 + sin(x * 0.021 - t * 0.6) * 1.1;
	float d = p.y - surface;  // depth under the surface
	if (d < -1.0) {
		discard;
	}
	float edge_aa = clamp(d + 1.0, 0.0, 1.0);
	// Round 5: water in the hero's style: flat bands (the warm sky reflected in a light band under
	// the surface, a mid teal, the deep blue), ripple dashes drifting in them, a white foam line on
	// top, foam curling at the banks, the banks' earth sloping in under an ink edge
	float ripple = noise(vec2(x * 0.03 + t * 0.35, floor(d / 5.0) * 3.7));
	float band_y = d + (ripple - 0.5) * 5.0;
	vec3 c = deep.rgb;
	c = mix(c, mix(shallow.rgb, deep.rgb, 0.5), step(band_y, 30.0));
	c = mix(c, shallow.rgb * 1.08, step(band_y, 15.0));
	// (round 10, "a flat cyan rectangle with a white rim": the low sun's sky lies on the surface in a
	// warm gold sheen, broken by the ripples, over the teal)
	vec3 sky_band = mix(sky_tint.rgb, vec3(1.0, 0.66, 0.36), 0.3);
	float row = floor(d / 2.6);
	float streak = smoothstep(0.48, 0.56, noise(vec2(x * 0.022 - t * 0.3 + row * 3.1, row * 1.7)))
			* (1.0 - smoothstep(0.3, 0.5, abs(fract(d / 2.6) - 0.5) * 2.0 - 0.35));
	float sheen = streak * (1.0 - smoothstep(3.0, 16.0, d));
	c = mix(c, sky_band, max(step(band_y, 3.0) * 0.85, sheen * 0.8));
	c *= mix(1.0, 0.72, smoothstep(6.0, 60.0, d));  // (round 6: deeper is darker within the bands: it reads small)
	// round 9: the reflection: the picture above the surface mirrored under it, broken by the
	// ripples (rows of it slide sideways), darker and bluer with depth, strongest near the surface
	float wob = (noise(vec2(x * 0.02 - t * 0.6, d * 0.32 + t * 0.4)) - 0.5) * (4.0 + d * 0.25)
			+ sin(d * 0.9 - t * 3.0) * 1.2;
	// (seen from above the surface the mirror is squeezed: two and a half units of the view a unit
	// of water, so the hills show in it under the grass, not only the grass)
	float my = (UV.y * rect_size.y - d) - (2.5 * d + 2.0);  // the mirrored point's level y (the rect's top is 0)
	my += level_top;
	float mx = x + wob;
	vec3 mirrored = texture(sky_tex, vec2(0.5, clamp(my / 644.0, 0.0, 1.0))).rgb;
	vec2 hq = vec2((mx - scroll * (1.0 - hills_strip.x)) / hills_strip.z, (my - hills_strip.y + hills_strip.w) / hills_strip.w);
	vec4 hills = texture(hills_tex, vec2(hq.x / float(textureSize(hills_tex, 0).x), clamp(hq.y, 0.0, 1.0)));
	mirrored = mix(mirrored, hills.rgb * hills_tint, hills.a * step(0.0, hq.y));
	vec2 gq = vec2((mx - scroll * (1.0 - grass_strip.x)) / grass_strip.z, (my - grass_strip.y + grass_strip.w) / grass_strip.w);
	vec4 grass = texture(grass_tex, vec2(gq.x / float(textureSize(grass_tex, 0).x), clamp(gq.y, 0.0, 1.0)));
	mirrored = mix(mirrored, grass.rgb * grass_tint, grass.a * step(0.0, gq.y));
	// (the water keeps its own colour, lit and darkened by what it mirrors, a little of its hue)
	float refl = mix(0.9, 0.4, smoothstep(2.0, 40.0, d)) * smoothstep(1.0, 3.5, d);
	float luma = dot(mirrored, vec3(0.3, 0.55, 0.15));
	vec3 tinted = mix(c * (0.45 + 1.1 * luma), mirrored * vec3(0.8, 0.95, 1.0), 0.3);
	c = mix(c, tinted, refl);
	// light in the water: slanting shafts down from the surface, drifting
	float shaft = smoothstep(0.55, 0.95, sin((x + d * 0.7) * 0.07 + noise(vec2(x * 0.01 + t * 0.15, 2.0)) * 5.0 + t * 0.4));
	c += vec3(0.2, 0.32, 0.3) * shaft * smoothstep(3.0, 8.0, d) * (1.0 - smoothstep(10.0, 52.0, d)) * 0.5;
	// ripple dashes: short light strokes along the bands, sliding with the current
	float dash_row = fract(d / 7.0);
	float dash = step(0.62, noise(vec2(x * 0.06 - t * 0.5, floor(d / 7.0) * 5.3))) * (1.0 - smoothstep(0.0, 0.18, abs(dash_row - 0.5)));
	c = mix(c, mix(c, vec3(1.0, 0.97, 0.9), 0.5), dash * (1.0 - smoothstep(10.0, 44.0, d)));
	// round 8: the grassy banks mirrored just under the surface near them (the pool reads as water
	// between banks, not a cyan box)
	float near_bank = 1.0 - smoothstep(14.0, 40.0, min(p.x, rect_size.x - p.x) - 8.0);
	float mirror = near_bank * smoothstep(3.0, 5.0, d) * (1.0 - smoothstep(12.0, 16.0, d + (ripple - 0.5) * 4.0));
	c = mix(c, vec3(0.16, 0.3, 0.2), mirror * 0.75);
	// a few glints on the light band
	vec2 q = vec2(x / 10.0, d / 6.0);
	vec2 cell = floor(q);
	float h = hash(cell + 3.1);
	float flash = pow(max(0.0, sin(t * 2.6 + h * 37.0)), 12.0);
	vec2 fq = fract(q) - 0.5;
	float star = smoothstep(0.32, 0.0, length(fq * vec2(1.0, 1.6)));
	c += vec3(1.0, 0.97, 0.85) * step(0.9, h) * flash * star * (1.0 - smoothstep(2.0, 12.0, d));
	// the foam line on top, its thickness wandering; round 9: in drifting patches over a thin bright
	// line of sky, not an even white border all along
	float patch = smoothstep(0.5, 0.78, noise(vec2(x * 0.03 - t * 0.25, 1.7)));
	float thick = 1.0 + 2.8 * patch + 0.8 * noise(vec2(x * 0.11 - t * 0.8, 4.2));
	vec3 top_col = mix(mix(sky_band, foam.rgb, 0.35), foam.rgb, patch * 0.8);
	c = mix(c, top_col, 1.0 - smoothstep(thick - 0.5, thick + 0.5, d));
	float flecks = step(0.7, noise(vec2(x * 0.22 - t * 0.5, floor((d - thick) / 2.0) * 7.0))) * patch
			* step(thick, d) * (1.0 - smoothstep(thick, thick + 6.0, d));
	c = mix(c, foam.rgb, flecks * 0.7);
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
	COLOR = vec4(c, edge_aa);
}

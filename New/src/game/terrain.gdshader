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

void vertex() {
	level_pos = VERTEX;
}

void fragment() {
	vec4 shape = texture(TEXTURE, UV);
	ivec2 cell = ivec2(floor(level_pos / 32.0)) - ivec2(first_col, 0);
	cell = clamp(cell, ivec2(0), textureSize(depth_tex, 0) - 1);
	vec3 cells = floor(texelFetch(depth_tex, cell, 0).rgb * 255.0 + 0.5);
	float depth = cells.r * 32.0 + mod(level_pos.y, 32.0);
	float fx = mod(level_pos.x, 32.0);
	float from_left = cells.g * 32.0 + fx;  // units of solid ground to the open air on the left
	float from_right = cells.b * 32.0 + 32.0 - fx;
	vec2 uv = level_pos / repeat_units;
	vec3 soil = texture(soil_tex, uv).rgb;
	vec3 rock = texture(rock_tex, uv * 0.75 + vec2(0.37, 0.11)).rgb;
	float wobble = texture(soil_tex, level_pos / 1400.0).r;  // slow variation for the soil-rock line
	float to_rock = smoothstep(84.0, 150.0, depth + (wobble - 0.55) * 110.0);
	vec3 c = mix(soil, rock, to_rock);
	// deeper: darker and a little violet (cool shade), as in the hero sheet
	float d = smoothstep(18.0, 200.0, depth);
	c *= mix(vec3(1.0), deep_tint, d);
	// form: the wall turns towards the sun on its left and away on its right; a narrow pillar is
	// a rounded column (lit, then the core shadow, then a little bounce light at its far edge)
	float width = from_left + from_right;
	float lit = 1.0 - smoothstep(0.0, min(44.0, width * 0.42), from_left);
	float away = 1.0 - smoothstep(0.0, min(64.0, width * 0.62), from_right);
	float bounce = (1.0 - smoothstep(0.0, 7.0, from_right)) * 0.35;
	float below_top = smoothstep(4.0, 30.0, depth);  // not on the grass lip
	c *= mix(vec3(1.0), sun_tint, lit * 0.85 * below_top);
	c *= mix(vec3(1.0), shade_tint, (away * 0.8 - bounce) * below_top);
	// under the grass: a soft contact shadow, then the band of warm reflected light
	float under = 1.0 - smoothstep(6.0, 26.0, depth);
	c *= 1.0 - under * 0.42;
	// edges: R above 0.5 is light (open left side), below is shade (open right, open bottom)
	float l = shape.r - 0.5;
	c = l > 0.0 ? mix(c, c * lit_colour * 1.45, l * 1.6) : c * (1.0 + l * 1.7);
	c = mix(c, min(c * 1.35 + rim_colour * 0.12, vec3(1.0)), shape.b * 0.55);
	c = mix(c, outline_colour, shape.g * 0.92);
	COLOR = vec4(c, shape.a);
}

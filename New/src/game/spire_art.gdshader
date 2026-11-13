shader_type canvas_item;
// Blind round 13 ("the rock pillars are plain smooth-gradient posts with a green cap, identical in profile, far cheaper
// than the richly drawn plain behind them"): a stack of rock standing in the river is a painted pinnacle (spires.png,
// three of them: TerrainView), drawn here: moss creeping down from under its grass mat and the mat's shade on its cap
// rock, the light falling off a little down it; its foot wet at the waterline, murky under it, then gone, foam
// lapping round it (as spire.gdshader does for the other stacks).

uniform float top = 0.0;  // level y of its top
uniform float height = 400.0;  // units: from its top to its picture's foot
uniform float mid_x = 0.0;  // level x of its cap's middle
uniform float water_y = -1.0;  // units from its top to the waterline (< 0: standing on the ground)
uniform float fade = 0.0;  // units over which its foot fades out (over a pit; 0: none)
uniform float seed = 1.0;

varying vec2 at;  // where it is drawn (level units)
varying vec4 drawn;  // the colour it is drawn with (COLOR in fragment() has the texture in it)

void vertex() {
	at = VERTEX;
	drawn = COLOR;
}

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 c = t.rgb;
	float a = t.a;
	float y = at.y - top;
	float down = clamp(y / max(height, 1.0), 0.0, 1.0);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	// each its own stone: a little redder, paler or rosier than the next
	float st = hash(seed * 13.3);
	c *= st < 0.33 ? vec3(1.04, 0.95, 0.9) : (st < 0.66 ? vec3(0.97, 0.96, 1.0) : vec3(1.02, 0.93, 0.95));
	// moss: creeping down from under the grass mat in a few tongues (the painted rock shows through it)
	float tongue = 13.0 + 16.0 * pow(noise(at.x * 0.13 + seed * 7.0), 2.0) + 30.0 * pow(noise(at.x * 0.21 + seed), 5.0);
	float moss = 1.0 - smoothstep(tongue - 1.5, tongue + 1.5, y);
	vec3 moss_c = mix(vec3(0.25, 0.35, 0.12), vec3(0.42, 0.54, 0.18), smoothstep(0.35, 0.75, lum));
	c = mix(c, moss_c * (0.6 + 0.6 * lum), moss * 0.82);
	// the mat's shade on the cap rock, under its blades
	c *= 1.0 - 0.45 * (1.0 - smoothstep(7.0, 15.0, y)) * (1.0 - smoothstep(14.0, 24.0, abs(at.x - mid_x)));
	// the light falls off down it, cooler toward its foot
	c *= mix(1.04, 0.84, smoothstep(0.1, 1.0, down));
	c = mix(c, c * vec3(0.9, 0.88, 1.0), smoothstep(0.4, 1.0, down) * 0.45);
	if (fade > 0.0) {
		a *= 1.0 - smoothstep(height - fade, height, y);
	}
	if (water_y > 0.0) {
		float surface = water_y + sin(at.x * 0.045 + TIME * 1.7) * 1.6 + sin(at.x * 0.13 - TIME * 2.6) * 0.8;
		float d = y - surface;
		c *= mix(1.0, 0.66, smoothstep(-9.0, -1.0, d));  // (wet at the waterline)
		// (the water's own colours, as water_front.gdshader tints the cell it stands in: the two agree)
		vec3 murk = mix(vec3(0.1, 0.36, 0.4), vec3(0.02, 0.1, 0.24), clamp((d - 3.0) / 46.0, 0.0, 1.0));
		c = mix(c, murk, smoothstep(0.0, 5.0, d) * 0.92);
		a *= 1.0 - smoothstep(3.0, 20.0, d);
		float lap = (1.0 - smoothstep(0.0, 2.6, abs(d - 0.6))) * (0.65 + 0.35 * sin(at.x * 0.9 + TIME * 3.1));
		c = mix(c, vec3(0.97, 1.0, 1.0), lap * 0.9);
	}
	COLOR = vec4(c * drawn.rgb, a * drawn.a);
}

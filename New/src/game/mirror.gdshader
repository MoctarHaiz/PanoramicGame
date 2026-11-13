shader_type canvas_item;
// The landforms mirrored in the river beyond the first ridge (SavannaView._draw_mirror: they are drawn again upside
// down under its far waterline, squashed: the water is seen from above). A mirror image on moving water: each row of
// ripples slides its slice of the picture a little sideways and leaves gaps of sky between the slices; it takes the
// water's colour, and dies away toward the viewer, where the water is looked into.

uniform float top = 478.0;  // play y of the river's far waterline
uniform float squash = 0.42;  // the mirror image's height over the landform's
uniform float slide = 0.0;  // how far the river's layer has scrolled (units): the ripples are the water's
uniform vec4 water : source_color = vec4(0.72, 0.6, 0.86, 1.0);
uniform float strength = 0.62;

varying vec4 drawn;
varying vec2 at;

void vertex() {
	drawn = COLOR;
	at = VERTEX;  // (as the landform stands, before it is turned over)
}

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
	float d = (top - at.y) * squash;  // units under the waterline
	float x = at.x + slide;
	float wr = log(max(d, 1.5) / 1.5) / log(1.3);  // (the river's rows: river.gdshader)
	float wk = floor(wr);
	float shift = (noise(vec2(wk * 3.7, TIME * 0.3 + x * 0.003)) - 0.5) * (3.0 + wk * 0.9);
	vec4 t = texture(TEXTURE, UV + vec2(shift * TEXTURE_PIXEL_SIZE.x, 0.0));
	float gap = smoothstep(0.52, 0.62, noise(vec2(x * 0.06 / (1.0 + wk * 0.3) - TIME * 0.12 + wk * 5.1, wk * 2.3)));
	float a = t.a * strength * (1.0 - gap * 0.8) * smoothstep(3.0, 9.0, d) * (1.0 - smoothstep(58.0, 96.0, d));
	vec3 c = mix(t.rgb * vec3(0.84, 0.74, 0.92), water.rgb, 0.38);
	COLOR = vec4(c * drawn.rgb, a * drawn.a);
}

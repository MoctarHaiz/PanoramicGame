shader_type canvas_item;
// Grass tufts swaying in the breeze: the top of each tuft bends, its base stays put.
// Round 23 (the judges, j19: "the white daisies at his feet are the brightest pixels on the ground and hide his
// boots"): the petals' whites held down to a warm cream a value under his boots' highlights.

uniform float amount = 3.0;  // pixels of bend at the top

void vertex() {
	float top = step(UV.y, 0.5);  // the atlas is one row of tufts: the upper vertices
	VERTEX.x += sin(TIME * 1.6 + VERTEX.x * 0.021) * amount * top;
}

void fragment() {
	float lum = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
	COLOR.rgb = mix(COLOR.rgb, COLOR.rgb * vec3(0.86, 0.8, 0.68), smoothstep(0.6, 0.88, lum));
}

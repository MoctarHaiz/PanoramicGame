shader_type canvas_item;
// Grass tufts swaying in the breeze: the top of each tuft bends, its base stays put.

uniform float amount = 3.0;  // pixels of bend at the top

void vertex() {
	float top = step(UV.y, 0.5);  // the atlas is one row of tufts: the upper vertices
	VERTEX.x += sin(TIME * 1.6 + VERTEX.x * 0.021) * amount * top;
}

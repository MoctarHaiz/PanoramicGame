class_name GemPlay
extends Control
## The menu PLAY's emerald (UI r22, the judges of j18: "a stock glossy green pill" against the gritty key
## art): the go colour as a cut gem set in the bronze: a dark socket and a bronze bezel round it, an
## octagonal emerald, its facets lit from the top left (light above, deep green below), a flat table in its
## middle with the play sign cut into it in cream, a glint on its upper left.

const INK := Color("1e0c02")


func _init(side: float) -> void:
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


## The eight corners of an octagon of radius `r` round `c` (a flat side on top).
static func _octagon(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(c + Vector2.from_angle(-PI / 2 + PI / 8 + i * PI / 4) * r)
	return pts


func _draw() -> void:
	var ci := get_canvas_item()
	var c := size / 2
	var r := minf(size.x, size.y) / 2 - 2.0
	GlossStyle.fill_disc(ci, c + Vector2(0, 2.5), r + 2.0, Color(0.1, 0.03, 0.0, 0.45))  # its socket's shade
	GlossStyle.fill_disc(ci, c, r + 1.5, INK)
	GlossStyle.fill_disc(ci, c, r, Color("8a5218"))  # the bezel, bronze, lit at its top
	GlossStyle.fill_disc(ci, c + Vector2(0, r * 0.06), r * 0.9, Color("4a2408"))
	var g := r * 0.84
	draw_colored_polygon(_octagon(c, g + 1.8), INK)
	var outer := _octagon(c, g)
	var table := _octagon(c, g * 0.56)
	for i in 8:  # the facets round the table, each lit by where it faces (the light from the top left)
		var a := -PI / 2 + PI / 4 + i * PI / 4  # the facet's middle direction
		var lit := clampf(0.5 + 0.5 * Vector2.from_angle(a).dot(Vector2(-0.55, -0.83)), 0.0, 1.0)
		var col := Color("0c5a26").lerp(Color("9cf0a4"), lit * lit)
		draw_colored_polygon(PackedVector2Array([outer[i], outer[(i + 1) % 8], table[(i + 1) % 8], table[i]]), col)
	var tc := PackedColorArray()
	for p in table:  # the table: bright green, lighter at its top
		tc.append(Color("5ee07a").lerp(Color("24a24a"), clampf((p.y - (c.y - g * 0.56)) / (g * 1.12), 0.0, 1.0)))
	draw_polygon(table, tc)
	# the play sign cut into the table: cream in an ink line, its point to the right
	var k := g * 0.6
	var tri := PackedVector2Array([c + Vector2(-0.34, -0.5) * k, c + Vector2(0.56, 0.0) * k, c + Vector2(-0.34, 0.5) * k])
	var mid := (tri[0] + tri[1] + tri[2]) / 3.0
	var fat := PackedVector2Array()
	for p in tri:
		fat.append(mid + (p - mid) * 1.42)
	draw_colored_polygon(fat, INK)
	draw_colored_polygon(tri, Color("fff8e4"))
	# a glint on its upper left
	var at := c + Vector2(-g * 0.42, -g * 0.46)
	GlossStyle.fill_disc(ci, at, g * 0.13, Color(1, 1, 1, 0.85))
	GlossStyle.fill_disc(ci, at + Vector2(g * 0.2, -g * 0.02), g * 0.05, Color(1, 1, 1, 0.6))

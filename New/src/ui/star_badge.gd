class_name StarBadge
extends Control
## A star of the results and the best run, flat and inked (the user, 2026-11-13, of three panel styles shown: "C", no
## box, ink brush): a fat five-point star in one flat gold with an ink line round it and one cel step (its lower right
## in a deeper gold, its upper left edge lit by a thin pale line): no gloss, no glow, no sparkle. A star not yet
## earned is a dark socket of the same shape: the dark plates' face in an ink line, a thin gold line inside it
## (blind round 11: "the unlit star is a hairline": it was a thin outline alone; blind round 18, on the menu's dark
## plate: "the empty star a thin wireframe": its face a dull bronze, a star's own body with its light out).
## (Before: a glossy bevelled star in a warm glow, sparkles twinkling round it.)

const INK := Color("140607")
const GOLD := Color("ffc928")
const GOLD_DEEP := Color("f0940e")
const GOLD_PALE := Color("fff0a0")
const SOCKET := Color("6a4a26")  ## a star not yet earned: a dull bronze
const SOCKET_DEEP := Color("4c331a")

var lit := true:
	set(value):
		lit = value
		queue_redraw()


func _init(side: float, is_lit := true) -> void:
	lit = is_lit
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	pivot_offset = size / 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The ten corners of a star of outer radius `r` around `c`.
static func points(c: Vector2, r: float, inner := 0.52) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * inner))
	return pts


func _draw() -> void:
	var side := minf(size.x, size.y)
	var o := maxf(side * 0.05, 2.0)  # the ink line
	var c := size / 2 + Vector2(0, side * 0.04)
	var r := side * 0.5 - o
	if not lit:  # not yet earned: a dark socket in a gold line (a plate that waits, as the kit's dark plates do)
		var rim := points(c, r + o * 0.6, 0.53)
		draw_colored_polygon(rim, INK)
		var socket := points(c, r - o * 0.4, 0.5)
		draw_colored_polygon(socket, SOCKET)
		var under := PackedVector2Array([Vector2(-4.0, c.y + r * 0.1), Vector2(size.x + 4.0, c.y + r * 0.1),
				Vector2(size.x + 4.0, size.y + 4.0), Vector2(-4.0, size.y + 4.0)])
		for part in Geometry2D.intersect_polygons(socket, under):
			if not Geometry2D.triangulate_polygon(part).is_empty():
				draw_colored_polygon(part, SOCKET_DEEP)
		var line := points(c, r - o * 1.2, 0.5)
		line.append(line[0])
		draw_polyline(line, Color(GOLD, 0.5), maxf(o * 0.5, 1.5), true)
		return
	var outer := points(c, r + o * 0.6, 0.53)
	draw_colored_polygon(outer, INK)
	outer.append(outer[0])
	draw_polyline(outer, INK, 1.0, true)
	var face := points(c, r - o * 0.4, 0.5)
	draw_colored_polygon(face, GOLD)
	# one cel step: what lies under a line falling to the left through its middle is in a deeper gold
	var d := Vector2(-0.5, 0.86)  # along the line
	var n := Vector2(0.86, 0.5)  # to its shaded side
	var at := c + n * r * 0.16
	var half := PackedVector2Array([at - d * r * 2.0, at + d * r * 2.0, at + d * r * 2.0 + n * r * 2.0, at - d * r * 2.0 + n * r * 2.0])
	for part in Geometry2D.intersect_polygons(face, half):
		if not Geometry2D.triangulate_polygon(part).is_empty():
			draw_colored_polygon(part, GOLD_DEEP)
	var edge := points(c, r - o * 1.5, 0.5)  # a thin pale line inside its upper left edge
	draw_polyline(PackedVector2Array([edge[7], edge[8], edge[9], edge[0]]), Color(GOLD_PALE, 0.9), maxf(o * 0.45, 1.5), true)

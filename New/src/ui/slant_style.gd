class_name SlantStyle
extends StyleBox
## A flat, inked plate leaning to the right: the menu's PLAY (the user, 2026-11-13, of three interfaces shown:
## "the A, inked gold, but with the RED play in the C, bold action"; six blind judges on the lacquered turquoise
## pill before it: "a casual puzzle-game kit glued onto an action illustration").
##
##   a hard shadow down and to the right (flat, no blur: the plate stands off the painting)
##   an ink line all round, the face in one flat colour with a darker lower band (a cel shade), a thin pale line
##   a little inside its edge
## Pressed, the plate sits down on its shadow. No gloss, no gradient, no rounded corner.
## The quiet plates beside it (Ui.plate_button: Home, Share, the pause's tiles, the settings' help) are the same shape
## with no shadow (depth 0) and no cel band (shade = face): dark ink, a thin gold line just inside its edge.

var face := Color("d9261c")  ## the hero's scarf red
var shade := Color("b0180f")  ## its lower band
var ink := Color("140607")
var line := Color(1.0, 0.96, 0.9, 0.92)
var slant := 0.3  ## how far its top leans right of its foot, a share of its height
var ink_width := 6.0
var line_inset := 7.0  ## the pale line, this far inside the ink
var line_width := 2.5
var shade_from := 0.6  ## the lower band starts this far down the face
var depth := 10.0  ## its shadow: this far under it (and 0.6 of it to the right)
var pressed := false


func _draw(to: RID, rect: Rect2) -> void:
	var size := rect.size - Vector2(depth * 0.6, depth)
	if not pressed and depth > 0.0:
		_fill(to, _plate(Rect2(rect.position + Vector2(depth * 0.6, depth), size)), Color(0.06, 0.02, 0.03, 0.6))
	var at := rect.position + (Vector2(depth * 0.3, depth * 0.5) if pressed else Vector2.ZERO)
	var outer := _plate(Rect2(at, size))
	_fill(to, outer, ink)
	var inner := _inset(outer, ink_width)
	if inner.is_empty():
		return
	_fill(to, inner, face)
	var y := at.y + ink_width + (size.y - ink_width * 2.0) * shade_from
	var band := PackedVector2Array([Vector2(at.x - 4.0, y), Vector2(at.x + size.x + 4.0, y),
			Vector2(at.x + size.x + 4.0, at.y + size.y + 4.0), Vector2(at.x - 4.0, at.y + size.y + 4.0)])
	if shade != face:
		for part: PackedVector2Array in Geometry2D.intersect_polygons(inner, band):
			_fill(to, part, shade)
	var ring := _inset(outer, ink_width + line_inset)
	if not ring.is_empty() and line.a > 0.0:
		ring.append(ring[0])
		RenderingServer.canvas_item_add_polyline(to, ring, PackedColorArray([line]), line_width, true)


## The plate standing in `r`: its top edge leaning right of its foot.
func _plate(r: Rect2) -> PackedVector2Array:
	var s := r.size.y * slant
	return PackedVector2Array([r.position + Vector2(s, 0.0), r.position + Vector2(r.size.x, 0.0),
			r.position + Vector2(r.size.x - s, r.size.y), r.position + Vector2(0.0, r.size.y)])


func _inset(points: PackedVector2Array, by: float) -> PackedVector2Array:
	var parts := Geometry2D.offset_polygon(points, -by, Geometry2D.JOIN_MITER)
	return parts[0] if parts.size() > 0 else PackedVector2Array()


## A polygon in one colour, its edge smoothed by a thin line of the same colour (polygons are not antialiased).
func _fill(to: RID, points: PackedVector2Array, colour: Color) -> void:
	RenderingServer.canvas_item_add_polygon(to, points, PackedColorArray([colour]))
	var edge := points.duplicate()
	edge.append(points[0])
	RenderingServer.canvas_item_add_polyline(to, edge, PackedColorArray([colour]), 1.0, true)


func _get_minimum_size() -> Vector2:
	return Vector2(depth * 4.0, depth * 2.0)

class_name InsetStyle
extends StyleBox
## A groove cut into a panel (the results' count, the way-home bars): the panel's lit lip along its
## foot, a dark outline, a face darkest under its upper edge and lighter towards its foot, a deep
## shade cast by the upper edge into it, and a little light caught along its bottom inside. It reads
## as sunk into the parchment, not as a slab laid on it.

var top := Color("2a0f05")  ## the face under its upper edge
var bottom := Color("5e3016")  ## the face at its foot
var outline := Color("2e0d04")
var outline_width := 3.0
var radius := 20.0
var shade := 0.7  ## the upper edge's shade inside (alpha)
var lip := Color(1, 0.96, 0.85, 0.85)  ## the panel's lit edge under the groove


func _init(corner := 20.0) -> void:
	radius = corner
	set_content_margin_all(14)
	content_margin_left = 24
	content_margin_right = 24


func _draw(ci: RID, rect: Rect2) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) / 2)
	GlossStyle.fill_rounded(ci, Rect2(rect.position + Vector2(0, 3.0), rect.size), r, lip, lip)
	GlossStyle.fill_rounded(ci, rect, r, outline, outline)
	var face := rect.grow(-outline_width)
	var fr := maxf(r - outline_width, 0.0)
	GlossStyle.fill_rounded(ci, face, fr, top, bottom)
	var deep := minf(face.size.y * 0.45, 30.0)  # the upper edge's shade, fading down into the groove
	GlossStyle.fill_clipped(ci, face, fr, Rect2(face.position, Vector2(face.size.x, deep)),
			Color(0, 0, 0, shade), Color(0, 0, 0, 0))
	GlossStyle.fill_clipped(ci, face, fr, Rect2(face.position.x, face.end.y - 5.0, face.size.x, 5.0),
			Color(1, 0.85, 0.6, 0.0), Color(1, 0.85, 0.6, 0.2))  # light caught at its foot

class_name BoldIcon
extends Control
## An icon drawn like the display text around it: a fill colour, a thick dark outline and a little
## extruded depth below (copies of the white icon around a circle, then the icon on top).

const DIRECTIONS := 16

var texture: Texture2D
var fill := Color.WHITE
var outline := Color("2a1782")
var outline_width := 5.0
var depth := 4.0


func _init(icon_texture: Texture2D, size_px: float, fill_colour := Color.WHITE, outline_colour := Color("2a1782"),
		width := -1.0) -> void:
	texture = icon_texture
	fill = fill_colour
	outline = outline_colour
	outline_width = width if width >= 0 else roundf(size_px * 0.09)
	depth = roundf(outline_width * 0.8)
	custom_minimum_size = Vector2(size_px, size_px) + Vector2(outline_width * 2, outline_width * 2 + depth)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var side := minf(size.x - outline_width * 2, size.y - outline_width * 2 - depth)
	var at := Vector2((size.x - side) / 2, (size.y - depth - side) / 2)
	var rect := Rect2(at, Vector2(side, side))
	if outline.a > 0 and outline_width > 0:
		for d in [depth, 0.0]:  # the depth under the outline, then the outline
			for i in DIRECTIONS:
				var o := Vector2.from_angle(TAU * i / DIRECTIONS) * outline_width
				draw_texture_rect(texture, Rect2(rect.position + o + Vector2(0, d), rect.size), false,
						outline.darkened(0.2) if d > 0 else outline)
	draw_texture_rect(texture, rect, false, fill)

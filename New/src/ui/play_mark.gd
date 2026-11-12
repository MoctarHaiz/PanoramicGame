class_name PlayMark
extends Control
## The play triangle on the red plate (Ui.cta_button): flat white, inked, leaning as the plate and its word do.

const SLANT := 0.3  ## its top leans this far right of its foot, a share of its height (SlantStyle.slant)
const INK := Color("140607")

var _h := 40.0


func _init(height := 40.0) -> void:
	_h = height
	custom_minimum_size = Vector2(height * 0.86, height)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	# (drawn upright, then leant: x moves right by SLANT of how high the point is over its foot)
	draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(-SLANT, 1.0), Vector2(_h * SLANT, 0.0)))
	var points := PackedVector2Array([Vector2(0.0, 0.0), Vector2(_h * 0.7, _h * 0.5), Vector2(0.0, _h)])
	var edge := points.duplicate()
	edge.append(points[0])
	draw_polyline(edge, INK, maxf(_h * 0.09, 2.0), true)
	draw_colored_polygon(points, Color.WHITE)
	draw_polyline(edge, Color.WHITE, 1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)

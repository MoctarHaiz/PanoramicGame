class_name Rays
extends Control
## Soft light rays from the centre, for celebrations (new best score, best score medal).

var count := 14
var colour := Color(1, 0.95, 0.8, 0.32)


func _init(diameter: float, ray_colour := Color(1, 0.95, 0.8, 0.32), rays := 14) -> void:
	colour = ray_colour
	count = rays
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size
	pivot_offset = size / 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## All the rays in one triangle array: one draw call however many rays (a polygon each cost one).
func _draw() -> void:
	var c := size / 2
	var r := size.x / 2
	var w := TAU / count * 0.28
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	for i in count:
		var a := i * TAU / count
		indices.append_array([points.size(), points.size() + 1, points.size() + 2])
		points.append_array([c, c + Vector2.from_angle(a - w) * r, c + Vector2.from_angle(a + w) * r])
		colours.append_array([colour, Color(colour, 0), Color(colour, 0)])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)

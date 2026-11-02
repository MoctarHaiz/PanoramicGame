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


func _draw() -> void:
	var c := size / 2
	var r := size.x / 2
	var w := TAU / count * 0.28
	for i in count:
		var a := i * TAU / count
		draw_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - w) * r, c + Vector2.from_angle(a + w) * r]),
				PackedColorArray([colour, Color(colour, 0), Color(colour, 0)]))

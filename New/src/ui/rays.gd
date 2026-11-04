class_name Rays
extends Control
## Soft light rays from the centre, for celebrations (new best score, best score medal). `soft`:
## each ray fades to its two sides and out along its length, wide and narrower ones in turn, each
## overlapping the next: shafts of light, not the hard stripes of a sunburst wallpaper.

var count := 14
var colour := Color(1, 0.95, 0.8, 0.32)
var soft := false


func _init(diameter: float, ray_colour := Color(1, 0.95, 0.8, 0.32), rays := 14, soft_rays := false) -> void:
	colour = ray_colour
	count = rays
	soft = soft_rays
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
	var clear := Color(colour, 0)
	for i in count:
		var a := i * TAU / count
		var n := points.size()
		if not soft:
			indices.append_array([n, n + 1, n + 2])
			points.append_array([c, c + Vector2.from_angle(a - w) * r, c + Vector2.from_angle(a + w) * r])
			colours.append_array([colour, clear, clear])
			continue
		# the centre, then at half the reach its two clear sides and its lit middle, then its clear tips
		var half := w * (1.0 if i % 2 == 0 else 0.75) * 2.4  # neighbours overlap: no dark gaps between them
		points.append_array([c, c + Vector2.from_angle(a - half) * r * 0.5, c + Vector2.from_angle(a) * r * 0.5,
				c + Vector2.from_angle(a + half) * r * 0.5, c + Vector2.from_angle(a - half) * r,
				c + Vector2.from_angle(a) * r, c + Vector2.from_angle(a + half) * r])
		colours.append_array([colour, clear, Color(colour, colour.a * 0.55), clear, clear, clear, clear])
		indices.append_array([n, n + 1, n + 2, n, n + 2, n + 3, n + 1, n + 4, n + 5, n + 1, n + 5, n + 2,
				n + 2, n + 5, n + 6, n + 2, n + 6, n + 3])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)

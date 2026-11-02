class_name Motes
extends Control
## Specks of warm dust and pollen drifting up through the evening light, each swaying and
## twinkling on its own rhythm (the menu, the results).

var count := 34
var colour := Color(1.0, 0.86, 0.55)
var _motes: Array[Vector4] = []  # x (0..1), phase, speed, size
var _t := 0.0


func _init(motes := 34, mote_colour := Color(1.0, 0.86, 0.55)) -> void:
	count = motes
	colour = mote_colour
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in count:
		_motes.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.03, 0.08), rng.randf_range(1.5, 4.5)))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for m in _motes:
		var rise := fposmod(m.y + _t * m.z, 1.0)  # bottom to top, then again
		var x := m.x * size.x + sin(_t * 0.8 + m.y * 20.0) * 18.0
		var y := size.y * (1.05 - rise * 1.1)
		var a := sin(rise * PI) * (0.55 + 0.45 * sin(_t * 3.0 + m.x * 30.0))
		draw_circle(Vector2(x, y), m.w * 2.4, Color(colour, 0.08 * a))
		draw_circle(Vector2(x, y), m.w, Color(colour, 0.55 * a))

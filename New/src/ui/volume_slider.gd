class_name VolumeSlider
extends Control
## A volume on the inked panels (the user, 2026-11-13: "C", no box, ink brush): a cream line, bright up to the value
## and faint after it, a small tick at each step still to go, and an angular red handle in an ink line (the red
## plate's colours, a spear point's shape) to drag (or tap the line); no value written beside it (UI r23, the judges
## of j19: "the redundant 100 % labels"). Steps of 10 %; at 0 the sound is off. A tick plays at each step while
## dragging. (Before: a thick sunk groove filled with gold, a round gold-rimmed knob.)

signal changed(value: float)

const INK := Color("140607")
const STEPS := 10

var value := 1.0
var _dragging := false


func _init(start := 1.0) -> void:
	value = clampf(start, 0.0, 1.0)
	custom_minimum_size = Vector2(250, 58)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _has_point(point: Vector2) -> bool:  # a thumb-sized area around the groove
	return Rect2(Vector2(-12, -14), size + Vector2(24, 28)).has_point(point)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_set_from(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from(event.position.x)
		accept_event()


## The knob's radius and the groove's two ends (the knob's centre at 0 % and at 100 %).
func _knob_r() -> float:
	return size.y * 0.4


func _ends() -> Vector2:
	var r := _knob_r()
	return Vector2(r, size.x - r)


func _set_from(x: float) -> void:
	var e := _ends()
	var v := roundf(clampf((x - e.x) / maxf(e.y - e.x, 1.0), 0.0, 1.0) * STEPS) / STEPS
	if is_equal_approx(v, value):
		return
	value = v
	queue_redraw()
	Audio.play_sfx(&"tick", 0.8 + value * 0.6, 0.6)
	Haptics.tap()
	changed.emit(value)


func _draw() -> void:
	var e := _ends()
	var mid := size.y / 2
	var cx := lerpf(e.x, e.y, value)
	var cream := Ui.BONE
	draw_line(Vector2(e.x, mid), Vector2(e.y, mid), Color(cream, 0.3), 4.0, true)  # the way still to go
	for i in range(1, STEPS + 1):
		var x := lerpf(e.x, e.y, float(i) / STEPS)
		if x > cx + _knob_r():
			draw_line(Vector2(x, mid - 5.0), Vector2(x, mid + 5.0), Color(cream, 0.4), 2.0, true)
	if value > 0.0:
		draw_line(Vector2(e.x, mid), Vector2(cx, mid), cream, 5.0, true)
		draw_circle(Vector2(e.x, mid), 2.5, cream, true, -1, true)
	# the handle: a spear point, its tip to the right
	var r := _knob_r()
	var c := Vector2(cx, mid)
	var head := PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.5), c + Vector2(r * 0.1, -r * 0.92), c + Vector2(r * 1.05, 0.0),
			c + Vector2(r * 0.1, r * 0.92), c + Vector2(-r * 0.95, r * 0.5), c + Vector2(-r * 0.55, 0.0)])
	for part in Geometry2D.offset_polygon(head, 3.0, Geometry2D.JOIN_MITER):
		draw_colored_polygon(part, INK)
		var edge := part.duplicate()
		edge.append(part[0])
		draw_polyline(edge, INK, 1.0, true)
	draw_colored_polygon(head, Ui.SCARF_RED)
	var low := PackedVector2Array([c + Vector2(-r * 0.55, 0.0), c + Vector2(r * 1.05, 0.0), c + Vector2(r * 0.1, r * 0.92),
			c + Vector2(-r * 0.95, r * 0.5)])
	draw_colored_polygon(low, Color("b0180f"))  # its lower half in shade (one cel step)

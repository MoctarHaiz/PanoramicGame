class_name VolumeSlider
extends Control
## A volume in the interface's candy style: a groove sunk into the panel, filled with gold up to
## the value, and a white candy knob in a gold ring to drag (or tap the groove). Steps of 10 %; at
## 0 the sound is off. A tick plays at each step while dragging.

signal changed(value: float)

const INK := Color("4a1e04")
const STEPS := 10

var value := 1.0
var _dragging := false


func _init(start := 1.0) -> void:
	value = clampf(start, 0.0, 1.0)
	custom_minimum_size = Vector2(250, 46)
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


func _set_from(x: float) -> void:
	var r := size.y / 2
	var v := roundf(clampf((x - r) / maxf(size.x - r * 2, 1.0), 0.0, 1.0) * STEPS) / STEPS
	if is_equal_approx(v, value):
		return
	value = v
	queue_redraw()
	Audio.play_sfx(&"tick", 0.8 + value * 0.6, 0.6)
	Haptics.tap()
	changed.emit(value)


func _draw() -> void:
	var r := size.y / 2
	var ci := get_canvas_item()
	var groove := Rect2(Vector2(0, r * 0.62), Vector2(size.x, r * 0.76))
	var gr := groove.size.y / 2
	GlossStyle.fill_rounded(ci, groove.grow(1.0), gr + 1.0, Color(1, 1, 0.95, 0.7), Color(1, 1, 0.95, 0.7))
	GlossStyle.fill_rounded(ci, groove, gr, INK, INK)
	var inside := groove.grow(-3.5)
	GlossStyle.fill_rounded(ci, inside, gr - 3.5, ToggleSwitch.TRACK_OFF_DEEP, ToggleSwitch.TRACK_OFF)
	var cx := lerpf(r, size.x - r, value)
	if value > 0.0:
		var fill := Rect2(inside.position, Vector2(cx - inside.position.x, inside.size.y))
		GlossStyle.fill_rounded(ci, fill, gr - 3.5, Color("ffe066"), Color("e8860e"))
		GlossStyle.fill_rounded(ci, Rect2(fill.position + Vector2(5, 2), Vector2(maxf(fill.size.x - 10, 0), 4)), 2.0,
				Color(1, 1, 0.9, 0.75), Color(1, 1, 0.9, 0.5))
	var knob_r := r - 2.0
	var centre := Vector2(cx, r)
	draw_circle(centre + Vector2(0, 4), knob_r, Color(Ui.NIGHT, 0.3), true, -1, true)
	draw_circle(centre, knob_r, INK, true, -1, true)
	draw_circle(centre, knob_r - 3.0, Color("e0961e"), true, -1, true)
	draw_circle(centre - Vector2(0, 1.5), knob_r - 4.5, Color("ffe9a0"), true, -1, true)
	draw_circle(centre, knob_r - 8.0, Color("d6c0a0"), true, -1, true)  # a glossy cream ball: shaded below,
	draw_circle(centre - Vector2(0, 2.5), knob_r - 10.0, Color("fffaf0"), true, -1, true)  # lit above
	draw_set_transform(centre - Vector2(knob_r * 0.12, knob_r * 0.34), -0.35, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, knob_r * 0.42, Color(1, 1, 1, 0.95), true, -1, true)
	draw_set_transform(Vector2.ZERO)

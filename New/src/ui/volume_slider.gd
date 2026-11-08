class_name VolumeSlider
extends Control
## A volume that reads as a slider, not a switch (j15: "sliders look like toggles, 100% collides with
## the knob"): a slim groove sunk into the panel with a notch at each step, filled with gold up to the
## value (a soft light along it), a round gold-rimmed knob bigger than the groove, a grip cut in it,
## to drag (or tap the groove); the value written beside it, outside the groove ("80%", never under
## the knob). Steps of 10 %; at 0 the sound is off. A tick plays at each step while dragging.

signal changed(value: float)

const INK := Color("4a1e04")
const STEPS := 10
const VALUE_W := 70.0  ## the value's room at the right end (outside the groove)

var value := 1.0
var _dragging := false


func _init(start := 1.0) -> void:
	value = clampf(start, 0.0, 1.0)
	custom_minimum_size = Vector2(250, 54)
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
	return size.y * 0.42


func _ends() -> Vector2:
	var r := _knob_r()
	return Vector2(r, size.x - VALUE_W - r)


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
	var ci := get_canvas_item()
	var e := _ends()
	var mid := size.y / 2
	var gh := maxf(roundf(size.y * 0.26), 10.0)  # a slim groove: the knob stands well over it
	var groove := Rect2(Vector2(e.x - gh * 0.5, mid - gh / 2), Vector2(e.y - e.x + gh, gh))
	var gr := gh / 2
	GlossStyle.fill_rounded(ci, Rect2(groove.position + Vector2(0, 2), groove.size).grow(1.5), gr + 1.5,
			Color(1, 1, 0.95, 0.8), Color(1, 1, 0.95, 0.8))  # the panel's lit lip under it
	GlossStyle.fill_rounded(ci, groove.grow(1.5), gr + 1.5, INK, INK)
	GlossStyle.fill_rounded(ci, groove, gr, Color("5a3a26"), Color("8a6a50"))  # sunk: dark under its upper edge
	var cx := lerpf(e.x, e.y, value)
	for i in range(1, STEPS):  # a notch at each step, on the way still to go
		var x := lerpf(e.x, e.y, float(i) / STEPS)
		if x > cx + _knob_r():
			draw_circle(Vector2(x, mid), 2.2, Color(1, 0.92, 0.78, 0.55), true, -1, true)
	if value > 0.0:
		var fill := Rect2(groove.position, Vector2(cx - groove.position.x, groove.size.y)).grow(-1.0)
		GlossStyle.fill_rounded(ci, fill.grow(3.0), gr + 3.0, Color(1, 0.8, 0.3, 0.22), Color(1, 0.8, 0.3, 0.22))  # its glow
		GlossStyle.fill_rounded(ci, fill, gr - 1.0, Color("ffe066"), Color("e8860e"))
		GlossStyle.fill_rounded(ci, Rect2(fill.position + Vector2(gr * 0.6, 1.5), Vector2(maxf(fill.size.x - gr * 1.2, 0), 2.5)), 1.2,
				Color(1, 1, 0.92, 0.8), Color(1, 1, 0.92, 0.8))
	var knob_r := _knob_r()
	var centre := Vector2(cx, mid)
	draw_circle(centre + Vector2(0, 3.5), knob_r, Color(Ui.NIGHT, 0.32), true, -1, true)
	draw_circle(centre, knob_r, INK, true, -1, true)
	draw_circle(centre, knob_r - 2.5, Color("d8781a"), true, -1, true)  # the gold rim, lit at its top
	draw_circle(centre - Vector2(0, 1.2), knob_r - 3.5, Color("ffd45a"), true, -1, true)
	draw_circle(centre + Vector2(0, 1.0), knob_r - 7.5, Color("e8a83a"), true, -1, true)  # its face, a shallow dome
	draw_circle(centre, knob_r - 8.5, Color("fff0c0"), true, -1, true)
	for dx: float in [-3.5, 3.5]:  # the grip: two cuts across it
		draw_line(centre + Vector2(dx, -knob_r * 0.32), centre + Vector2(dx, knob_r * 0.32), Color("b06a1c"), 2.4, true)
	_value_text()


## The value beside the groove, right-aligned in its own room (never under the knob).
func _value_text() -> void:
	var french := TranslationServer.get_locale().begins_with("fr")
	var words := ("%d %%" if french else "%d%%") % roundi(value * 100.0)
	var font: Font = Ui.font_display
	var px := 24
	var w := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var base := size.y / 2 + px * 0.36
	draw_string(font, Vector2(size.x - VALUE_W + 12.0 + maxf(VALUE_W - 12.0 - w, 0.0) * 0.5, base), words, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
			Color("8a4a14") if value > 0.0 else Color("a08a78"))

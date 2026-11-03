class_name ToggleSwitch
extends Control
## An on/off switch in the interface's candy style: an outlined track sunk into the panel, green
## with a tick when on, dark sand with a cross when off (the state reads without colour too), and
## a white candy knob in a gold ring that slides over with a spring.

signal toggled(on: bool)

const TRACK_OFF := Color("b58a5c")
const TRACK_OFF_DEEP := Color("8a6038")
const INK := Color("4a1e04")

var on := false
var _knob := 0.0  # 0 = off, 1 = on (animated)
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(110, 58)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func set_on(value: bool, animate := false) -> void:
	on = value
	if _tween:
		_tween.kill()
	if animate:
		_tween = create_tween()
		_tween.tween_method(_set_knob, _knob, 1.0 if on else 0.0, 0.22) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_set_knob(1.0 if on else 0.0)


## Flips the switch as if tapped.
func toggle() -> void:
	set_on(not on, true)
	Audio.play_sfx(&"toggle_on" if on else &"toggle_off")
	Haptics.tap()
	toggled.emit(on)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		toggle()
		accept_event()


func _set_knob(v: float) -> void:
	_knob = v
	queue_redraw()


func _draw() -> void:
	var k := clampf(_knob, 0, 1)
	var green := Ui.tone_colours(Ui.Tone.GREEN)
	var r := size.y / 2
	var ow := 4.0
	var rect := Rect2(Vector2.ZERO, size)
	var ci := get_canvas_item()
	# the track: outlined, sunk in (its top in shade), green when on
	GlossStyle.fill_rounded(ci, rect.grow(1.0), r + 1.0, Color(1, 1, 0.95, 0.7), Color(1, 1, 0.95, 0.7))
	GlossStyle.fill_rounded(ci, rect, r, INK, INK)
	var inside := rect.grow(-ow)
	GlossStyle.fill_rounded(ci, inside, r - ow, TRACK_OFF_DEEP.lerp(green.edge, k), TRACK_OFF.lerp(green.bottom, k))
	var lit := Rect2(inside.position + Vector2(0, 6), inside.size - Vector2(0, 6))
	GlossStyle.fill_rounded(ci, lit, r - ow, TRACK_OFF.lerp(green.bottom, k), TRACK_OFF.lerp(green.top, k).lerp(Color.WHITE, 0.1))
	# the state's mark, on the side the knob has left: a tick (on) or a cross (off)
	var mark := Ui.icon_texture("check-bold" if k > 0.5 else "x-bold")
	var ms := size.y * 0.42
	var mx := r * 0.95 if k > 0.5 else size.x - r * 0.95
	draw_texture_rect(mark, Rect2(Vector2(mx - ms / 2, r - ms / 2), Vector2(ms, ms)), false,
			Color(1, 1, 1, 0.95) if k > 0.5 else Color(INK, 0.55))
	# the knob: a white candy ball in a gold ring, its shadow under it
	var knob_r := r - 2.0
	var centre := Vector2(lerpf(r, size.x - r, k), r)
	draw_circle(centre + Vector2(0, 4), knob_r, Color(Ui.NIGHT, 0.3), true, -1, true)
	draw_circle(centre, knob_r, INK, true, -1, true)
	draw_circle(centre, knob_r - 3.0, Color("e0961e"), true, -1, true)
	draw_circle(centre - Vector2(0, 1.5), knob_r - 4.5, Color("ffe9a0"), true, -1, true)
	draw_circle(centre, knob_r - 8.0, Color("d6c0a0"), true, -1, true)  # a glossy cream ball: shaded below,
	draw_circle(centre - Vector2(0, 2.5), knob_r - 10.0, Color("fffaf0"), true, -1, true)  # lit above
	draw_set_transform(centre - Vector2(knob_r * 0.12, knob_r * 0.34), -0.35, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, knob_r * 0.42, Color(1, 1, 1, 0.95), true, -1, true)
	draw_set_transform(Vector2.ZERO)

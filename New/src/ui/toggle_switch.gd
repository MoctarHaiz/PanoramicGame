class_name ToggleSwitch
extends Control
## An on/off switch in the interface's candy style: an outlined track, sunk in when off and green
## when on, and a glossy white knob that slides with a spring.

signal toggled(on: bool)

const TRACK_OFF := Color("dcd6f3")
const TRACK_OFF_DEEP := Color("c4bbe8")

var on := false
var _knob := 0.0  # 0 = off, 1 = on (animated)
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(116, 66)
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
	# The track: outlined, its inside darker at the top (sunk in), green when on.
	var outline: Color = Ui.NIGHT.lerp(green.outline, k)
	var ci := get_canvas_item()
	GlossStyle.fill_rounded(ci, rect, r, outline, outline)
	var inside := rect.grow(-ow)
	GlossStyle.fill_rounded(ci, inside, r - ow, TRACK_OFF_DEEP.lerp(green.edge, k), TRACK_OFF.lerp(green.bottom, k))
	var lit := Rect2(inside.position + Vector2(0, 5), inside.size - Vector2(0, 5))
	GlossStyle.fill_rounded(ci, lit, r - ow, TRACK_OFF.lerp(green.bottom, k), TRACK_OFF.lerp(green.top, k))
	# The knob: a white candy ball with an outline and a shaded underside.
	var knob_r := r - 3.0
	var centre := Vector2(lerpf(r, size.x - r, k), r)
	draw_circle(centre + Vector2(0, 4), knob_r, Color(Ui.NIGHT, 0.25), true, -1, true)
	draw_circle(centre, knob_r, outline, true, -1, true)
	draw_circle(centre, knob_r - ow, Color("cfc6f2"), true, -1, true)
	draw_circle(centre - Vector2(0, 3), knob_r - ow - 1.5, Color.WHITE, true, -1, true)

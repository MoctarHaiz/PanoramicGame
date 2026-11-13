class_name DisplayText
extends Control
## Display text as on the titles and buttons of top mobile games: the display face (Ui.DISPLAY), always in
## capitals, with a gradient fill and a light top edge, a thick dark outline, an extruded depth under it and a soft drop
## shadow, optionally along an arch. Drawn glyph by glyph (display_text.gdshader gives the fill
## its gradient in each letter's own frame), so letters can also pop in one by one (reveal()).
##
## Build it with Ui.display_text() rather than by hand; after changing the look, call refresh().

const SHADER := preload("res://src/ui/display_text.gdshader")
const MARKER := Color(1, 0, 1)  ## the fill is drawn in this colour; the shader paints the gradient
const CAP := 0.859  ## the display face's capital height, as a share of the font size (Ui.DISPLAY_CAP)
const POP_TIME := 0.5  ## seconds for one letter to pop in

var text := "":
	set(value):
		text = value.to_upper()  # the display face is set in capitals
		refresh()
var font_size := 96:
	set(value):
		font_size = value
		refresh()
var font: Font
var fill_top := Color.WHITE
var fill_bottom := Color.WHITE
var outline := Color("2a1782")
var outline_width := -1.0  ## visible thickness; -1: 14 % of the font size
var depth := -1.0  ## extruded thickness under the outline; -1: 7 % of the font size
var depth_colour := Color(0, 0, 0, 0)  ## transparent: the outline's colour, a little darker
var highlight := 0.0  ## a light edge along the top of the letters (0..1 towards white)
var inner_line := Color(0, 0, 0, 0)  ## a second, light outline inside the dark one (alpha 0: none)
var shadow := Color(0.1, 0.05, 0.3, 0.3)  ## soft drop shadow under everything (alpha 0: none)
var arch := 0.0  ## how many px the middle of the line rises above its ends
var tracking := 0.0  ## extra px between letters
var align := HORIZONTAL_ALIGNMENT_CENTER

var _x: PackedFloat32Array = []  # left of each glyph on the straight line
var _w: PackedFloat32Array = []  # advance of each glyph
var _width := 0.0
var _material := ShaderMaterial.new()
var _revealing := false
var _clock := 0.0  # seconds into the pop-in
var _stagger := 0.05


func _init(value := "", size_px := 96) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = Ui.font_display
	_material.shader = SHADER
	material = _material
	font_size = size_px
	text = value
	set_process(false)


## Measures the text again and redraws it (after changing the look).
func refresh() -> void:
	if not font:
		return
	_x.clear()
	_w.clear()
	for i in text.length():
		# The width of the text so far keeps the font's kerning.
		_x.append(font.get_string_size(text.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + tracking * i)
		_w.append(font.get_char_size(text.unicode_at(i), font_size).x)
	_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x \
			+ tracking * maxi(0, text.length() - 1)
	var pad := _ow() + 2.0
	custom_minimum_size = Vector2(ceilf(_width + pad * 2), ceilf(font_size * CAP + pad * 2 + _depth() + absf(arch)))
	_material.set_shader_parameter(&"top_colour", fill_top)
	_material.set_shader_parameter(&"bottom_colour", fill_bottom)
	_material.set_shader_parameter(&"y_top", -font_size * CAP)
	_material.set_shader_parameter(&"y_bottom", 0.0)
	queue_redraw()


## Width of the text itself, without the outline.
func text_width() -> float:
	return _width


## Letters pop in one after the other, with a bounce.
func reveal(delay := 0.0, stagger := 0.05) -> void:
	_stagger = stagger
	_clock = -delay
	_revealing = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()
	if _clock > text.length() * _stagger + POP_TIME:
		_revealing = false
		set_process(false)


func _ow() -> float:
	return outline_width if outline_width >= 0 else roundf(font_size * 0.14)


func _depth() -> float:
	return depth if depth >= 0 else roundf(font_size * 0.07)


## Scale of letter i during the pop-in: 0, a quick overshoot, then 1.
func _pop(i: int) -> float:
	if not _revealing:
		return 1.0
	var u := (_clock - i * _stagger) / POP_TIME
	if u <= 0:
		return 0.0
	if u >= 1:
		return 1.0
	return 1.0 + pow(2.0, -9.0 * u) * sin((u * 9.0 - 0.75) * TAU / 3.0)


func _draw() -> void:
	if text.is_empty() or not font:
		return
	var ow := _ow()
	var d := _depth()
	var left := (size.x - _width) / 2
	if align == HORIZONTAL_ALIGNMENT_LEFT:
		left = ow + 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		left = size.x - ow - 2.0 - _width
	# The baseline: the capitals centred in the box above the depth, the arch rising above them.
	var baseline := (size.y - d - absf(arch)) / 2 + font_size * CAP / 2 + maxf(arch, 0.0)
	var deep := depth_colour if depth_colour.a > 0 else outline.darkened(0.25)
	var lift := maxf(1.0, roundf(font_size * 0.035)) if highlight > 0 else 0.0
	var light := fill_top.lerp(Color.WHITE, highlight)
	var half := maxf(_width / 2, 1.0)
	# Straight and still (no arch, no letter popping in): every glyph drawn where it stands, with no
	# transform of its own, so they batch into a few draw calls (a transform per glyph cost one each);
	# the fill's gradient is then measured from the baseline.
	var straight := is_zero_approx(arch) and not _revealing
	_material.set_shader_parameter(&"y_top", (baseline if straight else 0.0) - font_size * CAP)
	_material.set_shader_parameter(&"y_bottom", baseline if straight else 0.0)
	# One pass per layer over all the letters, so no outline covers a neighbour's fill.
	for layer in 6:
		for i in text.length():
			var k := _pop(i)
			if k <= 0.001:
				continue
			var ch := text[i]
			var cx := left + _x[i] + _w[i] / 2
			var o := Vector2(-_w[i] / 2, 0)
			if straight:
				o += Vector2(cx, baseline)
			else:
				var u := (cx - (left + _width / 2)) / half
				draw_set_transform(Vector2(cx, baseline - arch * (1.0 - u * u)), atan(2.0 * arch * u / half), Vector2(k, k))
			match layer:
				0:  # soft drop shadow
					if shadow.a > 0:
						draw_char_outline(font, o + Vector2(0, d + ow * 0.5), ch, font_size, int(ow * 3.2), shadow)
				1:  # the extruded depth, a slice every 1.5 px
					if d > 0:
						var steps := ceili(d / 1.5)
						for s in range(steps, 0, -1):
							draw_char_outline(font, o + Vector2(0, d * s / steps), ch, font_size, int(ow * 2), deep)
				2:  # the outline
					if ow > 0:
						draw_char_outline(font, o, ch, font_size, int(ow * 2), outline)
				3:  # the light line inside it
					if inner_line.a > 0:
						draw_char_outline(font, o, ch, font_size, int(ow * 0.8), inner_line)
				4:  # the lit top edge
					if lift > 0:
						draw_char(font, o, ch, font_size, light)
				5:  # the fill (its gradient comes from the shader)
					draw_char(font, o + Vector2(0, lift), ch, font_size, MARKER)
	if not straight:
		draw_set_transform(Vector2.ZERO)

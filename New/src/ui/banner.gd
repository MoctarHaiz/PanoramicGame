class_name Banner
extends Control
## A title ribbon, as over the panels of top mobile games ("GAME OVER", "NEW BEST!", page titles):
## a glossy band with a dark outline, gently arched, its two notched tails folded behind it, and the
## title in outlined display text along the same arch. Colours come from a Ui.Tone.

const SEGMENTS := 24

var title: DisplayText
var tone := Ui.Tone.CRIMSON
var arch := 0.0
var _band_h := 0.0
var _tail := 0.0


func _init(text: String, banner_tone := Ui.Tone.CRIMSON, font_size := 56, arch_px := -1.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tone = banner_tone
	var c := Ui.tone_colours(tone)
	title = Ui.display_text(text, font_size, Color.WHITE, c.outline)
	title.depth = roundf(font_size * 0.06)
	title.shadow = Color(0, 0, 0, 0)
	_band_h = roundf(font_size * 1.32)
	_tail = roundf(font_size * 1.0)
	var band_w := title.text_width() + font_size * 2.2  # room at both ends, clear of the folds
	arch = arch_px if arch_px >= 0 else roundf(band_w * 0.035)
	custom_minimum_size = Vector2(band_w + _tail * 2 * 0.72, _band_h + _band_h * 0.3 + arch + 10)
	# The same curve as the band: y = arch * (x / half the width)², over the text's narrower width.
	title.arch = arch * pow(title.text_width() / custom_minimum_size.x, 2)
	title.refresh()
	add_child(title)
	resized.connect(_place_title)


func _ready() -> void:
	_place_title()


func _place_title() -> void:
	# Sized so the capitals' middle sits on the band's middle (see DisplayText._draw).
	title.size = Vector2(size.x, _band_h + title.arch + title.depth)
	title.position = Vector2.ZERO
	pivot_offset = size / 2


## Points of a band from x0 to x1, `h` high, its top at y0, following the arch (top edge then
## bottom edge, back).
func _band(x0: float, x1: float, y0: float, h: float) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var mid := size.x / 2
	var half := maxf(size.x / 2, 1.0)
	for i in SEGMENTS + 1:
		var x := lerpf(x0, x1, float(i) / SEGMENTS)
		var u := (x - mid) / half
		var y := y0 + arch * u * u
		top.append(Vector2(x, y))
		bottom.append(Vector2(x, y + h))
	bottom.reverse()
	return top + bottom


func _draw() -> void:
	var c := Ui.tone_colours(tone)
	var ow := maxf(3.0, roundf(_band_h * 0.07))
	var tail_h := _band_h * 0.78
	var tail_y := _band_h * 0.34
	var reach := _tail * 0.72  # how far a tail sticks out past the band
	var notch := tail_h * 0.42
	# The tails, behind: a notched end outside, tucked under the band inside.
	for side: float in [-1.0, 1.0]:
		var outer := size.x / 2 + side * (size.x / 2)
		var inner := outer - side * (reach + _tail * 0.9)
		var y := tail_y + arch * 0.75
		var pts := PackedVector2Array([Vector2(inner, y), Vector2(outer, y), Vector2(outer - side * notch, y + tail_h / 2),
				Vector2(outer, y + tail_h), Vector2(inner, y + tail_h)])
		for p in Geometry2D.offset_polygon(pts, ow, Geometry2D.JOIN_ROUND):
			draw_colored_polygon(p, c.outline)
		# shaded as cloth folded under: dark at the fold (inner end), lit towards its free end
		draw_polygon(pts, PackedColorArray([c.edge.darkened(0.42), c.edge.lightened(0.12), c.edge.darkened(0.05),
				c.edge.darkened(0.18), c.edge.darkened(0.55)]))
		draw_line(Vector2(inner, y + tail_h * 0.18), Vector2(outer - side * notch * 0.6, y + tail_h * 0.18),
				Color(1, 0.9, 0.75, 0.28), maxf(2.0, tail_h * 0.08), true)  # light along its top
		var crease := outer - side * reach * 0.8  # a crease just past the fold
		draw_line(Vector2(crease, y + 3.0), Vector2(crease, y + tail_h - 3.0), Color(c.outline, 0.4), 2.0, true)
		# The fold: a dark triangle where the band turns into the tail.
		var x_end := outer - side * reach
		var fold := PackedVector2Array([Vector2(x_end, y), Vector2(x_end - side * _tail * 0.38, y + tail_h * 0.42),
				Vector2(x_end - side * _tail * 0.38, y)])
		draw_colored_polygon(fold, c.outline.lerp(c.edge, 0.35))
	# The band.
	var x0 := reach
	var x1 := size.x - reach
	var band := _band(x0, x1, 0.0 + ow, _band_h - ow * 2)
	for p in Geometry2D.offset_polygon(band, ow, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(p, c.outline)
	# Gradient across the band's thickness: top colour on the top edge, bottom colour on the bottom.
	var n := SEGMENTS + 1
	var colours := PackedColorArray()
	for i in n:
		colours.append(c.top)
	for i in n:
		colours.append(c.bottom.darkened(0.06))
	_strip(band, colours)
	# The lower lip (a darker band along the bottom), the gloss and a light top edge.
	var lip := _band(x0, x1, _band_h - ow - _band_h * 0.16, _band_h * 0.16)
	var lip_colours := PackedColorArray()
	for i in n * 2:
		lip_colours.append(c.edge)
	_strip(lip, lip_colours)
	var gloss := _band(x0 + ow * 2, x1 - ow * 2, ow + _band_h * 0.08, _band_h * 0.34)
	var gloss_colours := PackedColorArray()
	for i in n:
		gloss_colours.append(Color(1, 1, 1, 0.45))
	for i in n:
		gloss_colours.append(Color(1, 1, 1, 0.08))
	_strip(gloss, gloss_colours)
	var line := _band(x0 + ow, x1 - ow, ow + 1.0, maxf(2.0, _band_h * 0.035))
	var line_colours := PackedColorArray()
	for i in n * 2:
		line_colours.append(Color(1, 1, 1, 0.55))
	_strip(line, line_colours)


## Fills a band made by _band() (top points, then bottom points backwards) as a triangle strip.
func _strip(pts: PackedVector2Array, colours: PackedColorArray) -> void:
	var n := pts.size() / 2
	for i in n - 1:
		var a := i
		var b := i + 1
		var bb := pts.size() - 1 - (i + 1)
		var ab := pts.size() - 1 - i
		draw_polygon(PackedVector2Array([pts[a], pts[b], pts[bb], pts[ab]]),
				PackedColorArray([colours[a], colours[b], colours[bb], colours[ab]]))

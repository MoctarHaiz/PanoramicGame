class_name Card
extends PanelContainer
## The panel of the interface kit (pause, results, settings, About), as the pop-ups of top mobile
## games: a soft shadow, a dark ink outline, a thick frame of warm lacquered wood lit along its top
## and shaded at its foot, a gold trim ring inside it, and a cream body that sits under the frame (an
## inner shadow along its top, a soft light in its middle). Text on the body is dark brown.
## The light variant (the start card, tutorial hints) is a see-through dark glass with a gold line.
## `well()` is the style of a sunken area inside the body (the results' counts, settings' rows).

const INK := Color("2e0d04")
const FRAME := 15.0  ## width of the wooden frame
const FRAME_TOP := Color("c8642a")
const FRAME_BOTTOM := Color("6e240a")
const TRIM := 4.0  ## the gold ring inside the frame
const TRIM_TOP := Color("ffe9a0")
const TRIM_BOTTOM := Color("e0901c")

var top_colour := Ui.CREAM
var bottom_colour := Ui.SAND
var radius := 34.0
var _framed := true


func _init(margin := Vector4(34, 40, 34, 34), light := false) -> void:
	if light:  # dark glass over the game
		top_colour = Color(Ui.NIGHT, 0.74)
		bottom_colour = Color(Ui.NIGHT, 0.84)
		radius = 28.0
		_framed = false
	var s := StyleBoxEmpty.new()
	s.content_margin_left = margin.x
	s.content_margin_top = margin.y
	s.content_margin_right = margin.z
	s.content_margin_bottom = margin.w
	add_theme_stylebox_override(&"panel", s)
	mouse_filter = Control.MOUSE_FILTER_STOP


## A sunken area inside a card's cream body: sand, its top edge in shade and its bottom edge lit.
static func well(corner := 20) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("efcf98")
	s.set_corner_radius_all(corner)
	s.corner_detail = 10
	s.border_width_top = 5
	s.border_width_bottom = 2
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_color = Color("b98348")
	s.border_blend = true
	s.anti_aliasing = true
	s.set_content_margin_all(16)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.shadow_color = Color(1, 1, 0.95, 0.7)  # the lit lip under it
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 2)
	return s


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _framed:  # a soft shadow under it
		for i in 6:
			var g := 4.0 + i * 5.0
			_fill(_rounded(r.grow(g - 6.0), radius + g), Color(0.1, 0.02, 0.0, 0.07), Color(0.1, 0.02, 0.0, 0.07),
					Vector2(0, 16))
	_fill(_rounded(r.grow(4.0), radius + 4.0), INK, INK)
	var body := r
	var inner := radius
	if _framed:
		# the frame: lacquered wood, a lit edge along its top, darker at its foot
		_fill(_rounded(r, radius), FRAME_TOP, FRAME_BOTTOM)
		_fill(_rounded(Rect2(r.position + Vector2(radius * 0.5, 2.5), Vector2(r.size.x - radius, 5.0)), 2.5),
				Color(1, 0.92, 0.75, 0.8), Color(1, 0.92, 0.75, 0.25))
		# the gold trim and the ink line inside it
		var trim := r.grow(-FRAME + TRIM)
		_fill(_rounded(trim.grow(1.5), radius - FRAME + TRIM + 1.5), INK, INK)
		_fill(_rounded(trim, radius - FRAME + TRIM), TRIM_TOP, TRIM_BOTTOM)
		body = r.grow(-FRAME)
		inner = radius - FRAME
		_fill(_rounded(body.grow(1.5), inner + 1.5), INK, INK)
	_fill(_rounded(body, inner), top_colour, bottom_colour)
	if _framed:
		# the body sits under the frame: a shadow along its top; a soft light in its middle
		_fill(_rounded(Rect2(body.position, Vector2(body.size.x, maxf(30.0, inner * 2.0 + 2.0))), inner), Color(0.35, 0.12, 0.0, 0.28),
				Color(0.35, 0.12, 0.0, 0.0))
		_glow(Rect2(body.position + body.size * Vector2(0.1, 0.12), body.size * Vector2(0.8, 0.6)))
	else:  # glass: a light top edge and a fine gold line inside
		_fill(_rounded(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, minf(40.0, r.size.y * 0.25))), radius - 4),
				Color(1, 0.85, 0.6, 0.16), Color(1, 0.85, 0.6, 0.0))
		var line := _rounded(body.grow(-3.0), inner - 3.0)
		line.append(line[0])
		draw_polyline(line, Color(Ui.GOLD, 0.55), 2.0, true)


## A soft lighter oval: the light falling on the content.
func _glow(area: Rect2) -> void:
	var c := area.get_center()
	for i in 6:
		var k := 1.0 - i * 0.15
		var pts := PackedVector2Array()
		for j in 32:
			var a := j * TAU / 32
			pts.append(c + Vector2(cos(a) * area.size.x * 0.5 * k, sin(a) * area.size.y * 0.5 * k))
		draw_colored_polygon(pts, Color(1, 1, 0.94, 0.06))


## A rounded rectangle as points (each corner a quarter circle).
func _rounded(r: Rect2, rad: float) -> PackedVector2Array:
	rad = clampf(rad, 0.0, minf(r.size.x, r.size.y) / 2)
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(r.size.x - rad, rad), r.end - Vector2(rad, rad),
			Vector2(r.position.x + rad, r.end.y - rad), r.position + Vector2(rad, rad)]
	for c in 4:
		for i in 9:
			var a := -PI / 2 + c * PI / 2 + i * PI / 2 / 8
			pts.append(corners[c] + Vector2.from_angle(a) * rad)
	return pts


## Fills points with a vertical gradient.
func _fill(pts: PackedVector2Array, top: Color, bottom: Color, offset := Vector2.ZERO) -> void:
	var cols := PackedColorArray()
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var moved := PackedVector2Array()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - y0) / maxf(y1 - y0, 1.0)))
		moved.append(p + offset)
	draw_polygon(moved, cols)

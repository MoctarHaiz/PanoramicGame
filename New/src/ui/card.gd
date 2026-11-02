class_name Card
extends PanelContainer
## The in-game panel (start card, pause, results): a warm card with a soft shadow, a dark ink
## outline, a carved frame lit along its top, a body of wooden planks sunk inside it (an inner
## shadow under the frame, a soft light behind the content), a fine gold line inside the frame,
## and quiet bands of beadwork (gold and cream diamonds on ink) along its top and bottom. `well()`
## is the style of a sunken area inside it (the results' counts).

const INK := Color("2e0d04")
const FRAME := 9.0  ## width of the carved frame
const FRAME_TOP := Color("e0943e")
const FRAME_BOTTOM := Color("8a4014")
const BEAD_COLOURS := [Color("f2b84a"), Color("fff0d6")]  ## gold and cream: a quiet trim

var top_colour := Color("94361a")
var bottom_colour := Color("4a140a")
var radius := 30.0
var bead_height := 18.0
var beads_bottom := true
var _framed := true


func _init(margin := Vector4(34, 40, 34, 34), light := false) -> void:
	if light:  # the start card: lighter, see-through, no frame
		top_colour = Color(Ui.NIGHT, 0.6)
		bottom_colour = Color(Ui.NIGHT, 0.72)
		beads_bottom = false
		bead_height = 14.0
		_framed = false
	var s := StyleBoxEmpty.new()
	s.content_margin_left = margin.x
	s.content_margin_top = margin.y
	s.content_margin_right = margin.z
	s.content_margin_bottom = margin.w
	add_theme_stylebox_override(&"panel", s)
	mouse_filter = Control.MOUSE_FILTER_STOP


## A sunken area inside a card: darker, its top edge in shade and its bottom edge catching light.
static func well(corner := 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.02, 0.0, 0.4)
	s.set_corner_radius_all(corner)
	s.border_width_top = 4
	s.border_width_bottom = 2
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_color = Color(0.05, 0.0, 0.0, 0.45)
	s.border_blend = true
	s.anti_aliasing = true
	s.set_content_margin_all(16)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.expand_margin_bottom = 2
	s.shadow_color = Color(1, 0.8, 0.55, 0.12)
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 2)
	return s


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# soft shadow under it
	if top_colour.a >= 1.0:  # a solid card casts a soft shadow (a see-through one would show it)
		for i in 6:
			var g := 4.0 + i * 4.0
			_fill(_rounded(r.grow(g - 6.0), radius + g), Color(0.12, 0.03, 0.0, 0.08), Color(0.12, 0.03, 0.0, 0.08),
					Vector2(0, 14))
	_fill(_rounded(r.grow(3.0), radius + 3.0), INK, INK)
	var body := r
	if _framed:
		_fill(_rounded(r, radius), FRAME_TOP, FRAME_BOTTOM)
		# the frame catches the light along its top
		_fill(_rounded(Rect2(r.position + Vector2(radius * 0.6, 2.0), Vector2(r.size.x - radius * 1.2, 4.0)), 2.0),
				Color(1, 0.95, 0.8, 0.75), Color(1, 0.95, 0.8, 0.2))
		body = r.grow(-FRAME)
		_fill(_rounded(body.grow(1.5), radius - FRAME + 1.5), INK, INK)
	var inner := radius - (FRAME if _framed else 0.0)
	_fill(_rounded(body, inner), top_colour, bottom_colour)
	if _framed:
		# the body is made of planks: wavy grain, a seam between planks lit on its lower lip
		_planks(body.grow(-4.0), inner - 4.0)
		# the body sits under the frame: a shadow along its top; a soft light in its middle
		_fill(_rounded(Rect2(body.position, Vector2(body.size.x, 18.0)), inner), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0))
		_glow(Rect2(body.position + body.size * Vector2(0.1, 0.18), body.size * Vector2(0.8, 0.6)))
	else:
		_fill(_rounded(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, minf(40.0, r.size.y * 0.25))), radius - 4),
				Color(1, 0.85, 0.6, 0.14), Color(1, 0.85, 0.6, 0.0))
	# beadwork bands
	var inset := 10.0 if _framed else 8.0
	_beads(Rect2(body.position.x + inner * 0.6, body.position.y + inset, body.size.x - inner * 1.2, bead_height))
	if beads_bottom:
		_beads(Rect2(body.position.x + inner * 0.6, body.end.y - inset - bead_height, body.size.x - inner * 1.2, bead_height))
	# a fine gold line inside the edge
	var line := _rounded(body.grow(-3.0), inner - 3.0)
	line.append(line[0])
	draw_polyline(line, Color(Ui.GOLD, 0.5), 2.0, true)


## Wooden planks across the body: seams every ~70 px (dark, with a lit lip under them) and fine
## wavy grain lines, kept inside the rounded corners.
func _planks(area: Rect2, corner: float) -> void:
	var plank := 70.0
	var y := area.position.y + plank
	while y < area.end.y - 8.0:
		var inset := _corner_inset(area, corner, y)
		draw_line(Vector2(area.position.x + inset, y), Vector2(area.end.x - inset, y), Color(0.12, 0.03, 0.0, 0.5), 2.0)
		draw_line(Vector2(area.position.x + inset, y + 2.0), Vector2(area.end.x - inset, y + 2.0), Color(1, 0.75, 0.5, 0.12), 1.5)
		y += plank
	var line := 0
	y = area.position.y + 9.0
	while y < area.end.y - 6.0:
		var inset := _corner_inset(area, corner, y) + 4.0
		var pts := PackedVector2Array()
		var x := area.position.x + inset
		line += 1
		while x <= area.end.x - inset:
			pts.append(Vector2(x, y + sin(x * 0.013 + line * 1.7) * 2.5 + sin(x * 0.041 + line) * 1.0))
			x += 24.0
		if pts.size() > 1:
			var light := line % 3 == 0
			draw_polyline(pts, Color(1, 0.8, 0.55, 0.06) if light else Color(0.1, 0.02, 0.0, 0.14), 1.4, true)
		y += 7.0 + float(line * 37 % 5)


## How far in from the side a rounded rectangle's edge is at height y.
func _corner_inset(area: Rect2, corner: float, y: float) -> float:
	var d := minf(y - area.position.y, area.end.y - y)
	if d >= corner:
		return 0.0
	return corner - sqrt(maxf(corner * corner - (corner - d) * (corner - d), 0.0))


## A soft lighter oval: the light falling on the content.
func _glow(area: Rect2) -> void:
	var c := area.get_center()
	for i in 6:
		var k := 1.0 - i * 0.15
		var pts := PackedVector2Array()
		for j in 32:
			var a := j * TAU / 32
			pts.append(c + Vector2(cos(a) * area.size.x * 0.5 * k, sin(a) * area.size.y * 0.5 * k))
		draw_colored_polygon(pts, Color(1, 0.62, 0.36, 0.035))


## A band of beadwork: an ink strip with a row of diamonds in turn gold and cream, a small bead
## between two.
func _beads(band: Rect2) -> void:
	_fill(_rounded(band.grow(2.0), band.size.y / 2 + 2.0), INK, INK)
	var h := band.size.y
	var step := h * 1.6
	var n := maxi(int(band.size.x / step), 1)
	var x0 := band.position.x + (band.size.x - n * step) / 2 + step / 2
	var y := band.position.y + h / 2
	for i in n:
		var cx := x0 + i * step
		var dx := h * 0.5
		var dy := h * 0.42
		var colour: Color = BEAD_COLOURS[i % BEAD_COLOURS.size()]
		draw_colored_polygon(PackedVector2Array([Vector2(cx - dx, y), Vector2(cx, y - dy), Vector2(cx + dx, y), Vector2(cx, y + dy)]), colour)
		if i < n - 1:
			draw_circle(Vector2(cx + step / 2, y), h * 0.1, Color(0.95, 0.85, 0.7, 0.6))


## A rounded rectangle as points (each corner a quarter circle).
func _rounded(r: Rect2, rad: float) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) / 2)
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

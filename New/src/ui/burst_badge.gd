class_name BurstBadge
extends Control
## A burst badge ("NEW BEST!"), as the seals of top games' result screens: a gold starburst with an
## ink outline and a soft shadow, a glossy red medallion in it, the words on two lines in outlined
## white display text, a gold crown on its top edge and a glint twinkling on its rim. A seal set on
## the panel (not a button: no bevel, no ring, never the shape of the buttons beside it).

const POINTS := 22  ## the burst's spikes
const INK := Color("3a1006")

var radius := 62.0  ## the burst's outer radius (its spikes' tips)
var calm := false  ## the quiet plaque (a new best after a defeat): no spikes, no glint, dark words on gold
var _clock := 0.0


## `text`: the words (split on two lines at the first space); `burst`: the outer radius in units;
## `quiet`: the calm plaque instead of the burst (its box the same size: it takes the same place).
func _init(text: String, burst := 62.0, quiet := false) -> void:
	radius = burst
	calm = quiet
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius, radius) * 2.0
	size = custom_minimum_size
	pivot_offset = size / 2
	var words := text.to_upper().split(" ", false, 1)
	var disc := radius * 0.74
	var room := radius * 2.0 if calm else disc * 1.42  # (calm: a gold plaque wider than tall, its words on it)
	var lines: Array[DisplayText] = []
	for w: String in words:
		var fit := 28.0 if calm else 34.0
		var t := _line(w, fit)
		# the widest line fits the medallion, a little air at both ends
		fit = minf(fit, fit * room / maxf(t.text_width(), 1.0))  # air at both ends: not cramped
		t.font_size = int(fit)
		t.outline_width = 0.0 if calm else roundf(fit * 0.11)
		t.depth = 0.0 if calm else roundf(fit * 0.07)
		t.refresh()
		lines.append(t)
	var line_h := 0.0
	for t in lines:
		line_h = maxf(line_h, t.font_size * 0.96)
	for i in lines.size():
		var t := lines[i]
		t.size = Vector2(size.x, line_h)
		t.position = Vector2(0, size.y / 2 + (i - lines.size() / 2.0) * line_h + 2.0)
		add_child(t)
	var crown := Ui.bold_icon("crown-fill", radius * (0.34 if calm else 0.46), Ui.GOLD, INK)
	crown.size = crown.custom_minimum_size
	var crown_y := size.y / 2 - radius * 0.62 - crown.size.y * 0.62 if calm else -crown.size.y * 0.28  # (calm: on the plaque's top)
	crown.position = Vector2(size.x / 2 - crown.size.x / 2, crown_y)
	add_child(crown)
	set_process(Prefs.motion() and not calm)


func _line(text: String, font_size: float) -> DisplayText:
	if calm:  # dark brown words engraved on the gold
		var q := Ui.display_text(text, int(font_size), Color("5a2408"), Color(0, 0, 0, 0), Color("3a1404"))
		q.shadow = Color(1, 0.95, 0.8, 0.0)
		return q
	var t := Ui.display_text(text, int(font_size), Ui.WHITE, Color("5a0804"), Color("ffe6c8"))
	t.shadow = Color(0, 0, 0, 0)
	return t


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## The burst's outline: spikes alternating between `outer` and `inner` around `c`.
static func _burst(c: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in POINTS * 2:
		var a := -PI / 2 + i * PI / POINTS
		pts.append(c + Vector2.from_angle(a) * (outer if i % 2 == 0 else inner))
	return pts


static func _disc(c: Vector2, r: float, n := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(c + Vector2.from_angle(i * TAU / n) * r)
	return pts


## Fills points with a vertical gradient from `top` (at y0) to `bottom` (at y1).
func _gradient(pts: PackedVector2Array, y0: float, y1: float, top: Color, bottom: Color) -> void:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - y0) / maxf(y1 - y0, 1.0), 0.0, 1.0)))
	draw_polygon(pts, cols)


func _draw() -> void:
	var c := size / 2
	if calm:  # a gold plaque: an ink line, a gold rim lit at its top, a pale gold face; no spikes, no glint
		var half := Vector2(radius * 1.18, radius * 0.62)
		var r := Rect2(c - half, half * 2.0)
		var ci := get_canvas_item()
		GlossStyle.fill_rounded(ci, Rect2(r.position + Vector2(0, 4), r.size).grow(4.0), 20.0, Color(0.12, 0.02, 0.0, 0.25),
				Color(0.12, 0.02, 0.0, 0.25))
		GlossStyle.fill_rounded(ci, r.grow(4.0), 20.0, INK, INK)
		GlossStyle.fill_rounded(ci, r.grow(1.5), 17.5, Color("ffe27a"), Color("c8780e"))
		GlossStyle.fill_rounded(ci, r.grow(-3.0), 13.0, Color("fff3c6"), Color("f2c55a"))
		return
	var r := radius - 3.0
	var inner := r * 0.84
	draw_colored_polygon(_burst(c + Vector2(0, 6), r + 3.0, inner + 3.0), Color(0.12, 0.02, 0.0, 0.35))  # its shadow
	draw_colored_polygon(_burst(c, r + 3.0, inner + 3.0), INK)
	_gradient(_burst(c, r, inner), c.y - r, c.y + r, Color("fff2a0"), Color("e0861a"))
	_gradient(_burst(c, r * 0.9, inner * 0.92), c.y - r, c.y + r, Color("ffe066"), Color("f0a028"))
	var d := radius * 0.74
	draw_colored_polygon(_disc(c, d + 3.0), INK)
	_gradient(_disc(c, d), c.y - d, c.y + d, Color("ff6a46"), Color("b81408"))
	_gradient(_disc(c + Vector2(0, d * 0.08), d * 0.86), c.y - d, c.y + d, Color("f23a1e"), Color("c81a0a"))
	# the gloss: a soft light over the medallion's upper half
	var gloss := PackedVector2Array()
	for i in 24:
		var a := i * TAU / 24
		gloss.append(c + Vector2(0, -d * 0.42) + Vector2(cos(a) * d * 0.72, sin(a) * d * 0.4))
	_gradient(gloss, c.y - d * 0.82, c.y - d * 0.02, Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.0))
	# a glint on the rim, at its top right, twinkling
	var beat := 0.5 + 0.5 * sin(_clock * 2.6)
	var at := c + Vector2.from_angle(-PI * 0.27) * r * 0.9
	var arm := r * 0.34 * (0.65 + 0.35 * beat)
	var star := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 8:
		star.append(at + Vector2.from_angle(i * PI / 4 - PI / 2) * (arm if i % 2 == 0 else arm * 0.16))
		cols.append(Color(1, 1, 0.9, 0.0 if i % 2 == 0 else 0.55 + 0.45 * beat))
	draw_polygon(star, cols)
	draw_circle(at, arm * 0.16, Color(1, 1, 0.95, 0.6 + 0.4 * beat), true, -1, true)

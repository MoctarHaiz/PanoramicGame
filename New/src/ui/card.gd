class_name Card
extends PanelContainer
## The panel of the interface kit (pause, results, settings, About). The user (2026-11-08): "I don't like the woody
## effect: make it sleeker, more beautiful, more modern": a clean warm-white body (a soft gradient, no grain) in a slim
## polished gold bezel, a fine highlight along its top, a soft deep shadow; no carved wood, no beadwork. (Before:) a deep shadow cast on the game behind, a dark ink outline, a thick
## frame of carved wood bevelled (lit along its top and outer edge, shaded at its foot) with an inlay
## of Zulu beadwork along its middle, a broad gold trim inside it, and a body of tanned hide (paper.png
## grain) that sinks under the frame (shade along its top, sides and foot, a soft light in its middle:
## it curves). Text on the body is dark brown. A mood (set_mood) gilds it for a win (a thicker polished
## gold frame), or darkens it to smoked wood, dusty beads and hide for a loss.
## The beadwork: a calm run of oxblood beads close in value to the wood along each straight side (an inlay, not a
## stripe; tools/art/ui_beadwork.py), the corners plain wood (UI r23, the judges of j19: r22's motif blocks and
## corner diamonds made four border layers: dropped).
## The light variant (the start card, tutorial hints) is a see-through dark glass with a gold line.
## `well()` is the style of a sunken area inside the body (the results' counts, settings' rows).

const INK := Color("2e0d04")
const FRAME := 12.0  ## width of the bezel (2026-11-08: slim polished gold, was 34 of carved wood)
const FRAME_TOP := Color("ffe9a6")
const FRAME_BOTTOM := Color("c98a24")
const TRIM := 3.0  ## the fine bright line inside the bezel
const TRIM_TOP := Color("fffbea")
const TRIM_BOTTOM := Color("f3d58c")

var top_colour := Color("fffcf5")  ## a clean warm white at the top
var bottom_colour := Color("f2e6cf")  ## a soft sand towards its foot
var frame_top := FRAME_TOP  ## the frame's wood (a mood changes it: gold for a win, dark for a loss)
var frame_bottom := FRAME_BOTTOM
var trim_top := TRIM_TOP
var trim_bottom := TRIM_BOTTOM
var radius := 34.0
var bronze := false  ## a defeat's: the beads dusty, as the smoked wood
var frame_w := FRAME  ## the frame's width (a win's is thicker)
var ornate := false  ## a win's frame: thick polished gold
var _framed := true
var _shadow_box: StyleBoxFlat


func _init(margin := Vector4(34, 40, 34, 34), light := false) -> void:
	if light:  # dark glass over the game (2026-11-08: the HUD's navy glass, not brown)
		top_colour = Color(0.12, 0.15, 0.24, 0.8)
		bottom_colour = Color(0.05, 0.07, 0.12, 0.88)
		radius = 28.0
		_framed = false
	var s := StyleBoxEmpty.new()
	s.content_margin_left = margin.x
	s.content_margin_top = margin.y
	s.content_margin_right = margin.z
	s.content_margin_bottom = margin.w
	add_theme_stylebox_override(&"panel", s)
	mouse_filter = Control.MOUSE_FILTER_STOP


## A mood for the panel: &"win" a gold frame and a bright trim on a warm hide; &"loss" dark smoked
## wood, a dull bronze trim, dusty beads, a dusty grey hide (the defeat drained, still of his warm
## world, not cold steel); anything else the wood.
func set_mood(mood: StringName) -> void:
	match mood:
		&"win":  # the biggest reward: a broader, brighter gold bezel on a warmer white
			frame_top = Color("fff2b0")
			frame_bottom = Color("e0a020")
			frame_w = 16.0
			radius = 40.0
			ornate = true
			trim_top = Color("ffffff")
			trim_bottom = Color("ffe9a6")
			top_colour = Color("fffaf0")
			bottom_colour = Color("f8e7c2")
		&"loss":  # quieter: a cool pewter bezel on a cooler white
			frame_top = Color("e4e8f0")
			frame_bottom = Color("8a94a8")
			trim_top = Color("ffffff")
			trim_bottom = Color("d6dbe6")
			top_colour = Color("fbfbfd")
			bottom_colour = Color("e6e8ee")
			bronze = true
	queue_redraw()


## A sunken area inside a card's cream body: deeper sand in the shade of its upper edge, warmer
## and lighter towards its foot, a fine brown outline, a lit lip under it (GlossStyle, no gloss).
static func well(corner := 20) -> GlossStyle:
	var s := GlossStyle.new(Color("ecdcbc"), Color("f8eedb"), Color(0, 0, 0, 0), corner, 0.0)  # (2026-11-08: soft, no wood brown)
	s.set_outline(Color("d8c098"), 2.0)
	s.gloss = 0.0
	s.spark = 0.0
	s.rim = 0.0
	s.shadow.shadow_color = Color(1, 1, 0.95, 0.75)  # the lit lip under it
	s.shadow.shadow_size = 0
	s.shadow.shadow_offset = Vector2(0, 3)
	s.set_content_margin_all(16)
	s.content_margin_left = 22
	s.content_margin_right = 22
	return s


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _framed:  # a deep soft shadow under it: one smooth falloff
		if not _shadow_box or _shadow_box.corner_radius_top_left != int(radius):
			_shadow_box = StyleBoxFlat.new()
			_shadow_box.bg_color = Color(0.06, 0.0, 0.02, 0.0)
			_shadow_box.set_corner_radius_all(int(radius))
			_shadow_box.shadow_color = Color(0.03, 0.02, 0.06, 0.6)
			_shadow_box.shadow_size = 40
			_shadow_box.shadow_offset = Vector2(0, 18)
			_shadow_box.anti_aliasing = true
		draw_style_box(_shadow_box, r)
	var body := r
	var inner := radius
	if _framed:
		# (2026-11-08) a slim polished bezel: a fine dark edge, the gold lit along its top, a bright line inside it
		_fill(_rounded(r.grow(1.5), radius + 1.5), Color(0.24, 0.14, 0.04, 0.85), Color(0.24, 0.14, 0.04, 0.85))
		_fill(_rounded(r, radius), frame_top, frame_bottom)
		_fill(_rounded(Rect2(r.position + Vector2(radius * 0.7, 1.5), Vector2(r.size.x - radius * 1.4, 3.0)), 1.5),
				Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.5))
		var trim := r.grow(-frame_w + TRIM)
		_fill(_rounded(trim, radius - frame_w + TRIM), trim_top, trim_bottom)
		body = r.grow(-frame_w)
		inner = maxf(radius - frame_w, 6.0)
		_fill(_rounded(body.grow(1.0), inner + 1.0), Color(0.55, 0.38, 0.12, 0.7), Color(0.55, 0.38, 0.12, 0.7))
	_fill(_rounded(body, inner), top_colour, bottom_colour)
	if _framed:
		# a soft inner shade along its top (it sits a little under the bezel), a gentle light in its middle
		_fill(_rounded(Rect2(body.position, Vector2(body.size.x, maxf(28.0, inner * 1.4))), inner), Color(0.4, 0.28, 0.1, 0.16),
				Color(0.4, 0.28, 0.1, 0.0))
		_glow(Rect2(body.position + body.size * Vector2(0.1, 0.1), body.size * Vector2(0.8, 0.55)))
	else:  # glass: a light top edge and a fine gold line inside
		_fill(_rounded(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, minf(40.0, r.size.y * 0.25))), radius - 4),
				Color(1, 0.85, 0.6, 0.16), Color(1, 0.85, 0.6, 0.0))
		var line := _rounded(body.grow(-3.0), inner - 3.0)
		line.append(line[0])
		draw_polyline(line, Color(Ui.GOLD, 0.55), 2.0, true)


## A rectangle with a horizontal gradient.
func _fill_h(r: Rect2, left: Color, right: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([left, right, right, left]))


## A soft lighter oval: the light falling on the content.
func _glow(area: Rect2) -> void:
	var c := area.get_center()
	for i in 6:
		var k := 1.0 - i * 0.15
		var pts := PackedVector2Array()
		for j in 32:
			var a := j * TAU / 32
			pts.append(c + Vector2(cos(a) * area.size.x * 0.5 * k, sin(a) * area.size.y * 0.5 * k))
		draw_colored_polygon(pts, Color(1, 1, 0.94, 0.085))


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

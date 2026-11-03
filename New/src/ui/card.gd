class_name Card
extends PanelContainer
## The panel of the interface kit (pause, results, settings, About), as the pop-ups of top mobile
## games, in his world's materials: a deep shadow cast on the game behind, a dark ink outline, a thick
## frame of carved wood bevelled (lit along its top and outer edge, shaded at its foot) with gold studs
## and a Zulu band, a gold trim ring inside it, and a body of tanned hide (paper.png grain) that sinks
## under the frame (shade along its top, sides and foot, a soft light in its middle: it curves). Text
## on the body is dark brown. A mood (set_mood) gilds it for a win or darkens and cools it for a loss.
## The light variant (the start card, tutorial hints) is a see-through dark glass with a gold line.
## `well()` is the style of a sunken area inside the body (the results' counts, settings' rows).

const INK := Color("2e0d04")
const FRAME := 15.0  ## width of the wooden frame
const FRAME_TOP := Color("c8642a")
const FRAME_BOTTOM := Color("6e240a")
const TRIM := 4.0  ## the gold ring inside the frame
const TRIM_TOP := Color("ffe9a0")
const TRIM_BOTTOM := Color("e0901c")
const PAPER := preload("res://assets/art/ui/paper.png")

var top_colour := Color("f6e4bc")  ## tanned hide, warm at the top
var bottom_colour := Color("dcb47c")  ## and darker towards its foot
var frame_top := FRAME_TOP  ## the frame's wood (a mood changes it: gold for a win, dark for a loss)
var frame_bottom := FRAME_BOTTOM
var trim_top := TRIM_TOP
var trim_bottom := TRIM_BOTTOM
var radius := 34.0
var _framed := true
var _shadow_box: StyleBoxFlat


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
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # the hide grain tiles


## A mood for the panel: &"win" a gold frame and a bright trim on a warm hide; &"loss" dark, cool
## wood, a dull bronze trim, a greyer hide (the defeat drained of warmth); anything else the wood.
func set_mood(mood: StringName) -> void:
	match mood:
		&"win":
			frame_top = Color("ffd25e")
			frame_bottom = Color("a8620c")
			trim_top = Color("fffbe6")
			trim_bottom = Color("f2c24a")
			top_colour = Color("fff0c8")
			bottom_colour = Color("ecc884")
		&"loss":
			frame_top = Color("8a5a40")
			frame_bottom = Color("3a1c10")
			trim_top = Color("cdbb98")
			trim_bottom = Color("7e6a4c")
			top_colour = Color("ece2cc")
			bottom_colour = Color("c6b496")
	queue_redraw()


## A sunken area inside a card's cream body: deeper sand in the shade of its upper edge, warmer
## and lighter towards its foot, a fine brown outline, a lit lip under it (GlossStyle, no gloss).
static func well(corner := 20) -> GlossStyle:
	var s := GlossStyle.new(Color("d9b075"), Color("f6dcaa"), Color(0, 0, 0, 0), corner, 0.0)
	s.set_outline(Color("a8743c"), 2.5)
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
	if _framed:  # a deep soft shadow under it: one smooth falloff (stacked layers showed as steps)
		if not _shadow_box or _shadow_box.corner_radius_top_left != int(radius):
			_shadow_box = StyleBoxFlat.new()
			_shadow_box.bg_color = Color(0.06, 0.0, 0.02, 0.0)
			_shadow_box.set_corner_radius_all(int(radius))
			_shadow_box.shadow_color = Color(0.04, 0.0, 0.02, 0.78)  # it stands off the blurred game
			_shadow_box.shadow_size = 46
			_shadow_box.shadow_offset = Vector2(0, 24)
			_shadow_box.anti_aliasing = true
		draw_style_box(_shadow_box, r)
	_fill(_rounded(r.grow(4.0), radius + 4.0), INK, INK)
	var body := r
	var inner := radius
	if _framed:
		# the frame: lacquered wood, a lit edge along its top, darker at its foot
		_fill(_rounded(r, radius), frame_top.lightened(0.25), frame_bottom)  # the outer bevel, lit
		_fill(_rounded(r.grow(-3.0), radius - 3.0), frame_top, frame_bottom.darkened(0.15))
		_fill(_rounded(Rect2(r.position + Vector2(radius * 0.5, 3.0), Vector2(r.size.x - radius, 5.0)), 2.5),
				Color(1, 0.92, 0.75, 0.85), Color(1, 0.92, 0.75, 0.3))
		# the gold trim and the ink line inside it
		var trim := r.grow(-FRAME + TRIM)
		_fill(_rounded(trim.grow(1.5), radius - FRAME + TRIM + 1.5), INK, INK)
		_fill(_rounded(trim, radius - FRAME + TRIM), trim_top, trim_bottom)
		body = r.grow(-FRAME)
		inner = radius - FRAME
		_fill(_rounded(body.grow(1.5), inner + 1.5), INK, INK)
	if _framed:  # cream hide: its colours over the paper grain
		_textured(_rounded(body, inner), top_colour, bottom_colour)
	else:
		_fill(_rounded(body, inner), top_colour, bottom_colour)
	if _framed:
		# the body sits under the frame: a shadow along its top; a soft light in its middle
		_fill(_rounded(Rect2(body.position, Vector2(body.size.x, maxf(48.0, inner * 2.0 + 18.0))), inner), Color(0.3, 0.1, 0.0, 0.5),
				Color(0.3, 0.1, 0.0, 0.0))
		for side: float in [0.0, 1.0]:  # and along its sides
			var band := Rect2(body.position + Vector2(side * (body.size.x - 30.0), inner * 0.6), Vector2(30.0, body.size.y - inner * 1.2))
			_fill_h(band, Color(0.3, 0.1, 0.0, 0.32 * (1.0 - side)), Color(0.3, 0.1, 0.0, 0.32 * side))
		var foot := Rect2(body.position + Vector2(inner * 0.6, body.size.y - 26.0), Vector2(body.size.x - inner * 1.2, 26.0))
		_fill(_rounded(foot, 0.0), Color(0.3, 0.1, 0.0, 0.0), Color(0.3, 0.1, 0.0, 0.24))  # and its foot
		_glow(Rect2(body.position + body.size * Vector2(0.1, 0.12), body.size * Vector2(0.8, 0.6)))
		_zulu_band(r)
		_studs(r)
	else:  # glass: a light top edge and a fine gold line inside
		_fill(_rounded(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, minf(40.0, r.size.y * 0.25))), radius - 4),
				Color(1, 0.85, 0.6, 0.16), Color(1, 0.85, 0.6, 0.0))
		var line := _rounded(body.grow(-3.0), inner - 3.0)
		line.append(line[0])
		draw_polyline(line, Color(Ui.GOLD, 0.55), 2.0, true)


## A Zulu band set into the frame along its top and bottom, between the corner studs: bold diamonds,
## red and black on cream with a dark edge, big enough to read on a phone (not a string of small beads,
## which read as dots), mirrored from the middle and clear of a wide card's middle stud.
func _zulu_band(r: Rect2) -> void:
	var tiles := _band_tiles()
	var x0 := r.position.x + radius + 12.0
	var x1 := r.end.x - radius - 12.0
	var mid := r.get_center().x
	var cut := BAND_STEP if r.size.x > 520.0 else 0.0  # the first diamond each side of the middle stud
	var tile_w := float(tiles[0].get_width())
	for y: float in [r.position.y + FRAME * 0.5, r.end.y - FRAME * 0.5]:
		_fill(_rounded(Rect2(Vector2(x0 - 1.5, y - BAND_H / 2 - 1.5), Vector2(x1 - x0 + 3.0, BAND_H + 3.0)), 3.0), INK, INK)
		var top := y - BAND_H / 2
		# the right half from a diamond centred on the middle (or past the stud), the left half the
		# mirror of it: one textured rect each
		var a := mid + cut - BAND_STEP / 2
		draw_texture_rect_region(tiles[0], Rect2(a, top, x1 - a, BAND_H),
				Rect2(0, 0, (x1 - a) * BAND_SCALE, tiles[0].get_height()))
		var b := mid - cut + BAND_STEP / 2
		var span := (b - x0) * BAND_SCALE
		draw_texture_rect_region(tiles[1], Rect2(x0, top, b - x0, BAND_H),
				Rect2(tile_w - fposmod(span, tile_w), 0, span, tiles[1].get_height()))


const BAND_STEP := 22.0  ## one diamond and its share of the band
const BAND_H := 14.0  ## the band, top to bottom (nearly the frame's width)
const BAND_SCALE := 3  ## the tile's pixels per unit (sharp on a phone's screen)
static var _band: Array[ImageTexture] = []


## The band drawn once into a tile of two diamonds (red, black) and its mirror; tiled along the frame
## it costs one draw call per half band.
static func _band_tiles() -> Array[ImageTexture]:
	if not _band.is_empty():
		return _band
	var s := float(BAND_SCALE)
	var w := int(BAND_STEP * 2 * s)
	var h := int(BAND_H * s)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cream := Color("f6e7c4")
	var edge := Color("2a0c04")
	var fills := [Color("cf2a18"), Color("1e1410")]
	for py in h:
		for px in w:
			var p := Vector2(px + 0.5, py + 0.5) / s
			var i := int(p.x / BAND_STEP)
			var c := Vector2((i + 0.5) * BAND_STEP, BAND_H / 2)
			# a diamond's "distance": 0 on its edge, positive inside (in units, roughly)
			var d := (1.0 - (absf(p.x - c.x) / 9.6 + absf(p.y - c.y) / 5.8)) * 4.6
			var col := cream.lerp(Color("e8cf9c"), p.y / BAND_H)  # the cream darkens a little downwards
			col = col.blend(Color(edge, clampf((d + 1.0) * s + 0.5, 0.0, 1.0)))
			var fill: Color = fills[i % 2].lightened(0.12 if p.y < c.y else 0.0)  # a lit upper half
			col = col.blend(Color(fill, clampf(d * s + 0.5, 0.0, 1.0)))
			img.set_pixel(px, py, col)
	var mirrored := img.duplicate() as Image
	mirrored.flip_x()
	_band = [ImageTexture.create_from_image(img), ImageTexture.create_from_image(mirrored)]
	return _band


## Gold studs nailed into the frame: one at each corner, and along the long edges of a wide card.
func _studs(r: Rect2) -> void:
	var m := FRAME * 0.5 + 1.0
	var spots := [r.position + Vector2(m + radius * 0.3, m + radius * 0.3), Vector2(r.end.x - m - radius * 0.3, r.position.y + m + radius * 0.3),
			Vector2(r.position.x + m + radius * 0.3, r.end.y - m - radius * 0.3), r.end - Vector2(m + radius * 0.3, m + radius * 0.3)]
	if r.size.x > 520.0:
		spots.append(Vector2(r.get_center().x, r.position.y + m))
		spots.append(Vector2(r.get_center().x, r.end.y - m))
	for c: Vector2 in spots:
		draw_circle(c + Vector2(0, 1.5), 6.5, Color(0.1, 0.02, 0.0, 0.5), true, -1, true)
		draw_circle(c, 6.0, INK, true, -1, true)
		draw_circle(c, 4.6, Color("c27a22"), true, -1, true)
		draw_circle(c - Vector2(0.6, 0.8), 3.6, Color("ffd36b"), true, -1, true)
		draw_circle(c - Vector2(1.6, 1.8), 1.4, Color(1, 1, 0.92, 0.95), true, -1, true)


## Points filled with a vertical gradient over the paper grain (tiled by the points' own position).
func _textured(pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - y0) / maxf(y1 - y0, 1.0)))
		uvs.append(p / 256.0)
	draw_polygon(pts, cols, uvs, PAPER)


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

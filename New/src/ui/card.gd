class_name Card
extends PanelContainer
## The panel of the interface kit (pause, results, settings, About), as the pop-ups of top mobile
## games, in his world's materials: a deep shadow cast on the game behind, a dark ink outline, a thick
## frame of carved wood bevelled (lit along its top and outer edge, shaded at its foot) with an inlay
## of Zulu beadwork along its middle, a broad gold trim inside it, and a body of tanned hide (paper.png
## grain) that sinks under the frame (shade along its top, sides and foot, a soft light in its middle:
## it curves). Text on the body is dark brown. A mood (set_mood) gilds it for a win (a thicker polished
## gold frame), or darkens it to smoked wood, dusty beads and hide for a loss.
## The beadwork (UI r21, the judges of j17: the r20 band of single-bead triangles "dithers / moires at
## phone size, the most detailed thing on every panel; the corner rosettes read as bottle caps: 2-3
## larger motif blocks, softer"): a calm run of oxblood beads close in value to the wood (an inlay, not
## a stripe), two or three larger motif blocks on each side (a pointed ivory cartouche, a dark diamond
## with a red heart, red triangles pointing at it), kept clear of the title ribbon (top_clear), and a
## small flat beaded diamond on each corner (tools/art/ui_beadwork.py).
## The light variant (the start card, tutorial hints) is a see-through dark glass with a gold line.
## `well()` is the style of a sunken area inside the body (the results' counts, settings' rows).

const INK := Color("2e0d04")
const FRAME := 34.0  ## width of the wooden frame (its beaded band along its middle, wood both sides)
const FRAME_TOP := Color("c8642a")
const FRAME_BOTTOM := Color("6e240a")
const TRIM := 6.0  ## the gold ring inside the frame
const TRIM_TOP := Color("ffe9a0")
const TRIM_BOTTOM := Color("e0901c")
const PAPER := preload("res://assets/art/ui/paper.png")
const BAND := preload("res://assets/art/ui/beadwork_band.png")  ## the run of beads along the frame (tools/art/ui_beadwork.py)
const MOTIFS := preload("res://assets/art/ui/beadwork_motifs.png")  ## its motif block and corner diamond
const BEAD_SCALE := 3.0  ## px of the beadwork's pictures per card unit
const BLOCK := Rect2(0, 0, 342, 84)  ## the motif block in MOTIFS (114 x 28 units, its clear edge round it)
const CORNER := Rect2(348, 0, 126, 126)  ## the corner diamond in MOTIFS (centred in it)

var top_colour := Color("f6e4bc")  ## tanned hide, warm at the top
var bottom_colour := Color("dcb47c")  ## and darker towards its foot
var frame_top := FRAME_TOP  ## the frame's wood (a mood changes it: gold for a win, dark for a loss)
var frame_bottom := FRAME_BOTTOM
var trim_top := TRIM_TOP
var trim_bottom := TRIM_BOTTOM
var radius := 34.0
var bronze := false  ## a defeat's: the beads dusty, as the smoked wood
var frame_w := FRAME  ## the frame's width (a win's is thicker)
var top_clear := 0.0  ## the width of the title ribbon over the top edge's middle: no motif block under it
var ornate := false  ## a win's frame: thick polished gold
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


## A mood for the panel: &"win" a gold frame and a bright trim on a warm hide; &"loss" dark smoked
## wood, a dull bronze trim, dusty beads, a dusty grey hide (the defeat drained, still of his warm
## world, not cold steel); anything else the wood.
func set_mood(mood: StringName) -> void:
	match mood:
		&"win":  # the biggest reward: a thick polished gold frame, a bright trim
			frame_top = Color("ffe27a")
			frame_bottom = Color("b0640a")
			frame_w = 40.0
			radius = 44.0
			ornate = true
			trim_top = Color("fffbe6")
			trim_bottom = Color("f2c24a")
			top_colour = Color("fff0c8")
			bottom_colour = Color("ecc884")
		&"loss":  # drained: smoked wood, old bronze, a dusty hide
			frame_top = Color("7a5a46")
			frame_bottom = Color("2e1c14")
			trim_top = Color("e8c896")
			trim_bottom = Color("8a6238")
			top_colour = Color("ece4d6")
			bottom_colour = Color("c2b6a2")
			bronze = true
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
		if ornate:  # the polish along the gold's top
			_fill(_rounded(Rect2(r.position + Vector2(radius * 0.6, 6.0), Vector2(r.size.x - radius * 1.2, 4.0)), 2.0),
					Color(1, 1, 0.92, 0.9), Color(1, 1, 0.92, 0.4))
		# the gold trim and the ink line inside it
		var trim := r.grow(-frame_w + TRIM)
		_fill(_rounded(trim.grow(1.5), radius - frame_w + TRIM + 1.5), INK, INK)
		_fill(_rounded(trim, radius - frame_w + TRIM), trim_top, trim_bottom)
		body = r.grow(-frame_w)
		inner = maxf(radius - frame_w, 4.0)
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
		_beadwork(r)
	else:  # glass: a light top edge and a fine gold line inside
		_fill(_rounded(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, minf(40.0, r.size.y * 0.25))), radius - 4),
				Color(1, 0.85, 0.6, 0.16), Color(1, 0.85, 0.6, 0.0))
		var line := _rounded(body.grow(-3.0), inner - 3.0)
		line.append(line[0])
		draw_polyline(line, Color(Ui.GOLD, 0.55), 2.0, true)


## The beadwork on the frame: a run of beads along the middle of each side, motif blocks set in it (two
## on the long sides, one on the short ones; off the title ribbon: top_clear), a beaded diamond over
## each corner where two runs meet. Two pictures (they batch). Dusty on a defeat.
func _beadwork(r: Rect2) -> void:
	var tint := Color(0.8, 0.75, 0.72) if bronze else Color.WHITE
	var mid := frame_w * 0.5
	var m := radius - (radius - mid) * 0.7071  # the frame's middle where it turns, from the corner
	var end := m + 8.0  # a run stops under its corner's diamond
	var top := [r.position + Vector2(end, mid), Vector2(r.end.x - end, r.position.y + mid)]
	var right := [Vector2(r.end.x - mid, r.position.y + end), r.end - Vector2(mid, end)]
	var bottom := [r.end - Vector2(end, mid), Vector2(r.position.x + end, r.end.y - mid)]
	var left := [Vector2(r.position.x + mid, r.end.y - end), r.position + Vector2(mid, end)]
	for run: Array in [top, right, bottom, left]:
		_band(run[0], run[1], tint)
	# the motif blocks: on a long top and foot two, a quarter of the way in from the middle (the same
	# places top and bottom, unless the ribbon covers the top's: then none there), on a shorter one one in
	# the middle (none on the top under a ribbon); one in the middle of each side if it is tall enough
	var block_w := BLOCK.size.x / BEAD_SCALE
	var long := r.size.x - end * 2.0
	var cx := r.get_center().x
	if long >= block_w * 5.5:
		var off := long * 0.28
		var room := long * 0.5 - block_w * 0.5 - 18.0  # the farthest a block's middle may be from a side's middle
		var cleared := top_clear * 0.5 + block_w * 0.5 + 22.0  # the nearest it may be under the ribbon
		var top_off := maxf(off, cleared) if top_clear > 0.0 else off
		var bottom_off := top_off if top_off <= room else off
		for k: float in [-1.0, 1.0]:
			if top_off <= room:
				_block(Vector2(cx + k * top_off, r.position.y + mid), 0.0, tint)
			_block(Vector2(cx + k * bottom_off, r.end.y - mid), 0.0, tint)
	elif long >= block_w * 1.6:
		if top_clear <= 0.0:
			_block(Vector2(cx, r.position.y + mid), 0.0, tint)
		_block(Vector2(cx, r.end.y - mid), 0.0, tint)
	if r.size.y - end * 2.0 > block_w * 3.0:
		for x: float in [r.position.x + mid, r.end.x - mid]:
			_block(Vector2(x, r.get_center().y), PI / 2, tint)
	var side := CORNER.size.x / BEAD_SCALE
	for c: Vector2 in [r.position + Vector2(m, m), Vector2(r.end.x - m, r.position.y + m),
			Vector2(r.position.x + m, r.end.y - m), r.end - Vector2(m, m)]:
		draw_texture_rect_region(MOTIFS, Rect2(c - Vector2(side, side) / 2, Vector2(side, side)), CORNER, tint)


## A run of the beads from `from` to `to`, centred on its middle.
func _band(from: Vector2, to: Vector2, tint: Color) -> void:
	var length := from.distance_to(to) * BEAD_SCALE
	if length < 8.0:
		return
	var h := float(BAND.get_height())
	var x0 := fposmod(-length * 0.5, float(BAND.get_width()))
	draw_set_transform(from, (to - from).angle(), Vector2.ONE / BEAD_SCALE)
	draw_texture_rect_region(BAND, Rect2(0.0, -h * 0.5, length, h), Rect2(x0, 0.0, length, h), tint)
	draw_set_transform(Vector2.ZERO)


## A motif block centred at `at`, along the run (turned by `angle`).
func _block(at: Vector2, angle: float, tint: Color) -> void:
	draw_set_transform(at, angle, Vector2.ONE / BEAD_SCALE)
	draw_texture_rect_region(MOTIFS, Rect2(-BLOCK.size * 0.5, BLOCK.size), BLOCK, tint)
	draw_set_transform(Vector2.ZERO)


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

class_name Card
extends PanelContainer
## The panel of the interface kit (pause, results, settings, About), as the pop-ups of top mobile
## games, in his world's materials: a deep shadow cast on the game behind, a dark ink outline, a thick
## frame of carved wood bevelled (lit along its top and outer edge, shaded at its foot), on the
## results a jewelled brass boss on each corner (a ring of beads, a red cabochon: corners.png;
## `bosses` off for the pause and settings: not one kit on every panel), a broad gold trim inside
## it, and a body of tanned hide (paper.png grain) that sinks under the frame (shade along its top,
## sides and foot, a soft light in its middle: it curves). Text on the body is dark brown. A mood
## (set_mood) gilds it for a win (a thicker polished gold frame, engraved), or darkens it to old
## bronze and dusty hide for a loss.
## The light variant (the start card, tutorial hints) is a see-through dark glass with a gold line.
## `well()` is the style of a sunken area inside the body (the results' counts, settings' rows).

const INK := Color("2e0d04")
const FRAME := 26.0  ## width of the wooden frame
const FRAME_TOP := Color("c8642a")
const FRAME_BOTTOM := Color("6e240a")
const TRIM := 6.0  ## the gold ring inside the frame
const TRIM_TOP := Color("ffe9a0")
const TRIM_BOTTOM := Color("e0901c")
const PAPER := preload("res://assets/art/ui/paper.png")
const CORNERS := preload("res://assets/art/ui/corners.png")  ## the corner bosses: brass, then bronze (tools/art/ui_kit.py)
const BOSS := 40.0  ## a corner boss, side in units (bigger ones read as heavy rivets)

var top_colour := Color("f6e4bc")  ## tanned hide, warm at the top
var bottom_colour := Color("dcb47c")  ## and darker towards its foot
var frame_top := FRAME_TOP  ## the frame's wood (a mood changes it: gold for a win, dark for a loss)
var frame_bottom := FRAME_BOTTOM
var trim_top := TRIM_TOP
var trim_bottom := TRIM_BOTTOM
var radius := 34.0
var bronze := false  ## a defeat's dark bronze bosses and studs instead of brass
var frame_w := FRAME  ## the frame's width (a win's is thicker)
var ornate := false  ## a win's frame: thick polished gold, an engraved line running round it
var bosses := true  ## the jewelled corner bosses and studs (the results' panels)
var inlays := false  ## an engraved gold inlay round each corner, its arms ending in diamonds (the pause)
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
## wood, a dull bronze trim and bosses, a dusty grey hide (the defeat drained, still of his warm
## world, not cold steel); anything else the wood.
func set_mood(mood: StringName) -> void:
	match mood:
		&"win":  # the biggest reward: a thick polished gold frame, engraved, a bright trim
			frame_top = Color("ffe27a")
			frame_bottom = Color("b0640a")
			frame_w = 36.0
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
		# the gold trim and the ink line inside it
		if ornate:  # an engraved line round the middle of the gold: a dark cut, its lit lower lip
			var cut := r.grow(-frame_w * 0.42)
			var cr := radius - frame_w * 0.42
			_outline(_rounded(cut.grow(1.5), cr + 1.5), Color(0.42, 0.2, 0.0, 0.75), 3.0)
			_outline(_rounded(Rect2(cut.position + Vector2(0, 2.0), cut.size).grow(1.5), cr + 1.5), Color(1, 0.96, 0.75, 0.55), 1.5)
			_fill(_rounded(Rect2(r.position + Vector2(radius * 0.6, 7.0), Vector2(r.size.x - radius * 1.2, 4.0)), 2.0),
					Color(1, 1, 0.92, 0.9), Color(1, 1, 0.92, 0.4))  # the polish along its top
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
		if bosses:
			_studs(r)
			_corners(r)
		if inlays:
			_inlays(r)
	else:  # glass: a light top edge and a fine gold line inside
		_fill(_rounded(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, minf(40.0, r.size.y * 0.25))), radius - 4),
				Color(1, 0.85, 0.6, 0.16), Color(1, 0.85, 0.6, 0.0))
		var line := _rounded(body.grow(-3.0), inner - 3.0)
		line.append(line[0])
		draw_polyline(line, Color(Ui.GOLD, 0.55), 2.0, true)


## The jewelled bosses on the four corners (corners.png), centred on the frame where it turns: one
## picture, four rects (they batch into one draw call).
func _corners(r: Rect2) -> void:
	var cell := float(CORNERS.get_height())
	var src := Rect2(cell if bronze else 0.0, 0.0, cell, cell)
	var m := radius - (radius - frame_w * 0.5) * 0.7071  # the frame's middle where it turns, from the corner
	for c: Vector2 in [r.position + Vector2(m, m), Vector2(r.end.x - m, r.position.y + m),
			Vector2(r.position.x + m, r.end.y - m), r.end - Vector2(m, m)]:
		draw_texture_rect_region(CORNERS, Rect2(c - Vector2(BOSS, BOSS) / 2, Vector2(BOSS, BOSS)), src)


## An engraved gold inlay round each corner, along the middle of the frame: a dark cut, its lit lip,
## each arm ending in a small gold diamond (the corner's detail, without rivets).
func _inlays(r: Rect2) -> void:
	var mid := frame_w * 0.5
	var arc_r := maxf(radius - mid, 2.0)
	var arm := 46.0
	var gems := PackedVector2Array()  # the eight diamonds, three shapes each, in one triangle array
	var gem_colours := PackedColorArray()
	var gem_idx := PackedInt32Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c := r.get_center() + Vector2(r.size.x / 2 - radius, r.size.y / 2 - radius) * corner
		var pts := PackedVector2Array()
		pts.append(c + Vector2(corner.x * arc_r, -corner.y * arm))  # along the side edge, into the corner
		for i in 9:  # round the corner
			var a := lerpf(0.0, PI / 2, i / 8.0)
			pts.append(c + Vector2(cos(a) * corner.x, sin(a) * corner.y) * arc_r)
		pts.append(c + Vector2(-corner.x * arm, corner.y * arc_r))  # and out along the top or foot
		var lip := PackedVector2Array()
		for q in pts:
			lip.append(q + Vector2(0, 1.6))
		draw_polyline(pts, Color(0.32, 0.12, 0.02, 0.8), 3.4, true)
		draw_polyline(lip, Color(1, 0.86, 0.5, 0.9), 1.6, true)
		for end: Vector2 in [pts[0], pts[pts.size() - 1]]:  # diamonds big enough to register on a phone
			var d := 8.5
			var o := d + 2.0
			var h := d * 0.5
			for quad: Array in [[Vector2(0, -o), Vector2(o, 0), Vector2(0, o), Vector2(-o, 0), Color("3a1606")],
					[Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0), Color("ffd060")],
					[Vector2(0, -d), Vector2(h, -h), Vector2.ZERO, Vector2(-h, -h), Color("fff2b8")]]:  # (its lit facet)
				var base := gems.size()
				for i in 4:
					gems.append(end + quad[i])
					gem_colours.append(quad[4])
				gem_idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), gem_idx, gems, gem_colours)


## Gold studs nailed into the middle of the frame's long edges on a wide card (the corners carry
## their bosses); dull bronze on a defeat.
func _studs(r: Rect2) -> void:
	if r.size.x <= 520.0:
		return
	var m := frame_w * 0.5
	var stud := _stud_texture()
	var tint := Color(0.78, 0.66, 0.54) if bronze else Color.WHITE
	for c: Vector2 in [Vector2(r.get_center().x, r.position.y + m), Vector2(r.get_center().x, r.end.y - m)]:
		draw_texture_rect(stud, Rect2(c - Vector2(STUD, STUD) / 2, Vector2(STUD, STUD)), false, tint)


const STUD := 16.0  ## a stud's picture, side in units
static var _stud: ImageTexture


## A gold stud drawn once (3x): its shadow, an ink ring, the gold, a lit dome, a glint.
static func _stud_texture() -> ImageTexture:
	if _stud:
		return _stud
	var s := 3.0
	var n := int(STUD * s)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) / 2
	var layers := [[Vector2(0, 2.0), 8.5, Color(0.1, 0.02, 0.0, 0.5)], [Vector2.ZERO, 8.0, INK],
			[Vector2.ZERO, 6.2, Color("c27a22")], [Vector2(-0.8, -1.0), 4.8, Color("ffd36b")],
			[Vector2(-2.1, -2.4), 1.9, Color(1, 1, 0.92, 0.95)]]
	for py in n:
		for px in n:
			var p := Vector2(px + 0.5, py + 0.5)
			var col := Color(0, 0, 0, 0)
			for l: Array in layers:
				var d: float = p.distance_to(c + (l[0] as Vector2) * s) / s
				var a := clampf(((l[1] as float) - d) * s + 0.5, 0.0, 1.0)
				var lc: Color = l[2]
				col = col.blend(Color(lc, lc.a * a))
			img.set_pixel(px, py, col)
	_stud = ImageTexture.create_from_image(img)
	return _stud


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


## Strokes the outline of points (closed) in one colour.
func _outline(pts: PackedVector2Array, colour: Color, width: float) -> void:
	pts.append(pts[0])
	draw_polyline(pts, colour, width, true)


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

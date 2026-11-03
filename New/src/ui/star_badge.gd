class_name StarBadge
extends Control
## A big shiny star (results, best run): a fat five-point star with a thick dark outline, a gold
## face lit from the top, a darker bevel along its lower edge and a glossy highlight on its upper
## left, a warm glow behind it and now and then a twinkle on a tip. Unlit, it is a socket carved
## into the panel: a dark inset with its shadow along the upper edges and a lit lip below, so an
## empty place reads on a dark panel.

const INK := Color("2e0d04")
const FACE_TOP := Color("fff47e")
const FACE_MID := Color("ffc61e")
const FACE_LOW := Color("f2860c")
const BEVEL := Color("b4520a")

var lit := true:
	set(value):
		lit = value
		queue_redraw()
var _clock := 0.0


func _init(side: float, is_lit := true) -> void:
	lit = is_lit
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	pivot_offset = size / 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(is_lit)
	if is_lit:  # a warm glow behind it
		var glow := TextureRect.new()
		glow.texture = Fx.glow_texture()
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.material = Fx.additive()
		glow.modulate = Color(1, 0.8, 0.35, 0.5)
		glow.size = Vector2(side, side) * 1.9
		glow.position = Vector2(side, side) / 2 - glow.size / 2
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.show_behind_parent = true
		add_child(glow)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## The ten corners of a star of outer radius `r` around `c` (points rounded off a little by the
## caller's outline).
static func points(c: Vector2, r: float, inner := 0.52) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * inner))
	return pts


func _draw() -> void:
	var side := minf(size.x, size.y)
	var o := maxf(side * 0.06, 2.5)  # outline thickness
	var c := size / 2 + Vector2(0, side * 0.04)
	var r := side * 0.5 - o
	if not lit:  # an empty socket pressed into the panel, in cool stone grey (never brown "dirt"):
		# a lit lip along its lower edges, a dark rim, the floor in the shade of its upper edges and
		# catching the light lower down, a faint star moulded in its middle
		draw_colored_polygon(points(c + Vector2(0, o * 0.8), r + o * 0.7), Color(1, 1, 0.97, 0.75))
		draw_colored_polygon(points(c, r + o * 0.7), Color(0.12, 0.08, 0.1))
		draw_colored_polygon(points(c, r - o * 0.2), Color(0.24, 0.2, 0.24))
		draw_colored_polygon(points(c + Vector2(0, o * 1.0), r - o * 1.1), Color(0.4, 0.36, 0.4))
		draw_colored_polygon(points(c + Vector2(0, o * 1.3), r - o * 2.0), Color(0.47, 0.43, 0.47))
		draw_colored_polygon(points(c + Vector2(0, o * 1.1), r * 0.36), Color(0.56, 0.52, 0.56, 0.8))
		return
	# the ink outline (a fatter star), the bevel under the face, then the face
	draw_colored_polygon(points(c + Vector2(0, o * 0.5), r + o * 1.15, 0.55), INK)
	draw_colored_polygon(points(c + Vector2(0, o * 0.55), r, 0.52), BEVEL)
	var face := points(c, r - o * 0.15, 0.52)
	var cols := PackedColorArray()
	for p in face:
		var t := clampf((p.y - (c.y - r)) / (r * 1.9), 0.0, 1.0)
		cols.append(FACE_TOP.lerp(FACE_MID, t * 1.6) if t < 0.6 else FACE_MID.lerp(FACE_LOW, (t - 0.6) / 0.4))
	draw_polygon(face, cols)
	# a lighter centre (the face bulges), and the gloss on the upper left
	draw_colored_polygon(points(c + Vector2(0, -r * 0.04), r * 0.5, 0.55), Color(1, 1, 0.85, 0.35))
	var gloss := PackedVector2Array()
	for i in 16:
		var a := i * TAU / 16
		gloss.append(c + Vector2(-r * 0.22, -r * 0.3) + Vector2(cos(a) * r * 0.2, sin(a) * r * 0.1).rotated(-0.6))
	draw_colored_polygon(gloss, Color(1, 1, 1, 0.7))
	# a twinkle that moves from tip to tip
	var t := _clock * 0.6 + c.x * 0.01
	var phase := fposmod(t, 2.5)
	if phase < 0.5:
		var tip := points(c, r)[(int(t / 2.5) % 5) * 2]
		var k := sin(phase / 0.5 * PI)
		var arm := r * 0.42 * k
		draw_line(tip - Vector2(arm, 0), tip + Vector2(arm, 0), Color(1, 1, 0.9, k), maxf(o * 0.45, 1.5), true)
		draw_line(tip - Vector2(0, arm), tip + Vector2(0, arm), Color(1, 1, 0.9, k), maxf(o * 0.45, 1.5), true)

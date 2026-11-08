class_name StarBadge
extends Control
## A big shiny star (results, best run): a fat five-point star with a fine warm rim, a gold face
## lit from the top, a lit bevel inside its edge, a darker bevel along its lower edge, a glossy
## highlight on its upper left, its shadow on the panel, a warm glow behind it, sparkles twinkling
## round it and now and then a twinkle on a tip. Unlit, a star not yet earned (UI r22, the judges of j18:
## r21's dark hollow "reads burnt / broken"): a pale greyed star, flat, in a soft grey-brown rim.

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
		glow.modulate = Color(1, 0.75, 0.3, 0.42)  # warm, not a white wash behind them
		glow.size = Vector2(side, side) * 1.9
		glow.position = Vector2(side, side) / 2 - glow.size / 2
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.show_behind_parent = true
		add_child(glow)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## A four-point glint: long arms fading to their tips around a white core.
func _glint(at: Vector2, arm: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 8:
		pts.append(at + Vector2.from_angle(i * PI / 4 - PI / 2) * (arm if i % 2 == 0 else arm * 0.2))
		cols.append(Color(1, 1, 0.9, 0.0 if i % 2 == 0 else alpha))
	draw_polygon(pts, cols)
	draw_circle(at, arm * 0.16, Color(1, 1, 0.95, alpha), true, -1, true)


## Fills a star's points with a vertical gradient from `top` (its top tip) to `bottom` (its feet).
func _gradient(pts: PackedVector2Array, c: Vector2, r: float, top: Color, bottom: Color) -> void:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - (c.y - r)) / (r * 1.8), 0.0, 1.0)))
	draw_polygon(pts, cols)


## The ten corners of a star of outer radius `r` around `c` (points rounded off a little by the
## caller's outline).
static func points(c: Vector2, r: float, inner := 0.52) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * inner))
	return pts


const RIM := Color("8a4004")  ## the lit star's edge: a fine warm brown, not a heavy ink line


func _draw() -> void:
	var side := minf(size.x, size.y)
	var o := maxf(side * 0.06, 2.5)  # outline thickness
	var c := size / 2 + Vector2(0, side * 0.04)
	var r := side * 0.5 - o
	if not lit:  # not yet earned (UI r22, the judges of j18: the dark hollow "reads burnt / broken"): a pale
		# greyed star, flat (no gloss, no glow), a soft grey-brown rim: plainly a star still to win
		draw_colored_polygon(points(c, r + o * 0.55, 0.55), Color(0.36, 0.28, 0.22, 0.5))  # its soft rim
		_gradient(points(c, r - o * 0.15, 0.53), c, r, Color(0.86, 0.82, 0.77, 0.62), Color(0.7, 0.65, 0.6, 0.62))  # greyed, see-through
		var inner := points(c, r - o * 0.95, 0.53)
		inner.append(inner[0])
		draw_polyline(inner, Color(1, 1, 1, 0.3), maxf(o * 0.3, 1.2), true)  # a faint bevel inside its edge
		return
	# its shadow on the panel, the ink outline (a fatter star), the bevel under the face, then the face
	draw_colored_polygon(points(c + Vector2(o * 0.5, o * 2.4), r + o * 0.5, 0.55), Color(0.3, 0.1, 0.0, 0.32))
	draw_colored_polygon(points(c + Vector2(0, o * 0.4), r + o * 0.6, 0.55), RIM)  # a fine warm rim
	draw_colored_polygon(points(c + Vector2(0, o * 0.55), r, 0.52), BEVEL)
	var face := points(c, r - o * 0.15, 0.52)
	var cols := PackedColorArray()
	for p in face:
		var t := clampf((p.y - (c.y - r)) / (r * 1.9), 0.0, 1.0)
		cols.append(FACE_TOP.lerp(FACE_MID, t * 1.6) if t < 0.6 else FACE_MID.lerp(FACE_LOW, (t - 0.6) / 0.4))
	draw_polygon(face, cols)
	var bevel := points(c, r - o * 0.8, 0.52)  # a lit bevel just inside its edge
	bevel.append(bevel[0])
	draw_polyline(bevel, Color(1, 1, 0.86, 0.55), maxf(o * 0.4, 1.2), true)
	# the gloss on the upper left (the face's gradient already lights its middle)
	var gloss := PackedVector2Array()
	for i in 16:
		var a := i * TAU / 16
		gloss.append(c + Vector2(-r * 0.22, -r * 0.3) + Vector2(cos(a) * r * 0.2, sin(a) * r * 0.1).rotated(-0.6))
	draw_colored_polygon(gloss, Color(1, 1, 1, 0.7))
	# sparkles round it, each twinkling on its own beat (never quite out: it reads as alive in a still)
	for g: Array in [[Vector2(0.62, -0.55), 0.0, 0.26], [Vector2(-0.7, -0.2), 1.9, 0.2], [Vector2(0.55, 0.62), 3.7, 0.16]]:
		var beat := 0.5 + 0.5 * sin(_clock * 3.1 + float(g[1]))
		_glint(c + (g[0] as Vector2) * r * 1.1, r * float(g[2]) * (0.7 + 0.3 * beat), 0.45 + 0.55 * beat)
	# a twinkle that moves from tip to tip
	var t := _clock * 0.6 + c.x * 0.01
	var phase := fposmod(t, 2.5)
	if phase < 0.5:
		var tip := points(c, r)[(int(t / 2.5) % 5) * 2]
		var k := sin(phase / 0.5 * PI)
		var arm := r * 0.42 * k
		draw_line(tip - Vector2(arm, 0), tip + Vector2(arm, 0), Color(1, 1, 0.9, k), maxf(o * 0.45, 1.5), true)
		draw_line(tip - Vector2(0, arm), tip + Vector2(0, arm), Color(1, 1, 0.9, k), maxf(o * 0.45, 1.5), true)

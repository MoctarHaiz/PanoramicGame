class_name Gesture
extends Control
## A move drawn as its gesture on a gold candy badge (the controls card, the pause panel, the
## tutorial): a fat white arrow with a ghosted trail behind it, outlined in ink; "top" ends under a
## vine across the badge's top (jump up to hang), "tap" is a dot with two rings. Each move has
## its own picture, so jump and hang never look alike. With `animated`, a hand plays the gesture
## over and over (the tutorial: the hand slides along the arrow, or taps).

enum Kind { TAP, UP, TOP, DOWN, RIGHT }

const HAND := preload("res://assets/icons/hand-pointing-fill.svg")
const INK := Color("2e0d04")
const PERIOD := 1.3  ## seconds per gesture of the hand

var kind := Kind.UP
var animated := false
var badge := true  ## the gold disc behind (off: the arrow alone, over the game)
var _t := 0.0


func _init(move := Kind.UP, side := 56.0, moving := false) -> void:
	kind = move
	animated = moving
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(moving)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Where the gesture goes, in shares of the badge: start, end.
func _path() -> Array:
	match kind:
		Kind.UP:
			return [Vector2(0.5, 0.8), Vector2(0.5, 0.24)]
		Kind.TOP:
			return [Vector2(0.5, 0.82), Vector2(0.5, 0.36)]
		Kind.DOWN:
			return [Vector2(0.5, 0.22), Vector2(0.5, 0.78)]
		Kind.RIGHT:
			return [Vector2(0.2, 0.5), Vector2(0.8, 0.5)]
	return [Vector2(0.5, 0.5), Vector2(0.5, 0.5)]


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := Vector2((size.x - s) / 2, (size.y - s) / 2)
	var c := o + Vector2(s, s) / 2
	var line := maxf(s * 0.045, 2.0)
	if badge:
		draw_circle(c + Vector2(0, s * 0.05), s * 0.5, Color(INK, 0.35), true, -1, true)
		draw_circle(c, s * 0.5, INK, true, -1, true)
		draw_circle(c, s * 0.5 - line, Color("e08a10"), true, -1, true)
		draw_circle(c - Vector2(0, s * 0.03), s * 0.5 - line * 1.6, Color("ffc93c"), true, -1, true)
		draw_circle(c - Vector2(s * 0.14, s * 0.2), s * 0.12, Color(1, 1, 0.9, 0.35), true, -1, true)
	if kind == Kind.TOP:  # the vine he will hang from, across the top
		var y := o.y + s * 0.2
		draw_line(o + Vector2(s * 0.14, s * 0.2), o + Vector2(s * 0.86, s * 0.2), INK, line * 3.2, true)
		draw_line(o + Vector2(s * 0.16, s * 0.2), o + Vector2(s * 0.84, s * 0.2), Color("6cbf2a"), line * 1.6, true)
		for k in 3:
			var lx := o.x + s * (0.28 + k * 0.22)
			draw_circle(Vector2(lx, y + line * 1.2), line * 1.3, Color("4e9a1e"), true, -1, true)
	if kind == Kind.TAP:
		var r := s * 0.12
		var pulse := fposmod(_t / PERIOD, 1.0) if animated else 0.6
		for k in 2:
			var rr := r * (1.6 + k * 0.9 + pulse * 0.6)
			draw_arc(c, rr, 0, TAU, 32, Color(1, 1, 1, 0.9 - k * 0.35 - pulse * 0.3), line * 1.4, true)
		draw_circle(c, r + line, INK, true, -1, true)
		draw_circle(c, r, Color.WHITE, true, -1, true)
	else:
		_arrow(o, s, line)
	if animated:
		_hand(o, s)


## The fat arrow along the path, its trail ghosted behind it.
func _arrow(o: Vector2, s: float, line: float) -> void:
	var p: Array = _path()
	var a: Vector2 = o + (p[0] as Vector2) * s
	var b: Vector2 = o + (p[1] as Vector2) * s
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	var w := s * 0.11
	var c := o + Vector2(s, s) / 2
	for k in 2:  # the ghosted trail: two fading dots where the finger came from
		var at := a - dir * w * (0.75 + k * 0.6)
		if at.distance_to(c) < s * 0.44 or not badge:
			draw_circle(at, w * (0.3 - k * 0.08), Color(1, 1, 1, 0.6 - k * 0.25), true, -1, true)
	var head := b - dir * w * 1.3
	var pts := PackedVector2Array([a + side * w * 0.5, head + side * w * 0.5, head + side * w * 1.25, b,
			head - side * w * 1.25, head - side * w * 0.5, a - side * w * 0.5])
	for poly in Geometry2D.offset_polygon(pts, line * 1.4, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(poly, INK)
	draw_colored_polygon(pts, Color.WHITE)


## The hand playing the gesture: it presses, slides along the arrow (or taps) and lifts.
func _hand(o: Vector2, s: float) -> void:
	var k := fposmod(_t / PERIOD, 1.0)
	var p: Array = _path()
	var at: Vector2
	var press := 1.0
	if kind == Kind.TAP:
		at = o + Vector2(0.5, 0.5) * s
		press = 1.0 - 0.15 * sin(clampf(k / 0.3, 0.0, 1.0) * PI)
		at.y += s * 0.06 * sin(clampf(k / 0.3, 0.0, 1.0) * PI)
	else:
		var u := smoothstep(0.15, 0.7, k)
		at = o + ((p[0] as Vector2).lerp(p[1], u)) * s
	var alpha := smoothstep(0.0, 0.1, k) * (1.0 - smoothstep(0.8, 1.0, k))
	var hs := s * 0.62 * press
	# the fingertip is at the top middle of the icon: it sits on the point
	var rect := Rect2(at + Vector2(-hs * 0.42, -hs * 0.08), Vector2(hs, hs))
	for i in 12:
		var d := Vector2.from_angle(TAU * i / 12) * maxf(s * 0.04, 2.0)
		draw_texture_rect(HAND, Rect2(rect.position + d, rect.size), false, Color(INK, alpha))
	draw_texture_rect(HAND, rect, false, Color(1, 1, 1, alpha))

class_name VineView
extends Node2D
## A liana along the top of the screen, moving with the level: where Panoramic hangs by his hands
## when a jump takes him to the top (the 2017 game drew a yellow bar there). Painted spans
## (tools/art/vine.py, VARIANTS of them, picked and mirrored by a fixed hash) between knots every
## SPAN units. Round 2: a thick liana with a sunlit edge, drawn in slices so it bends: it dips under
## his weight where he hangs (a damped spring: it gives on the catch, bounces, settles), springs
## back when he lets go, and stirs a little in the breeze.

const Y := -4.0  ## top of the spans (the rope's centre at its knots is 4 units below)
const SPAN := 160.0  ## level units between two knots
const TEXTURE := preload("res://assets/art/world/vine.png")
const VARIANTS := 5
const SLICES := 8  ## per span: the rope bends between them
const HOLD_DIP := 5.0  ## units the vine sags where he hangs, once it has settled
const CATCH_KICK := 170.0  ## units/s down when he catches it (it gives ~11 units, then bounces)
const STIFF := 230.0  ## the spring (1/s²): about 2.4 bounces a second
const DAMP := 7.0  ## (1/s): 2-3 bounces before it settles
const REACH := 95.0  ## units either side of his hands over which the vine bends
const SAG_MIN := 8.0  ## units a span hangs down between its knots (round 7: it still read straight), from ..
const SAG_MAX := 30.0  ## .. to (round 9: some spans nearly taut, some deep: even swags read as bunting)
const KNOT_RANGE := 6.0  ## units a knot is tied above or below the line
const KNOT_SHIFT := 0.28  ## round 9: share of SPAN a knot is tied off its even place (spans of uneven length)

var view_left := 0.0
var view_width := World.VIEW_W
var scroll := 0.0
## How far down the vine is where he hangs now (units): WorldView hangs him from it.
var dip := 0.0
var _dip_speed := 0.0
var _holding := false
var _hold_x := 0.0  # play x of his hands
var _clock := 0.0


## Each frame (WorldView): whether he hangs from the vine, and where (play x).
func hold(hanging: bool, x: float, delta: float) -> void:
	_holding = hanging
	if hanging:
		_hold_x = x
	_clock += delta
	var target := HOLD_DIP if hanging else 0.0
	_dip_speed += ((target - dip) * STIFF - _dip_speed * DAMP) * delta
	dip += _dip_speed * delta


## He has caught it: it gives under him.
func caught() -> void:
	_dip_speed += CATCH_KICK


func _process(_delta: float) -> void:
	queue_redraw()


## How far down the vine is at play x (units): each span hanging between its knots (round 4: knots
## at different heights, a different sag each: not a straight stripe under the HUD), his weight, and
## a slow breeze.
func sag_at(x: float) -> float:
	var lx := x + scroll
	var i := _span_at(lx)
	var a := _knot_x(i)
	var b := _knot_x(i + 1)
	var t := (lx - a) / (b - a)
	var knots := lerpf(_knot(i), _knot(i + 1), t)
	# (round 9: level at its knots, a smooth wave: the V at each knot read as bunting pinned up)
	var hang := pow(sin(PI * t), 2.0) * (SAG_MIN + (SAG_MAX - SAG_MIN) * _rand(i * 7 + 3)) * (b - a) / SPAN
	var weight := dip * exp(-pow((x - _hold_x) / REACH, 2.0))
	return knots + hang + weight + sin(_clock * 1.3 + lx * 0.021) * 0.8


## Round 9: a knot's level x by its index: tied every SPAN units, each off its even place.
func _knot_x(i: int) -> float:
	return (i + (_rand(i * 17 + 5) - 0.5) * 2.0 * KNOT_SHIFT) * SPAN


## The span (the index of its left knot) at level x.
func _span_at(lx: float) -> int:
	var i := floori(lx / SPAN)
	if lx < _knot_x(i):
		return i - 1
	if lx >= _knot_x(i + 1):
		return i + 1
	return i


## A knot's height (units) by its index: the vine is tied higher and lower along its length.
func _knot(i: int) -> float:
	return (_rand(i * 13 + 1) - 0.5) * 2.0 * KNOT_RANGE


static func _rand(n: int) -> float:
	var v := sin(n * 12.9898) * 43758.5453
	return v - floorf(v)


func _draw() -> void:
	var x0 := -view_left - SPAN
	var x1 := view_width - view_left + SPAN
	var first := _span_at(x0 + scroll)
	var h := TEXTURE.get_height() / float(VARIANTS)
	var tw := float(TEXTURE.get_width())
	var th := float(TEXTURE.get_height())
	var draw_h := h / 2.0
	var white := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	for i in range(first, first + int((x1 - x0) / SPAN) + 2):
		var v := posmod(i * 7 + (i >> 2) * 3, VARIANTS)
		var mirrored := posmod(i * 5 + (i >> 1), 3) == 0  # now and then: no two spans alike
		var left := _knot_x(i) - scroll
		var length := _knot_x(i + 1) - _knot_x(i)  # (round 9: each span its own length, the picture stretched)
		for k in SLICES:
			var a := left + length * k / SLICES
			var b := left + length * (k + 1) / SLICES
			var ua := float(k) / SLICES
			var ub := float(k + 1) / SLICES
			if mirrored:
				ua = 1.0 - ua
				ub = 1.0 - ub
			var ya := Y + sag_at(a)
			var yb := Y + sag_at(b)
			var top := v * h / th
			var bottom := (v + 1) * h / th
			draw_primitive(PackedVector2Array([Vector2(a, ya), Vector2(b, yb), Vector2(b, yb + draw_h), Vector2(a, ya + draw_h)]),
					white, PackedVector2Array([Vector2(ua, top), Vector2(ub, top), Vector2(ub, bottom), Vector2(ua, bottom)]),
					TEXTURE)

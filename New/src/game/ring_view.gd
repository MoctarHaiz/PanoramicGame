class_name RingView
extends Node2D
## Panoramic's throwing ring: a blue-steel chakram whose face carries a band of Zulu beadwork, red and black
## triangles on white (round 19: the old emblem "read as a brand logo"), its hole open (round 21: the grip bar across
## its middle "read as a steering wheel": a short leather grip on its inner lip now) and four hooked
## silver blades on its rim (round 20: ONE design everywhere, the key art's, the end screens' and this one;
## assets/art/fx/ring_spin.png, tools/art/ring_beadwork.py: 8 frames of a half turn), its ring 36 units across and
## its blades' tips 48, tumbling as it flies; a highlight racing
## round it, a flash where it leaves his hand, its wake swept from his hand behind it (WAKE_LEN) and now and
## then a spark shed into the air.

const RADIUS := 20.0
const DRAW_RADIUS := 25.0  ## half the frame drawn (round 20: the blades reach past the ring, ring_beadwork.py R_TIP)
const TEXTURE := preload("res://assets/art/fx/ring_spin.png")
const SPIN_FRAMES := 8  ## ring_spin.png: a half turn, side by side
const SPIN_FPS := 24.0
const TRAIL := 9  ## positions kept for its streak on its way back
## Its wake (blind round 14: "the ring is a small disc with a short white comet: give it a bold full-length motion arc
## from his hand across the gap, so the weapon and its path are the brightest, largest shape between the two
## figures"): one swept stroke from his throwing hand to the ring, as wide as the ring at the ring and a point at his
## hand, in three flat bands as a cel painter lays them (a red-orange rim, gold, a cream core: the blow's colours),
## two thin lines of speed beside it; WAKE_LEN at the longest, and what is left of it (WAKE_SHORT) once the ring is
## far from him. On its way back the same stroke follows its arc.
const WAKE_LEN := 250.0
const WAKE_SHORT := 130.0
const WAKE_HOLD := 0.34  ## seconds of flight it keeps its full length
const WAKE_STEPS := 16
const WAKE_TUCK := 14.5  ## units short of the ring's middle it ends: under its rim (its hole stays open)
const WAKE_RIM := Color("e4532b")
const WAKE_BODY := Color("ffbf47")
const WAKE_CORE := Color("fff6dc")
const WIND_UP := 0.04  ## seconds hidden while his hand swings back (HeroView.THROW_TIME)
const HOT := Color("e6f6ff")
## It leaves from his hand (the rules start it at his middle, ahead of him): drawn from this offset
## back to its place over its first HAND_TIME seconds.
const FROM_HAND := Vector2(-30.0, -18.0)
const HAND_TIME := 4.0 / 60.0
## (2026-11-12, the blind judge: "his hand releases at shoulder height, the ring first appears at hip height; edge-on
## it is a vertical line: not the same object as the one in his hand") Thrown on the run it leaves his thrown fist
## (WorldView sets `from_hand` from HeroView.THROW_FIST) and comes down to its lane over HAND_ARC seconds; it shows
## its face all the way (ring_spin.png's drawings near face-on, WOBBLE; the edge-on ones are not shown) and spins.
const HAND_ARC := 0.14
const WOBBLE: Array[int] = [0, 1, 2, 1, 0, 7, 6, 7]
const WOBBLE_WIDE := {0: 1.0, 1: 0.86, 2: 0.62, 6: 0.62, 7: 0.86}  ## how wide each of those drawings shows its face
const WOBBLE_FPS := 14.0
const SPIN := 15.0  ## radians a second it turns in its own plane

## The way back (blind round 11: "the hero's fist stops about 40 px short": with no ring in sight after the blow, his
## throw read as a punch that missed): the chakram that struck a bandit comes back to his hand, as a thrown chakram
## does: it stays on what it struck for the blow's freeze, then flies back over their heads in an arc, bigger at its
## top (nearer the eye), its streak behind it. Drawn only: the rules took the ring out when it struck.
const BACK_HOLD := 0.07  ## seconds on what it struck
const BACK_TIME := 0.34  ## seconds back to his hand
const BACK_UP := 120.0  ## units its way back rises over the straight line

signal caught(at: Vector2)  ## back in his hand (it is gone)

var from_hand := FROM_HAND
var hand_time := HAND_TIME
var hand: Callable  ## where his throwing hand is now (the parent's units): its wake starts there (WorldView)

var _clock := 0.0
var _glow: Node2D
var _wake: Node2D
var _trail: Array[Vector2] = []  # recent positions, in the parent's units
var _sparks: Array[Vector4] = []  # x, y (parent units), age, life
var _back := -1.0  # seconds since it struck a bandit (-1: flying out)
var _back_from := Vector2.ZERO
var _catch: Callable  # where his hand is now (the parent's units)


func _init() -> void:
	_wake = Node2D.new()
	_wake.draw.connect(_draw_wake)
	_wake.show_behind_parent = true
	add_child(_wake)
	_glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	_glow.show_behind_parent = true
	add_child(_glow)


func _process(delta: float) -> void:
	_clock += delta
	if _back >= 0.0:
		_back += delta
		var t := clampf((_back - BACK_HOLD) / BACK_TIME, 0.0, 1.0)
		var e := t * t * (3.0 - 2.0 * t)
		var to: Vector2 = _catch.call()
		var top := (_back_from + to) * 0.5 + Vector2(0.0, -BACK_UP)
		position = _back_from.lerp(top, e).lerp(top.lerp(to, e), e)
		scale = Vector2.ONE * (1.0 + 0.35 * sin(e * PI))
		if t >= 1.0:
			caught.emit(position)
			queue_free()
			return
	var at := position + _hand()
	_trail.push_front(at)
	if _trail.size() > TRAIL:
		_trail.pop_back()
	if randf() < delta * 14.0:
		_sparks.append(Vector4(at.x + randf_range(-6, 6), at.y + randf_range(-10, 10), 0.0, randf_range(0.18, 0.32)))
	for i in range(_sparks.size() - 1, -1, -1):
		var s := _sparks[i]
		s.z += delta
		s.y += delta * 30.0
		_sparks[i] = s
		if s.z > s.w:
			_sparks.remove_at(i)
	queue_redraw()
	_wake.queue_redraw()
	_glow.queue_redraw()


## (collision pass) It met a bandit or rock (WorldView): drawn where it met it, no longer easing out of his hand
## (a ring stopped in its first tenth of a second was drawn up to 30 units short of what it hit).
func met() -> void:
	_clock = maxf(_clock, WIND_UP + hand_time)


## It struck a bandit at its place now: it comes back to his hand (`catch`: where that is, asked every frame).
func rebound(catch: Callable) -> void:
	met()
	_back = 0.0
	_back_from = position
	_catch = catch


## The drawing of ring_spin.png shown now.
func _frame() -> int:
	return WOBBLE[int(_clock * WOBBLE_FPS) % WOBBLE.size()]


## How wide the ring shows as it turns (1: face-on).
func _turn() -> float:
	return WOBBLE_WIDE[_frame()]


## Where it is drawn from its place in the rules: still on its way out of his hand.
func _hand() -> Vector2:
	var t := clampf((_clock - WIND_UP) / hand_time, 0.0, 1.0)
	return from_hand * (1.0 - t) * (1.0 - t)


func _draw() -> void:
	if _clock < WIND_UP:
		return
	var hand := _hand()
	draw_set_transform(hand, _clock * SPIN)
	var f := _frame()
	var px := TEXTURE.get_height()
	draw_texture_rect_region(TEXTURE, Rect2(-DRAW_RADIUS, -DRAW_RADIUS, DRAW_RADIUS * 2, DRAW_RADIUS * 2), Rect2(f * px, 0, px, px))
	var spin := _clock * 18.0
	draw_set_transform(hand, 0.0, Vector2(_turn(), 1.0))
	draw_arc(Vector2.ZERO, DRAW_RADIUS * 0.67, spin, spin + 0.7, 12, Color(HOT, 0.55), 1.6, true)  # a glint running round the steel
	draw_set_transform(Vector2.ZERO)


## The way its wake runs, from its tail to the ring (the parent's units); empty when there is none to draw.
func _wake_path() -> PackedVector2Array:
	var path := PackedVector2Array()
	var head := position + _hand()
	if _back >= 0.0 or not hand.is_valid():  # on its way back (or thrown by no hand): where it has just been
		if _trail.size() < 3:
			return path
		for i in range(_trail.size() - 1, -1, -1):
			path.append(_trail[i])
		return path
	head.x -= WAKE_TUCK * _turn()  # (it ends under the ring's rim, the hole open on what is behind it)
	var gap: Vector2 = head - hand.call()
	if gap.x < 26.0:
		return path
	var flight := _clock - WIND_UP
	var keep := lerpf(WAKE_LEN, WAKE_SHORT, smoothstep(WAKE_HOLD, WAKE_HOLD + 0.25, flight))
	var k := minf(1.0, keep / gap.length())
	# (it leaves his hand downward and levels on its lane: far from him, what is left of it is level)
	var tail := Vector2(head.x - gap.x * k, head.y - gap.y * k * k)
	var turn := Vector2(lerpf(tail.x, head.x, 0.45), head.y)
	for i in WAKE_STEPS + 1:
		var u := float(i) / WAKE_STEPS
		path.append(tail.lerp(turn, u).lerp(turn.lerp(head, u), u))
	return path


## One band of its wake along `path` on `on`: `half` units to each side at the ring, a point where it starts (`from`:
## how far along the path that is, 0 to 1).
func _band(on: Node2D, path: PackedVector2Array, half: float, from: float, colour: Color) -> void:
	var n := path.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var cols := PackedColorArray()
	for i in n:
		var v := clampf((float(i) / (n - 1) - from) / (1.0 - from), 0.0, 1.0)
		var way := path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]
		var across := way.orthogonal().normalized() if way.length_squared() > 0.01 else Vector2.UP
		var p := on.to_local(get_parent().to_global(path[i]))
		var w := half * pow(v, 0.62) * (0.5 if i == n - 1 and _back < 0.0 else 1.0)
		left.append(p + across * w)
		right.append(p - across * w)
		cols.append(Color(colour, colour.a * smoothstep(0.0, 0.22, v)))
	var uv := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	for i in n - 1:
		if cols[i + 1].a <= 0.0:
			continue
		# (a primitive, not a polygon: nothing to triangulate, so a piece of no length, held on what it struck, or
		# one twisted at the turn of its arc draws as nothing instead of failing)
		on.draw_primitive(PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]]),
				PackedColorArray([cols[i], cols[i + 1], cols[i + 1], cols[i]]), uv)


func _draw_wake() -> void:
	if _clock < WIND_UP:
		return
	var path := _wake_path()
	if path.size() < 3:
		return
	var fade := 1.0 if _back < 0.0 else 0.85
	_band(_wake, path, RADIUS * 1.02, 0.0, Color(WAKE_RIM, 0.92 * fade))
	_band(_wake, path, RADIUS * 0.76, 0.1, Color(WAKE_BODY, fade))
	_band(_wake, path, RADIUS * 0.44, 0.24, Color(WAKE_CORE, fade))
	# two lines of speed beside it
	var n := path.size()
	for line: Array in [[-1.42, 0.3, 0.78], [1.36, 0.48, 0.94]]:
		var pts := PackedVector2Array()
		for i in n:
			var u := float(i) / (n - 1)
			if u < line[1] or u > line[2]:
				continue
			var way := path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]
			var across := way.orthogonal().normalized() if way.length_squared() > 0.01 else Vector2.UP
			pts.append(_wake.to_local(get_parent().to_global(path[i])) + across * RADIUS * float(line[0]) * pow(u, 0.62))
		if pts.size() > 1:
			_wake.draw_polyline(pts, Color(WAKE_CORE, 0.8 * fade), 2.2, true)


func _draw_glow() -> void:
	if _clock < WIND_UP:
		return
	# its wake's heart, hot
	var path := _wake_path()
	if path.size() > 2:
		_band(_glow, path, RADIUS * 0.56, 0.16, Color(1.0, 0.74, 0.36, 0.3))
	# (round 4: no pale halo round it, no launch disc: it read as a pool float; a steel ring)
	# sparks shed into the air
	for s in _sparks:
		var p := _glow.to_local(get_parent().to_global(Vector2(s.x, s.y)))
		var a := 1.0 - s.z / s.w
		_glow.draw_circle(p, 1.6 + a, Color(1.0, 0.9, 0.62, a))

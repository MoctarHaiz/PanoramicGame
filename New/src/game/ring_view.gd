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
## figures"): one swept stroke from his throwing hand to the ring; WAKE_LEN at the longest, and what is left of it
## (WAKE_SHORT) once the ring is far from him. On its way back the same stroke follows its arc.
## Blind round 15 (of that stroke in three flat bands as wide as the ring: "a fat, flat banana, a flamethrower sticker,
## the loudest thing on screen": "a thin, tapered, semi-transparent painted smear that fades to nothing at the hand
## and leaves the ring crisp at its head"): a dry brush's smear, narrower than the ring: six thin strands over a faint
## wash (WAKE_STRANDS), each starting at its own place along the way and all closing on one another toward his hand,
## where they are gone to nothing; half see-through at the ring.
## Blind round 16 (of that smear: "a thin pale-yellow hair that vanishes on the pale grass"; "chakram about 1.5 times
## larger with a bold tapered wake that has real value contrast against the grass"): between the two: a tapered
## wedge a little narrower than the ring, a point at his hand; a deep red under-stroke gave it its value
## against the pale grass, its dry strands over it hot orange outside and cream at its heart. The ring itself grows as
## it leaves his hand (FLIGHT_GROW: toward the eye, into its lane) and is back to his hand's size when he catches it.
## Blind round 17 ("a thick, flat orange wedge with a hard red underside"): the red under-stroke is gone (the hillside
## behind the path is in the dusk's shade now: the smear has its value against it by itself) and every band is soft
## across (_band): a smear of light, hot at its heart.
## Blind round 18 ("its wake a short soft orange puff"): the smear holds its strength longer toward his hand (it was
## nearly gone over its first half) on a fuller wash, its strands starting sooner.
const FLIGHT_GROW := 1.4
const WAKE_LEN := 250.0
const WAKE_SHORT := 130.0
const WAKE_HOLD := 0.34  ## seconds of flight it keeps its full length
const WAKE_STEPS := 16
const WAKE_TUCK := 14.5  ## units short of the ring's middle it ends: under its rim (its hole stays open)
const WAKE_HALF := RADIUS * 0.56  ## half its width at the ring (grown: FLIGHT_GROW): inside the ring's own height, lying flat (FLAT)
const WAKE_TAPER := 0.9  ## how its width closes toward his hand (1: a straight wedge)
const WAKE_BODY := Color("ff9a36")
const WAKE_TONES: Array[Color] = [Color("e9582a"), Color("ffb23e"), Color("fff0cf")]  # its strands: hot orange outside, cream at its heart
## Its strands, as a dry brush leaves them: where each lies across it at the ring (-1 to 1), its half width (a share
## of WAKE_HALF), how far along the wake it starts (0 at his hand), how solid it is, its tone (WAKE_TONES).
const WAKE_STRANDS := [[-0.8, 0.16, 0.28, 0.84, 0], [-0.46, 0.22, 0.12, 0.9, 1], [-0.12, 0.26, 0.02, 0.97, 2],
		[0.24, 0.24, 0.06, 0.95, 2], [0.56, 0.2, 0.18, 0.88, 1], [0.82, 0.15, 0.32, 0.8, 0]]
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
const SPIN := 15.0  ## radians a second it turns in its own plane
## Blind round 19 (of the ring in flight: "a perfect face-on circle at the end of the wake, like a UI icon rather than
## a spinning blade"): it flies as a thrown disc does, seen from a little over its edge: its face (ring_spin.png's
## first drawing, the one in his hand) flattened to FLAT of its height (rocking between the two), tipped TIP radians
## into its way, turning in its own plane, its blades smeared behind their turn (SMEAR: fainter copies, each a step of
## the turn back). It leaves his hand face-on and lies down into its flight as it grows.
const FLAT := Vector2(0.5, 0.64)
const FLAT_ROCK := 9.0  ## radians a second it rocks between them
const TIP := -0.2
const SMEAR := [[0.34, 0.2], [0.17, 0.42]]  ## [radians back, opacity], the faintest first

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
		# (bigger at the top of its way back, down to his hand's size as he takes it)
		scale = Vector2.ONE * lerpf(1.0, 1.0 / FLIGHT_GROW, e) * (1.0 + 0.2 * sin(e * PI))
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


## How much of its height shows (1: face-on, in his hand; FLAT in flight).
func _flat() -> float:
	var out := clampf((_clock - WIND_UP) / maxf(hand_time, 0.01), 0.0, 1.0)
	return lerpf(1.0, lerpf(FLAT.x, FLAT.y, 0.5 + 0.5 * sin(_clock * FLAT_ROCK)), out * (2.0 - out))


## How big it is drawn (1: as in his hand): growing as it leaves his hand.
func _grow() -> float:
	var t := clampf((_clock - WIND_UP) / maxf(hand_time, 0.01), 0.0, 1.0)
	return lerpf(1.0, FLIGHT_GROW, t * (2.0 - t))


## Where it is drawn from its place in the rules: still on its way out of his hand.
func _hand() -> Vector2:
	var t := clampf((_clock - WIND_UP) / hand_time, 0.0, 1.0)
	return from_hand * (1.0 - t) * (1.0 - t)


func _draw() -> void:
	if _clock < WIND_UP:
		return
	var hand := _hand()
	var r := DRAW_RADIUS * _grow()
	var flat := _flat()
	var plane := Transform2D(TIP * (1.0 - flat) / (1.0 - FLAT.x), Vector2(1.0, flat), 0.0, hand)  # (tipped as it lies down)
	var px := TEXTURE.get_height()
	var face := Rect2(0, 0, px, px)
	for smear: Array in SMEAR:
		draw_set_transform_matrix(plane * Transform2D(_clock * SPIN - float(smear[0]), Vector2.ZERO))
		draw_texture_rect_region(TEXTURE, Rect2(-r, -r, r * 2, r * 2), face, Color(1, 1, 1, float(smear[1]) * (1.0 - flat) / (1.0 - FLAT.x)))
	draw_set_transform_matrix(plane * Transform2D(_clock * SPIN, Vector2.ZERO))
	draw_texture_rect_region(TEXTURE, Rect2(-r, -r, r * 2, r * 2), face)
	var spin := _clock * 18.0
	draw_set_transform_matrix(plane)
	draw_arc(Vector2.ZERO, r * 0.67, spin, spin + 0.7, 12, Color(HOT, 0.55), 1.6, true)  # a glint running round the steel
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
	head.x -= WAKE_TUCK * _grow()  # (it ends under the ring's rim, the hole open on what is behind it)
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
## how far along the path that is, 0 to 1), `shift` units off the path's line at the ring.
func _band(on: Node2D, path: PackedVector2Array, half: float, from: float, colour: Color, shift := 0.0) -> void:
	var n := path.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var mid := PackedVector2Array()
	var cols := PackedColorArray()
	for i in n:
		var u := float(i) / (n - 1)
		var v := clampf((u - from) / (1.0 - from), 0.0, 1.0)
		var way := path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]
		var across := way.orthogonal().normalized() if way.length_squared() > 0.01 else Vector2.UP
		# (its strands close on one another toward his hand: `shift` is where this one lies at the ring)
		var p := on.to_local(get_parent().to_global(path[i])) + across * shift * pow(u, 0.8)
		var w := half * pow(v, WAKE_TAPER) * (0.5 if i == n - 1 and _back < 0.0 else 1.0)
		left.append(p + across * w)
		right.append(p - across * w)
		mid.append(p)
		# gone to nothing at his hand, full only near the ring
		cols.append(Color(colour, colour.a * smoothstep(0.0, 0.3, v) * pow(u, 0.75)))
	var uv := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	for i in n - 1:
		if cols[i + 1].a <= 0.0:
			continue
		# (a primitive, not a polygon: nothing to triangulate, so a piece of no length, held on what it struck, or
		# one twisted at the turn of its arc draws as nothing instead of failing)
		# (blind round 17: "a thick, flat orange wedge with a hard red underside": each band is soft across, full along
		# its middle and gone at its two edges, as a brush's smear is)
		var clear_a := Color(cols[i], 0.0)
		var clear_b := Color(cols[i + 1], 0.0)
		on.draw_primitive(PackedVector2Array([left[i], left[i + 1], mid[i + 1], mid[i]]),
				PackedColorArray([clear_a, clear_b, cols[i + 1], cols[i]]), uv)
		on.draw_primitive(PackedVector2Array([mid[i], mid[i + 1], right[i + 1], right[i]]),
				PackedColorArray([cols[i], cols[i + 1], clear_b, clear_a]), uv)


func _draw_wake() -> void:
	if _clock < WIND_UP:
		return
	var path := _wake_path()
	if path.size() < 3:
		return
	var fade := 1.0 if _back < 0.0 else 0.85
	var half := WAKE_HALF * _grow()
	_band(_wake, path, half * 1.1, 0.04, Color(WAKE_BODY, 0.5 * fade))  # a soft wash under its strands
	for strand: Array in WAKE_STRANDS:
		_band(_wake, path, half * float(strand[1]), strand[2], Color(WAKE_TONES[int(strand[4])], float(strand[3]) * fade),
				half * float(strand[0]))


func _draw_glow() -> void:
	if _clock < WIND_UP:
		return
	# its wake's heart, hot
	var path := _wake_path()
	if path.size() > 2:
		_band(_glow, path, WAKE_HALF * _grow() * 0.4, 0.3, Color(1.0, 0.8, 0.5, 0.2))
	# (round 4: no pale halo round it, no launch disc: it read as a pool float; a steel ring)
	# sparks shed into the air
	for s in _sparks:
		var p := _glow.to_local(get_parent().to_global(Vector2(s.x, s.y)))
		var a := 1.0 - s.z / s.w
		_glow.draw_circle(p, 1.6 + a, Color(1.0, 0.9, 0.62, a))

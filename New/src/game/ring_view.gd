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
## Blind round 21 (of the throw: "the ring is small and down in the grass tufts at ankle height", its wake "a straight
## airbrushed orange-to-cream beam from fingertip to ring, a laser in a soft language foreign to the ink": "the ring
## about 1.5 times larger at chest height on a curved, ink-drawn tapering wake"): it flies bigger (FLIGHT_GROW 1.4 ->
## 1.85) and LIFT units over its lane in the rules (his chest's height, not his hip's: drawn only), and its wake is
## drawn as the characters are: a slim blade of two flat tones, a point at his hand, an ink line along both its edges,
## curving down from his hand to its flight, two short ink strokes of speed beside it. No soft light.
## Blind round 22 ("a face-on disc as big as the hero's torso, tied to his fingertip by a flat orange-cream blade: an
## icon on a ribbon"): 1.5 times its size, lying flatter (FLAT), its wake a thrown arc that starts clear of his hand
## (WAKE_FREE of the way from it) and bows over the straight line (WAKE_BOW of its length).
## Round 23's check, of that: "too small and thin, so there is no impact weight", "the straight flat beam … a curved
## inked arc that does not touch the fingertip": 1.7 times, a little less flat, its wake the last six tenths of the way,
## bowed a quarter of its length (FLIGHT_GROW 1.5, FLAT 0.4 to 0.52, WAKE_FREE 0.2, WAKE_BOW 0.11, WAKE_HALF 8 before).
const FLIGHT_GROW := 1.7
const LIFT := 15.0
const WAKE_LEN := 250.0
const WAKE_SHORT := 130.0
const WAKE_HOLD := 0.34  ## seconds of flight it keeps its full length
const WAKE_STEPS := 16
const WAKE_TUCK := 14.5  ## units short of the ring's middle it ends: under its rim (its hole stays open)
const WAKE_HALF := 10.0  ## half its width at the ring: a blade well inside the ring's own height
const WAKE_TAPER := 0.9  ## how its width closes toward his hand (1: a straight wedge)
const WAKE_FREE := 0.4  ## of the way from his hand to the ring: where its point is at the nearest
const WAKE_BOW := 0.27  ## of its length: how high its middle bows over the straight line
const WAKE_BODY := Color("ff9a36")  ## its blade's outer tone
const WAKE_CORE := Color("fff1d2")  ## ... and its heart
const WAKE_INK := Color(0.33, 0.1, 0.07)  ## its line: the blow's burst's (tools/art/kie/world.py IMPACT_INK)
const WAKE_LINE := 1.7  ## units wide
## Its strokes of speed: [units off the blade's middle at the ring, from, to (along the wake, 0 at his hand)].
const WAKE_SPEED := [[-17.0, 0.34, 0.74], [15.0, 0.5, 0.92]]
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
const FLAT := Vector2(0.46, 0.58)
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
var _lifted := 1.0  # how much of LIFT it keeps (it comes down to his hand on its way back)
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
		_lifted = 1.0 - e
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
	# (blind round 21: no soft sparks off it: a white dot in its open hole; its wake is ink now)
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
	var held := (1.0 - t) * (1.0 - t)
	return from_hand * held + Vector2(0.0, -LIFT * _lifted) * (1.0 - held)


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
		# (held on what it struck, it has no wake; flying back, its wake ends under its rim: its hole stays open)
		if _trail.size() < 3 or (_back >= 0.0 and _back < BACK_HOLD + 0.04):
			return path
		for i in range(_trail.size() - 1, -1, -1):
			if _trail[i].distance_to(_trail[0]) > WAKE_TUCK * FLIGHT_GROW * scale.x:
				path.append(_trail[i])
		return path
	head.x -= WAKE_TUCK * _grow()  # (it ends under the ring's rim, the hole open on what is behind it)
	var gap: Vector2 = head - hand.call()
	if gap.x < 26.0:
		return path
	var flight := _clock - WIND_UP
	var keep := lerpf(WAKE_LEN, WAKE_SHORT, smoothstep(WAKE_HOLD, WAKE_HOLD + 0.25, flight))
	var k := minf(1.0 - WAKE_FREE, keep / gap.length())
	# (it leaves his hand downward and levels on its lane: far from him, what is left of it is level; a thrown arc,
	# its middle bowed over the straight line)
	var tail := Vector2(head.x - gap.x * k, head.y - gap.y * k * k)
	var turn := Vector2(lerpf(tail.x, head.x, 0.45), head.y - WAKE_BOW * gap.length() * k)
	for i in WAKE_STEPS + 1:
		var u := float(i) / WAKE_STEPS
		path.append(tail.lerp(turn, u).lerp(turn.lerp(head, u), u))
	return path


## One flat blade of its wake along `path` on `on`: `half` units to each side at the ring, a point where it starts
## (`from`: how far along the path that is, 0 to 1), hard-edged; `line`: an ink line this wide along both its edges.
func _blade(on: Node2D, path: PackedVector2Array, half: float, from: float, colour: Color, line := 0.0) -> void:
	var n := path.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var u := float(i) / (n - 1)
		if u < from:
			continue
		var v := (u - from) / (1.0 - from)
		var way := path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]
		var across := way.orthogonal().normalized() if way.length_squared() > 0.01 else Vector2.UP
		var p := on.to_local(get_parent().to_global(path[i]))
		# (a blade: it swells from its point and closes a little under the ring's rim)
		var w := half * pow(v, WAKE_TAPER) * (0.6 if i == n - 1 and _back < 0.0 else 1.0)
		left.append(p + across * w)
		right.append(p - across * w)
	if left.size() < 2:
		return
	var uv := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	var cols := PackedColorArray([colour, colour, colour, colour])
	for i in left.size() - 1:
		# (a primitive, not a polygon: nothing to triangulate, so a piece of no length, held on what it struck, or
		# one twisted at the turn of its arc draws as nothing instead of failing)
		on.draw_primitive(PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]]), cols, uv)
	if line > 0.0:
		var ink := Color(WAKE_INK, colour.a)
		on.draw_polyline(left, ink, line, true)
		on.draw_polyline(right, ink, line, true)


## A stroke of speed beside its wake: an ink line `off` units off the path's line, from `from` to `to` along it,
## thin at both its ends.
func _stroke(on: Node2D, path: PackedVector2Array, off: float, from: float, to: float, alpha: float) -> void:
	var n := path.size()
	var points := PackedVector2Array()
	var cols := PackedColorArray()
	for i in n:
		var u := float(i) / (n - 1)
		if u < from or u > to:
			continue
		var way := path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]
		var across := way.orthogonal().normalized() if way.length_squared() > 0.01 else Vector2.UP
		points.append(on.to_local(get_parent().to_global(path[i])) + across * off * pow(u, 0.8))
		cols.append(Color(WAKE_INK, alpha * sin(PI * (u - from) / (to - from))))
	if points.size() > 1:
		on.draw_polyline_colors(points, cols, WAKE_LINE * 0.8, true)


func _draw_wake() -> void:
	if _clock < WIND_UP:
		return
	var path := _wake_path()
	if path.size() < 3:
		return
	var fade := 1.0 if _back < 0.0 else 0.85
	_blade(_wake, path, WAKE_HALF, 0.0, Color(WAKE_BODY, fade), WAKE_LINE)
	_blade(_wake, path, WAKE_HALF * 0.46, 0.22, Color(WAKE_CORE, fade))
	for speed: Array in WAKE_SPEED:
		_stroke(_wake, path, speed[0], speed[1], speed[2], 0.75 * fade)


func _draw_glow() -> void:
	if _clock < WIND_UP:
		return
	# (round 4: no pale halo round it, no launch disc: it read as a pool float; a steel ring)
	# sparks shed into the air
	for s in _sparks:
		var p := _glow.to_local(get_parent().to_global(Vector2(s.x, s.y)))
		var a := 1.0 - s.z / s.w
		_glow.draw_circle(p, 1.6 + a, Color(1.0, 0.9, 0.62, a))

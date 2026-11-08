class_name RingView
extends Node2D
## Panoramic's throwing ring: a blue-steel chakram whose face carries a band of Zulu beadwork, red and black
## triangles on white (round 19: the old emblem "read as a brand logo"), its hole open (round 21: the grip bar across
## its middle "read as a steering wheel": a short leather grip on its inner lip now) and four hooked
## silver blades on its rim (round 20: ONE design everywhere, the key art's, the end screens' and this one;
## assets/art/fx/ring_spin.png, tools/art/ring_beadwork.py: 8 frames of a half turn), its ring 36 units across and
## its blades' tips 48, tumbling as it flies; a highlight racing
## round it, a flash where it leaves his hand, a soft tapered streak of light behind it and now and
## then a spark shed into the air.

const RADIUS := 20.0
const DRAW_RADIUS := 25.0  ## half the frame drawn (round 20: the blades reach past the ring, ring_beadwork.py R_TIP)
const TEXTURE := preload("res://assets/art/fx/ring_spin.png")
const SPIN_FRAMES := 8  ## ring_spin.png: a half turn, side by side
const SPIN_FPS := 24.0
const TRAIL := 6  ## positions kept for the streak: a short motion streak, not a line between rings
const WIND_UP := 0.04  ## seconds hidden while his hand swings back (HeroView.THROW_TIME)
const HOT := Color("e6f6ff")
## It leaves from his hand (the rules start it at his middle, ahead of him): drawn from this offset
## back to its place over its first HAND_TIME seconds.
const FROM_HAND := Vector2(-30.0, -18.0)
const HAND_TIME := 4.0 / 60.0

var _clock := 0.0
var _glow: Node2D
var _trail: Array[Vector2] = []  # recent positions, in the parent's units
var _sparks: Array[Vector4] = []  # x, y (parent units), age, life


func _init() -> void:
	_glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	_glow.show_behind_parent = true
	add_child(_glow)


func _process(delta: float) -> void:
	_clock += delta
	_trail.push_front(position)
	if _trail.size() > TRAIL:
		_trail.pop_back()
	if randf() < delta * 14.0:
		_sparks.append(Vector4(position.x + randf_range(-6, 6), position.y + randf_range(-10, 10), 0.0, randf_range(0.18, 0.32)))
	for i in range(_sparks.size() - 1, -1, -1):
		var s := _sparks[i]
		s.z += delta
		s.y += delta * 30.0
		_sparks[i] = s
		if s.z > s.w:
			_sparks.remove_at(i)
	queue_redraw()
	_glow.queue_redraw()


## (collision pass) It met a bandit or rock (WorldView): drawn where it met it, no longer easing out of his hand
## (a ring stopped in its first tenth of a second was drawn up to 30 units short of what it hit).
func met() -> void:
	_clock = maxf(_clock, WIND_UP + HAND_TIME)


## How wide the ring shows as it turns (with ring_spin.png's frames: 1 face-on, ~0.2 edge-on).
func _turn() -> float:
	return 0.2 + 0.8 * absf(cos(_clock * SPIN_FPS / SPIN_FRAMES * PI))


func _draw() -> void:
	if _clock < WIND_UP:
		return
	var hand := FROM_HAND * (1.0 - clampf((_clock - WIND_UP) / HAND_TIME, 0.0, 1.0))
	draw_set_transform(hand)
	var f := int(_clock * SPIN_FPS) % SPIN_FRAMES
	var px := TEXTURE.get_height()
	draw_texture_rect_region(TEXTURE, Rect2(-DRAW_RADIUS, -DRAW_RADIUS, DRAW_RADIUS * 2, DRAW_RADIUS * 2), Rect2(f * px, 0, px, px))
	var spin := _clock * 18.0
	draw_set_transform(hand, 0.0, Vector2(_turn(), 1.0))
	draw_arc(Vector2.ZERO, DRAW_RADIUS * 0.67, spin, spin + 0.7, 12, Color(HOT, 0.55), 1.6, true)  # a glint running round the steel
	draw_set_transform(Vector2.ZERO)


func _draw_glow() -> void:
	if _clock < WIND_UP:
		return
	var k := _turn()
	# the streak behind it: a tapered band of blue light
	if _trail.size() > 2:
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var cols := PackedColorArray()
		for i in _trail.size():
			var p := _glow.to_local(get_parent().to_global(_trail[i]))
			var w := RADIUS * 0.75 * (1.0 - float(i) / _trail.size())
			left.append(p + Vector2(0, -w))
			right.append(p + Vector2(0, w))
		for i in _trail.size() - 1:
			var a := 0.35 * (1.0 - float(i) / _trail.size())
			var b := 0.35 * (1.0 - float(i + 1) / _trail.size())
			_glow.draw_polygon(PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]]),
					PackedColorArray([Color(0.3, 0.6, 1.0, a), Color(0.3, 0.6, 1.0, b), Color(0.3, 0.6, 1.0, b), Color(0.3, 0.6, 1.0, a)]))
	# the halo
	_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, 1.0))
	# (round 4: no pale halo round it, no launch disc: it read as a pool float; a steel ring)
	_glow.draw_set_transform(Vector2.ZERO)
	# sparks shed into the air
	for s in _sparks:
		var p := _glow.to_local(get_parent().to_global(Vector2(s.x, s.y)))
		var a := 1.0 - s.z / s.w
		_glow.draw_circle(p, 1.6 + a, Color(0.7, 0.9, 1.0, a))

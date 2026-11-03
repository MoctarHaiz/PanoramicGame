class_name RingView
extends Node2D
## Panoramic's throwing ring: a thick blue-steel ring with a glowing inner edge, rendered in 3D and
## lit like him (assets/art/fx/ring_spin.png, tools/art/blender/ring_render.py: 8 frames of a half
## turn), 40 units across, tumbling as it flies; around it a soft additive glow, a highlight racing
## round it, a flash where it leaves his hand, a soft tapered streak of light behind it and now and
## then a spark shed into the air.

const RADIUS := 20.0
const TEXTURE := preload("res://assets/art/fx/ring_spin.png")
const SPIN_FRAMES := 8  ## ring_spin.png: a half turn, side by side
const SPIN_FPS := 24.0
const TRAIL := 6  ## positions kept for the streak: a short motion streak, not a line between rings
const WIND_UP := 0.04  ## seconds hidden while his hand swings back (HeroView.THROW_TIME)
const HOT := Color("e6f6ff")

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


## How wide the ring shows as it turns (with ring_spin.png's frames: 1 face-on, ~0.2 edge-on).
func _turn() -> float:
	return 0.2 + 0.8 * absf(cos(_clock * SPIN_FPS / SPIN_FRAMES * PI))


func _draw() -> void:
	if _clock < WIND_UP:
		return
	var f := int(_clock * SPIN_FPS) % SPIN_FRAMES
	var px := TEXTURE.get_height()
	draw_texture_rect_region(TEXTURE, Rect2(-RADIUS, -RADIUS, RADIUS * 2, RADIUS * 2), Rect2(f * px, 0, px, px))
	var spin := _clock * 18.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_turn(), 1.0))
	draw_arc(Vector2.ZERO, RADIUS * 0.62, spin, spin + 0.9, 12, Color(HOT, 0.7), 2.0, true)
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
	for i in 2:  # (slimmer: the 3D ring carries its own glowing edge)
		_glow.draw_arc(Vector2.ZERO, RADIUS * 0.75, 0, TAU, 40, Color(0.2, 0.55, 1.0, 0.14 - i * 0.05), 8.0 + i * 6.0, true)
	_glow.draw_set_transform(Vector2.ZERO)
	# the flash where it leaves his hand
	if _clock < 0.12:
		var f := 1.0 - _clock / 0.12
		_glow.draw_circle(Vector2.ZERO, RADIUS * (1.2 + 1.4 * (1.0 - f)), Color(0.6, 0.85, 1.0, 0.5 * f))
	# sparks shed into the air
	for s in _sparks:
		var p := _glow.to_local(get_parent().to_global(Vector2(s.x, s.y)))
		var a := 1.0 - s.z / s.w
		_glow.draw_circle(p, 1.6 + a, Color(0.7, 0.9, 1.0, a))

class_name RingView
extends Node2D
## Panoramic's throwing ring, as on the hero sheet: a glowing blue ring that spins as it flies.
## The ring is painted (assets/art/fx/ring.png, tools/art/ring.py: a lit torus of blue light), 40
## units across, turning as it flies; around it a soft additive glow, a highlight racing round it,
## a flash where it leaves his hand, a soft tapered streak of light behind it and now and then a
## spark shed into the air.

const RADIUS := 20.0
const TEXTURE := preload("res://assets/art/fx/ring.png")
const TRAIL := 12  ## positions kept for the streak (it sells the speed)
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


## The ring turns as it flies: squeezed sideways, then wide again.
func _turn() -> float:
	return 0.55 + 0.45 * absf(cos(_clock * 14.0))


func _draw() -> void:
	if _clock < WIND_UP:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_turn(), 1.0))
	draw_texture_rect(TEXTURE, Rect2(-RADIUS, -RADIUS, RADIUS * 2, RADIUS * 2), false)
	var spin := _clock * 18.0
	draw_arc(Vector2.ZERO, RADIUS * 0.7, spin, spin + 0.9, 12, Color(HOT, 0.85), 2.4, true)
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
			var a := 0.55 * (1.0 - float(i) / _trail.size())
			var b := 0.55 * (1.0 - float(i + 1) / _trail.size())
			_glow.draw_polygon(PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]]),
					PackedColorArray([Color(0.3, 0.6, 1.0, a), Color(0.3, 0.6, 1.0, b), Color(0.3, 0.6, 1.0, b), Color(0.3, 0.6, 1.0, a)]))
		# a white-hot core line along the streak
		var core := PackedVector2Array()
		var core_cols := PackedColorArray()
		for i in _trail.size():
			core.append(_glow.to_local(get_parent().to_global(_trail[i])))
			core_cols.append(Color(0.9, 0.97, 1.0, 0.75 * (1.0 - float(i) / _trail.size())))
		_glow.draw_polyline_colors(core, core_cols, 3.0, true)
	# the halo
	_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, 1.0))
	for i in 4:
		_glow.draw_arc(Vector2.ZERO, RADIUS * 0.75, 0, TAU, 40, Color(0.2, 0.55, 1.0, 0.2 - i * 0.04), 10.0 + i * 7.0, true)
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

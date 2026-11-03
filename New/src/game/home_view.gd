class_name HomeView
extends Node2D
## HOME, at the end of the level (tools/art/home.py): a Zulu homestead on the last screen. A
## palisade, a granary and smaller huts at the back, a carved HOME signpost, and the main beehive
## hut whose doorway Panoramic walks into when he gets home (World.HOME_X). Round 2: the hut is
## bigger, its doorway taller than him and centred where he stops (he stands in it, nothing over
## him); the hut's wall right of the doorway, with its right post, is drawn in front of him
## (`front`, added by WorldView above the actors), so walking on in he goes behind the jamb.
## Firelight spills out of the doorway along the ground and the fire flares when he is home. Smoke
## rises from the apex. `back` and `front` are in level units.

const DIR := "res://assets/art/world/"
const LEFT := Level.WIDTH - World.VIEW_W  ## level x of the last screen (the camera stops here)
const GROUND := (Level.ROWS - 2) * Level.TILE  ## the top of the ground at the end
const DOOR_RIGHT := 840.0  ## play x of the doorway's right edge: he stops in it at 790 (World.HOME_X)

var back: Node2D
var yard: Node2D  ## over the ground's grass, under the actors (WorldView adds it after the ground)
var front: Node2D
var _glow: Sprite2D
var _fire: Node2D
var _spill: Sprite2D  # firelight on the ground before the doorway
var _clock := 0.0
var _welcome := 0.0  # the fire flares when he walks in (1 -> 0)


func build() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "home.json"))
	back = Node2D.new()
	back.name = &"HomeBack"
	front = Node2D.new()
	front.name = &"HomeFront"

	yard = Node2D.new()
	yard.name = &"HomeYard"
	var hut_info: Dictionary = info["home_hut"]
	var hut_left: float = LEFT + DOOR_RIGHT - float(hut_info["front_x"])
	# the back of the homestead: huts and a granary behind the palisade
	_put(back, "home_granary", LEFT + 330.0, 0.95, Color(0.9, 0.88, 0.9)).material = form(1.0)
	_put(back, "home_hut_small", LEFT + 1120.0, 0.9, Color(0.92, 0.9, 0.93)).material = form(1.0)
	_put(back, "home_hut_low", LEFT + 1400.0, 0.8, Color(0.86, 0.84, 0.9), true).material = form(1.0)
	_fence(back, LEFT + 120.0, LEFT + 680.0)
	_fence(back, LEFT + 960.0, LEFT + 1900.0)
	var sign_shadow := _put(back, "home_sign", LEFT + 556.0, 1.35, Color(0.08, 0.04, 0.06, 0.4))  # (round 6: its shadow)
	sign_shadow.skew = 0.35
	_put(back, "home_sign", LEFT + 548.0, 1.35, Color.WHITE).material = form(0.0, 0.6)
	_put(back, "home_pot", hut_left + float(hut_info["door_x"]) - 62.0, 1.0, Color.WHITE)
	# round 3: the homestead is alive: a cooking fire in the yard, and people at it who greet him
	_fire = Fire.new()
	_fire.position = Vector2(LEFT + 430.0, GROUND - 8.0)  # (on a hearth stone, over the grass blades)
	_fire.scale = Vector2(1.5, 1.5)
	back.add_child(_fire)
	var fire_smoke := _smoke()
	fire_smoke.position = _fire.position + Vector2(0, -26)
	fire_smoke.amount = 10
	back.add_child(fire_smoke)
	# (round 5: the family drawn at the fire read as placeholders two rounds running: gone)
	var path := _sprite("home_yard", 1.0)  # trodden earth up to the doorway
	path.position = Vector2(hut_left + float(hut_info["door_x"]) - 70.0, GROUND - 10.0 + 30.0)
	path.offset = Vector2(-path.texture.get_width() / 2.0, -path.texture.get_height())
	# (round 5: no patch of trodden earth: it read as his boots standing in the dirt under the grass
	# line; the grass runs on to the doorway)
	path.queue_free()
	_spill = _sprite("home_glow", 1.0)  # the fire's light on the ground before the doorway
	_spill.centered = true
	_spill.offset = Vector2.ZERO
	_spill.position = Vector2(hut_left + float(hut_info["door_x"]) + 10.0, GROUND + 6.0)
	_spill.scale = Vector2(3.6, 0.62)  # (round 2: a long warm pool along the ground)
	var spill_add := CanvasItemMaterial.new()
	spill_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_spill.material = spill_add
	yard.add_child(_spill)
	var shade := Sprite2D.new()  # the hut's shadow on the ground, falling to the right (round 4: over the
	shade.texture = TerrainView.cast_shade()  # grass of the yard, long: the sun is low on the left)
	shade.centered = false
	shade.modulate = Color(0.16, 0.08, 0.16, 0.6)
	var hut_w := float(hut_info["size"][0])
	shade.position = Vector2(hut_left + hut_w * 0.45, GROUND - 16.0)
	shade.scale = Vector2(hut_w * 1.3 / 64.0, 34.0 / 32.0)
	yard.add_child(shade)
	var hut := _sprite("home_hut", 1.0)
	hut.position = Vector2(hut_left, GROUND + 4.0)
	hut.material = form(1.0)
	back.add_child(hut)
	var smoke := _smoke()
	smoke.position = Vector2(hut_left + float(hut_info["size"][0]) / 2.0, GROUND + 4.0 - float(hut_info["size"][1]) + 18.0)
	back.add_child(smoke)
	# in front of him: the wall right of the doorway, the shade inside, the firelight on him
	var wall := _sprite("home_hut_front", 1.0)
	wall.position = hut.position + Vector2(float(hut_info.get("front_crop_x", 0.0)), 0.0)  # (stored cropped)
	front.add_child(wall)
	_glow = _sprite("home_glow", 1.0)
	_glow.centered = true
	_glow.offset = Vector2.ZERO
	_glow.position = Vector2(hut_left + float(hut_info["door_x"]) + 6.0, GROUND - 20.0)
	_glow.scale = Vector2(1.1, 0.8)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	back.add_child(_glow)  # the fire's glow in the doorway, behind him


func _process(delta: float) -> void:
	_clock += delta
	_welcome = maxf(_welcome - delta * 0.6, 0.0)
	if _glow:  # the fire inside breathes and flickers
		var f := 0.55 + 0.12 * sin(_clock * 2.3) + 0.08 * sin(_clock * 7.1) + 0.05 * sin(_clock * 13.7)
		# (round 5: dimmer and lower behind him: it washed out his silhouette in the doorway)
		_glow.modulate = Color(1, 1, 1, minf(f * 0.55 + 0.25 * _welcome, 0.7))
		_glow.scale = Vector2(0.9, 0.55) * (1.0 + 0.2 * _welcome)
		_spill.modulate = Color(1, 0.8, 0.55, minf(f * 0.75 + 0.3 * _welcome, 1.0))


## He is home: the fire flares up to welcome him.
func welcome() -> void:
	var t := create_tween()
	t.tween_interval(0.55)
	t.tween_property(self, "_welcome", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _sprite(name: String, k: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(DIR + name + ".png")
	s.centered = false
	s.scale = Vector2(k, k) * 0.5  # pictures are 2 px per unit
	s.offset = Vector2(0, -s.texture.get_height())
	return s


## New: the huts were painted flat ("no shadow side, no rim: a sticker"); form.gdshader lights each
## as a rounded form from the sun's side, darkens its foot and puts a warm rim on its sun edge.
static func form(dome: float, strength := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/game/form.gdshader")
	m.set_shader_parameter(&"dome", dome)
	m.set_shader_parameter(&"strength", strength)
	return m


## A picture standing on the ground, its foot centred at x.
func _put(layer: Node2D, name: String, x: float, k: float, colour: Color, flip := false) -> Sprite2D:
	var s := _sprite(name, k)
	s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
	s.position = Vector2(x, GROUND + 5.0)
	s.modulate = colour
	s.flip_h = flip
	layer.add_child(s)
	return s


## The palisade from x0 to x1. Round 3: in stretches of different height and wear, each from another
## part of its picture, with a gap now and then (it was one strip repeated at one height).
func _fence(layer: Node2D, x0: float, x1: float) -> void:
	var tex: Texture2D = load(DIR + "home_fence.png")
	var fence := Painted.new()
	var x := x0
	var i := 0
	while x < x1:
		var w := minf(90.0 + _rand(i, 1) * 150.0, x1 - x)
		var k := 0.8 + _rand(i, 2) * 0.42  # its height
		var shade := 0.8 + _rand(i, 3) * 0.14
		var src_x := _rand(i, 4) * (tex.get_width() - w * 2.0 / k)
		var h := tex.get_height() * 0.5 * k
		fence.items.append([tex, Rect2(x, GROUND + 6.0 - h, w, h), Rect2(src_x, 0, w * 2.0 / k, tex.get_height()),
				Color(shade, shade * 0.97, shade)])
		x += w + (14.0 + _rand(i, 5) * 20.0 if _rand(i, 6) < 0.25 else -2.0)
		i += 1
	fence.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	layer.add_child(fence)


## Pictures drawn once from regions: [texture, rect, source rect, colour].
class Painted extends Node2D:
	var items := []

	func _draw() -> void:
		for it: Array in items:
			draw_texture_rect_region(it[0], it[1], it[2], it[3])


static func _rand(i: int, k: int) -> float:
	var v := sin(i * 12.9898 + k * 78.233) * 43758.5453
	return v - floorf(v)


## Thin smoke from the hearth, rising through the thatch and leaning with the breeze.
func _smoke() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = Fx.puff_texture()
	p.amount = 16
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.direction = Vector2(0.25, -1)
	p.spread = 8.0
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 22.0
	p.gravity = Vector2(6, -2)
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.5
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 2.6))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color(0.9, 0.84, 0.8, 0.0), Color(0.88, 0.82, 0.8, 0.22), Color(0.86, 0.82, 0.88, 0.0)])
	p.color_ramp = fade
	return p


## Round 3: a cooking fire in the yard (drawn, no picture): a ring of stones, crossed logs, flames
## licking up and flickering, its light on the ground (home_glow.png, added).
class Fire extends Node2D:
	var _clock := 0.0
	var _glow: Sprite2D

	func _ready() -> void:
		_glow = Sprite2D.new()
		_glow.texture = load(DIR + "home_glow.png")
		_glow.scale = Vector2(1.6, 0.7)
		_glow.position = Vector2(0, -8)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = add
		add_child(_glow)
		_glow.show_behind_parent = true

	func _process(delta: float) -> void:
		_clock += delta
		_glow.modulate = Color(1, 0.75, 0.45, 0.55 + 0.1 * sin(_clock * 9.0) + 0.06 * sin(_clock * 23.0))
		queue_redraw()

	func _draw() -> void:
		# round 6: a campfire (the pot over it read as a black box): hearth stones, two crossed logs,
		# flame tongues over them
		for i in 7:  # flat stones, lit on top, in a ring
			var sx := (i - 3) * 7.5
			draw_set_transform(Vector2(sx, -2.0), 0.0, Vector2(1.0, 0.55))
			draw_circle(Vector2.ZERO, 5.0, Color(0.36, 0.3, 0.28))
			draw_circle(Vector2(-0.8, -1.8), 3.4, Color(0.62, 0.5, 0.42))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for side in [-1.0, 1.0]:  # the logs, crossed, their ends glowing
			var a := Vector2(-16.0 * side, -2.0)
			var b := Vector2(12.0 * side, -12.0)
			draw_line(a, b, Color(0.3, 0.17, 0.1), 5.0)
			draw_line(a + Vector2(0, -1.5), b + Vector2(0, -1.5), Color(0.55, 0.32, 0.18), 1.6)
			draw_circle(b, 2.6, Color(1.0, 0.55, 0.18))
		for i in 5:  # the flames: tongues swaying and stretching, a hot core in each
			var x := (i - 2) * 5.5
			var h := 24.0 + 8.0 * sin(_clock * (7.0 + i) + i * 1.7) + (8.0 if i == 2 else 0.0) - absf(i - 2) * 3.0
			var lean := sin(_clock * 3.1 + i) * 3.5 + 2.0
			var base := 6.0 - absf(i - 2) * 0.8
			draw_colored_polygon(PackedVector2Array([Vector2(x - base, -6), Vector2(x + base, -6), Vector2(x + lean * 0.5 + base * 0.6, -6 - h * 0.5),
					Vector2(x + lean, -6 - h), Vector2(x + lean * 0.5 - base * 0.6, -6 - h * 0.5)]), Color(1.0, 0.42, 0.1, 0.92))
			draw_colored_polygon(PackedVector2Array([Vector2(x - base * 0.5, -6), Vector2(x + base * 0.5, -6), Vector2(x + lean * 0.6, -6 - h * 0.62)]),
					Color(1.0, 0.86, 0.42, 0.95))

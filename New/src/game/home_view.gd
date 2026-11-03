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
## Round 3: people at the cooking fire (x from LEFT, units): kind, x, size, facing left
const VILLAGERS := [[&"woman", 380.0, 0.95, false], [&"child", 466.0, 0.9, true], [&"elder", 610.0, 0.92, true]]

var back: Node2D
var yard: Node2D  ## over the ground's grass, under the actors (WorldView adds it after the ground)
var front: Node2D
var _glow: Sprite2D
var _fire: Node2D
var _villagers: Array[Node2D] = []
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
	for v: Array in VILLAGERS:
		var person := Villager.new()
		person.kind = v[0]
		person.position = Vector2(LEFT + float(v[1]), GROUND + 6.0)
		person.scale = Vector2(float(v[2]) * (-1.0 if v[3] else 1.0), float(v[2]))
		back.add_child(person)
		_villagers.append(person)
	var path := _sprite("home_yard", 1.0)  # trodden earth up to the doorway
	path.position = Vector2(hut_left + float(hut_info["door_x"]) - 70.0, GROUND - 10.0 + 30.0)
	path.offset = Vector2(-path.texture.get_width() / 2.0, -path.texture.get_height())
	yard.add_child(path)
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
		_glow.modulate = Color(1, 1, 1, minf(f + 0.45 * _welcome, 1.0))
		_glow.scale = Vector2(1.1, 0.8) * (1.0 + 0.35 * _welcome)
		_spill.modulate = Color(1, 0.8, 0.55, minf(f * 0.75 + 0.3 * _welcome, 1.0))


## He is home: the people at the fire raise their arms, the fire flares up to welcome him.
func welcome() -> void:
	for v in _villagers:
		v.set(&"cheer", true)
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


## Round 3: a cooking fire in the yard: a ring of stones, flames licking up and flickering (drawn,
## no picture), a pot on three stones over it, its light on the ground (home_glow.png, added).
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
		for i in 5:  # the flames: tongues swaying and stretching, hot cores
			var x := (i - 2) * 6.0
			var h := 26.0 + 9.0 * sin(_clock * (7.0 + i) + i * 1.7) + (6.0 if i == 2 else 0.0)
			var lean := sin(_clock * 3.1 + i) * 4.0 + 3.0
			var base := 7.0 - absf(i - 2) * 1.2
			draw_colored_polygon(PackedVector2Array([Vector2(x - base, -4), Vector2(x + base, -4), Vector2(x + lean, -4 - h)]),
					Color(1.0, 0.45, 0.1, 0.9))
			draw_colored_polygon(PackedVector2Array([Vector2(x - base * 0.5, -4), Vector2(x + base * 0.5, -4), Vector2(x + lean * 0.6, -4 - h * 0.6)]),
					Color(1.0, 0.85, 0.4, 0.95))
		for i in 7:  # the stones
			var sx := (i - 3) * 8.0
			draw_circle(Vector2(sx, -2.0 - absf(i - 3) * 0.4), 5.5, Color(0.22, 0.15, 0.13))
			draw_circle(Vector2(sx - 1.5, -3.5), 2.2, Color(0.75, 0.42, 0.22))  # lit by the fire
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -30), Vector2(12, -30), Vector2(10, -16), Vector2(-10, -16)]),
				Color(0.16, 0.1, 0.09))  # the pot over it, in silhouette
		draw_line(Vector2(-13, -31), Vector2(13, -31), Color(0.85, 0.5, 0.25), 2.0)


## Round 3: one of the family at the fire, a silhouette against the evening (drawn, no picture): a
## warm rim on the side of the low sun, a coloured wrap; it sways a little and raises its arms when
## he is home (`cheer`). Units, standing on y 0, facing right.
class Villager extends Node2D:
	var kind := &"woman"
	var cheer := false
	var _clock := 0.0
	var _arms := 0.0  # 0 down .. 1 raised

	func _process(delta: float) -> void:
		_clock += delta
		_arms = move_toward(_arms, 1.0 if cheer else 0.0, delta * 4.0)
		queue_redraw()

	func _draw() -> void:
		var tall := 128.0 if kind == &"woman" else (82.0 if kind == &"child" else 134.0)
		var bob := sin(_clock * (2.0 if kind == &"child" else 1.2)) * 1.2 + (sin(_clock * 9.0) * 3.0 * _arms if cheer else 0.0)
		# round 4: shaded and lit, not cut-outs: a shadow tone, a lit mid-tone on the sun's side, a rim
		var dark := Color(0.3, 0.18, 0.16)
		var lit := Color(0.52, 0.33, 0.24)
		var rim := Color(0.98, 0.68, 0.38)
		var wrap := Color(0.62, 0.12, 0.1) if kind != &"child" else Color(0.85, 0.55, 0.15)
		var head := Vector2(0, -tall + 10.0 + bob)
		var waist := -tall * 0.5 + bob
		var hem := 17.0 if kind == &"woman" else (9.0 if kind == &"child" else 12.0)
		var body := PackedVector2Array([Vector2(-6, -tall + 19 + bob), Vector2(6, -tall + 19 + bob), Vector2(10, -tall + 24 + bob),
				Vector2(11, waist - 6), Vector2(9, waist + 4), Vector2(hem, -3), Vector2(hem * 0.4, 0), Vector2(-hem * 0.4, 0),
				Vector2(-hem, -3), Vector2(-9, waist + 4), Vector2(-11, waist - 6), Vector2(-10, -tall + 24 + bob)])
		var arm_up := _arms * 2.2
		var shoulder_l := Vector2(-9, -tall + 26 + bob)
		var shoulder_r := Vector2(9, -tall + 26 + bob)
		var hand_l := shoulder_l + Vector2(-6, 34).rotated(arm_up)
		var hand_r := shoulder_r + Vector2(6, 34).rotated(-arm_up)
		for pass_i in 2:  # the rim first, offset towards the sun (upper left), then the body over it
			var o := Vector2(-1.6, -1.6) if pass_i == 0 else Vector2.ZERO
			var c := rim if pass_i == 0 else dark
			draw_colored_polygon(_shift(body, o), c)
			draw_circle(head + o, 9.0 if kind != &"child" else 7.5, c)
			draw_line(shoulder_l + o, hand_l + o, c, 4.5)
			draw_line(shoulder_r + o, hand_r + o, c, 4.5)
			draw_circle(hand_l + o, 3.2, c)
			draw_circle(hand_r + o, 3.2, c)
			if kind == &"woman":  # a round clay pot carried on her head
				draw_circle(head + o + Vector2(0, -15), 9.5, c)
				draw_line(head + o + Vector2(-4, -24), head + o + Vector2(4, -24), c, 4.0)
			elif kind == &"elder":  # a staff
				draw_line(hand_r + o + Vector2(0, -50), hand_r + o + Vector2(2, 70), c, 4.0)
		# the lit side: the body again, narrower and to the left (a rounded form turned to the sun)
		var lit_body := PackedVector2Array()
		for q in body:
			lit_body.append(Vector2(q.x * 0.55 - 3.5, q.y))
		draw_colored_polygon(lit_body, lit)
		draw_circle(head + Vector2(-2.5, -1.5), (9.0 if kind != &"child" else 7.5) * 0.62, lit)
		if kind == &"woman":  # the clay pot: shaded round, lit on the left, a glint
			draw_circle(head + Vector2(-2.5, -17), 6.0, Color(0.72, 0.38, 0.22))
			draw_circle(head + Vector2(-4.5, -19), 1.8, Color(1.0, 0.82, 0.6))
		var band := PackedVector2Array([Vector2(-12.5, waist - 8), Vector2(12.5, waist - 8), Vector2(14, waist + 10), Vector2(-14, waist + 10)])
		draw_colored_polygon(band, wrap)
		draw_colored_polygon(PackedVector2Array([band[1], band[2], band[2] + Vector2(-9, 0), band[1] + Vector2(-8, 0)]), wrap.darkened(0.35))
		draw_line(Vector2(-12.5, waist - 8), Vector2(12.5, waist - 8), wrap.lightened(0.4), 1.5)

	func _shift(points: PackedVector2Array, o: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q in points:
			out.append(q + o)
		return out


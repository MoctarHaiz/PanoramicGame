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
var _pour: Sprite2D  # round 10: the light pouring out of the doorway onto the grass
var _fire_light: Sprite2D  # round 19: the campfire's light on the hut, the sign and the fence
var _fire_pool: Sprite2D  # round 19: and on the grass round it
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
	# (round 7: no shadow copy of the sign behind it: it read as a faint duplicate arrow)
	_put(back, "home_sign", LEFT + 548.0, 1.35, Color.WHITE).material = form(0.0, 0.6)
	_put(back, "home_pot", hut_left + float(hut_info["door_x"]) - 62.0, 1.0, Color.WHITE)
	# round 3: the homestead is alive: a cooking fire in the yard, and people at it who greet him
	_fire = Fire.new()
	_fire.position = Vector2(LEFT + 622.0, GROUND - 8.0)  # (round 7: by the hut, in the pushed-in shot)
	_fire.scale = Vector2(2.3, 2.3)  # (round 9: a little bigger: it reads at phone size; round 19: bigger still)
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
	# round 10: the hut's firelight pouring out of the doorway onto the grass before it, a fan from
	# the threshold (the doorway's rays read as "a cheap starburst, not light pouring out")
	_pour = Sprite2D.new()
	_pour.texture = load(DIR + "home_door_light.png")
	_pour.centered = false
	_pour.offset = Vector2(-128, 0)
	_pour.position = Vector2(hut_left + float(hut_info["door_x"]) + 4.0, GROUND - 14.0)
	_pour.scale = Vector2(0.9, 0.42)
	_pour.material = spill_add
	yard.add_child(_pour)
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
	# round 19 (the judges: "the campfire flat triangles casting no glow"): its light reaches the hut's
	# side, the sign's post and the fence (added over them), and pools warm on the grass round it
	_fire_light = _sprite("home_glow", 1.0)
	_fire_light.centered = true
	_fire_light.offset = Vector2.ZERO
	_fire_light.position = _fire.position + Vector2(10, -60)
	_fire_light.scale = Vector2(1.6, 1.3)
	_fire_light.material = spill_add
	back.add_child(_fire_light)
	_fire_pool = _sprite("home_glow", 1.0)
	_fire_pool.centered = true
	_fire_pool.offset = Vector2.ZERO
	_fire_pool.position = _fire.position + Vector2(6, 10)
	_fire_pool.scale = Vector2(1.3, 0.3)
	_fire_pool.material = spill_add
	yard.add_child(_fire_pool)
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
		_pour.modulate = Color(1, 0.9, 0.75, minf(0.45 + f * 0.35 + 0.3 * _welcome, 1.0))
		var flick := 0.08 * sin(_clock * 9.0) + 0.05 * sin(_clock * 23.0) + 0.03 * sin(_clock * 3.7)
		_fire_light.modulate = Color(1, 0.62, 0.3, 0.3 + flick + 0.12 * _welcome)
		_fire_pool.modulate = Color(1, 0.66, 0.34, 0.55 + flick * 1.5 + 0.15 * _welcome)


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
## licking up and flickering, its light on the ground (home_glow.png, added). Round 9 ("flat orange
## triangles"): flame tongues in three layers that curl and sway, each shading from a hot root to a
## transparent tip, a bed of glowing embers, the logs' bark and the stones lit by the fire from
## above, sparks rising.
class Fire extends Node2D:
	const OUTER := [Color(1.0, 0.36, 0.08, 0.9), Color(0.85, 0.12, 0.04, 0.0)]
	const MIDDLE := [Color(1.0, 0.62, 0.16, 0.95), Color(1.0, 0.36, 0.08, 0.0)]
	const CORE := [Color(1.0, 0.97, 0.7, 1.0), Color(1.0, 0.78, 0.3, 0.0)]
	var _clock := 0.0
	var _glow: Sprite2D
	var _light: Sprite2D  # its light on the fence and the yard round it

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
		# round 10 ("the campfire casts no light on the fence or ground"): a wide warm light round it
		_light = Sprite2D.new()
		_light.texture = _glow.texture
		_light.scale = Vector2(3.0, 1.8)
		_light.position = Vector2(0, -26)
		_light.material = add
		add_child(_light)
		_light.show_behind_parent = true
		add_child(_sparks())

	func _process(delta: float) -> void:
		_clock += delta
		var flicker := 0.1 * sin(_clock * 9.0) + 0.06 * sin(_clock * 23.0)
		_glow.modulate = Color(1, 0.75, 0.45, 0.75 + flicker)
		_light.modulate = Color(1, 0.6, 0.3, 0.22 + flicker * 0.5)
		queue_redraw()

	func _draw() -> void:
		var flick := 0.85 + 0.1 * sin(_clock * 11.0) + 0.05 * sin(_clock * 27.0)
		# the embers under the logs, glowing
		draw_set_transform(Vector2(0, -3.0), 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, 17.0, Color(0.55, 0.12, 0.04))
		draw_circle(Vector2.ZERO, 12.0, Color(0.95, 0.34, 0.08, flick))
		draw_circle(Vector2(1, -2), 6.0, Color(1.0, 0.72, 0.3, flick))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 7:  # flat stones in a ring, their tops lit by the fire, their feet dark
			var sx := (i - 3) * 7.5
			var near := 1.0 - absf(i - 3) / 4.0
			draw_set_transform(Vector2(sx, -2.0), 0.0, Vector2(1.0, 0.55))
			draw_circle(Vector2.ZERO, 5.2, Color(0.2, 0.14, 0.14))
			draw_circle(Vector2(0, -1.2), 4.2, Color(0.44, 0.32, 0.28))
			draw_circle(Vector2(signf(-sx) * 0.8, -2.4), 2.8, Color(0.95, 0.56, 0.3).lerp(Color(0.6, 0.46, 0.38), 1.0 - near))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for side in [-1.0, 1.0]:  # the logs, crossed: bark dark under, lit by the fire on top, glowing ends
			var a := Vector2(-17.0 * side, -2.0)
			var b := Vector2(11.0 * side, -13.0)
			draw_line(a, b, Color(0.18, 0.1, 0.07), 5.5)
			draw_line(a + Vector2(0, -1.2), b + Vector2(0, -1.2), Color(0.42, 0.24, 0.14), 2.6)
			draw_line(a.lerp(b, 0.45) + Vector2(0, -2.0), b + Vector2(0, -2.0), Color(1.0, 0.5, 0.2, 0.8 * flick), 1.2)
			draw_circle(a, 2.6, Color(0.24, 0.14, 0.1))  # its cut end, charred, an ember in it
			draw_circle(a + Vector2(0.4, -0.4), 1.1, Color(1.0, 0.5, 0.16, flick))
		# the flames: three layers of tongues, back to front (round 19: more, taller, licking higher)
		_tongues(8, 40.0, 6.5, 13.0, OUTER, 0.0)
		_tongues(5, 30.0, 5.2, 9.0, MIDDLE, 1.7)
		_tongues(3, 18.0, 3.8, 5.0, CORE, 3.1)

	## n flame tongues across `spread` units, `tall` at most, each `width` wide at its root, shading
	## from colours[0] at the root to colours[1] at the tip; they sway and stretch, each its own way.
	func _tongues(n: int, tall: float, width: float, spread: float, colours: Array, phase: float) -> void:
		for i in n:
			var u := (i + 0.5) / n * 2.0 - 1.0
			var x := u * spread
			var seed := i * 1.37 + phase
			var h := tall * (1.0 - absf(u) * 0.45) * (0.8 + 0.2 * sin(_clock * (7.0 + i) + seed * 3.0))
			var lean := sin(_clock * 3.1 + seed) * 3.0 + 1.5 + u * 3.0
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			var steps := 6
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for k in steps + 1:  # a centre line that sways and curls, the tongue round it
				var t := float(k) / steps
				var centre := Vector2(x + lean * t * t + sin(t * 3.2 + _clock * 6.0 + seed) * 1.6 * t, -5.0 - h * t)
				var half := width * (1.0 - t) * (1.0 - t * 0.3) + 0.2
				left.append(centre - Vector2(half, 0))
				right.append(centre + Vector2(half, 0))
			for k in steps + 1:
				pts.append(left[k])
				cols.append(colours[0].lerp(colours[1], pow(float(k) / steps, 1.3)))
			for k in range(steps, -1, -1):
				pts.append(right[k])
				cols.append(colours[0].lerp(colours[1], pow(float(k) / steps, 1.3)))
			draw_polygon(pts, cols)

	## Sparks rising from the fire, flickering out.
	func _sparks() -> CPUParticles2D:
		var p := CPUParticles2D.new()
		p.texture = load(DIR + "mote.png")  # (a soft glowing speck, 32 px)
		p.amount = 14
		p.lifetime = 1.3
		p.preprocess = 1.3
		p.position = Vector2(0, -14)
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(9, 3)
		p.direction = Vector2(0, -1)
		p.spread = 22.0
		p.initial_velocity_min = 22.0
		p.initial_velocity_max = 48.0
		p.gravity = Vector2(6, -14)
		p.scale_amount_min = 0.12
		p.scale_amount_max = 0.24
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		fade.colors = PackedColorArray([Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.55, 0.15, 0.9), Color(0.9, 0.25, 0.05, 0.0)])
		p.color_ramp = fade
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = add
		return p

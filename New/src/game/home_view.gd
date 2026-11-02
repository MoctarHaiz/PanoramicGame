class_name HomeView
extends Node2D
## HOME, at the end of the level (tools/art/home.py): a Zulu homestead on the last screen. A
## palisade, a granary and smaller huts at the back, a carved HOME signpost, and the main beehive
## hut whose low doorway Panoramic walks into when he gets home (World.HOME_X): the hut's wall
## right of the doorway and a deepening shade inside it are drawn in front of him (`front`, added
## by WorldView above the actors). He no longer walks in (drawn bigger than the 2017 sprite, he
## is taller than the low doorway and showed over its arch): he stops before it, lit by the fire,
## so `front` stays hidden. Firelight spills out of the doorway onto the ground and the fire flares
## when he is home. Smoke rises from the apex. `back` and `front` are in level units.

const DIR := "res://assets/art/world/"
const LEFT := Level.WIDTH - World.VIEW_W  ## level x of the last screen (the camera stops here)
const GROUND := (Level.ROWS - 2) * Level.TILE  ## the top of the ground at the end
const DOOR_RIGHT := 786.0  ## play x of the doorway's right edge: he is home at 790 (World.HOME_X)

var back: Node2D
var yard: Node2D  ## over the ground's grass, under the actors (WorldView adds it after the ground)
var front: Node2D
var _glow: Sprite2D
var _spill: Sprite2D  # firelight on the ground before the doorway
var _clock := 0.0
var _welcome := 0.0  # the fire flares when he walks in (1 -> 0)


func build() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "home.json"))
	back = Node2D.new()
	back.name = &"HomeBack"
	front = Node2D.new()
	front.name = &"HomeFront"
	front.visible = false  # he stops before the doorway: nothing of the hut is drawn over him
	yard = Node2D.new()
	yard.name = &"HomeYard"
	var hut_info: Dictionary = info["home_hut"]
	var hut_left: float = LEFT + DOOR_RIGHT - float(hut_info["front_x"])
	# the back of the homestead: huts and a granary behind the palisade
	_put(back, "home_granary", LEFT + 330.0, 0.95, Color(0.9, 0.88, 0.9))
	_put(back, "home_hut_small", LEFT + 1120.0, 0.9, Color(0.92, 0.9, 0.93))
	_put(back, "home_hut_low", LEFT + 1400.0, 0.8, Color(0.86, 0.84, 0.9), true)
	_fence(back, LEFT + 120.0, LEFT + 680.0)
	_fence(back, LEFT + 960.0, LEFT + 1900.0)
	_put(back, "home_sign", LEFT + 548.0, 1.35, Color.WHITE)
	_put(back, "home_pot", hut_left + float(hut_info["door_x"]) - 62.0, 1.0, Color.WHITE)
	var path := _sprite("home_yard", 1.0)  # trodden earth up to the doorway
	path.position = Vector2(hut_left + float(hut_info["door_x"]) - 70.0, GROUND - 10.0 + 30.0)
	path.offset = Vector2(-path.texture.get_width() / 2.0, -path.texture.get_height())
	yard.add_child(path)
	_spill = _sprite("home_glow", 1.0)  # the fire's light on the ground before the doorway
	_spill.centered = true
	_spill.offset = Vector2.ZERO
	_spill.position = Vector2(hut_left + float(hut_info["door_x"]) - 10.0, GROUND + 4.0)
	_spill.scale = Vector2(2.4, 0.5)
	var spill_add := CanvasItemMaterial.new()
	spill_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_spill.material = spill_add
	yard.add_child(_spill)
	var shade := Sprite2D.new()  # the hut's shadow on the ground, falling a little to the right
	shade.texture = TerrainView.soft_disc()
	shade.modulate = Color(0.16, 0.05, 0.1, 0.6)
	shade.position = Vector2(hut_left + float(hut_info["size"][0]) * 0.56, GROUND + 6.0)
	shade.scale = Vector2(float(hut_info["size"][0]) * 1.2, 40.0) / 64.0
	back.add_child(shade)
	var hut := _sprite("home_hut", 1.0)
	hut.position = Vector2(hut_left, GROUND + 4.0)
	back.add_child(hut)
	var smoke := _smoke()
	smoke.position = Vector2(hut_left + float(hut_info["size"][0]) / 2.0, GROUND + 4.0 - float(hut_info["size"][1]) + 18.0)
	back.add_child(smoke)
	# in front of him: the wall right of the doorway, the shade inside, the firelight on him
	var wall := _sprite("home_hut_front", 1.0)
	wall.position = hut.position
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


## He is home: the fire flares up to welcome him (after he has walked in).
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


## A picture standing on the ground, its foot centred at x.
func _put(layer: Node2D, name: String, x: float, k: float, colour: Color, flip := false) -> void:
	var s := _sprite(name, k)
	s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
	s.position = Vector2(x, GROUND + 5.0)
	s.modulate = colour
	s.flip_h = flip
	layer.add_child(s)


## The palisade from x0 to x1: its picture repeats along the ground.
func _fence(layer: Node2D, x0: float, x1: float) -> void:
	var tex: Texture2D = load(DIR + "home_fence.png")
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, (x1 - x0) * 2.0, tex.get_height())
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.scale = Vector2(0.5, 0.5)
	s.position = Vector2(x0, GROUND + 6.0 - tex.get_height() * 0.5)
	s.modulate = Color(0.88, 0.85, 0.88)
	layer.add_child(s)


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

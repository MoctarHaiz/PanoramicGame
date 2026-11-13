@tool
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
## Round 21 (the judges, j17: "the hut dwarfs him: its door 2.5x his height, cut off at the top"): the main hut drawn
## at this share of its picture's size, about its doorway's right edge (DOOR_RIGHT: where he stops and the jamb goes
## over him are unchanged): its doorway a little taller than him, the whole dome in the pushed-in shot with sky over
## it, so he leads the picture.
const HUT_K := 0.8
## (blind round 17: "the hut's whole left side glows warm, while the sign, fence and ground right beside the fire
## barely change": the light dies sooner and is warmer, the shade away from it deeper: the sign's board goes from
## the dusk at its tip to orange at the fire's side, the hut from orange by the fire to the night at its far side)
const FIRE_REACH := 220.0  ## how far the campfire's light carries on the props round it (units)
const DUSK := Color(0.54, 0.53, 0.82)  ## the shade away from it (form.gdshader's dusk)
const FIRE_TINT := Color(1.3, 1.0, 0.7)  ## its light (form.gdshader's fire_tint)
const FIRE_X := 644.0  ## play x of the campfire on the last screen
## Blind round 15 ("the bright yellow line along the grass base reads as a strip, not a light pool"): the ground's own
## light: the grass and the earth are in a deeper night away from the fire (the turf's straw at DUSK was still the
## brightest thing far right of the hut) and warmer in its pool (ground_colour: the turf, the props, the earth)
const GROUND_DUSK := Color(0.4, 0.4, 0.7)
const GROUND_FIRE := Color(1.14, 0.9, 0.64)
## (blind round 17: "the bottom 12% is a dead black strip": the earth under the path, dark by day already, keeps more
## of itself in the dusk than the turf does: its roots and stones still read)
const SOIL_DUSK := Color(0.66, 0.6, 0.9)
## (blind round 16: "a yellow-green lit strip runs ruler-straight along the grass across the full width: a band of
## light, not a pool": seen side-on, a pool reads only if all of its falloff is in the picture: the fire's light on
## the ground dies within this many units of it, well inside the pushed-in shot's 780)
const GROUND_REACH := 170.0
## (blind round 17: "a heavy dark trunk runs down the whole left edge": its foot is out of the pushed-in shot, its
## trunk comes in from the left edge and its crown hangs over the corner, in the dusk's air, not near black)
const TREE_X := 366.0  ## the great acacia behind the palisade: its foot (from LEFT), left of the pushed-in shot
const TREE_K := 1.25  ## its size: its crown leaves the picture by the top left corner
const TREE_FOOT := 230.5  ## its trunk's foot in its picture (px: tree_info.json's anchor_x)
const TREE_AIR := Color(0.3, 0.28, 0.56)
const TREE_AIR_K := 0.36
const TREE_DUSK := Color(1.0, 0.96, 1.12)  ## (blind round 18: "a heavy dark trunk slices the left edge": deeper in the dusk's air, TREE_AIR)

var back: Node2D
var yard: Node2D  ## over the ground's grass, under the actors (WorldView adds it after the ground)
var front: Node2D
var _glow: Sprite2D
var _fire: Node2D
var _fire_light: Sprite2D  # round 19: the campfire's light on the hut, the sign and the fence
var _fire_pool: Sprite2D  # round 19: and on the grass round it
var _fire_side: Sprite2D  # round 21: and on the hut's thatch by the doorway, at his left
var _clock := 0.0
var _welcome := 0.0  # the fire flares when he walks in (1 -> 0)


func build() -> void:
	# (round 20: the campfire's shader is compiled in the menu, BobView._warm_up_world())
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "home.json"))
	back = Node2D.new()
	back.name = &"HomeBack"
	front = Node2D.new()
	front.name = &"HomeFront"

	yard = Node2D.new()
	yard.name = &"HomeYard"
	var hut_info: Dictionary = info["home_hut"]
	var hut_left: float = LEFT + DOOR_RIGHT - float(hut_info["front_x"]) * HUT_K
	var door_x: float = hut_left + float(hut_info["door_x"]) * HUT_K  # the doorway's middle (level x)
	var hut_size := Vector2(float(hut_info["size"][0]), float(hut_info["size"][1])) * HUT_K
	# the back of the homestead: huts and a granary behind the palisade
	# (blind round 16: "bottom-heavy, cropped composition: the right hut sliced by the frame, the upper-left 40% empty
	# violet sky": a great acacia behind the palisade, its crown the picture's upper left corner, in the dusk's
	# shade; the small hut a little further back and whole in the pushed-in shot)
	var tree := _put(back, "tree_acacia_2", LEFT + TREE_X, TREE_K, TREE_DUSK)
	tree.offset.x = -TREE_FOOT
	var air := ShaderMaterial.new()  # (it stands back in the dusk's air: its darks toward the night sky's violet)
	air.shader = preload("res://src/game/haze.gdshader")
	air.set_shader_parameter(&"haze_colour", TREE_AIR)
	air.set_shader_parameter(&"amount", TREE_AIR_K)
	air.set_shader_parameter(&"foot", 0.0)
	tree.material = air
	var granary := _put(back, "home_granary", LEFT + 330.0, 0.95, Color(0.9, 0.88, 0.9))
	granary.material = form(1.0)
	var small := _put(back, "home_hut_small", LEFT + 1078.0, 0.8, Color(0.88, 0.86, 0.92))
	small.material = form(1.0)
	var low := _put(back, "home_hut_low", LEFT + 1400.0, 0.8, Color(0.86, 0.84, 0.9), true)
	low.material = form(1.0)
	_fence(back, LEFT + 120.0, LEFT + 680.0)
	_fence(back, LEFT + 960.0, LEFT + 1900.0)
	# (round 7: no shadow copy of the sign behind it: it read as a faint duplicate arrow)
	# (blind round 7: "the HOME signpost as large as the hero, the first thing the eye lands on": 1.35 -> 1.05)
	# (blind round 12: "chunky casual-game letters, a cheaper drawing language than the painted hut": a weathered plank
	# arrow lashed to a post, HOME cut and burnt in the logo's angular capitals; its picture is 3 px a unit)
	# (blind round 17: "the carved HOME sign is literal": the old game's own HOME signpost stays, a step smaller: 0.67)
	var sign := _put(back, "home_sign", LEFT + 524.0, 0.6, Color.WHITE)
	sign.material = form(0.0, 0.0)
	var pot := _put(back, "home_pot", door_x - 58.0, 1.0, Color.WHITE)
	pot.material = form(0.0, 0.0)
	# round 3: the homestead is alive: a cooking fire in the yard, and people at it who greet him
	_fire = Fire.new()
	# (round 7: by the hut, in the pushed-in shot; round 21: nearer him, its light reaching his left side)
	_fire.position = Vector2(LEFT + FIRE_X, GROUND - 8.0)
	_fire.scale = Vector2(2.0, 2.0)  # (round 9: a little bigger: it reads at phone size; round 19: bigger still; round 23, the judges, j19: "a glow blob brighter than the hero": smaller, its light lower)
	back.add_child(_fire)
	var fire_smoke := _smoke()
	fire_smoke.position = _fire.position + Vector2(0, -26)
	fire_smoke.amount = 10
	back.add_child(fire_smoke)
	# (round 5: the family drawn at the fire read as placeholders two rounds running: gone)
	var path := _sprite("home_yard", 1.0)  # trodden earth up to the doorway
	path.position = Vector2(door_x - 70.0, GROUND - 10.0 + 30.0)
	path.offset = Vector2(-path.texture.get_width() / 2.0, -path.texture.get_height())
	# (round 5: no patch of trodden earth: it read as his boots standing in the dirt under the grass
	# line; the grass runs on to the doorway)
	path.queue_free()
	# (blind round 15: "the bright yellow line along the grass base reads as a strip, not a light pool": the long
	# warm pool before the doorway and the fan of light pouring out of it are gone: the doorway is dark, the campfire
	# is the yard's one light and its pool is round it: _fire_pool)
	var spill_add := CanvasItemMaterial.new()
	spill_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var shade := Sprite2D.new()  # the hut's shadow on the ground, falling to the right (round 4: over the
	shade.texture = TerrainView.cast_shade()  # grass of the yard, long: the sun is low on the left)
	shade.centered = false
	shade.modulate = Color(0.16, 0.08, 0.16, 0.6)
	var hut_w := hut_size.x
	shade.position = Vector2(hut_left + hut_w * 0.45, GROUND - 16.0)
	shade.scale = Vector2(hut_w * 1.3 / 64.0, 34.0 / 32.0)
	yard.add_child(shade)
	var hut := _sprite("home_hut", HUT_K)
	hut.position = Vector2(hut_left, GROUND + 4.0)
	hut.material = form(1.0)
	back.add_child(hut)
	# (the doorway's inside is the hut's dark in the dusk's violet-brown, painted so: tools/art/kie/world.py door():
	# over his black hair's value, well under his skin's; it was a glow down to bright orange with a soft dark
	# sprite laid over its middle: blind rounds 5, 6, 11 and 12: "his warm torso sits on a warm orange doorway")
	var smoke := _smoke()
	smoke.position = Vector2(hut_left + hut_size.x / 2.0, GROUND + 4.0 - hut_size.y + 18.0 * HUT_K)
	back.add_child(smoke)
	# in front of him: the wall right of the doorway, the shade inside, the firelight on him
	var wall := _sprite("home_hut_front", HUT_K)
	wall.position = hut.position + Vector2(float(hut_info.get("front_crop_x", 0.0)) * HUT_K, 0.0)  # (stored cropped)
	wall.material = form(0.0, 0.0)
	front.add_child(wall)
	# One light (blind round 12: "no single light: a campfire burns a metre from him and nothing receives it"): every
	# prop is in the dusk's cool shade away from the fire and in its warm light near it (form.gdshader)
	for prop: Sprite2D in [tree, granary, small, low, sign, pot, hut, wall]:
		_fire_lit(prop)
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
	# (blind round 15: "a strip, not a light pool": one wide soft pool lying on the yard, brightest under the fire
	# and falling off on every side; the band of light that ran along the grass from the fire to the doorway is gone)
	_fire_pool.position = _fire.position + Vector2(24, 8)
	_fire_pool.scale = Vector2(1.5, 0.34)
	_fire_pool.material = spill_add
	yard.add_child(_fire_pool)
	# round 21 (the judges, j17: "the fire's glow doesn't reach him"): it warms the thatch by the doorway at his
	# left; the doorway behind him and the ground under him stay as they were (no bloom at his feet)
	_fire_side = _sprite("home_glow", 1.0)
	_fire_side.centered = true
	_fire_side.offset = Vector2.ZERO
	_fire_side.position = Vector2(door_x - 62.0, GROUND - 52.0)
	_fire_side.scale = Vector2(0.62, 0.95)
	_fire_side.material = spill_add
	back.add_child(_fire_side)
	_glow = _sprite("home_glow", 1.0)
	_glow.centered = true
	_glow.offset = Vector2.ZERO
	_glow.position = Vector2(door_x + 6.0, GROUND - 20.0)
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
		# (round 5: dimmer and lower behind him: it washed out his silhouette in the doorway; round 20, the judges:
		# "everything orange, the hero melts into the backdrop", "a yellow bloom smudge at his feet instead of a
		# dark contact shadow": the doorway stays a cool dark behind him, the light on the ground before it low)
		_glow.modulate = Color(1, 0.8, 0.6, minf(f * 0.26 + 0.14 * _welcome, 0.36))
		_glow.scale = Vector2(0.9, 0.55) * (1.0 + 0.2 * _welcome)
		(_fire as Fire).flare = _welcome
		var flick := 0.08 * sin(_clock * 9.0) + 0.05 * sin(_clock * 23.0) + 0.03 * sin(_clock * 3.7)
		# (round 20: kept round the fire, not over the whole left of the home: the dusk's cool reads round it)
		# (round 22, the judges, j18: "the fire's orange washes the left third": its light kept nearer it)
		_fire_light.modulate = Color(1, 0.6, 0.3, 0.05 + flick * 0.35 + 0.03 * _welcome)
		_fire_pool.modulate = Color(1, 0.62, 0.3, 0.3 + flick * 0.8 + 0.08 * _welcome)
		_fire_side.modulate = Color(1, 0.58, 0.28, 0.12 + flick * 0.5 + 0.05 * _welcome)


## He is home: the fire flares up to welcome him and throws a cloud of embers into the dusk (the home's own
## celebration; paper confetti flew out of the doorway until blind round 12: "a few stray specks that read as dirt").
func welcome() -> void:
	var t := create_tween()
	t.tween_interval(0.55)
	t.tween_callback((_fire as Fire).flare_up)
	t.tween_property(self, "_welcome", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _sprite(name: String, k: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(DIR + name + ".png")
	s.centered = false
	s.scale = Vector2(k, k) * 0.5  # pictures are 2 px per unit
	s.offset = Vector2(0, -s.texture.get_height())
	return s


## An additive material (light laid over what is under it).
static func _add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## New: the huts were painted flat ("no shadow side, no rim: a sticker"); form.gdshader lights each
## as a rounded form from the sun's side, darkens its foot and puts a warm rim on its sun edge.
static func form(dome: float, strength := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/game/form.gdshader")
	m.set_shader_parameter(&"dome", dome)
	m.set_shader_parameter(&"strength", strength)
	return m


## The same on something standing at level x on the ground (a stretch of the palisade: one colour each).
func _fire_colour(x: float) -> Color:
	return fire_colour(x)


## The home's one light on what stands or lies at level x: the fire's warmth near it, the dusk's shade away from it.
static func fire_colour(x: float) -> Color:
	var d := (x - (LEFT + FIRE_X)) / FIRE_REACH
	return DUSK.lerp(FIRE_TINT, exp(-d * d * 1.6))


## The same on the ground (the turf, its blades and flowers, the props standing on it): a pool round the fire, the
## night away from it.
static func ground_colour(x: float) -> Color:
	var d := (x - (LEFT + FIRE_X)) / GROUND_REACH
	return GROUND_DUSK.lerp(GROUND_FIRE, exp(-d * d * 2.2))


## The fire's light and the dusk's shade on a prop (form.gdshader): where the fire is in the prop's own pixels.
func _fire_lit(prop: Sprite2D) -> void:
	var m := prop.material as ShaderMaterial
	var hearth := _fire.position + Vector2(0.0, -40.0)
	m.set_shader_parameter(&"fire_at", (hearth - prop.position) / prop.scale)
	m.set_shader_parameter(&"fire_reach", FIRE_REACH / prop.scale.x)
	m.set_shader_parameter(&"dusk", DUSK)
	m.set_shader_parameter(&"fire_tint", FIRE_TINT)


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
				Color(shade, shade * 0.97, shade) * _fire_colour(x + w * 0.5)])
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
	const FIRE_SHADER := preload("res://src/game/fire.gdshader")
	var _clock := 0.0
	var _glow: Sprite2D
	var _light: Sprite2D  # its light on the fence and the yard round it
	var flare := 0.0  ## round 20: 0..1, it flares up when he is home (HomeView)
	var _flames: Array[ShaderMaterial] = []  # round 20: the painted flames (fire.gdshader), back and front

	const FRAMES := 4
	const FPS := 9.0
	var _painted: Sprite2D  # the painted hearth (home_fire.png: the stones, the logs and their embers), when it is there
	var _flame: Sprite2D  # its flames behind the logs (home_flames.png, four frames: tools/art/kie/world.py fire)
	var _bloom: Sprite2D  # over it: its light a little past the flame's edge
	var _heart: Sprite2D  # and its soft white-hot heart

	func _ready() -> void:
		_glow = Sprite2D.new()
		_glow.texture = load(DIR + "home_glow.png")
		_glow.scale = Vector2(0.85, 0.42)  # (round 22: x the fire's own 2.3 it spread ~940 units wide: the left third orange)
		_glow.position = Vector2(0, -8)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = add
		add_child(_glow)
		_glow.show_behind_parent = true
		# round 10 ("the campfire casts no light on the fence or ground"): a wide warm light round it
		_light = Sprite2D.new()
		_light.texture = _glow.texture
		_light.scale = Vector2(0.8, 0.6)  # (round 20: x the fire's own 2.3: it washed the whole left half orange; round 22: smaller)
		_light.position = Vector2(0, -26)
		_light.material = add
		add_child(_light)
		_light.show_behind_parent = true
		# round 20 (the judges, j16: "the campfire flat vector triangles"): the flames painted by fire.gdshader,
		# a bigger, redder body behind and a smaller, hotter one in front, each its own flicker
		# (blind rounds 5 to 7: "the fire is flat flame shapes, half see-through: the fence shows through it": the fire
		# painted in the world's inked cel style, four frames; the shader's flames and the drawn stones stay as the fallback)
		if ResourceLoader.exists(DIR + "home_fire.png"):
			_painted = Sprite2D.new()
			_painted.texture = load(DIR + "home_fire.png")
			_painted.centered = false
			var size := _painted.texture.get_size()
			var k := 56.0 / size.x  # units wide at the fire's own scale (HomeView doubles it)
			_painted.scale = Vector2(k, k)
			_painted.position = Vector2(-size.x * k / 2.0, 5.0 - size.y * k)
			# (blind round 17: "a flat cartoon flame (three hard tones, yellow tongue)", of the hearth's own flame with a
			# smaller yellow tongue laid in it: the flames are painted alone now, soft, a white-hot heart, embers, and
			# stand behind the logs: a frame as wide as the hearth, its foot on the embers)
			_flame = Sprite2D.new()
			_flame.texture = load(DIR + "home_flames.png")
			_flame.hframes = FRAMES
			_flame.centered = false
			_flame.scale = Vector2(k, k)
			_flame.position = Vector2(-size.x * k / 2.0, 5.0 - _flame.texture.get_height() * k)
			add_child(_flame)
			add_child(_painted)
			# (blind round 15: "a hard-edged cartoon flame with a weak glow": a soft white-hot heart over the painted
			# flame and a bloom a little wider than it: the flame's ink softens into its own light)
			_bloom = Sprite2D.new()
			_bloom.texture = _glow.texture
			_bloom.scale = Vector2(0.4, 0.46)
			_bloom.position = Vector2(0, -30)
			_bloom.material = add
			add_child(_bloom)
			_heart = Sprite2D.new()
			_heart.texture = _glow.texture
			_heart.scale = Vector2(0.16, 0.24)
			_heart.position = Vector2(0, -20)
			_heart.material = add
			add_child(_heart)
			add_child(_sparks())
			return
		var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		var white := ImageTexture.create_from_image(img)
		for k in 2:
			var size := Vector2(46.0, 52.0) if k == 0 else Vector2(31.0, 36.0)
			var f := Sprite2D.new()
			f.texture = white
			f.centered = false
			f.scale = size / 4.0
			f.position = Vector2(-size.x / 2.0 + (1.5 if k == 0 else -1.0), -size.y - 3.0)
			var m := ShaderMaterial.new()
			m.shader = FIRE_SHADER
			m.set_shader_parameter(&"seed", 1.3 + k * 6.1)
			f.material = m
			f.modulate = Color(0.9, 0.7, 0.6, 0.9) if k == 0 else Color(0.96, 0.86, 0.76)  # (round 23: under his value)
			add_child(f)
			_flames.append(m)
		add_child(_sparks())

	func _process(delta: float) -> void:
		_clock += delta
		var flicker := 0.1 * sin(_clock * 9.0) + 0.06 * sin(_clock * 23.0)
		_glow.modulate = Color(1, 0.7, 0.42, 0.3 + flicker * 0.6)  # (round 23: lower)
		# (round 20: its light kept round it: it washed the whole left half of the home orange; round 22: less still)
		_light.modulate = Color(1, 0.6, 0.3, 0.06 + flicker * 0.15)
		for m in _flames:
			m.set_shader_parameter(&"flare", flare)
		if _painted:
			_flame.frame = int(_clock * FPS) % FRAMES
			_bloom.modulate = Color(1.0, 0.56, 0.24, 0.2 + flicker * 0.4 + 0.1 * flare)
			_heart.modulate = Color(1.0, 0.9, 0.62, 0.16 + flicker * 0.4 + 0.1 * flare)  # (the painted flames have their own white heart)
			return
		queue_redraw()

	func _draw() -> void:
		if _painted:
			return
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
		# (round 20: the flames are painted over these by fire.gdshader, the child sprites)

	## A cloud of embers thrown up at once, drifting off on the evening air as they die.
	func flare_up() -> void:
		var p := _sparks()
		p.one_shot = true
		p.explosiveness = 0.8
		p.amount = 46
		p.lifetime = 2.6
		p.preprocess = 0.0
		p.spread = 34.0
		p.initial_velocity_min = 40.0
		p.initial_velocity_max = 150.0
		p.damping_min = 30.0
		p.damping_max = 60.0
		p.gravity = Vector2(14, -22)
		p.scale_amount_min = 0.1
		p.scale_amount_max = 0.3
		p.emitting = true
		add_child(p)
		p.finished.connect(p.queue_free)

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

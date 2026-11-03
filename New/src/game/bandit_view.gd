class_name BanditView
extends Node2D
## A bandit (World.Bandit): the masked raider, rendered in 3D from Panoramic's own mesh and rig in
## the same light (violet wraps, a mask with amber eyes, a teal crest, a club: tools/art/blender/
## hero_render.py --character bandit, packed by tools/art/bandit_sheet.py into assets/art/bandit/).
## Placed at its feet. It waits crouched and breathing until it enters the play window, then runs
## (16 frames played at the speed that keeps the planted boot still on the ground). As it closes on
## Panoramic it draws its club back over its head and swings it (a smeared blow), so the hit is
## seen coming. A ring makes it flash white and jolt back; after the first one it runs dazed (head
## lolling, stars circling it). The second knocks it out: it freezes on the blow, is thrown up and
## back spinning while its club flies off on its own, and drops out of the picture.
##
## Animation runs on the world's clock, so pause and hit-stop freeze it too.

const DIR := "res://assets/art/bandit/"
const FLASH_TIME := Fx.FLASH_TIME  ## New (audio): the shared impact's white, 2 frames, then the reaction shows
const KO_HOLD := 0.09  ## seconds frozen on the blow before the tumble
const KO_VELOCITY := Vector2(560, -820)  ## units/s on screen: thrown back (right) and up, fast
const KO_GRAVITY := 2600.0
const KO_SPIN := 15.0  ## radians/s
## Once it has struck him it can't again: it vaults over him (drawn only) instead of running
## through his body.
const VAULT_TIME := 0.46  ## seconds
const VAULT_HEIGHT := 150.0  ## units: over his head
const STAR_COUNT := 3
const FLIGHT_FRAME := 4  ## the run frame with both feet off the ground (hopping a wall, vaulting)

static var _data: Dictionary
static var _sheet: Texture2D
static var _club: Texture2D
static var _shade: Texture2D

## How far a running bandit's body reaches ahead of its centre (units): the club may touch a wall.
const REACH := 40.0

var world: World
var wall_shift := 0.0  ## held off a wall face it is pressed on (units, >= 0; WorldView eases it)
var bandit: World.Bandit
var _sprite: Sprite2D
var _material: ShaderMaterial
var _front: Node2D  # what is drawn over the sprite (the stars in front of the hood)
var _ground_shadow: Node2D
var _cols := 8
var _run_frames := 8
## The raider is drawn a quarter larger than its sheet (from the feet up): about three quarters of
## Panoramic's height, an adult rather than a child next to him. Its hit box (World.BANDIT_SIZE, the
## 2017 rules) is unchanged; rings meet it at chest height either way.
const DRAW_SCALE := 1.25

var _scale := 0.5
var _anchor := Vector2.ZERO
var _last_time := -1.0
var _run := 0.0  # position in the run cycle (frames)
var _breath := 0.0
var _flash := 0.0
var _jolt := 0.0  # units pushed back by the last ring, springing to 0
var _squash := Vector2.ONE
var _stars := 0.0  # 0..1: dazed stars showing
var _star_turn := 0.0
var _grounded := true
var _head := Vector2.ZERO  # the hood's middle in this frame, local units
# knocked out
var _ko := false
var _ko_time := 0.0
var _velocity := Vector2.ZERO
var _vault := -1.0  # 0..1 through the vault over him (-1: not vaulting)


static func load_art() -> void:
	if _sheet:
		return
	_data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "bandit.json"))
	_sheet = load(DIR + "bandit.png")
	_club = load(DIR + "club.png")
	var g := GradientTexture2D.new()
	g.width = 64
	g.height = 64
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.gradient = Gradient.new()
	g.gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.gradient.colors = PackedColorArray([Color(0.1, 0.04, 0.08, 0.62), Color(0.1, 0.04, 0.08, 0.32), Color(0.1, 0.04, 0.08, 0)])
	_shade = g


func _init(w: World, b: World.Bandit) -> void:
	world = w
	bandit = b
	load_art()
	_cols = int(_data.columns)
	_run_frames = int(_data.run_frames)
	_scale = DRAW_SCALE / float(_data.texture_scale)
	_anchor = Vector2(_data.anchor[0], _data.anchor[1])
	_sprite = Sprite2D.new()
	_sprite.texture = _sheet
	_sprite.hframes = _cols
	_sprite.vframes = int(_data.rows)
	_sprite.centered = false
	_sprite.offset = -_anchor
	_sprite.scale = Vector2.ONE * _scale
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/game/actor.gdshader")
	# as on Panoramic: a warm rim on its sun side and a thin dark edge, so it reads at phone size
	_material.set_shader_parameter(&"rim", 0.75)  # (the ink and a rim are in its cel-shaded render; the sun's edge here)
	_material.set_shader_parameter(&"rim_px", 2.0)
	_material.set_shader_parameter(&"rim_colour", Color(1.0, 0.8, 0.55))
	_material.set_shader_parameter(&"rim_dir", Vector2(-0.6, -0.8))
	_material.set_shader_parameter(&"outline_px", 0.0)
	_material.set_shader_parameter(&"outline_colour", Color(0.08, 0.03, 0.1, 0.85))
	_sprite.material = _material
	add_child(_sprite)
	_front = Node2D.new()
	_front.draw.connect(_draw_stars.bind(true))
	add_child(_front)
	# its shadow on the ground, over the grass blades in front of the runners (they hid it)
	_ground_shadow = Node2D.new()
	_ground_shadow.z_index = 1
	_ground_shadow.draw.connect(_draw_shadow)
	add_child(_ground_shadow)
	_run = float(b.id * 3 % _run_frames)
	_breath = b.id * 0.7
	_star_turn = b.id * 1.3


## Called by WorldView every frame while the bandit is in the game. `grounded`: not hopping a wall.
func show_state(grounded: bool) -> void:
	_grounded = grounded


## A ring hit it (knocked_out: the second one).
func hit(knocked_out: bool) -> void:
	_flash = 1.0
	_jolt = 9.0
	_squash = Vector2(1.22, 0.82)
	if knocked_out:
		_ko = true
		_ko_time = 0.0
		# it tumbles in the level, which scrolls toward him: add the scroll so it flies away on screen
		_velocity = KO_VELOCITY + Vector2(0.0 if world.blocked else World.SCROLL_SPEED / World.TICK, 0.0)
		_stars = 0.0
		var centre: Array = _data.ko_centres[0]
		_ko_pose(0, Vector2(centre[0], centre[1]))


## Ran off the left of the screen: fades away.
func leave() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)


func _process(delta: float) -> void:
	if _ko:
		_tumble(delta)
		return
	# the world's clock: frozen when the game is paused or held for a hit-stop
	var now := (world.ticks + world.alpha) * World.TICK
	var dt := 0.0 if _last_time < 0.0 else clampf(now - _last_time, 0.0, 0.1)
	_last_time = now
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)  # real time: 2 frames, even inside a hit-stop
	_jolt = lerpf(_jolt, 0.0, 1.0 - exp(-dt * 16.0))
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-dt * 13.0))
	_stars = move_toward(_stars, 1.0 if bandit.hurt else 0.0, dt * 4.0)
	_star_turn += dt * TAU * 1.4
	var row := 1 if bandit.hurt else 0
	var frame: int
	if not bandit.active:  # waiting to pounce: crouched, breathing
		_breath += dt
		var k := 0.5 + 0.5 * sin(_breath * 3.4)
		frame = 2 * _cols + 2 + (1 if k > 0.5 else 0)
		_sprite.scale = Vector2(_scale * (1.0 - 0.012 * k), _scale * (1.0 + 0.02 * k))
	else:
		_run = fposmod(_run + dt * float(_data.run_fps), _run_frames)
		var f := int(_run)
		if not _grounded:
			f = FLIGHT_FRAME  # hopping a wall: the flight frame
		frame = row * _cols + f
		var swing := _swing_frame()
		if swing >= 0 and _grounded:
			frame = 2 * _cols + int(_data.swing_from) + swing
		_sprite.scale = Vector2.ONE * _scale
		var head: Array = _data.head[f]
		_head = (Vector2(head[0], head[1]) - _anchor) * _scale
	var lift := 0.0
	if bandit.touched_hero and _vault < 1.0:
		if _vault < 0.0:  # the blow: it rears back, then leaps
			_vault = 0.0
			_squash = Vector2(0.86, 1.14)
		_vault = minf(_vault + dt / VAULT_TIME, 1.0)
		lift = VAULT_HEIGHT * 4.0 * _vault * (1.0 - _vault)
		frame = row * _cols + FLIGHT_FRAME  # the flight frame
		rotation = -0.5 * sin(_vault * PI)
	elif _vault >= 1.0:
		rotation = 0.0
	_sprite.frame = frame
	_sprite.scale *= _squash
	_sprite.position = Vector2(_jolt, -lift)
	_material.set_shader_parameter(&"amount", _flash * 0.85)
	queue_redraw()
	_front.queue_redraw()
	_ground_shadow.queue_redraw()


## The frame of the club's swing (0..7): drawn back then the blow over gameplay's strike() (its
## last World.STRIKE_TICKS before the club reaches him), the follow-through once it has; or -1.
func _swing_frame() -> int:
	if bandit.hurt or not bandit.active or world.state != World.State.RUNNING:
		return -1
	if bandit.touched_hero:
		return 6 + (1 if _vault > 0.3 else 0)
	var k := world.strike(bandit)
	if k < 0.0:
		return -1
	return mini(int(k * 6.0), 5)


func _draw() -> void:
	if _ko:
		return
	_draw_stars(false)


## A soft shadow on the ground under him (only while he stands on it).
func _draw_shadow() -> void:
	if _ko or not _grounded:
		return
	_ground_shadow.draw_set_transform(Vector2(_jolt * 0.5, -1.0), 0.0, Vector2(0.8, 0.17))
	_ground_shadow.draw_texture(_shade, -Vector2(32, 32))
	_ground_shadow.draw_set_transform(Vector2.ZERO)


## Dazed stars on a ring above the hood: those behind it drawn under the sprite, the rest over it.
func _draw_stars(front: bool) -> void:
	if _stars <= 0.01 or _ko:
		return
	var target: CanvasItem = _front if front else self
	var centre := _head + Vector2(_jolt + 4.0, -26.0)
	for i in STAR_COUNT:
		var a := _star_turn + i * TAU / STAR_COUNT
		var depth := sin(a)  # > 0: in front
		if (depth > 0.0) != front:
			continue
		var p := centre + Vector2(cos(a) * 17.0, depth * 5.0)
		var size := (3.6 + 1.2 * depth) * _stars
		_star(target, p, size, a * 0.6, Color(1, 0.86, 0.3, _stars * (0.75 + 0.25 * depth)))


static func _star(target: CanvasItem, at: Vector2, r: float, turn: float, colour: Color) -> void:
	if r < 0.4:  # fading out: too small to see, and a collapsed star can't be triangulated
		return
	var pts := PackedVector2Array()
	for k in 10:
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(at + Vector2.from_angle(turn + k * TAU / 10.0 - PI / 2) * rr)
	var ink := Color(0.25, 0.08, 0.02, colour.a)
	var outline := pts.duplicate()
	outline.append(pts[0])
	target.draw_colored_polygon(pts, colour)
	target.draw_polyline(outline, ink, 1.0, true)


func _ko_pose(index: int, centre: Vector2) -> void:
	_sprite.frame = 2 * _cols + index
	_sprite.scale = Vector2.ONE * _scale
	# turn around the middle of the pose: the node sits there
	_sprite.offset = -centre
	position += (centre - _anchor) * _scale
	_anchor = centre


func _tumble(delta: float) -> void:
	_ko_time += delta
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	_material.set_shader_parameter(&"amount", _flash)
	if _ko_time < KO_HOLD:
		_sprite.position = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))  # the blow shakes him
		return
	if _sprite.frame == 2 * _cols:
		var centre: Array = _data.ko_centres[1]
		_ko_pose(1, Vector2(centre[0], centre[1]))
		_sprite.position = Vector2.ZERO
		_throw_club()
	_velocity.y += KO_GRAVITY * delta
	position += _velocity * delta
	rotation += KO_SPIN * delta
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-delta * 10.0))
	_sprite.scale = Vector2.ONE * _scale * _squash
	if _ko_time > 0.75:
		modulate.a = maxf(modulate.a - delta * 3.0, 0.0)
	if position.y > World.VIEW_H + 160.0 or modulate.a <= 0.0:
		queue_free()


## The club flies off on its own, spinning the other way.
func _throw_club() -> void:
	var club := Sprite2D.new()
	club.texture = _club
	club.scale = Vector2.ONE * _scale
	club.position = position + Vector2(-6, -30)
	club.rotation = -2.3
	get_parent().add_child(club)
	var v := Vector2(-90, -560)
	var y0 := club.position.y
	var t := club.create_tween().set_parallel(true)
	t.tween_property(club, "position:x", club.position.x + v.x * 0.9, 0.9)
	t.tween_method(func(k: float) -> void:
		club.position.y = y0 + v.y * k + 0.5 * KO_GRAVITY * k * k, 0.0, 0.9, 0.9)
	t.tween_property(club, "rotation", club.rotation - TAU * 2.2, 0.9)
	t.tween_property(club, "modulate:a", 0.0, 0.25).set_delay(0.65)
	t.chain().tween_callback(club.queue_free)

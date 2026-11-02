class_name HeroView
extends Node2D
## Panoramic: the user's 3D model (ROOT/Making/Animation.blend), re-lit for the savanna's low sun
## and rendered frame by frame (tools/art/blender/hero_render.py), packed into atlases
## (tools/art/hero_atlas.py, assets/art/hero/hero_frames.json) and played by the state of the rules:
## - the run: 16 frames at the pace that keeps his planted foot on the scrolling ground;
## - the jump: the push-off, then the rise, the top and the fall picked by his vertical speed (the
##   rules decide how high and how far), the landing played out into the run;
## - the vine: reaching up into it, hanging by his hands (a damped pendulum, legs swaying), the
##   climb over a ledge, the crouch, the throw (his arm over the running legs), the blow, the fall
##   onto his back when caught, and at home he turns to us and throws his fists up;
## - a soft shadow on the ground under him, cast a little away from the sun.
## Animation runs on the world's clock while the game runs, so pause and hit-stop freeze him too.

const FRAMES := "res://assets/art/hero/hero_frames.json"
const DIR := "res://assets/art/hero/"
## His drawn size is the atlas' (GameArt.HERO_DRAW_HEIGHT standing): kept for the views that size
## things after him.
const DRAW_SCALE := 1.0
## The run: atlas frames a second at the ground's speed (233 units/s), measured from the render so
## the planted boot moves back exactly with the ground (tools/art/hero_atlas.py prints it).
const RUN_FPS := 26.0
const RUN_FRAMES := 16
const TAKEOFF := 0.07  ## seconds of the push-off (the rules have already left the ground)
const THROW_TIME := 0.2  ## the throw: the arm drawn back, then the release
const THROW_BACK := 0.3  ## share of the throw spent drawing the arm back
const MANTLE := 0.16  ## seconds standing up after a climb over a ledge
const BLINK_HZ := 8.0  ## the mercy pulse after a hit (smooth, not a strobe)
const VINE_Y := 6.0  ## where his hands grip the vine
const GRIP_UP := 14.0  ## atlas px from his wrists up to his grip
const WIN_LOOP := 10  ## the cheer at home loops from this frame
const JUMP_RISE := [2, 9]  ## jump frames of the rise (vertical speed -JUMP_SPEED .. -TOP)
const JUMP_TOP := [10, 13]  ## the top (-TOP .. +TOP)
const JUMP_FALL := [14, 18]  ## the fall (+TOP .. +JUMP_SPEED)
const JUMP_LAND := [19, 26]  ## the landing, played out (it ends in the run's first frame)
const TOP := 6.0  ## units a tick of vertical speed counted as the top of the jump
const SHADOW_SHIFT := 10.0  ## units the ground shadow falls right of him (the sun is upper left)

enum Anchor { FEET, HIPS, HANDS }

static var _data := {}
static var _pages: Array[Texture2D] = []
static var _units := 1.0  # units per atlas pixel
static var _hips_dy := 0.0  # standing: his hips this far above the centre of his box (units, < 0: above)

var _sprite: Sprite2D
var _material: ShaderMaterial
var _anim := &""
var _index := 0
var _clock := 0.0
var _last_time := -1.0
var _run := 0.0  # frames into the run cycle
var _run_rate := 1.0  # the run's pace (1: the ground's speed), eased
var _squash := Vector2.ONE
var _land_time := -1.0  # seconds since landing (-1: not landing)
var _takeoff := 0.0  # seconds left of the push-off
var _throw_left := 0.0
var _hurt_time := -1.0  # seconds since a blow (-1: none)
var _hurt_left := 0.0
var _knock := 0.0  # 1 -> 0: the knock back of a blow
var _flash := 0.0  # seconds of frames left of the blow's white flash (frames: a hit-stop holds the world's clock)
var _crouch_time := 0.0
var _climb_time := 0.0
var _mantle := 0.0  # seconds left of standing up after a climb
var _was_climbing := false
var _wall_shift := 0.0  # held back from a wall face (units, <= 0)
var _swing := 0.0  # hanging: pendulum angle and speed
var _swing_speed := 0.0
var _was_hanging := false
var _settle := 0.0  # rotation left over from a change, easing to 0
var _end_time := 0.0
var _death := Vector2.ZERO  # the knock back of the fatal blow, then lying where he fell
var _death_speed := Vector2.ZERO
var _under: Node2D  # his shadow, drawn under him by a node of his parent
var _shadow := Vector2(-1, -1)  # where the shadow is (x, ground y), -1: none
var _shadow_k := 0.0  # 0..1: his height above it (1: on it)
var _shadow_w := 1.0  # the shadow's width (lying down: longer)
var _world: World
var _visible := 1.0


static func frames_data() -> Dictionary:
	if _data.is_empty():
		_data = (load(FRAMES) as JSON).data
		for page: String in _data.pages:
			_pages.append(load(DIR + page))
		_units = float(_data.units_per_px)
		var f: Dictionary = _data.anims.run.frames[0]
		var feet := World.HERO_SIZE.y / 2 + GameArt.FEET_SINK
		_hips_dy = feet - (float(f.origin[1]) - float(f.hips[1])) * _units
	return _data


static func frames(anim: StringName) -> Array:
	return frames_data().anims[anim].frames


func _init() -> void:
	frames_data()
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.region_enabled = true
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/game/actor.gdshader")
	_sprite.material = _material
	add_child(_sprite)


func _ready() -> void:
	_under = Node2D.new()
	_under.draw.connect(_draw_under)
	get_parent().add_child.call_deferred(_under)
	get_parent().move_child.call_deferred(_under, get_index())


func _exit_tree() -> void:
	if is_instance_valid(_under):
		_under.queue_free()


func landed() -> void:
	if _was_climbing:  # over the ledge: he stands up onto it
		_mantle = MANTLE
		return
	_land_time = 0.0
	var k := clampf(_world.land_speed / 45.0, 0.3, 1.1) if _world else 1.0  # a step down lands softly, a drop hard
	_squash = Vector2(1.0 + 0.07 * k, 1.0 - 0.07 * k)


func jumped() -> void:
	_land_time = -1.0
	if _world and (_world.on_ground or _anim in [&"run", &"throw", &"crouch", &"idle"]):
		_takeoff = TAKEOFF
		_squash = Vector2(1.04, 0.96)


func threw() -> void:
	_throw_left = THROW_TIME


## A bandit knocked out: a proud little lift.
func cheer() -> void:
	_squash = Vector2(0.97, 1.04)


func hurt() -> void:
	_hurt_left = World.MERCY_TICKS * World.TICK  # pulses while bandits can't hurt him
	_hurt_time = 0.0
	_knock = 1.0
	_flash = 0.05


func pose() -> StringName:
	return _anim


## Places him for this frame. `p` is his centre (World.draw_hero()), in play units.
func show_state(w: World, p: Vector2, delta: float) -> void:
	_world = w
	var playing := w.state == World.State.RUNNING and w.ticks > 0
	var dt := delta
	if playing:  # the world's clock: frozen when paused or held for a hit-stop
		var now := (w.ticks + w.alpha) * World.TICK
		dt = 0.0 if _last_time < 0.0 else clampf(now - _last_time, 0.0, 0.1)
		_last_time = now
	_clock += dt
	_flash = maxf(_flash - delta, 0.0)
	_throw_left = maxf(_throw_left - dt, 0.0)
	_hurt_left = maxf(maxf(_hurt_left - dt, 0.0), w.mercy * World.TICK)  # also the mercy after a fall
	_knock = maxf(_knock - dt * 3.2, 0.0)
	_takeoff = maxf(_takeoff - dt, 0.0)
	_mantle = maxf(_mantle - dt, 0.0)
	if _land_time >= 0.0:
		_land_time += dt
	if _hurt_time >= 0.0:
		_hurt_time += dt
	_settle = lerpf(_settle, 0.0, 1.0 - exp(-dt * 14.0))
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-dt * 14.0))
	# the run's pace follows the ground under him (the scroll, plus his own steps at the end)
	var ground_speed := 0.0
	if playing and not w.blocked:
		ground_speed = (w.scroll - w.prev_scroll + w.x - w.prev_x) / World.TICK
	var rate := clampf(ground_speed / (World.SCROLL_SPEED / World.TICK), 0.55, 1.6)
	_run_rate = lerpf(_run_rate, rate, 1.0 - exp(-dt * 8.0))
	_run = fmod(_run + dt * RUN_FPS * _run_rate, float(RUN_FRAMES))

	var anim := &"run"
	var index := int(_run)
	var anchor := Anchor.FEET
	var offset := Vector2.ZERO
	var tilt := 0.0
	var sink := 0.0  # 0..1: how far he has gone under a pool's surface
	var airborne := w.jumping or not w.on_ground
	var air_y := p.y + _hips_dy  # where his hips are drawn in the air
	_crouch_time = _crouch_time + dt if w.crouching else 0.0
	_climb_time = _climb_time + dt if w.climbing else 0.0
	_shadow_w = 1.0
	if w.state == World.State.WON:
		# home: he stops before the glowing doorway, turns to us and throws his fists up, cheering
		_end_time += delta
		anim = &"win"
		var n := frames(anim).size()
		var f := int(_end_time * float(frames_data().anims.win.fps))
		index = f if f < n else WIN_LOOP + (f - WIN_LOOP) % (n - WIN_LOOP)
	elif w.state == World.State.DEAD:
		_end_time += delta
		if w.death_reason == &"bandit":  # knocked back off his feet, onto his back
			anim = &"die"
			index = mini(int(_end_time * float(frames_data().anims.die.fps)), frames(anim).size() - 1)
			if _death_speed == Vector2.ZERO:
				_death_speed = Vector2(-160.0, 0.0)
			_death_speed.x = move_toward(_death_speed.x, 0.0, 420.0 * delta)
			_death += _death_speed * delta
			offset = _death
			_shadow_w = 1.0 + clampf(_end_time / 0.8, 0.0, 1.0) * 1.4
			if airborne:  # caught in the air: he drops to where he stands
				air_y = p.y
				anchor = Anchor.HIPS
		else:  # into a pool or a pit: the fall
			anim = &"jump"
			index = JUMP_FALL[1]
			anchor = Anchor.HIPS
	elif not playing and w.ticks == 0:  # on his marks: standing, breathing
		anim = &"idle"
		index = int(_clock * float(frames_data().anims.idle.fps)) % frames(&"idle").size()
	elif w.hanging:
		anim = &"hang"
		anchor = Anchor.HANDS
		index = int(_clock * float(frames_data().anims.hang.fps)) % frames(anim).size()
	elif w.climbing:  # up a ledge: reaching for its top, a knee onto it
		anim = &"climb"
		anchor = Anchor.HIPS
		index = mini(int(_climb_time * 30.0), 3)
	elif airborne and w.vy < 0.0 and w.rising_to_vine() and p.y < 150.0:  # reaching up into the vine
		anim = &"catch"
		anchor = Anchor.HIPS
		index = clampi(int((1.0 - p.y / 150.0) * 4.0), 0, 3)
	elif airborne:
		anim = &"jump"
		anchor = Anchor.HIPS
		if _takeoff > 0.0 and w.vy < 0.0:  # the push-off
			index = 1 if _takeoff > TAKEOFF * 0.5 else 2
		elif w.vy < -TOP:
			var t := clampf(1.0 - (-w.vy - TOP) / (World.JUMP_SPEED - TOP), 0.0, 1.0)
			index = roundi(lerpf(JUMP_RISE[0], JUMP_RISE[1], t))
		elif w.vy <= TOP:
			index = roundi(lerpf(JUMP_TOP[0], JUMP_TOP[1], (w.vy + TOP) / (2.0 * TOP)))
		else:
			var t := clampf((w.vy - TOP) / (World.JUMP_SPEED - TOP), 0.0, 1.0)
			index = roundi(lerpf(JUMP_FALL[0], JUMP_FALL[1], t))
			if _shadow.x < 0.0 and w.vy > 6.0:  # nothing below him: a fall into a pit
				tilt = sin(_clock * 18.0) * 0.08
				var surface := World.SURFACE_Y - World.HERO_SIZE.y / 2
				if w.water_at(w.draw_scroll() + p.x):
					sink = clampf((p.y - surface) / 70.0, 0.0, 1.0)
		_land_time = -1.0
	elif _mantle > 0.0:  # over the ledge: standing up onto it
		anim = &"climb"
		index = clampi(4 + int((1.0 - _mantle / MANTLE) * 4.0), 4, 7)
	elif _hurt_time >= 0.0 and _hurt_time < 0.33:  # a blow: snapped back, arms flung
		anim = &"hurt"
		index = mini(int(_hurt_time * 30.0), frames(anim).size() - 1)
	elif w.crouching:
		anim = &"crouch"
		index = mini(int(_crouch_time * 24.0), frames(anim).size() - 1)
	elif _land_time >= 0.0 and _land_time < (JUMP_LAND[1] - JUMP_LAND[0] + 1) / 30.0:
		anim = &"jump"
		index = JUMP_LAND[0] + int(_land_time * 30.0)
		_run = 0.0  # the landing ends in the run's first frame
	elif _throw_left > 0.0:  # the throwing arm over the running legs
		anim = &"throw"
		var back := _throw_left > THROW_TIME * (1.0 - THROW_BACK)
		index = int(_run) + (0 if back else RUN_FRAMES)
	elif _over_edge(w, p):  # the rules still hold him by the back of his box: leaning off the edge
		tilt = 0.08
	_set_anim(anim, index)

	_was_climbing = w.climbing
	var f: Dictionary = frames(anim)[index]
	var region: Array = f.region
	var grip := Vector2.ZERO
	var anchor_px := Vector2(f.origin[0], f.origin[1])
	var feet := p.y + World.HERO_SIZE.y / 2 + GameArt.FEET_SINK
	match anchor:
		Anchor.FEET:
			position = Vector2(p.x, feet)
		Anchor.HIPS:
			anchor_px = Vector2(f.hips[0], f.hips[1])
			position = Vector2(p.x, air_y)
		Anchor.HANDS:
			grip = Vector2((float(f.hand_r[0]) + float(f.hand_l[0])) / 2.0, minf(f.hand_r[1], f.hand_l[1]) - GRIP_UP)
			anchor_px = grip
			# his hips over his box
			position = Vector2(p.x + (grip.x - float(f.hips[0])) * _units, VINE_Y)
	# hanging: a damped pendulum from his hands, pushed back by the wind of the run
	if w.hanging and not _was_hanging:
		_swing_speed = -1.6  # the jump's momentum swings his legs forward
	_was_hanging = w.hanging
	if w.hanging:
		var wind := 0.0 if w.blocked else 0.05
		var accel := -14.0 * (_swing - wind) - 1.4 * _swing_speed + sin(_clock * 3.7) * 0.18
		_swing_speed += accel * dt
		_swing += _swing_speed * dt
	else:
		_swing = lerpf(_swing, 0.0, 1.0 - exp(-dt * 10.0))
		_swing_speed = 0.0
	# the knock back of a blow: thrown back and up a little
	if _knock > 0.0 and w.state == World.State.RUNNING:
		var e := _knock * _knock
		offset += Vector2(-34.0 * e, -18.0 * sin(_knock * PI))
	# at a wall: his picture reaches past the chest the rules stop, so it is held back from the face
	# ahead (before and while it blocks him): his hands and knee rest on the wall
	var shift := 0.0
	var front := (float(region[2]) - anchor_px.x) * _units * _squash.x
	var face := w.wall_ahead(p.x, p.y, front + 4.0, w.draw_scroll()) if w.state == World.State.RUNNING and not w.hanging else -1.0
	if face >= 0.0:
		shift = minf(face - 4.0 - (p.x + front), 0.0)
	_wall_shift = lerpf(_wall_shift, shift, 1.0 - exp(-dt * 22.0))
	offset.x += _wall_shift
	position += offset
	rotation = tilt + _swing + _settle
	scale = _squash * _units
	_sprite.texture = _pages[int(f.page)]
	_sprite.region_rect = Rect2(region[0], region[1], region[2], region[3])
	_sprite.offset = -anchor_px
	# a white flash on the blow, then a soft pulse while he recovers; under a pool's surface he fades
	var visible_k := 1.0 - sink
	if _hurt_left > 0.0 and _knock <= 0.0 and w.state == World.State.RUNNING:
		visible_k *= 0.7 + 0.3 * cos(_hurt_left * TAU * BLINK_HZ)
	_visible = visible_k
	_sprite.modulate.a = visible_k
	_material.set_shader_parameter(&"amount", 0.85 if _flash > 0.0 else 0.0)
	_material.set_shader_parameter(&"tint", Color(1.0, 0.97, 0.92))
	_update_shadow(w, p)
	if is_instance_valid(_under):
		_under.queue_redraw()


## Standing with his middle past the end of the grass (the rules hold him while any of his box is
## over it).
func _over_edge(w: World, p: Vector2) -> bool:
	var row := floori((w.ground_y + World.HERO_SIZE.y / 2 + 1.0) / Level.TILE)
	return w.level.kind_at(floori((w.draw_scroll() + p.x + 6.0) / Level.TILE), row) != Level.Kind.TOP


func _set_anim(anim: StringName, index: int) -> void:
	if anim != _anim and _anim == &"jump" and anim == &"catch":
		_settle = 0.0
	_anim = anim
	_index = index


# ------------------------------------------------------------------ shadow

## The shadow sits on the first grass top below him, smaller and lighter the higher he is.
func _update_shadow(w: World, p: Vector2) -> void:
	_shadow = Vector2(-1, -1)
	if w.state == World.State.DEAD and w.death_reason != &"bandit":
		return
	var col := floori((w.draw_scroll() + p.x) / Level.TILE)
	if col < 0 or col >= Level.COLS:
		return
	var feet := p.y + World.HERO_SIZE.y / 2
	for r in range(maxi(floori((feet - 8.0) / Level.TILE), 0), Level.ROWS):
		if w.level.kind_at(col, r) == Level.Kind.TOP:
			var ground := r * Level.TILE + GameArt.FEET_SINK - 3.0
			_shadow = Vector2(p.x, ground)
			_shadow.x = p.x + _wall_shift + SHADOW_SHIFT + (_death.x if w.state == World.State.DEAD else 0.0)
			_shadow_k = clampf(1.0 - (ground - feet) / 360.0, 0.0, 1.0)
			return


func _draw_under() -> void:
	if _shadow.x < 0.0:
		return
	var w := 46.0 * (0.45 + 0.55 * _shadow_k)
	for i in 6:  # a soft ellipse: rings of falling darkness, darkest under his feet
		var r := 1.0 - i * 0.15
		_under.draw_set_transform(_shadow, 0.0, Vector2(_shadow_w, 0.2))
		_under.draw_circle(Vector2.ZERO, w * r, Color(0.16, 0.06, 0.1, (0.11 * _shadow_k + 0.03) * _visible))
	_under.draw_set_transform(Vector2.ZERO)

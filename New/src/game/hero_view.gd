class_name HeroView
extends Node2D
## Panoramic, drawn from the poses cut out of the hero sheet (assets/art/hero/, made by
## tools/art/hero_sprites.py) and brought to life in code:
## - the run: two strides, each landing in a squash and rising into a stretch, the body bobbing and
##   leaning into the run; on his marks before the start, crouched and breathing;
## - the air: the leap stretching with the speed, the tuck, a squash on landing and on take-off;
## - the hang: a damped pendulum from the staff's hook, pushed back by the wind of the run;
## - a red scarf (physics: a chain pushed by the wind of the run, gravity and his moves) where the
##   painted pose has only its knot, and a soft shadow on the ground under him;
## - a dark outline, a rim of sunlight on his sun side (upper left) and a soft warm backlight
##   behind him, so he is the clearest thing on screen even against the brown rock;
## - hurt: a flash, a knock back and a flicker; caught: thrown up and tumbling out of the picture;
## - home: he stops before the glowing doorway and hops with his staff raised.
## Animation runs on the world's clock while the game runs, so pause and hit-stop freeze him too.

const DIR := "res://assets/art/hero/"
const STRIDE := 0.16  ## seconds per stride (one pose)
const DOOR_DUCK := 110.0  ## units before the doorway where he ducks (his staff reaches ahead)
const TAKEOFF := 0.07  ## seconds of the push-off: crouched, rising out of it (the rules have left)
const THROW_TIME := 0.15  ## the throw: the ring hand back, then forward
const MANTLE := 0.17  ## seconds pulling himself over a ledge after a climb
const BLINK_HZ := 8.0  ## the mercy pulse after a hit (smooth, not a strobe)
const STANCE_SLIDE := 20.0  ## texture px the feet slide back over one stride (the planted foot)
const VINE_Y := 4.0  ## where his staff hooks on when hanging
const PAD := 24  ## transparent pixels added around each pose: room for the outline and the stance slide
const STAND_SCALE := 0.58  ## the turnaround poses are drawn about twice as big on the sheet
## He is drawn a quarter bigger than the 2017 sprite his hit box was made for, so he reads on a
## phone among the painted scenery (the rules' box is unchanged; feet, hands and hook stay put).
const DRAW_SCALE := 1.25
## Where the scarf is knotted (behind the neck), in each pose's texture pixels; poses not listed
## have their scarf painted in full.
const SCARF_KNOT := {&"run_a": Vector2(170, 66), &"run_b": Vector2(174, 70), &"leap_up": Vector2(136, 106)}
const SCARF_LINKS := 9
const SCARF_LINK := 8.6  ## units between two links
const SCARF_RED := Color("d22a14")
const SCARF_DARK := Color("8c1206")
const SCARF_LIGHT := Color("ff6a3c")
const INK := Color(0.16, 0.05, 0.04, 0.9)

var _sprite: Sprite2D
var _halo: Sprite2D  # the soft warm backlight behind him (additive)
var _material: ShaderMaterial
var _poses := {}  # name -> {"texture", "anchor", "mode", "k"}
var _pose := &""
var _clock := 0.0
var _last_time := -1.0
var _squash := Vector2.ONE
var _land_left := 0.0
var _throw_left := 0.0
var _hurt_left := 0.0
var _knock := 0.0  # 1 -> 0: the knock back of a hit
var _flash := 0.0
var _wall_shift := 0.0  # held back from a wall face (units, <= 0)
var _swing := 0.0  # hanging: pendulum angle and speed
var _swing_speed := 0.0
var _was_hanging := false
var _air_pose_time := 0.0
var _takeoff := 0.0  # seconds left of the push-off
var _takeoff_y := 0.0  # the ground he pushed off from (his centre y)
var _mantle := 0.0  # seconds left of the pull over a ledge
var _was_climbing := false
var _settle := 0.0  # rotation left over from a pose change, easing to 0
var _flash_until := 0  # Time.get_ticks_msec() until which the blow's white flash shows
# the end of the run
var _end_time := 0.0
var _end_alpha := 1.0  # fades into the hut at the end
var _death := Vector2.ZERO  # offset of the tumble when caught
var _death_speed := Vector2.ZERO
var _spin := 0.0
# the scarf and the shadow, drawn under him by a node of his parent
var _under: Node2D
var _scarf: Array[Vector2] = []
var _scarf_speed: Array[Vector2] = []
var _scarf_alpha := 0.0
var _shadow := Vector2(-1, -1)  # where the shadow is (x, ground y), -1: none
var _shadow_k := 0.0  # 0..1: his height above it (1: on it)
var _world: World
var _visible := 1.0  # the flicker after a hit (the picture and the scarf)


func _init() -> void:
	var data: Dictionary = (load(DIR + "hero.json") as JSON).data
	for name: String in data:
		var d: Dictionary = data[name]
		var k := DRAW_SCALE / float(d.get("texture_scale", 2.0))
		if name.begins_with("stand"):
			k *= STAND_SCALE
		var texture: Texture2D = load(DIR + name + ".png")
		_poses[StringName(name)] = {
			"texture": _padded(texture),
			"anchor": Vector2(d.anchor[0], d.anchor[1]) + Vector2(PAD, PAD),
			"mode": d.mode,
			"k": k,
			# hanging: his body hangs left of the staff tip; this shift puts it over his hit box
			"body_dx": (float(d.anchor[0]) - _body_x(texture)) * k if d.mode == "top" else 0.0,
			"front": (_front_x(texture) - float(d.anchor[0])) * k,  # how far ahead of him it reaches
		}
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/game/actor.gdshader")
	_material.set_shader_parameter(&"outline_px", 3.2)
	_material.set_shader_parameter(&"outline_colour", Color(0.1, 0.03, 0.02, 0.95))
	_material.set_shader_parameter(&"rim", 0.9)
	_material.set_shader_parameter(&"rim_px", 5.0)
	_material.set_shader_parameter(&"rim_colour", Color(1.0, 0.84, 0.55))
	_material.set_shader_parameter(&"rim_dir", Vector2(-0.6, -0.8))  # towards the sun
	_sprite.material = _material
	_halo = Sprite2D.new()
	_halo.texture = Fx.glow_texture()
	_halo.material = Fx.additive()
	_halo.modulate = Color(1.0, 0.82, 0.55, 0.3)
	add_child(_halo)
	add_child(_sprite)
	for i in SCARF_LINKS:
		_scarf.append(Vector2.ZERO)
		_scarf_speed.append(Vector2.ZERO)


## The front of a pose (texture px): the right-most opaque pixel (his hand or staff).
static func _front_x(texture: Texture2D) -> float:
	var img := texture.get_image()
	if img.is_compressed():
		img.decompress()
	for x in range(img.get_width() - 1, -1, -1):
		for y in range(0, img.get_height(), 2):
			if img.get_pixel(x, y).a > 0.5:
				return x
	return img.get_width()


## The middle of a pose's body (texture px): the mean x of its opaque pixels below the top third
## (above that are the raised arms and the staff).
static func _body_x(texture: Texture2D) -> float:
	var img := texture.get_image()
	if img.is_compressed():
		img.decompress()
	var total := 0.0
	var count := 0
	for y in range(img.get_height() / 3, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			if img.get_pixel(x, y).a > 0.5:
				total += x
				count += 1
	return total / maxi(count, 1)


## A pose's picture with a transparent border (so the outline is not cut) and mipmaps.
static func _padded(texture: Texture2D) -> Texture2D:
	var img := texture.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var out := Image.create_empty(img.get_width() + PAD * 2, img.get_height() + PAD * 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(PAD, PAD))
	out.fix_alpha_edges()
	out.generate_mipmaps()
	return ImageTexture.create_from_image(out)


func _ready() -> void:
	_under = Node2D.new()
	_under.draw.connect(_draw_under)
	get_parent().add_child.call_deferred(_under)
	get_parent().move_child.call_deferred(_under, get_index())


func _exit_tree() -> void:
	if is_instance_valid(_under):
		_under.queue_free()


func landed() -> void:
	if _was_climbing:  # over the ledge: he pulls himself up onto it, leaning in
		_mantle = MANTLE
		_squash = Vector2(1.1, 0.9)
		return
	_land_left = 0.14
	var k := clampf(_world.land_speed / 45.0, 0.3, 1.1) if _world else 1.0  # a step down lands softly, a drop hard
	_squash = Vector2(1.0 + 0.26 * k, 1.0 - 0.26 * k)


func jumped() -> void:
	if _pose in [&"run_a", &"run_b", &"crouch", &"kneel"]:  # from the ground: a push-off
		_takeoff = TAKEOFF
		_takeoff_y = _world.ground_y if _world else 0.0
		_squash = Vector2(1.16, 0.84)
	else:  # the jump left for a fall: no ground to push from
		_squash = Vector2(0.86, 1.16)


func threw() -> void:
	_throw_left = THROW_TIME
	_squash = Vector2(1.05, 0.96)


## A bandit knocked out: a proud little stretch, leaning back.
func cheer() -> void:
	_squash = Vector2(0.9, 1.12)
	_settle = -0.12


func hurt() -> void:
	_hurt_left = World.MERCY_TICKS * World.TICK  # pulses while bandits can't hurt him
	_knock = 1.0
	_flash = 1.0
	_flash_until = Time.get_ticks_msec() + 40  # real time: a hit-stop holds the world's clock


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
	_land_left = maxf(_land_left - dt, 0.0)
	_throw_left = maxf(_throw_left - dt, 0.0)
	_hurt_left = maxf(maxf(_hurt_left - dt, 0.0), w.mercy * World.TICK)  # also the mercy after a fall
	_knock = maxf(_knock - dt * 3.2, 0.0)
	_flash = maxf(_flash - dt * 30.0, 0.0)  # white for two frames
	_takeoff = maxf(_takeoff - dt, 0.0)
	_mantle = maxf(_mantle - dt, 0.0)
	_settle = lerpf(_settle, 0.0, 1.0 - exp(-dt * 14.0))
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-dt * 15.0))
	var draw_y := p.y  # where his centre is drawn (the push-off draws him rising out of the ground)
	var sink := 0.0  # 0..1: how far he has gone under a pool's surface

	var pose := &"run_a"
	var offset := Vector2.ZERO
	var tilt := 0.0
	var stretch := Vector2.ONE
	var slide := 0.0  # the stance slide of the feet (texture px, + back)
	var airborne := w.jumping or not w.on_ground
	var by_feet := false  # place a "top" pose by its boots (the victory hop)
	if w.state == World.State.WON:
		# home: he stops before the glowing doorway, hops with his staff raised high (the hanging
		# pose, placed by its boots) and lands into a little squash: the run ends on him, whole and
		# readable (walking in, he was taller than the low doorway and showed over its arch)
		_end_time += delta
		pose = &"leap_up"
		by_feet = true
		var hop := clampf(_end_time / 0.42, 0.0, 1.0)
		offset.y = -sin(hop * PI) * 34.0
		var land := clampf((_end_time - 0.42) / 0.25, 0.0, 1.0)
		var squash := sin(land * PI) * 0.1 if _end_time > 0.42 else 0.0
		stretch = Vector2(1.0 + squash, 1.0 - squash) * (1.0 + 0.06 * sin(hop * PI))
		_end_alpha = 1.0
	elif w.state == World.State.DEAD:
		_end_time += delta
		pose = &"tuck"
		if w.death_reason == &"bandit":  # thrown up and back, tumbling out of the picture
			if _death_speed == Vector2.ZERO:
				_death_speed = Vector2(-55, -760)  # mostly up: he is near the left edge
			_death_speed.y += 2300.0 * delta
			_death += _death_speed * delta
			_spin -= delta * 7.5
			offset = _death
			tilt = _spin
		else:
			_spin -= delta * 2.0
			tilt = _spin
	elif not playing and w.ticks == 0:  # on his marks: crouched, breathing
		pose = &"crouch"
		var b := sin(_clock * 3.0)
		stretch = Vector2(1.0 - 0.012 * b, 1.0 + 0.022 * b)
	elif w.hanging:
		pose = &"leap_up"
	elif w.climbing or (w.blocked and airborne and w.vy < 0.0):  # up a wall: arms up, body to it, feet scrabbling
		pose = &"leap_up"
		by_feet = true
		offset.x += sin(_clock * 46.0) * 2.5
		offset.y += absf(sin(_clock * 23.0)) * -3.0
		stretch = Vector2(0.95, 1.07)
		tilt = 0.06
	elif airborne and _takeoff > 0.0 and w.vy < 0.0:  # the push-off: crouched, rising out of it
		pose = &"crouch"
		var t := 1.0 - _takeoff / TAKEOFF
		draw_y = lerpf(_takeoff_y, p.y, t * t)
		stretch = Vector2(1.1 - 0.16 * t, 0.88 + 0.22 * t)
	elif airborne:
		var s := clampf(absf(w.vy) / World.JUMP_SPEED, 0.0, 1.0)
		if w.vy < -12.0:  # the rise: drawn out along the leap
			pose = &"leap"
			stretch = Vector2(1.0 - 0.13 * s, 1.0 + 0.2 * s)
			tilt = -0.03 * s
		else:  # over the top and down: tucked and turning forward, a squash at the top, stretched as
			# the fall speeds up; near the ground he braces for it (legs down)
			pose = &"tuck"
			var down := clampf(w.vy / World.JUMP_SPEED, 0.0, 1.6)
			var top := 1.0 - clampf(absf(w.vy) / 12.0, 0.0, 1.0)
			stretch = Vector2(1.0 + 0.07 * top - 0.07 * down, 1.0 - 0.07 * top + 0.15 * down)
			tilt = lerpf(-0.14, 0.24, clampf((w.vy + 12.0) / 40.0, 0.0, 1.0))
			if w.vy > 18.0 and _shadow.x >= 0.0 and _shadow.y - (p.y + World.HERO_SIZE.y / 2) < 110.0:
				pose = &"crouch"
				stretch = Vector2(0.93, 1.1)
				tilt = 0.04
			if _shadow.x < 0.0 and w.vy > 6.0:  # nothing below him: a fall into a pit, flailing
				tilt += sin(_clock * 26.0) * 0.24
				var surface := World.SURFACE_Y - World.HERO_SIZE.y / 2
				if w.water_at(w.draw_scroll() + p.x):
					sink = clampf((p.y - surface) / 70.0, 0.0, 1.0)
	elif _mantle > 0.0:  # over the ledge: crouched, leaning in, pulling up onto it
		pose = &"crouch"
		var m := _mantle / MANTLE
		tilt = 0.2 * m
		offset.x = -8.0 * m
		stretch = Vector2(1.0 + 0.06 * m, 1.0 - 0.06 * m)
	elif _knock > 0.45:  # a blow: knocked back, curled up
		pose = &"tuck"
		by_feet = true
	elif w.crouching:
		pose = &"kneel"
	elif w.at_end and w.x > World.HOME_X - DOOR_DUCK:  # the doorway is low: he ducks to go in
		pose = &"crouch"
	elif _over_edge(w, p):  # the rules still hold him by the back of his box: he steps off, leaning
		pose = &"crouch"
		tilt = 0.2
	elif _land_left > 0.0:
		pose = &"crouch"
	else:
		var cadence := STRIDE * (1.6 if w.blocked else 1.0)  # pushing against a wall: slower
		var phase := fmod(_clock / cadence, 2.0)
		pose = &"run_a" if phase < 1.0 else &"run_b"
		var u := fmod(phase, 1.0)  # 0: the foot lands, 0.5: up in the stride
		var rise := sin(u * PI)
		offset.y = -rise * 6.0 + (1.0 - rise) * 1.5
		# each stride lands into a squash and rises into a stretch
		var land := exp(-u * 9.0)
		stretch = Vector2(1.0 + 0.07 * land - 0.025 * rise, 1.0 - 0.08 * land + 0.035 * rise)
		tilt = 0.035 + 0.025 * rise
		# the planted foot travels back with the ground through the stride, then the next stride
		slide = lerpf(-STANCE_SLIDE * 0.5, STANCE_SLIDE * 0.5, u) * (0.5 if w.blocked else 1.0)
		if _throw_left > 0.0:  # the ring hand back (run_b), then forward through the throw (run_a)
			var u2 := 1.0 - _throw_left / THROW_TIME
			pose = &"run_b" if u2 < 0.3 else &"run_a"
			tilt += -0.05 if u2 < 0.3 else 0.1 * (1.0 - u2)
			offset.x += -3.0 if u2 < 0.3 else 7.0 * sin((u2 - 0.3) / 0.7 * PI)
			stretch.x *= 1.0 if u2 < 0.3 else 1.0 + 0.06 * sin((u2 - 0.3) / 0.7 * PI)
	_set_pose(pose)

	_was_climbing = w.climbing
	var info: Dictionary = _poses[pose]
	var k: float = info.k
	var feet := draw_y + World.HERO_SIZE.y / 2 + GameArt.FEET_SINK
	var anchor: Vector2 = info.anchor
	if by_feet and info.mode != "feet":  # a pose placed by its boots (the climb, the recoil)
		var tex: Texture2D = info.texture
		anchor = Vector2(anchor.x, tex.get_height() - PAD)
		position = Vector2(p.x, feet)
	else:
		match info.mode:
			"feet":
				position = Vector2(p.x, feet)
			"top":
				position = Vector2(p.x + info.body_dx, VINE_Y)
			_:
				position = Vector2(p.x, draw_y + 4.0)
	# hanging: a damped pendulum from the hook, pushed back by the wind of the run
	if w.hanging and not _was_hanging:
		_swing_speed = -2.2  # the jump's momentum swings his legs forward
	_was_hanging = w.hanging
	if w.hanging:
		var wind := 0.0 if w.blocked else 0.07
		var accel := -16.0 * (_swing - wind) - 1.3 * _swing_speed + sin(_clock * 4.1) * 0.25
		_swing_speed += accel * dt
		_swing += _swing_speed * dt
	else:
		_swing = lerpf(_swing, 0.0, 1.0 - exp(-dt * 10.0))
		_swing_speed = 0.0
	# the knock back of a hit: thrown back and up, leaning back
	if _knock > 0.0:
		var e := _knock * _knock
		offset += Vector2(-30.0 * e, -26.0 * sin(_knock * PI))
		tilt -= 0.36 * e
	# at a wall: his picture reaches ~50 units past the chest the rules stop, so it is held back
	# from the face ahead (before and while it blocks him): his staff hand rests on the wall
	var shift := 0.0
	var front := float(info.front) * stretch.x
	var face := w.wall_ahead(p.x, p.y, front + 4.0, w.draw_scroll()) if w.state == World.State.RUNNING and not w.hanging else -1.0
	if face >= 0.0:
		shift = minf(face - 6.0 - (p.x + front), 0.0)
	_wall_shift = lerpf(_wall_shift, shift, 1.0 - exp(-dt * 22.0))
	offset.x += _wall_shift
	position += offset
	rotation = tilt + _swing + _settle
	scale = _squash * stretch * k
	_sprite.texture = info.texture
	_sprite.offset = -anchor
	var tex_size: Vector2 = (info.texture as Texture2D).get_size()
	_halo.position = _sprite.offset + tex_size / 2
	_halo.scale = Vector2.ONE * tex_size.y * 1.15 / 128.0
	# a white flash on the blow, then (once the knock is over) a soft pulse while he recovers; going
	# under a pool's surface he fades into it
	var visible_k := _end_alpha * (1.0 - sink)
	if _hurt_left > 0.0 and _flash <= 0.0 and _knock <= 0.0 and w.state == World.State.RUNNING:  # (caught: none)
		visible_k *= 0.675 + 0.325 * cos(_hurt_left * TAU * BLINK_HZ)
	_visible = visible_k
	_halo.modulate.a = 0.3 * visible_k
	_material.set_shader_parameter(&"opacity", visible_k)
	_sprite.modulate.a = 1.0 if slide != 0.0 else visible_k
	_material.set_shader_parameter(&"warp_px", slide)
	_material.set_shader_parameter(&"warp_from", 0.42)
	_material.set_shader_parameter(&"amount", 0.9 if Time.get_ticks_msec() < _flash_until else 0.0)
	_material.set_shader_parameter(&"tint", Color(1.0, 1.0, 1.0))
	_material.set_shader_parameter(&"outline_opacity", visible_k)
	_update_scarf(w, pose, dt)
	_update_shadow(w, p)
	if is_instance_valid(_under):
		_under.queue_redraw()


## Standing with his middle past the end of the grass (the rules hold him while any of his box is
## over it).
func _over_edge(w: World, p: Vector2) -> bool:
	var row := floori((w.ground_y + World.HERO_SIZE.y / 2 + 1.0) / Level.TILE)
	return w.level.kind_at(floori((w.draw_scroll() + p.x + 6.0) / Level.TILE), row) != Level.Kind.TOP


func _set_pose(pose: StringName) -> void:
	if pose == _pose:
		return
	# changing between the ground and the air pops a little
	var air := [&"leap", &"tuck", &"leap_up"]
	if (pose in air) != (_pose in air) and not _pose.is_empty():
		_squash *= Vector2(0.94, 1.06) if pose in air else Vector2(1.06, 0.94)
	if _pose == &"leap" and pose == &"tuck":  # the leap leans forward: the tuck turns in from it
		_settle = 0.22
	_pose = pose


func pose() -> StringName:
	return _pose


# ------------------------------------------------------------------ scarf and shadow

## The scarf's links follow the knot; the wind of the run blows them back, gravity pulls them
## down, a flutter ripples them (position-based: each link kept at its distance from the last).
func _update_scarf(w: World, pose: StringName, dt: float) -> void:
	var show := SCARF_KNOT.has(pose) and w.state != World.State.DEAD
	if not show:  # a pose with its scarf painted in full: the code one goes at once
		_scarf_alpha = 0.0
		return
	var knot: Vector2 = get_transform() * (SCARF_KNOT[pose] + Vector2(PAD, PAD) + _sprite.offset)
	if _scarf_alpha <= 0.0:  # back: laid out straight behind the knot, then it moves on its own
		for i in SCARF_LINKS:
			_scarf[i] = knot + Vector2(-SCARF_LINK * i, SCARF_LINK * 0.3 * i)
			_scarf_speed[i] = Vector2.ZERO
	_scarf_alpha = move_toward(_scarf_alpha, 1.0, dt * 12.0)
	if dt <= 0.0:
		return
	var running := w.state == World.State.RUNNING and w.ticks > 0 and not w.blocked
	var wind := Vector2(-World.SCROLL_SPEED / World.TICK if running else 0.0, 0.0)
	_scarf[0] = knot
	var before := _scarf.duplicate()
	for i in range(1, SCARF_LINKS):
		var flutter := Vector2(0, sin(_clock * 15.0 - i * 0.95) * 170.0 * float(i) / SCARF_LINKS)
		var lift := Vector2(0, -0.32 * absf(wind.x))  # cloth in a fast wind flies up as well as back
		var v := _scarf_speed[i]
		v += (Vector2(0, 300.0) + (wind + lift + flutter - v) * 7.0) * dt
		_scarf_speed[i] = v
		_scarf[i] += v * dt
	for it in 3:
		for i in range(1, SCARF_LINKS):
			var d := _scarf[i] - _scarf[i - 1]
			_scarf[i] = _scarf[i - 1] + d.normalized() * SCARF_LINK if d.length() > 0.001 else _scarf[i - 1] + Vector2(-SCARF_LINK, 0)
	for i in range(1, SCARF_LINKS):
		_scarf_speed[i] = _scarf_speed[i].lerp((_scarf[i] - before[i]) / dt, 0.5)


## The shadow sits on the first grass top below him, smaller and lighter the higher he is.
func _update_shadow(w: World, p: Vector2) -> void:
	_shadow = Vector2(-1, -1)
	if w.state != World.State.RUNNING and w.state != World.State.WON:
		return
	var col := floori((w.draw_scroll() + p.x) / Level.TILE)
	if col < 0 or col >= Level.COLS:
		return
	var feet := p.y + World.HERO_SIZE.y / 2
	for r in range(maxi(floori((feet - 8.0) / Level.TILE), 0), Level.ROWS):
		if w.level.kind_at(col, r) == Level.Kind.TOP:
			var ground := r * Level.TILE + GameArt.FEET_SINK - 3.0
			_shadow = Vector2(p.x, ground)
			_shadow_k = clampf(1.0 - (ground - feet) / 360.0, 0.0, 1.0) * _end_alpha
			return


func _draw_under() -> void:
	if _shadow.x >= 0.0:
		var w := 40.0 * (0.45 + 0.55 * _shadow_k)
		for i in 5:  # a soft ellipse: rings of falling darkness
			var r := 1.0 - i * 0.18
			_under.draw_set_transform(_shadow, 0.0, Vector2(1.0, 0.24))
			_under.draw_circle(Vector2.ZERO, w * r, Color(0.14, 0.05, 0.06, 0.12 * _shadow_k + 0.03))
		_under.draw_set_transform(Vector2.ZERO)
	if _scarf_alpha <= 0.01 or _scarf[0] == Vector2.ZERO:
		return
	# the ribbon: two tails from the knot, tapering, lit on top, an ink edge
	var a := _scarf_alpha * _visible
	for tail in 2:
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in SCARF_LINKS:
			var p := _scarf[i] + Vector2(0, tail * 2.2 * float(i) / SCARF_LINKS)
			var t := _scarf[mini(i + 1, SCARF_LINKS - 1)] - _scarf[maxi(i - 1, 0)]
			var n := t.normalized().orthogonal() if t.length() > 0.001 else Vector2.UP
			var width := lerpf(5.6, 2.2, float(i) / (SCARF_LINKS - 1)) * (1.0 if tail == 0 else 0.8)
			left.append(p + n * width)
			right.append(p - n * width)
		var tip := _scarf[SCARF_LINKS - 1] + (_scarf[SCARF_LINKS - 1] - _scarf[SCARF_LINKS - 2]) * (0.6 - tail * 0.25)
		var base := Color(SCARF_RED if tail == 0 else SCARF_RED.darkened(0.2), a)
		var ink := Color(INK, a * 0.85)
		# the ink edge first (a little wider), then the cloth: quad by quad, drawn as triangles
		# (a twisted quad is a bow tie that draw_colored_polygon can't triangulate)
		var edge := left.duplicate()
		edge.append(tip)
		var back := right.duplicate()
		back.reverse()
		edge.append_array(back)
		_under.draw_polyline(edge, ink, 2.4, true)
		var fill := PackedColorArray([base, base, base, base])
		for i in SCARF_LINKS - 1:
			_under.draw_primitive(PackedVector2Array([left[i], left[i + 1], right[i]]), fill.slice(0, 3), PackedVector2Array())
			_under.draw_primitive(PackedVector2Array([left[i + 1], right[i + 1], right[i]]), fill.slice(0, 3), PackedVector2Array())
		_under.draw_primitive(PackedVector2Array([left[SCARF_LINKS - 1], tip, right[SCARF_LINKS - 1]]), fill.slice(0, 3), PackedVector2Array())
		# the shaded underside and a lit edge along the top
		_under.draw_polyline(right, Color(SCARF_DARK, a * 0.7), 1.6, true)
		_under.draw_polyline(left, Color(SCARF_LIGHT, a * 0.55), 1.1, true)

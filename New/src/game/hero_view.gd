class_name HeroView
extends Node2D
## Panoramic: drawn with kie.ai from the user's target picture and a turnaround of their 3D model
## (ROOT/Making/Animation.blend): Nano Banana 2 stills, animated with Seedance clips (2.0 Mini; the throw 2.5) and
## resampled to the game's slots, packed into atlases (tools/art/hero_atlas_ai.py, assets/art/hero/hero_frames.json;
## the earlier 3D renders: tools/art/hero_atlas.py) and played by the state of the rules:
## - the run: 16 frames at the pace that keeps his planted foot on the scrolling ground;
## - the jump: the push-off, then the rise, the top and the fall picked by his vertical speed (the
##   rules decide how high and how far), the landing played out into the run;
## - the vine: reaching up into it, hanging by his hands (a damped pendulum, legs swaying), the
##   climb over a ledge, the crouch, the throw (his arm over the running legs), the blow, the fall
##   onto his back when caught, and at home he lands and springs into his victory pose (round 19: a kie.ai still,
##   a fist punched to the sky, the beadwork chakram in his armoured hand);
## - a soft shadow on the ground under him, cast a little away from the sun.
## Animation runs on the world's clock while the game runs, so pause and hit-stop freeze him too.

const FRAMES := "res://assets/art/hero/hero_frames.json"
const DIR := "res://assets/art/hero/"
## His drawn size is the atlas' (GameArt.HERO_DRAW_HEIGHT standing): kept for the views that size
## things after him.
const DRAW_SCALE := 1.0
## The run: atlas frames a second. 16, the user's choice (2026-11-07): the pace the Seedance sprint was filmed at
## (16 slots out of 24 video frames, a second of it). The boot pace that would match the ground (233 units/s) is
## lower (tools/art/hero_atlas_ai.py prints it); at 16 the planted boot moves back faster than the ground.
const RUN_FPS := 16.0
const RUN_FRAMES := 16
const TAKEOFF := 0.07  ## seconds of the push-off (the rules have already left the ground)
const THROW_TIME := 0.3  ## the throw: the chakram cocked overhead, then the arm thrown forward (legs running on)
const THROW_BACK := 0.3  ## share of the throw spent with the chakram cocked
const MANTLE := 0.16  ## seconds standing up after a climb over a ledge
const BLINK_HZ := 8.0  ## the mercy pulse after a hit (smooth, not a strobe)
const VINE_Y := 6.0  ## where his hands grip the vine
const GRIP_UP := 14.0  ## atlas px from his wrists up to his grip
const WIN_LOOP := 10  ## the cheer at home loops from this frame
const WIN_POSE := 3  ## the win's frame where the landing crouch springs into the victory pose (hero_atlas_ai.py)
const JUMP_RISE := [2, 9]  ## jump frames of the rise (vertical speed -JUMP_SPEED .. -TOP)
const JUMP_TOP := [10, 13]  ## the top (-TOP .. +TOP)
const JUMP_FALL := [14, 18]  ## the fall (+TOP .. +JUMP_SPEED)
const JUMP_LAND := [19, 26]  ## the landing, played out (it ends in the run's first frame)
const TOP := 6.0  ## units a tick of vertical speed counted as the top of the jump
const SHADOW_SHIFT := 10.0  ## units the ground shadow falls right of him (the sun is upper left)
const SHADOW_WIDTH := 100.0  ## units across his shadow on the ground, standing on it
const SHADOW := Color(0.11, 0.04, 0.07)  ## the characters' shadows: the dusk's warm plum shade
const CONTACT := Color(0.05, 0.02, 0.03)  ## (round 20) the tight contact under the feet: near black
## (round 21, the judges: "at home his shadow a hard black ellipse offset to the left, a hole") at home a soft occlusion
## right under his stride: this much wider (x) and darker (y) than in play, its near-black contact softened (CONTACT_HOME),
## its middle under his frame's middle a little right of it, away from the fire on his left (SHADOW_HOME_SHIFT units)
const SHADOW_HOME := Vector2(1.15, 1.15)
const SHADOW_HOME_SHIFT := 5.0
const CONTACT_HOME := 0.5
## (round 21) at home, where the dark front grass clears to show the ground line, his feet stand this share of
## GameArt.FEET_SINK higher (in play the grass hides the sink; at home his back boot's toe showed under the ground)
const HOME_LIFT := 0.6
const HOLD := 0.1  ## seconds an animation shows at least before another replaces it (no flicker)
const HURT_TIME := 0.33  ## seconds of the blow's reaction
const STUMBLE := 0.14  ## seconds of the stumble after it, leaning back and catching himself
const PULL := 0.16  ## seconds per hand-over-hand pull up a ledge
const HAND_STEP := 0.2  ## seconds per hand step along the vine while hanging
const LIGHT_GAIN := 1.18  ## his lit colours x this in play (actor.gdshader light_gain; the ink untouched; round 16:
## 1.28 -> 1.18, "traffic-cone orange")
## (round 19) the characters' one line and light system (character.gdshaderinc, shared with BanditView)
const LINE := Color(0.17, 0.085, 0.06)  ## his ink: a dark warm brown, not black
const LINE_INSIDE := 0.55  ## the brown lines inside him (the muscles' grooves, folds) softened towards the colours round them
const SHADE := 0.14  ## his shade tinted towards the dusk's cool ambient
## (round 20, the judges: "a sticker: lit flat from the front while the scenes are back- and side-lit") the form: the
## half of him away from the sun (upper left) in a soft cool shade, deepest along the edges turning away from it
## (character.gdshaderinc char_form()); no rim, no glow on the lit side (the user)
## (round 21, the judges: "still lit flat from the front, his skin on the gold grass's value") the shade side deeper and
## cooler (0.46 -> 0.7, reaching further over the half away from the sun), and a warm key on the sun's side (character.gdshaderinc key_colour): a lit form, the skin warmer
## than the grass on one side and darker than it on the other
const FORM := 0.7
const FORM_REACH := 0.6  ## how much of the half away from the sun is in that shade (character.gdshaderinc form_reach)
const FORM_COLOUR := Color(0.6, 0.58, 0.86)  ## the shade's colour: the sky's cool, multiplied
const FORM_HOME := 0.22  ## at home the fire's bounce already shades his far side cool (actor.gdshader bounce)
const FORM_PX := 12.0  ## atlas texels the edges turning away from the sun reach in (round 20: 9)
const KEY := 0.9  ## the warm key on the sun's side (0: none)
const KEY_HOME := 0.4  ## at home the fire's own warmth is on that side (bounce)
const HAIR_LIFT := 0.45  ## (round 21) at home the top of his hair a little lighter, clear of the dark doorway (no rim)
const VINE_INK_PX := 0.9  ## atlas px of ink added at the vine: hero_atlas.py's 3.2 x (1 / 0.78 - 1), the vine framing's zoom
const WALK_IN := 70.0  ## units he walks into the doorway at home
const DIE_PUSH := 40.0  ## units the fatal blow knocks him back
const DIE_MIN_X := 70.0  ## play x he is never drawn left of when caught (the death stays on screen)

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
var _vine_ink := 0.0  # 0..1: the extra ink while the camera frames the vine
var _home := 0.0  # 0..1: at home (his shadow there a soft occlusion under his stride: SHADOW_HOME)
var _mid := 0.0  # units from his anchor to the middle of the frame shown (his stride's middle at home)


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
	# so he reads at phone size: a warm rim on the edges facing the sun (2-3 px on a 1179 px screen)
	# and a thin dark edge (both stay inside the atlas' 3 px of padding)
	# (round 4: the ink line and the warm rim are now in the cel-shaded render itself; the shader
	# only adds a touch of the sun's warmth on the lit edge)
	# (hero pass 2: no shader rim: on the atlas' ink it drew a pale band, "a white sticker outline";
	# the hot sun-side rim is now in the frames, inside the ink: tools/art/hero_atlas.py sun_rim())
	_material.set_shader_parameter(&"rim", 0.0)
	_material.set_shader_parameter(&"rim_px", 2.6)
	_material.set_shader_parameter(&"rim_colour", Color(1.0, 0.86, 0.6))
	_material.set_shader_parameter(&"rim_dir", Vector2(-0.6, -0.8))
	_material.set_shader_parameter(&"outline_px", 0.0)
	# (round 19) one line and light system with the bandits (character.gdshaderinc): his ink a dark warm brown, a
	# lighter brown on the edges facing the sun, his shade tinted to the dusk's ambient; the vine's extra ink too
	_material.set_shader_parameter(&"outline_colour", LINE)
	_material.set_shader_parameter(&"line_colour", LINE)
	_material.set_shader_parameter(&"line_inside", LINE_INSIDE)
	_material.set_shader_parameter(&"shade_amount", SHADE)
	_material.set_shader_parameter(&"form_amount", FORM)  # (round 20) a shade side (figure_box, region: show_state())
	_material.set_shader_parameter(&"form_colour", FORM_COLOUR)
	_material.set_shader_parameter(&"form_px", FORM_PX)
	_material.set_shader_parameter(&"form_reach", FORM_REACH)
	_material.set_shader_parameter(&"key_amount", KEY)
	# (round 12, "top runners light the hero brightest on screen") his lit side raised in the level's light
	_material.set_shader_parameter(&"light_gain", LIGHT_GAIN)
	_sprite.material = _material
	add_child(_sprite)


func _ready() -> void:
	_under = Node2D.new()
	# round 6 ("he floats on the grass"): his shadow is drawn over the grass blades in front of the
	# runners (WorldView's front grass hid it), darkening them and the soles of his boots
	_under.z_index = 1
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


## For the footsteps (the audio track): the run frame showing (0..15), -1 when he isn't running.
## Boots touch the ground around frames 1 and 9.
func run_frame() -> int:
	return int(_run) % RUN_FRAMES if _anim in [&"run", &"throw"] else -1


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
	var duck := 1.0  # under a low roof: drawn this much shorter (at home: his breath)
	var air_y := p.y + _hips_dy  # where his hips are drawn in the air
	var phase := w.move_phase()  # gameplay's hooks: what he is doing and since when
	var t := w.phase_time()
	_shadow_w = 1.0
	match phase:
		&"home":
			# he lands at the door, the victory beat (turns to us, fists up), then walks into the
			# doorway (the hut's jamb is drawn over him by HomeView.front)
			_end_time = t
			offset.y -= GameArt.FEET_SINK * HOME_LIFT * clampf(t / World.HOME_LAND, 0.0, 1.0)
			if t < World.HOME_LAND:
				anim = &"jump"
				index = JUMP_LAND[0] + mini(int(t / World.HOME_LAND * 4.0), 3)
			elif t < World.HOME_CHEER:
				anim = &"win"
				var n := frames(anim).size()
				var f := int((t - World.HOME_LAND) * float(frames_data().anims.win.fps))
				index = f if f < n else WIN_LOOP + (f - WIN_LOOP) % (n - WIN_LOOP)
				# (round 19) out of the landing crouch he springs into the victory pose (one drawing): a stretch as he
				# rises into it, then breathing, his punched fist high
				if index >= WIN_POSE and _anim == &"win" and _index < WIN_POSE:
					_squash = Vector2(0.9, 1.12)
				if index >= WIN_POSE:
					duck = 1.0 + 0.012 * sin((t - World.HOME_LAND) * 5.0)
			else:
				anim = &"run"
				var u := clampf((t - World.HOME_CHEER) / (World.HOME_TIME - World.HOME_CHEER), 0.0, 1.0)
				index = int(t * RUN_FPS * 0.6) % RUN_FRAMES
				offset.x = WALK_IN * u * u
		&"dead":
			_end_time = t
			if w.death_reason == &"bandit":  # knocked back off his feet onto his back, and he stays
				anim = &"die"
				var n := frames(anim).size()
				index = mini(int(t / (World.DYING_TIME * 0.7) * n), n - 1)
				offset.x = -DIE_PUSH * (1.0 - exp(-t * 4.0))
				_death.x = offset.x
				_shadow_w = 1.0 + clampf(t / 0.8, 0.0, 1.0) * 1.4
				var ground := w.ground_below(p.x, p.y)
				if ground >= 0.0 and ground > p.y + 1.0:  # caught in the air: he drops to it
					offset.y = (ground - p.y) * minf(t / 0.3, 1.0) ** 2
			else:  # into a pool or a pit: falling, flailing
				anim = &"jump"
				index = JUMP_FALL[1]
				anchor = Anchor.HIPS
				tilt = sin(t * 16.0) * 0.18
				var surface := World.SURFACE_Y - World.HERO_SIZE.y / 2
				if w.water_at(w.draw_scroll() + p.x):
					sink = clampf((p.y - surface) / 70.0, 0.0, 1.0)
		&"idle":  # on his marks: standing, breathing
			anim = &"idle"
			index = int(_clock * float(frames_data().anims.idle.fps)) % frames(&"idle").size()
		&"hang":  # the last of the catch, then hanging by his hands
			anchor = Anchor.HANDS
			if t < 0.1:
				anim = &"catch"
				index = 2 + mini(int(t / 0.05), 1)
			else:
				anim = &"hang"
				index = int(_clock * float(frames_data().anims.hang.fps)) % frames(anim).size()
				# hand over hand along the vine: a small lift and lean at each grip
				var step := sin((t - 0.1) * PI / HAND_STEP)
				offset.y -= absf(step) * 3.0
				tilt += 0.035 * signf(step)
		&"climb":  # up a ledge hand over hand: a pull every PULL seconds, most of it at its start
			anim = &"climb"
			anchor = Anchor.HIPS
			var k := fmod(t, PULL) / PULL
			index = 0 if fmod(t, PULL * 2.0) < PULL else 1
			if t > PULL * 2.0:
				index = 2 + mini(int((t - PULL * 2.0) / 0.06), 1)  # a knee onto the top
			offset.y = -sin(minf(k * 2.0, 1.0) * PI * 0.5) * 6.0
		&"takeoff":
			anim = &"jump"
			anchor = Anchor.HIPS
			index = 1 + mini(int(t / 0.025), 1)
		&"rise", &"apex", &"fall":
			anim = &"jump"
			anchor = Anchor.HIPS
			var ap := w.air_progress()  # 0..1 through his time in the air (the rules decide how long)
			if ap >= 0.0:
				if ap < 0.45:
					index = roundi(lerpf(JUMP_RISE[0], JUMP_RISE[1], ap / 0.45))
				elif ap < 0.6:
					index = roundi(lerpf(JUMP_TOP[0], JUMP_TOP[1], (ap - 0.45) / 0.15))
				else:
					index = roundi(lerpf(JUMP_FALL[0], JUMP_FALL[1], (ap - 0.6) / 0.4))
				tilt = lerpf(-0.06, 0.08, ap)
			elif w.vy < 0.0 and w.rising_to_vine() and p.y < 150.0:  # reaching up into the vine
				anim = &"catch"
				index = clampi(int((1.0 - p.y / 150.0) * 2.0), 0, 1)
			elif w.vy < 0.0:
				var r := clampf(1.0 - (-w.vy - TOP) / (World.JUMP_SPEED - TOP), 0.0, 1.0)
				index = roundi(lerpf(JUMP_RISE[0], JUMP_RISE[1], r))
			else:  # no ground ahead: a fall into a pit, flailing
				index = JUMP_FALL[1]
				tilt = sin(_clock * 16.0) * 0.18
				var surface := World.SURFACE_Y - World.HERO_SIZE.y / 2
				if w.water_at(w.draw_scroll() + p.x):
					sink = clampf((p.y - surface) / 70.0, 0.0, 1.0)
			_land_time = -1.0
		&"crouch":
			anim = &"crouch"
			index = mini(int(t * 24.0), frames(anim).size() - 1)
		_:  # on the ground: the mantle after a climb, the landing played out, the blow, the run
			if _mantle > 0.0:
				anim = &"climb"
				index = clampi(4 + int((1.0 - _mantle / MANTLE) * 4.0), 4, 7)
			elif _hurt_time >= 0.0 and _hurt_time < HURT_TIME:
				anim = &"hurt"
				index = mini(int(_hurt_time * 30.0), frames(anim).size() - 1)
			elif _land_time >= 0.0 and _land_time < (JUMP_LAND[1] - JUMP_LAND[0] + 1) / 30.0:
				anim = &"jump"
				index = JUMP_LAND[0] + int(_land_time * 30.0)
				_run = 0.0  # the landing ends in the run's first frame
			elif _throw_left > 0.0:  # the throwing arm over the running legs
				anim = &"throw"
				var back := _throw_left > THROW_TIME * (1.0 - THROW_BACK)
				index = int(_run) + (0 if back else RUN_FRAMES)
			if _hurt_time >= HURT_TIME and _hurt_time < HURT_TIME + STUMBLE:  # the stumble after it
				tilt -= 0.17 * (1.0 - (_hurt_time - HURT_TIME) / STUMBLE)
			if anim == &"run" and _over_edge(w, p):  # held by the back of his box: leaning off the edge
				tilt = 0.08
	# under the tunnel's roof he ducks (his picture is taller than his box)
	if w.state == World.State.RUNNING and not w.hanging:
		var roof := w.ceiling_above(p.x, p.y - World.HERO_SIZE.y / 2, w.draw_scroll())
		var top := p.y + World.HERO_SIZE.y / 2 + GameArt.FEET_SINK - GameArt.HERO_DRAW_HEIGHT
		if roof >= 0.0 and roof > top - 40.0:
			duck = clampf((p.y + World.HERO_SIZE.y / 2 + GameArt.FEET_SINK - roof + 2.0) / GameArt.HERO_DRAW_HEIGHT, 0.8, 1.0)
			tilt += (1.0 - duck) * 0.8
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
	position.x = maxf(position.x, DIE_MIN_X) if w.state == World.State.DEAD else position.x  # the death stays on screen
	rotation = tilt + _swing + _settle
	scale = _squash * _units * Vector2(1.0, duck)
	_sprite.texture = _pages[int(f.page)]
	_sprite.region_rect = Rect2(region[0], region[1], region[2], region[3])
	_sprite.offset = -anchor_px
	# (round 20) the form's shade is measured across this frame (its box about the anchor), its samples kept in it
	var page_size := _sprite.texture.get_size()
	_material.set_shader_parameter(&"region", Vector4(float(region[0]) / page_size.x, float(region[1]) / page_size.y,
			float(region[2]) / page_size.x, float(region[3]) / page_size.y))
	_material.set_shader_parameter(&"figure_box", Vector4(-anchor_px.x, -anchor_px.y, float(region[2]), float(region[3])))
	_mid = (float(region[2]) * 0.5 - anchor_px.x) * _units
	# a white flash on the blow, then (while bandits can't hurt him) a warm red flicker, 4 frames
	# on, 4 off: he stays solid (a faded ghost vanished against the bright savanna); under a
	# pool's surface he fades
	var visible_k := 1.0 - sink
	_visible = visible_k
	_sprite.modulate.a = visible_k
	var flicker := _hurt_left > 0.0 and _knock <= 0.0 and w.state == World.State.RUNNING and fmod(_hurt_left, 8.0 / 60.0) < 4.0 / 60.0
	if _flash > 0.0:
		_material.set_shader_parameter(&"amount", 0.85)
		_material.set_shader_parameter(&"tint", Color(1.0, 0.97, 0.92))
	else:
		_material.set_shader_parameter(&"amount", 0.32 if flicker else 0.0)
		_material.set_shader_parameter(&"tint", Color(1.0, 0.45, 0.35))
	_material.set_shader_parameter(&"opacity", visible_k)
	_material.set_shader_parameter(&"outline_opacity", visible_k * 0.9)  # (his white wraps against the pale sky)
	# round 10 ("hanging from the vine he is pale, nearly vanishes into the sky"): the camera pulls out to frame
	# the vine (about 0.8 of the run's zoom) and his baked ink thins on screen with him; the shader adds ink
	# outside it so its weight on screen stays the run's
	var at_vine := w.state == World.State.RUNNING and (w.hanging or _anim == &"catch")
	_vine_ink = move_toward(_vine_ink, 1.0 if at_vine else 0.0, delta * 4.0)
	_material.set_shader_parameter(&"outline_px", VINE_INK_PX * _vine_ink)
	# (hero pass 3) at home the campfire, on his left, warms that side of him
	var home_k := clampf(_end_time / 0.5, 0.0, 1.0) if phase == &"home" else 0.0
	_material.set_shader_parameter(&"bounce", 0.6 * home_k)
	_material.set_shader_parameter(&"form_amount", lerpf(FORM, FORM_HOME, home_k))
	_material.set_shader_parameter(&"key_amount", lerpf(KEY, KEY_HOME, home_k))
	_material.set_shader_parameter(&"hair_lift", HAIR_LIFT * home_k)
	_home = home_k
	# (round 19, the user: no rim light on him; the judges: "backlit by the door into a halo") no back rim at home
	_material.set_shader_parameter(&"back_rim", 0.0)
	# (round 14: round 13's darker front "merged with the dark doorway": his front light kept at home)
	_material.set_shader_parameter(&"bounce_scale", 2.0 / maxf(float(region[2]), 1.0))
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
			var ground := r * Level.TILE + GameArt.FEET_SINK * (1.0 - HOME_LIFT * _home) - 3.0
			_shadow = Vector2(p.x, ground)
			_shadow.x = p.x + _wall_shift + lerpf(SHADOW_SHIFT, _mid + SHADOW_HOME_SHIFT, _home) \
					+ (_death.x if w.state == World.State.DEAD else 0.0)
			_shadow_k = clampf(1.0 - (ground - feet) / 360.0, 0.0, 1.0)
			return


func _draw_under() -> void:
	if _shadow.x < 0.0:
		return
	# (round 20, the judges: "a yellow bloom smudge at his feet at home instead of a dark contact shadow") at home, in the
	# fire's light on the ground, his shadow under his stride; (round 21: "a hard black hole") soft, its core no longer black
	contact_shadow(_under, _shadow, SHADOW_WIDTH * lerpf(1.0, SHADOW_HOME.x, _home), _shadow_k,
			_visible * lerpf(1.0, SHADOW_HOME.y, _home), _shadow_w, lerpf(1.0, CONTACT_HOME, _home))


## (round 19) Every character's shadow on the ground (Panoramic's, the bandits'): one soft blob, darkest under the
## feet (round 14: no stacked rings, "like a puddle"), a tight darker contact where they stand (grounded, not
## hovering), both in the dusk's warm plum shade, smaller and lighter the higher `k` (1: on the ground, 0: high
## above it). `stretch` widens it (lying down); `core`: the near-black contact's share (round 21: softer at home).
static func contact_shadow(target: CanvasItem, at: Vector2, width: float, k: float, opacity := 1.0, stretch := 1.0, core := 1.0) -> void:
	var w := width * 0.5 * (0.45 + 0.55 * k)
	var a := (1.0 - pow(1.0 - (0.2 * k + 0.05), 6.0)) * opacity
	target.draw_set_transform(at, 0.0, Vector2(stretch, 0.24))
	target.draw_texture_rect(_blob(), Rect2(-w, -w, w * 2.0, w * 2.0), false, Color(SHADOW, a * 0.85))
	# (round 20, the judges: "no visible contact shadow in play") the contact: where the boots meet the ground, near black
	var c := w * 0.6
	target.draw_set_transform(at, 0.0, Vector2(stretch, 0.15))
	target.draw_texture_rect(_blob(), Rect2(-c, -c, c * 2.0, c * 2.0), false, Color(CONTACT, k * k * 0.85 * opacity * core))
	target.draw_set_transform(Vector2.ZERO)


static var _blob_tex: Texture2D


## A soft round shadow: full in the middle, falling smoothly to nothing at the edge (no bands).
static func _blob() -> Texture2D:
	if _blob_tex:
		return _blob_tex
	var n := 64
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := (Vector2(x + 0.5, y + 0.5) / (n / 2.0) - Vector2.ONE).length()
			img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - r * r, 0.0, 1.0), 1.6)))
	img.generate_mipmaps()
	_blob_tex = ImageTexture.create_from_image(img)
	return _blob_tex

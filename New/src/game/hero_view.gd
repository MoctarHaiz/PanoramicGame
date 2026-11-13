class_name HeroView
extends Node2D
## Panoramic: drawn with kie.ai from the user's target picture and a turnaround of their 3D model
## (ROOT/Making/Animation.blend): Nano Banana 2 stills, animated with Seedance clips (2.0 Mini) and
## resampled to the game's slots, packed into atlases (tools/art/hero_atlas_ai.py, assets/art/hero/hero_frames.json;
## the earlier 3D renders: tools/art/hero_atlas.py) and played by the state of the rules:
## - the run: 16 frames (the user, 2026-11-12, shown a 12-drawing stride from a Kling clip beside it: "the hero before
##   run animation was better and smoother": this one stays);
## - the jump: the push-off, then his air poses by how far through the jump he is (the rules decide how high and how
##   far): the rise, the tuck at the top, opening, the fall, braced for the ground; he lands into the run's stride;
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
const RUN_LAND := 1.0  ## the run's drawing a landing goes into: his front boot coming down, his weight onto it next
const TAKEOFF := 0.07  ## seconds of the push-off (the rules have already left the ground)
const THROW_TIME := 0.3  ## the throw: the chakram cocked overhead, then the arm thrown forward (legs running on)
## (2026-11-10: 0.3 -> 0.14: the ring flies 0.04 s after the tap, RingView.WIND_UP; cocked for 0.09 s he still held the
## chakram overhead while it was already in the air ahead of him: the release shows as it leaves)
## His thrown fist in the throw's drawings (the arm flung forward), from his feet (units; measured on the atlas:
## 72 to 76 ahead, 104 to 108 up over the sixteen): the ring is drawn leaving it (RingView.from_hand)
const THROW_FIST := Vector2(74.0, -106.0)
const THROW_BACK := 0.14  ## share of the throw spent with the chakram cocked
const MANTLE := 0.16  ## seconds standing up after a climb over a ledge
const BLINK_HZ := 8.0  ## the mercy pulse after a hit (smooth, not a strobe)
const VINE_Y := 6.0  ## where his hands grip the vine
const GRIP_UP := 14.0  ## atlas px from his wrists up to his grip
## (round 23, the judges: "his hand sits on top of the vine: he seems to float under it") hanging, the middle of his two
## fists (hero_frames.json "fists": tools/art/hero_contacts.py) on the rope's middle line (VineView's spans: their top
## and a quarter of the rope's rows). The user (2026-11-08: "the hands inside the rope flicker"): his grip follows the
## rope as VineView draws it at his hands (its dip under his weight, its breeze), and his fists are drawn over it
## (round 23 drew a strip of the rope again over his fingers: it slid against them as the vine moved).
const ROPE_MID := VineView.Y + VineView.ROPE_PX * 0.25
const WRIST_PX := 14.0  ## atlas px from his fists' middle down to his wrists: above them his fists are kept level
const WRIST_BLEND := 10.0  ## atlas px round his wrists over which they bend
## (round 23, the judges: "a floating dark oval under him: contact occlusion, not an oval") in play, under each sole
## (hero_frames.json "soles") a soft occlusion as dark as the sole is near the ground, gone by SOLE_FADE units up; the
## broad soft shadow under him kept faint (SHADOW_PLAY on the ground, SHADOW_AIR in the air: where he will land)
const SOLE_FADE := 14.0
const STANCE_UP := 7.0  ## units a planted far boot of a three-quarter stance is drawn above the near one's ground
const SOLE_DARK := 0.6
const SHADOW_PLAY := 0.95  ## (blind round 18, in four pictures: "no contact shadows", "throws no shadow on the turf": 0.58 was lost on the turf's dark front; blind round 5: "no cast shadows or ground contact": 0.22 was lost on the grass; round 13: 0.4, "one small shadow blob under one foot")
## Blind round 13 ("the characters receive nothing from the sunset: ground both with real cast shadows"): the sun is
## low: a shadow lies long on the ground, away from it (the characters' shadows this much longer than wide, in play).
const SHADOW_LONG := 1.9
const SHADOW_AIR := 0.6
const WIN_LOOP := 10  ## the cheer at home loops from this frame
const WIN_POSE := 3  ## the win's frame where the landing crouch springs into the victory pose (hero_atlas_ai.py)
## (2026-11-12, the user: "the animations are not full") the jump's own drawings (one kie.ai sheet,
## tools/art/kie/hero_pack.py): until then he leapt in the vine's reach, both arms up from the ground to the ground
## (2026-11-10: its fall drawings were another costume). Now each part of the jump has its pose, changed with a
## little stretch (AIR_POP) so the change reads as a move.
const JUMP_PUSH := 1  ## the push-off
const JUMP_RISE := 2  ## climbing: a knee driven up, an arm thrown up
const JUMP_TUCK := 3  ## the top: knees to his chest
const JUMP_OPEN := 4  ## opening out of it, eyes on the ground ahead
const JUMP_FALL := 5  ## coming down, legs reaching, arms back
const JUMP_BRACE := 6  ## an instant before the ground
const JUMP_THROW := 7  ## a throw in the air: his arm thrown forward
## how far through the jump (World.air_progress()) each pose begins: rise, tuck, open, fall, brace
const AIR_PARTS := [0.0, 0.3, 0.5, 0.66, 0.9]
const AIR_POP := Vector2(0.95, 1.06)  ## the stretch as he changes pose in the air
const LAND_CROUCH := 4  ## at home: the landing's crouch drawings (the old landing, hero_frames.json "land")
const FALL_LEAN := 0.06  ## radians he leans forward into the ground at the end of a fall (the poses lean themselves)
const TOP := 6.0  ## units a tick of vertical speed counted as the top of the jump
const SHADOW_SHIFT := 34.0  ## units the ground shadow falls right of him (the sun is upper left)
const SHADOW_WIDTH := 100.0  ## units across his shadow on the ground, standing on it
const SHADOW := Color(0.11, 0.04, 0.07)  ## the characters' shadows: the dusk's warm plum shade
const CONTACT := Color(0.05, 0.02, 0.03)  ## (round 20) the tight contact under the feet: near black
## (round 21, the judges: "at home his shadow a hard black ellipse offset to the left, a hole") at home a soft occlusion
## right under his stride: this much wider (x) and darker (y) than in play, its near-black contact softened (CONTACT_HOME),
## its middle under his frame's middle a little right of it, away from the fire on his left (SHADOW_HOME_SHIFT units)
## (blind round 14: "a cast shadow away from the fire") and it lies long to his right, thrown by the fire (SHADOW_HOME_LONG)
const SHADOW_HOME := Vector2(1.15, 1.15)
const SHADOW_HOME_SHIFT := 30.0
const SHADOW_HOME_LONG := 1.7
## Blind round 14 ("he does not sit in the dusk: grade the hero into the scene, warm on the fire side, the shadow side
## falling to the dusk's blue-violet; only values and hue"): at home his side away from the fire takes this much of
## HOME_COOL, and all of him HOME_DUSK under the fire's light (actor.gdshader bounce_far, bounce_dusk); no rim, no glow.
const HOME_FAR := 0.9
## (blind round 15: "his loincloth stays day-white, his armour clean blue") his whites and his metal take the light's
## own hue: the fire's orange on its side, the dusk's violet on the other (actor.gdshader bounce_take)
const HOME_TAKE := 1.0
## Blind round 18 ("he throws no shadow on the turf or into the doorway ... a long cast shadow away from the fire"):
## at home the fire throws his shadow on the hut behind him: his own shape, dark, a little larger and to his right
## (the fire is low on his left), under him in the picture; lost in the dark doorway, plain on the thatch beside it.
const HOME_CAST := Color(0.07, 0.035, 0.13)
const HOME_CAST_ALPHA := 0.4
const HOME_CAST_SHIFT := Vector2(46.0, -4.0)  ## units right of him and up
const HOME_CAST_SCALE := Vector2(1.16, 1.03)
const HOME_COOL := Color(0.5, 0.47, 0.86)
const HOME_DUSK := Color(0.74, 0.69, 0.87)  ## (blind round 17: "keeps near-daylight local colours": it was 0.84, 0.8, 0.9)
const HOME_FIRE := Color(1.42, 1.0, 0.62)  ## the fire's side of him (actor.gdshader bounce_colour)
const HOME_BOUNCE := 0.82  ## how much of it all (blind round 16: 0.6 was "too weak to see at phone size")
const CONTACT_HOME := 0.5
## (round 21) at home, where the dark front grass clears to show the ground line, his feet stand this share of
## GameArt.FEET_SINK higher (in play the grass hides the sink; at home his back boot's toe showed under the ground)
const HOME_LIFT := 0.6
const HOLD := 0.1  ## seconds an animation shows at least before another replaces it (no flicker)
const HURT_TIME := 0.33  ## seconds of the blow's reaction
const STUMBLE := 0.14  ## seconds of the stumble after it, leaning back and catching himself
const PULL := 0.16  ## seconds per hand-over-hand pull up a ledge
const LIGHT_GAIN := 1.18  ## his lit colours x this in play (actor.gdshader light_gain; the ink untouched; round 16:
## 1.28 -> 1.18, "traffic-cone orange")
## (round 19) the characters' one line and light system (character.gdshaderinc, shared with BanditView)
const LINE := Color(0.17, 0.085, 0.06)  ## his ink: a dark warm brown, not black
const LINE_INSIDE := 0.55  ## the brown lines inside him (the muscles' grooves, folds) softened towards the colours round them
const SHADE := 0.34  ## his shade tinted towards the dusk's cool ambient (round 23: 0.14 -> 0.22, "lit his own neutral way"; blind round 19:
## "the fighters do not share the scene's dusk": 0.34, by value and hue only)
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
## (round 23, the judges: "dark skin and black ink over dark grass: a dark smudge; thin uniform ink: want a thicker outer
## silhouette line") the silhouette's ink, heavier than the lines inside him (character.gdshaderinc sil_*): atlas texels
## of his own edge drawn in it and round his outside (about 3.5 px on a 1179 px screen with the drawn line; the
## bandits' the same on screen)
const SIL_IN := 1.4
const SIL_OUT := 2.1
const SKIN_LIFT := 0.2  ## his skin's middle values lighter (character.gdshaderinc char_skin)
const FORM_SPLIT := Vector2(-0.12, 0.42)  ## (round 23) a cleaner split between his lit and shade halves (was -0.35 .. 0.75)
const SHADE_COLOUR := Color(0.74, 0.7, 1.0)  ## (round 23) his shadow tones a little towards the dusk's ambient
const WALK_IN := 70.0  ## units he walks into the doorway at home
const DIE_PUSH := 40.0  ## units the fatal blow knocks him back
const DIE_MIN_X := 70.0  ## play x he is never drawn left of when caught (the death stays on screen)
## (round 22, the judges: "the run upright with boxer-guard fists: a jog, not a sprint") the run leans into the stride:
## his chest and head turned forward about his hips (actor.gdshader's bend: his legs and planted boots as drawn) and
## the whole drawing slanted forward from the ground line (Node2D.skew: his boots stay on it; the rules' box as it was),
## eased in with the ground's pace from a standstill, out at a jump's push-off, a landing, a blow
const LEAN_CHEST := 0.2  ## radians his upper body turns forward about his hips at full pace
const LEAN_SLANT := 0.07  ## radians the whole of him slants forward from the ground line
const LEAN_IN := 5.0  ## easing into the lean (/s: most of it in ~0.45 s from a standstill)
const LEAN_OUT := 18.0  ## out of it
const LEAN_REACH := 16.0  ## units his front (the fist, the face) reaches further at full lean (held back from walls)
const BEND_MARGIN := 60.0  ## atlas px his quad is drawn past the frame while bent: room for the turned parts
const BEND_BLEND := 48.0  ## atlas px round his hips over which the bend blends
## (round 22, the judges: "the hang a limp hung doll") hanging, he swings: a pendulum from his hands kept going (pumped
## towards SWING_AMP once the catch's momentum is spent), his legs trailing the swing (bent back about his hips against
## its speed, actor.gdshader's bend) and leading it at its ends, a little tuck there; his hands stay on the grip
const SWING_K := 16.0  ## the pendulum's stiffness (/s^2: a swing of ~1.6 s)
const SWING_AMP := 0.27  ## radians the swing settles to (blind round 17: "a passive frontal dangle": it was 0.17)
const SWING_PUMP := 1.6  ## how fast it settles there (/s)
const SWING_CATCH := -1.5  ## rad/s the catch starts it with (-: legs forward, the jump's momentum)
const SWING_WIND := 0.05  ## radians the wind of the run pushes the swing's middle back
const HANG_BACK := 5  ## the hang clip's drawing with his feet furthest back (its feet-forward ones: 10-1)
const LEG_LAG := 0.14  ## radians his legs bend back per rad/s of swing
const LEG_PIKE := 0.8  ## radians his legs bend further out per radian of swing (at its ends: a pike in front, an arch behind)
const LEG_MAX := 0.32
const TUCK := 0.04  ## at the swing's ends he is drawn this much shorter (knees drawn up)

enum Anchor { FEET, HIPS, HANDS }

static var _data := {}
static var _pages: Array[Texture2D] = []
static var _units := 1.0  # units per atlas pixel
static var _hips_dy := 0.0  # standing: his hips this far above the centre of his box (units, < 0: above)

var _sprite: Sprite2D
var _cast: Sprite2D  # his shadow on the hut at home (HOME_CAST)
var _material: ShaderMaterial
var _anim := &""
var _index := 0
var _clock := 0.0
var _last_time := -1.0
var _run := 0.0  # frames into the run cycle
var _run_rate := 1.0  # the run's pace (1: the ground's speed), eased
var _squash := Vector2.ONE
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
var _legs := 0.0  # hanging: radians his legs are bent back about his hips (trailing the swing)
var _lean := 0.0  # 0..1: how far into the run's lean
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
var _lift := 0.0  # (round 23) 0..1: his feet lifted HOME_LIFT of the sink (at home, on his marks): his shadow with them
var _stand := 0.0  # (round 23) 0..1: standing on his marks (his feet lifted), eased
var _mid := 0.0  # units from his anchor to the middle of the frame shown (his stride's middle at home)
var _fist_px: Array[Vector2] = []  # hanging: his fists' middles (the frame's px from his anchor)
var _sole_px: Array[Vector3] = []  # each sole: its two ends' x and its y (the frame's px from his anchor)


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
	_cast = Sprite2D.new()  # (first: drawn under his own picture)
	_cast.centered = false
	_cast.region_enabled = true
	_cast.visible = false
	_cast.scale = HOME_CAST_SCALE
	_cast.position = HOME_CAST_SHIFT
	_cast.material = ShaderMaterial.new()
	_cast.material.shader = preload("res://src/game/cast.gdshader")
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
	_material.set_shader_parameter(&"sil_colour", LINE)  # (round 23) the silhouette's ink, his skin, the light's split
	_material.set_shader_parameter(&"sil_in_px", SIL_IN)
	_material.set_shader_parameter(&"sil_out_px", SIL_OUT)
	_material.set_shader_parameter(&"skin_lift", SKIN_LIFT)
	_material.set_shader_parameter(&"form_split", FORM_SPLIT)
	_material.set_shader_parameter(&"shade_colour", SHADE_COLOUR)
	# (round 12, "top runners light the hero brightest on screen") his lit side raised in the level's light
	_material.set_shader_parameter(&"light_gain", LIGHT_GAIN)
	_material.set_shader_parameter(&"bounce_cool", HOME_COOL)
	_material.set_shader_parameter(&"bounce_dusk", HOME_DUSK)
	_material.set_shader_parameter(&"bounce_colour", HOME_FIRE)
	_sprite.material = _material
	add_child(_cast)
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
	# (2026-11-12) no landing played out before he runs on (0.2 s in a crouch drawn for another costume): he comes
	# down into the stride, his front boot landing, and the squash takes the weight
	_run = RUN_LAND
	var k := clampf(_world.land_speed / 45.0, 0.3, 1.1) if _world else 1.0  # a step down lands softly, a drop hard
	_squash = Vector2(1.0 + 0.1 * k, 1.0 - 0.1 * k)


func jumped() -> void:
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
	var stand_lift := 0.0  # (round 23) 1: standing on his marks, lifted as at home (HOME_LIFT)
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
				anim = &"land"
				index = mini(int(t / World.HOME_LAND * LAND_CROUCH), LAND_CROUCH - 1)
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
				index = JUMP_FALL
				anchor = Anchor.HIPS
				tilt = sin(t * 16.0) * 0.18
				var surface := World.SURFACE_Y - World.HERO_SIZE.y / 2
				if w.water_at(w.draw_scroll() + p.x):
					sink = clampf((p.y - surface) / 70.0, 0.0, 1.0)
		&"idle":  # on his marks: standing, breathing
			anim = &"idle"
			index = int(_clock * float(frames_data().anims.idle.fps)) % frames(&"idle").size()
			# (round 23) standing, his back boot's toe reached under the grass's front edge (a blue scrap under the
			# ground, its new ink round it): he stands as at home, HOME_LIFT of the sink higher (eased: _stand)
			stand_lift = 1.0
		&"hang":  # the last of the catch, then hanging by his hands
			anchor = Anchor.HANDS
			if t < 0.1:
				anim = &"catch"
				index = 2 + mini(int(t / 0.05), 1)
			else:
				anim = &"hang"
				var n := frames(anim).size()
				index = int(_clock * float(frames_data().anims.hang.fps)) % n
				# (round 22) the clip's own leg sway played by the swing (below): its feet-back drawing at the swing's
				# back end, its feet-forward ones at the front, so the two move as one (they cancelled out on their
				# own clocks); no lift and lean flipping at each grip (a 5 Hz shiver that lifted his hands off the vine)
				var x := _swing - _wind(w)
				var v := _swing_speed / sqrt(SWING_K)
				if x * x + v * v > 0.03 * 0.03:
					index = posmod(HANG_BACK + roundi(atan2(-v, x) / TAU * n), n)
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
			index = JUMP_PUSH
		&"rise", &"apex", &"fall":
			anim = &"jump"
			anchor = Anchor.HIPS
			var ap := w.air_progress()  # 0..1 through his time in the air (the rules decide how long)
			if ap >= 0.0:
				index = JUMP_RISE
				for i in AIR_PARTS.size():
					if ap >= AIR_PARTS[i]:
						index = JUMP_RISE + i
				tilt = lerpf(-0.05, FALL_LEAN, ap)
				if _throw_left > 0.0:  # a throw in the air: his arm thrown forward, legs trailing
					index = JUMP_THROW
					tilt = 0.0
			elif w.vy < 0.0 and w.rising_to_vine() and p.y < 150.0:  # reaching up into the vine
				anim = &"catch"
				index = clampi(int((1.0 - p.y / 150.0) * 2.0), 0, 1)
			elif w.vy < 0.0:
				index = JUMP_RISE if -w.vy > TOP * 2.0 else JUMP_TUCK
			else:  # no ground ahead: a fall into a pit, flailing
				index = JUMP_FALL
				tilt = sin(_clock * 16.0) * 0.18
				var surface := World.SURFACE_Y - World.HERO_SIZE.y / 2
				if w.water_at(w.draw_scroll() + p.x):
					sink = clampf((p.y - surface) / 70.0, 0.0, 1.0)
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
			elif _throw_left > 0.0:  # the throwing arm over the running legs
				anim = &"throw"
				var back := _throw_left > THROW_TIME * (1.0 - THROW_BACK)
				index = int(_run) + (0 if back else RUN_FRAMES)
			if _hurt_time >= HURT_TIME and _hurt_time < HURT_TIME + STUMBLE:  # the stumble after it
				tilt -= 0.17 * (1.0 - (_hurt_time - HURT_TIME) / STUMBLE)
			if anim == &"run" and _over_edge(w, p):  # held by the back of his box: leaning off the edge
				tilt = 0.08
	# (round 23) on his marks, lifted (eased off as he runs; at once on the first frame)
	_stand = stand_lift if _anim == &"" else lerpf(_stand, stand_lift, 1.0 - exp(-dt * 10.0))
	offset.y -= GameArt.FEET_SINK * HOME_LIFT * _stand
	stand_lift = _stand
	# under the tunnel's roof he ducks (his picture is taller than his box)
	if w.state == World.State.RUNNING and not w.hanging:
		var roof := w.ceiling_above(p.x, p.y - World.HERO_SIZE.y / 2, w.draw_scroll())
		var top := p.y + World.HERO_SIZE.y / 2 + GameArt.FEET_SINK - GameArt.HERO_DRAW_HEIGHT
		if roof >= 0.0 and roof > top - 40.0:
			duck = clampf((p.y + World.HERO_SIZE.y / 2 + GameArt.FEET_SINK - roof + 2.0) / GameArt.HERO_DRAW_HEIGHT, 0.8, 1.0)
			tilt += (1.0 - duck) * 0.8
	# (round 22) the run's lean: as much as the ground's pace under him (none standing, walking in at home, blocked)
	var lean_to := 0.0
	if playing and anim in [&"run", &"throw"] and phase != &"home":
		lean_to = smoothstep(0.2, 0.85, ground_speed / (World.SCROLL_SPEED / World.TICK))
	_lean = lerpf(_lean, lean_to, 1.0 - exp(-dt * (LEAN_IN if lean_to > _lean else LEAN_OUT)))
	if w.state != World.State.RUNNING:
		_lean = 0.0
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
			var grip_y := VINE_Y
			if f.has("fists") and (f.fists as Array).size() == 2:  # (round 23) his fists' middle on the rope's middle
				grip = (Vector2(f.fists[0][0], f.fists[0][1]) + Vector2(f.fists[1][0], f.fists[1][1])) / 2.0
				grip_y = ROPE_MID
			else:
				grip = Vector2((float(f.hand_r[0]) + float(f.hand_l[0])) / 2.0, minf(f.hand_r[1], f.hand_l[1]) - GRIP_UP)
			anchor_px = grip
			# his hips over his box; his grip on the rope where it is drawn at his hands (it dips under him, sways)
			var hand_x := p.x + (grip.x - float(f.hips[0])) * _units
			var vine := _find_vine()
			if vine != null:
				grip_y += vine._drawn_sag(hand_x)
			position = Vector2(hand_x, grip_y)
	# (round 23) his fists on the vine (the strand over his fingers) and his soles (their contact on the ground)
	_fist_px.clear()
	if anchor == Anchor.HANDS and f.has("fists"):
		for q: Array in f.fists:
			_fist_px.append(Vector2(q[0], q[1]) - anchor_px)
	_sole_px.clear()
	if f.has("soles"):
		for s: Array in f.soles:
			_sole_px.append(Vector3(float(s[0]) - anchor_px.x, float(s[1]) - anchor_px.x, float(s[2]) - anchor_px.y))
	# hanging: a pendulum from his hands, pushed back by the wind of the run; (round 22) kept swinging: the catch's
	# momentum spent down to SWING_AMP, then pumped to it (its energy measured as the amplitude it would reach)
	var swing_end := 0.0  # 0..1: how near the end of a swing he is
	if w.hanging and not _was_hanging:
		_swing_speed = SWING_CATCH  # the jump's momentum swings his legs forward
	_was_hanging = w.hanging
	if w.hanging:
		var x := _swing - _wind(w)
		var amp := sqrt(_swing_speed * _swing_speed / SWING_K + x * x)
		var accel := -SWING_K * x + SWING_PUMP * (1.0 - amp / SWING_AMP) * _swing_speed
		_swing_speed += accel * dt
		_swing += _swing_speed * dt
		swing_end = clampf(x * x / maxf(amp * amp, 0.0001), 0.0, 1.0) * clampf(amp / SWING_AMP, 0.0, 1.0)
	else:
		_swing = lerpf(_swing, 0.0, 1.0 - exp(-dt * 10.0))
		_swing_speed = 0.0
	# his legs trail the swing (against its speed) and lead it at its ends (piked forward at the front, arched back
	# behind), springing after it: never hanging straight
	var legs_to := 0.0
	if w.hanging:
		legs_to = clampf(LEG_PIKE * (_swing - _wind(w)) - LEG_LAG * _swing_speed, -LEG_MAX, LEG_MAX)
	_legs = lerpf(_legs, legs_to, 1.0 - exp(-dt * 18.0))
	duck *= 1.0 - TUCK * swing_end * swing_end
	# the knock back of a blow: thrown back and up a little
	if _knock > 0.0 and w.state == World.State.RUNNING:
		var e := _knock * _knock
		offset += Vector2(-34.0 * e, -18.0 * sin(_knock * PI))
	# at a wall: his picture reaches past the chest the rules stop, so it is held back from the face
	# ahead (before and while it blocks him): his hands and knee rest on the wall
	var shift := 0.0
	var front := (float(region[2]) - anchor_px.x) * _units * _squash.x + LEAN_REACH * _lean
	var face := w.wall_ahead(p.x, p.y, front + 4.0, w.draw_scroll()) if w.state == World.State.RUNNING and not w.hanging else -1.0
	if face >= 0.0:
		shift = minf(face - 4.0 - (p.x + front), 0.0)
	_wall_shift = lerpf(_wall_shift, shift, 1.0 - exp(-dt * 22.0))
	offset.x += _wall_shift
	position += offset
	position.x = maxf(position.x, DIE_MIN_X) if w.state == World.State.DEAD else position.x  # the death stays on screen
	rotation = tilt + _swing + _settle
	skew = LEAN_SLANT * _lean
	scale = _squash * _units * Vector2(1.0, duck)
	_sprite.texture = _pages[int(f.page)]
	# (round 22) the bend about his hips: the run's lean (his chest forward), the hang's legs trailing the swing; while
	# bent, his quad is drawn BEND_MARGIN past the frame (the shader keeps to the frame's own rectangle)
	var bend_up := LEAN_CHEST * _lean
	var bend_down := _legs
	var bent := absf(bend_up) + absf(bend_down) > 0.001
	# (round 23) hanging, his fists turned back against his swing (above his wrists): level on the vine, his body
	# swinging from them
	var gripped := not _fist_px.is_empty()
	var m := BEND_MARGIN if bent or gripped else 0.0
	_sprite.region_rect = Rect2(float(region[0]) - m, float(region[1]) - m, float(region[2]) + 2.0 * m, float(region[3]) + 2.0 * m)
	_sprite.offset = -anchor_px - Vector2(m, m)
	_material.set_shader_parameter(&"grip_on", gripped)
	if gripped:
		_material.set_shader_parameter(&"grip_pivot", Vector2(0.0, WRIST_PX))
		_material.set_shader_parameter(&"grip_turn", -rotation)
		_material.set_shader_parameter(&"grip_blend", WRIST_BLEND)
	_material.set_shader_parameter(&"bend_on", bent)
	if bent:
		_material.set_shader_parameter(&"bend_pivot", Vector2(f.hips[0], f.hips[1]) - anchor_px)
		_material.set_shader_parameter(&"bend_up", bend_up)
		_material.set_shader_parameter(&"bend_down", bend_down)
		_material.set_shader_parameter(&"bend_blend", BEND_BLEND)
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
	_material.set_shader_parameter(&"outline_opacity", visible_k)  # (round 23: the silhouette's ink solid)
	# round 10 ("hanging from the vine he is pale, nearly vanishes into the sky"): the camera pulls out to frame
	# the vine (about 0.8 of the run's zoom) and his baked ink thins on screen with him; the shader adds ink
	# outside it so its weight on screen stays the run's
	var at_vine := w.state == World.State.RUNNING and (w.hanging or _anim == &"catch")
	_vine_ink = move_toward(_vine_ink, 1.0 if at_vine else 0.0, delta * 4.0)
	_material.set_shader_parameter(&"outline_px", VINE_INK_PX * _vine_ink)
	# (hero pass 3) at home the campfire, on his left, warms that side of him
	var home_k := clampf(_end_time / 0.5, 0.0, 1.0) if phase == &"home" else 0.0
	_material.set_shader_parameter(&"bounce", HOME_BOUNCE * home_k)
	_material.set_shader_parameter(&"bounce_far", HOME_FAR * home_k)
	_material.set_shader_parameter(&"bounce_take", HOME_TAKE * home_k)
	_material.set_shader_parameter(&"form_amount", lerpf(FORM, FORM_HOME, home_k))
	_material.set_shader_parameter(&"key_amount", lerpf(KEY, KEY_HOME, home_k))
	_material.set_shader_parameter(&"hair_lift", HAIR_LIFT * home_k)
	_home = home_k
	_cast.visible = home_k > 0.01
	if _cast.visible:
		_cast.texture = _sprite.texture
		_cast.region_rect = _sprite.region_rect
		_cast.offset = _sprite.offset
		_cast.flip_h = _sprite.flip_h
		_cast.modulate = Color(HOME_CAST, HOME_CAST_ALPHA * home_k * _sprite.modulate.a)
	_lift = maxf(home_k, stand_lift)
	# (round 19, the user: no rim light on him; the judges: "backlit by the door into a halo") no back rim at home
	_material.set_shader_parameter(&"back_rim", 0.0)
	# (round 14: round 13's darker front "merged with the dark doorway": his front light kept at home)
	_material.set_shader_parameter(&"bounce_scale", 2.0 / maxf(float(region[2]), 1.0))
	_update_shadow(w, p)
	if is_instance_valid(_under):
		_under.queue_redraw()


## Hanging: the swing's middle, pushed back by the wind of the run (none while a wall holds him).
func _wind(w: World) -> float:
	return 0.0 if w.blocked else SWING_WIND


## Standing with his middle past the end of the grass (the rules hold him while any of his box is
## over it).
func _over_edge(w: World, p: Vector2) -> bool:
	var row := floori((w.ground_y + World.HERO_SIZE.y / 2 + 1.0) / Level.TILE)
	return w.level.kind_at(floori((w.draw_scroll() + p.x + 6.0) / Level.TILE), row) != Level.Kind.TOP


func _set_anim(anim: StringName, index: int) -> void:
	if anim != _anim and _anim == &"jump" and anim == &"catch":
		_settle = 0.0
	if anim == &"jump" and _anim == &"jump" and index != _index and index > JUMP_RISE:
		_squash = AIR_POP
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
			var ground := r * Level.TILE + GameArt.FEET_SINK * (1.0 - HOME_LIFT * _lift) - 3.0
			_shadow = Vector2(p.x, ground)
			_shadow.x = p.x + _wall_shift + lerpf(SHADOW_SHIFT, _mid + SHADOW_HOME_SHIFT, _home) \
					+ (_death.x if w.state == World.State.DEAD else 0.0)
			_shadow_k = clampf(1.0 - (ground - feet) / 360.0, 0.0, 1.0)
			return


func _draw_under() -> void:
	if _shadow.x < 0.0:
		return
	# (round 23) each sole's contact: where it is (his transform as drawn: the vine's sag, the squash), as dark as it is
	# near the ground
	var feet := _shadow.y + 3.0
	var t := transform
	var lowest := INF  # units his lowest sole is above the ground
	# standing in a three-quarter stance (on his marks, the victory, the crouch) his far boot is drawn higher on the
	# picture and still planted: its contact under it, where it stands; in the run's side view the ground is one line
	var stance := _anim in [&"idle", &"win", &"crouch"]
	for s in _sole_px:
		var a := t * Vector2(s.x, s.z)
		var b := t * Vector2(s.y, s.z)
		var h := feet - maxf(a.y, b.y)
		lowest = minf(lowest, h)
		var k := 1.0 - smoothstep(STANCE_UP if stance else 0.0, SOLE_FADE, h)
		if k <= 0.0:
			continue
		var at := Vector2((a.x + b.x) * 0.5, minf(maxf(a.y, b.y), feet) - 1.5 if stance else feet - 1.5)
		var half := absf(b.x - a.x) * 0.5 + 3.0
		_under.draw_set_transform(at, 0.0, Vector2(1.0, 0.26))
		var r := half * 1.9 * (1.0 + 0.4 * (1.0 - k))
		_under.draw_texture_rect(_blob(), Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(SHADOW, k * 0.45 * _visible))
		_under.draw_set_transform(at, 0.0, Vector2(1.0, 0.24))
		r = half * 1.15
		_under.draw_texture_rect(_blob(), Rect2(-r, -r, r * 2.0, r * 2.0), false,
				Color(CONTACT, k * k * SOLE_DARK * _visible * lerpf(1.0, CONTACT_HOME, _home)))
	_under.draw_set_transform(Vector2.ZERO)
	# the broad soft shadow under him: (round 23) in play faint while he stands on the ground (the soles' contacts ground
	# him), a drop shadow when he is in the air; (round 20, the judges: "a yellow bloom smudge at his feet at home instead
	# of a dark contact shadow") at home, in the fire's light on the ground, his shadow under his stride; (round 21: "a hard
	# black hole") soft, its core no longer black
	var air := smoothstep(4.0, 30.0, lowest) if lowest < INF else 1.0
	var broad := lerpf(lerpf(SHADOW_PLAY, SHADOW_AIR, air), SHADOW_HOME.y, _home)
	contact_shadow(_under, _shadow, SHADOW_WIDTH * lerpf(1.0, SHADOW_HOME.x, _home), _shadow_k,
			_visible * broad, _shadow_w * lerpf(SHADOW_LONG, SHADOW_HOME_LONG, _home), CONTACT_HOME * _home)


var _vine: VineView


## (round 23) The vine he hangs from (WorldView's "Vine", beside his parent): his grip follows it as drawn.
func _find_vine() -> VineView:
	if not is_instance_valid(_vine) and get_parent() and get_parent().get_parent():
		_vine = get_parent().get_parent().get_node_or_null(^"Vine") as VineView
	return _vine


## (round 19) Every character's shadow on the ground (Panoramic's, the bandits'): one soft blob, darkest under the
## feet (round 14: no stacked rings, "like a puddle"), a tight darker contact where they stand (grounded, not
## hovering), both in the dusk's warm plum shade, smaller and lighter the higher `k` (1: on the ground, 0: high
## above it). `stretch` widens it (lying down); `core`: the near-black contact's share (round 21: softer at home).
static func contact_shadow(target: CanvasItem, at: Vector2, width: float, k: float, opacity := 1.0, stretch := 1.0, core := 1.0) -> void:
	var w := width * 0.5 * (0.45 + 0.55 * k)
	var a := (1.0 - pow(1.0 - (0.2 * k + 0.05), 6.0)) * opacity
	target.draw_set_transform(at, 0.0, Vector2(stretch, 0.3))
	target.draw_texture_rect(_blob(), Rect2(-w, -w, w * 2.0, w * 2.0), false, Color(SHADOW, minf(a, 0.9)))
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

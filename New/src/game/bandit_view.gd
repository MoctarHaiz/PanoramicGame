class_name BanditView
extends Node2D
## A bandit (World.Bandit), one of two kinds that come at random (World.is_strong(): about 3 in 10 are strong
## and take 3 rings; jumpers leap over a ring coming at them, drawn in the leap pose): the user's bandit (spiky
## teal hair, a torn red scarf, a yellow shirt with its round steel emblem, golden shin guards) and the strong
## one, their leader (muscular, bright-blue hair, a dark-red cape-scarf, the black-and-white emblem, blue wraps),
## drawn bigger. Both drawn with kie.ai from the user's
## pictures, their runs from Seedance clips (tools/art/bandit_sheet.py packs assets/art/bandit/<kind>.png).
## Placed at its feet. It waits crouched and breathing until it enters the play window, then runs (its clip's
## loop, at the pace that keeps the planted boot on the ground). What the rules have it do in the world shows
## (2026-11-10, World._sense): a "!" as it spots him, its jump along a leap over a pool or onto a wall (leaning
## along the arc, a squash and dust as it lands), its fighting stance while it holds a bank as a guard (turning
## to watch him once he is past), stopped on its heels by a ring. As it closes on Panoramic it
## draws its fist back and punches (the rules' reach in front of it), so the blow is seen coming. A ring
## makes it flash white and recoil; after the first one it runs dazed (rocking, stars circling its head).
## The second knocks it out (the redesign, 2026-11-12, with the user's yes; the blind judges, four rounds: "the grey
## glaze reads as a fade bug; show a full-colour recoil, a knockback, a burst in the ring's colours"): frozen a
## moment on the blow in its recoil, then thrown back off its feet in its own colours, turning over backward along a
## low arc, and gone in a puff and a few sparks at the arc's end. (2017's chrome glaze and twirl are retired.)
##
const DIR := "res://assets/art/bandit/"
const FLASH_TIME := Fx.FLASH_TIME  ## New (audio): the shared impact's white, 2 frames, then the reaction shows
const KO_HOLD := 0.08  ## seconds frozen on the blow, in its recoil
const KO_FLIGHT := 0.5  ## seconds thrown back through the air
const KO_BACK := 150.0  ## units it is thrown back, the way the ring flew
const KO_UP := 92.0  ## units its arc rises: over the heads of those behind it
## (blind round 5: "an unreadable smear inside a pale ring"; "two enemies stacked into one tangled silhouette": its
## recoil pose stays readable (it leans back, it does not turn over), no ring of light is drawn over it, and it is
## thrown away from the play: smaller and paler as it goes, so it never tangles with the bandit behind it)
const KO_TURN := 0.6  ## radians it leans back in the flight
## (blind round 6: "bleached pale with a glow: a transparency glitch, not a hit": it keeps its full colours to the end)
const KO_AWAY := 0.1  ## how much smaller it is at the flight's end (thrown away from the play)
## (blind round 10: a dark-clothed bandit thrown back read as "a dark smudge: the hero seems to punch a shadow": the
## line round a knocked-out bandit turns to a warm white for its flight, so its recoil pose reads on any ground)
const KO_LINE := Color(1.0, 0.95, 0.82)
const KO_LINE_WIDTH := 1.7  ## times its usual width
const KO_POOF := 0.12  ## seconds, the flight's last: it shrinks into its puff
## its puff's sparks: the chakram's steel blue, its beadwork's red and white
const KO_SPARKS: Array[Color] = [Color("ffffff"), Color("6cc4ff"), Color("e82808"), Color("ffd36b")]
const HIT_TIME := 0.2  ## seconds the first ring's recoil shows
const DAZE_ROCK := 0.08  ## radians it rocks on its feet while dazed
## Once it has struck him it can't again: it vaults over him (drawn only) instead of running
## through his body.
const VAULT_TIME := 0.46  ## seconds
const VAULT_HEIGHT := 150.0  ## units: over his head
const STAR_COUNT := 3
const STAR_RISE := 30.0  ## units the dazed stars circle above the middle of its hair
## (round 19) The characters' one line and light system (character.gdshaderinc, as Panoramic's): the same warm
## brown ink and dusk shade, and the bandits graded down (their hues kept: the user's design) so he stays the
## hottest, clearest shape on screen ("the cyan-haired bandits are the most saturated shapes, they read as the stars").
const SATURATION := 1.0  ## (round 23: the grade is the dark core's below)
const VALUE := 1.0
const SHADE := 0.2
## (round 21, the judges: "the bandits read first: as big as him, higher, darker on the sky") their sizes are the user's;
## pushed back in value instead, towards the sky's haze (round 22, the judges: "now lighter, bigger and more detailed
## than the hero"): the other way now, every colour drawn this far into the scene's shade (bandit.gdshader haze: RECEDE,
## the muted plum of the rocks' shaded faces; SATURATION, VALUE above lower), their values pulled together (half the
## contrast, the whites of their shirts down to the shade's), so they sit back as figures in the shade and he, the one
## lit with a warm key, leads. (Tried: the darker shade (0.3, 0.23, 0.31) at 0.42 drew them as dark cut-outs on the sky.)
## (round 23, the judges, j19: "ghosted, semi-transparent, a disabled state: plum-grey at the sky's value") a dark core
## instead (bandit.gdshader): their values pulled down well under the sky's and the mesas' (CORE_VALUE), their colours
## muted (CORE_SAT), their form and ink kept (solid figures, not black cut-outs), a breath of the scene's shade (HAZE),
## and one costume accent of each kind kept in colour (ACCENT: its head-wrap); the silhouette's ink of Panoramic's
## weight on screen (HeroView.SIL_IN, SIL_OUT at this sheet's scale). Panoramic stays the most saturated, highest-contrast.
const HAZE := 0.03
const RECEDE := Color(0.4, 0.31, 0.38)
const CORE_SAT := 0.96  ## (the user, 2026-11-08: "too dark, we don't see them": r23's 0.5 / 0.55 core lifted; 2026-11-12,
## "some assets are not good quality": at 0.8 / 0.9 they were the one washed-out drawing in a vivid scene)
const CORE_VALUE := 0.97
const CORE_TINT := Color(1.1, 0.95, 0.86)  ## (the grey they are muted towards: a warm umber, skin not ash)
const CORE_FLOOR := 0.06  ## their darkest value: their black trousers keep their folds over the ink (not a cut-out)
const INK := Color(0.075, 0.04, 0.035)  ## their silhouette's ink: darker than Panoramic's brown, under their dark core
## kind -> [its hues (degrees from, to, least saturation, least value), its brightest, where round its head (sheet px:
## left, top, right, bottom), its saturation and value x as drawn]: the bandit's indigo wrap, the strong one's rust wrap
## (its skin, the same hue, is brighter and less saturated; its crimson cape redder)
const ACCENT := {
	# (the savanna raiders, 2026-11-12: painted in their own colours; no accent is lifted: x 1.0)
	&"bandit": [Vector4(205.0, 268.0, 0.18, 0.18), 1.0, Vector4(-75.0, -95.0, 95.0, 8.0), 1.0, 1.0],
	&"bandit_strong": [Vector4(6.0, 34.0, 0.58, 0.22), 0.8, Vector4(-80.0, -70.0, 70.0, 8.0), 1.0, 1.0],
	&"bandit_a": [Vector4(205.0, 268.0, 0.18, 0.18), 1.0, Vector4(-75.0, -95.0, 95.0, 8.0), 1.0, 1.0],
	&"bandit_strong_a": [Vector4(6.0, 34.0, 0.58, 0.22), 0.8, Vector4(-80.0, -70.0, 70.0, 8.0), 1.0, 1.0],
}
const SHADOW_WIDTH := 84.0  ## units across its shadow on the ground (Panoramic's: 100)
const SHADOW_SHIFT := 8.0  ## its shadow falls a little right of it, away from the sun (upper left), as his does

const KINDS: Array[StringName] = [&"bandit", &"bandit_strong", &"bandit_a", &"bandit_strong_a"]
## Each kind's two looks (the user, 2026-11-12, having seen both: "use the 2 versions of the bandits"): the savanna
## raiders (a braid and a hyena pelt; the horned brute) and the user's own two bandits redrawn in the hero's
## proportions (the head-wrap and the scarf; the headband and the cape). A bandit is one or the other for good
## (look_of: in turns along the level), so a band of them is mixed. Same drawings, pivots and sizes in both: the
## rules see no difference.
const LOOKS := {false: [&"bandit", &"bandit_a"], true: [&"bandit_strong", &"bandit_strong_a"]}
static var _kinds := {}  # kind -> [its bandit.json data, its sheet]

## How far a running bandit's body reaches ahead of its centre (units): pressed on a wall, its crest
## touches the face.
const REACH := 42.0

var world: World
var wall_shift := 0.0  ## held off a wall face it is pressed on (units, >= 0; WorldView eases it)
var bandit: World.Bandit
var kind: StringName
var _d: Dictionary  # this kind's sheet data
var _tex: Texture2D  # this kind's sheet
var _sprite: Sprite2D
var _material: ShaderMaterial
var _front: Node2D  # what is drawn over the sprite (the stars in front of its head)
var _ground_shadow: Node2D
var _run_frames := 10
## The sheet is drawn at its own scale (bandit.json: px a unit, the hero's atlas' density); the drawing is
## about 120 units from its crest to its boots, four fifths of Panoramic's height. Its hit box
## (World.BANDIT_SIZE, the 2017 rules) is unchanged; rings meet it at chest height either way.
const DRAW_SCALE := 1.0
## Each kind drawn at this share of its sheet (the user, 2026-11-07: the strong one as tall as the hero, the bandit
## smaller). Measured 2026-11-08 (r23): the strong one's dreadlock tufts above his wrap made him 1.07 x the hero on
## screen (366 px against 344): 0.94 brings his whole silhouette, tufts included, to the hero's height. His run
## pace is raised by as much (a shorter stride at the same ground speed), so his planted boot doesn't slide. The
## rules' body (World.STRONG_BODY, to the top of his wrap at full size) is unchanged: its top now meets his tufts' tips.
const KIND_SCALE := {&"bandit": 1.0, &"bandit_strong": 0.94, &"bandit_a": 1.0, &"bandit_strong_a": 0.94}

var _scale := 0.5
var _last_time := -1.0
var _run := 0.0  # position in the run cycle (frames)
var _breath := 0.0
var _flash := 0.0
var _jolt := 0.0  # units pushed back by the last ring, springing to 0
var _squash := Vector2.ONE
var _stars := 0.0  # 0..1: dazed stars showing
var _star_turn := 0.0
var _hit_left := 0.0  # seconds of the recoil still to show
var _grounded := true
var _air_hold := 0.0  # seconds its leap is still shown after it stands again
const AIR_HOLD := 0.12
var _air_time := 0.0  # seconds since it left the ground
const TAKEOFF_TIME := 0.1  ## seconds its take-off frame shows as it leaves the ground
const JUMP_DY := 6.0  ## units a tick: faster up is its rise, faster down its fall, between them the top
var _head := Vector2.ZERO  # the middle of its hair in this frame, local units
# knocked out
var _ko := false
var _ko_time := 0.0
var _pushed := 0.0  # 0..1 of KO_BACK done
var _poofed := false
var _lit := false  # its line is the knock-out's white
var _vault := -1.0  # 0..1 through the vault over him (-1: not vaulting)
var _lift := 0.0  # units it is drawn above the ground (the vault)
## (2026-11-10, the user: "their animation are not quite good, and the interaction of the enemies in the world should
## be improved") what it does in the world now shows (World._sense): it spots him as it wakes (a start, a "!" over its
## head), leans along a leap's arc and lands with a squash, holds its bank in its fighting stance (turning to watch
## him once he is past), stands stopped by a ring for as long as the rules stop it, and stands down when he is caught.
const SPOT_TIME := 0.55  ## seconds the "!" shows over its head as it wakes
const SPOT_RISE := 34.0  ## units over the middle of its hair
const ARC_LEAN := 0.011  ## radians its body leans per unit a tick of a leap's vertical speed (nose up rising)
const ARC_LEAN_MAX := 0.24
const TURN_TIME := 0.14  ## seconds a guard takes to turn round
const TURN_PAST := 26.0  ## units he is past its middle before it turns to watch him
var _spot := 0.0  # seconds left of the "!"
var _was_active := false
var _lean := 0.0  # radians it leans along a leap
var _facing := 1.0  # 1: left, as drawn; -1: turned round (a guard watching him go)
var _stand_down := 0.0  # 0..1: he is caught: it stands down into its stance
var landed_seen := -99  # the landing (World.Bandit.landed_tick) WorldView has shown


static func load_art() -> void:
	if not _kinds.is_empty():
		return
	for k in KINDS:
		if ResourceLoader.exists(DIR + k + ".png"):
			_kinds[k] = [JSON.parse_string(FileAccess.get_file_as_string(DIR + k + ".json")), load(DIR + k + ".png")]


func _init(w: World, b: World.Bandit) -> void:
	world = w
	bandit = b
	load_art()
	var looks: Array = LOOKS[b.strong]  # (World.is_strong)
	kind = looks[look_of(w, b)]
	if not _kinds.has(kind):
		kind = looks[0]
	_d = _kinds[kind][0]
	_tex = _kinds[kind][1]
	_run_frames = int(_d.run_frames)
	_scale = DRAW_SCALE * float(KIND_SCALE[kind]) / float(_d.texture_scale)
	_sprite = Sprite2D.new()
	_sprite.texture = _tex
	_sprite.region_enabled = true  # the frames are packed, each its own rectangle: bandit.json
	_sprite.centered = false
	_sprite.scale = Vector2.ONE * _scale
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/game/bandit.gdshader")
	_material.set_shader_parameter(&"seed", fmod(b.id * 1.7, 13.0))
	_material.set_shader_parameter(&"line_colour", HeroView.LINE)
	_material.set_shader_parameter(&"line_inside", HeroView.LINE_INSIDE)
	_material.set_shader_parameter(&"saturation", SATURATION)
	_material.set_shader_parameter(&"value", VALUE)
	_material.set_shader_parameter(&"shade_amount", SHADE)
	_material.set_shader_parameter(&"haze_amount", HAZE)
	_material.set_shader_parameter(&"haze", RECEDE)
	_material.set_shader_parameter(&"core_sat", CORE_SAT)
	_material.set_shader_parameter(&"core_value", CORE_VALUE)
	_material.set_shader_parameter(&"core_tint", CORE_TINT)
	_material.set_shader_parameter(&"core_floor", CORE_FLOOR)
	var acc: Array = ACCENT[kind]
	_material.set_shader_parameter(&"accent_hue", acc[0])
	_material.set_shader_parameter(&"accent_vmax", acc[1])
	_material.set_shader_parameter(&"accent_box", acc[2])
	_material.set_shader_parameter(&"accent_sat", acc[3])
	_material.set_shader_parameter(&"accent_value", acc[4])
	# the silhouette's ink as wide on screen as Panoramic's (his atlas texel over this sheet's)
	var texel := float(HeroView.frames_data().units_per_px) * float(_d.texture_scale)
	_material.set_shader_parameter(&"sil_colour", INK)
	_material.set_shader_parameter(&"sil_in_px", HeroView.SIL_IN * texel / float(KIND_SCALE[kind]))
	_material.set_shader_parameter(&"sil_out_px", HeroView.SIL_OUT * texel / float(KIND_SCALE[kind]))
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
	_show(int(_d.run) + int(_run))


## Which of its kind's two looks a bandit has: the small ones take turns along the level, and so do the strong ones,
## so both looks are met from the first bands on and a band of them is mixed.
static func look_of(w: World, b: World.Bandit) -> int:
	var before := 0
	for o in w.bandits:
		if o.strong == b.strong and o.id < b.id:
			before += 1
	return before % 2


## Called by WorldView every frame while the bandit is in the game. `grounded`: on its ledge this tick (not hopping a
## wall, not leaping). Off the ground it shows its leap until it has stood AIR_HOLD seconds again (the top of a hop,
## where it barely moves, doesn't flicker back to the run).
func show_state(grounded: bool, delta := 0.0) -> void:
	if not grounded:
		_air_hold = AIR_HOLD
	else:
		_air_hold = maxf(_air_hold - delta, 0.0)
	_grounded = _air_hold <= 0.0
	_air_time = 0.0 if _grounded else _air_time + delta


## (the user, 2026-11-08, the jump drawn with kie.ai: bandit.json "jump") its jump frame in the air, by how it moves
## this tick: the take-off as it leaves the ground, the rise while it climbs fast, tucked at the top, the fall coming
## down (`force`: that phase, 0..3). Without the jump frames: its one leap pose.
func _jump_frame(force := -1) -> int:
	if not _d.has("jump"):
		return int(_d.leap)
	var k := force
	if k < 0:
		var dy := bandit.y - bandit.prev_y
		if _air_time < TAKEOFF_TIME and dy < 0.0:
			k = 0
		elif dy < -JUMP_DY:
			k = 1
		elif dy <= JUMP_DY:
			k = 2
		else:
			k = 3
	return int((_d.jump as Array)[k])


## (2026-11-10) It left the ground on a leap (WorldView): a stretch off its toes.
func took_off() -> void:
	_squash = Vector2(0.9, 1.12)


## It came down from a leap or a drop: a squash into its knees, and its run starts on a planted boot.
func touched_down(hard: float) -> void:
	_squash = Vector2(1.0 + 0.16 * hard, 1.0 - 0.16 * hard)
	_run = 0.0
	_lean = 0.0


## A ring hit it (knocked_out: the second one).
func hit(knocked_out: bool) -> void:
	_flash = 1.0
	_jolt = 9.0
	_squash = Vector2(1.18, 0.86)
	if knocked_out:
		_ko = true
		_ko_time = 0.0
		_stars = 0.0
		rotation = 0.0
		_sprite.rotation = 0.0
		_show(int(_d.hit))
		queue_redraw()
	else:
		_hit_left = HIT_TIME
		_jolt = 16.0  # (2026-11-10: the rules stop it now, World.STAGGER_TICKS: thrown back on its heels)
		_show(int(_d.hit))


## Ran off the left of the play window: it runs on out of the picture (a wide phone shows more to the left of the
## window: it faded away there in full view, a see-through bandit at the screen's edge) and is gone.
func leave() -> void:
	var t := create_tween()
	t.tween_property(self, "position:x", position.x - 460.0, 0.8)
	t.tween_callback(queue_free)


func _process(delta: float) -> void:
	if _ko:
		_disappear(delta)
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
	_hit_left = maxf(_hit_left - dt, 0.0)
	var frame: int
	var rock := 0.0
	var caught := world.state == World.State.DEAD
	_stand_down = move_toward(_stand_down, 1.0 if caught else 0.0, delta * 5.0)
	_spot = maxf(_spot - dt, 0.0)
	if bandit.active and not _was_active:  # it has seen him: a start, a "!" over its head
		_spot = SPOT_TIME
		_squash = Vector2(0.92, 1.1)
	_was_active = bandit.active
	var stance := not bandit.active or bandit.holding
	if stance or _stand_down > 0.5:  # waiting to pounce, holding its bank, or he is caught: its stance, breathing
		_breath += delta if caught else dt
		var k := 0.5 + 0.5 * sin(_breath * 3.4)
		frame = int(_d.wait)
		_sprite.scale = Vector2(_scale * (1.0 - 0.012 * k), _scale * (1.0 + 0.02 * k))
		if bandit.holding and not caught:
			var swing := _swing_frame()
			if swing >= 0:  # he is on it: its punch, drawn back then thrown
				frame = int(_d.swing) + swing
			if _hit_left > 0.0 or bandit.stagger > 0:
				frame = int(_d.hit)
	else:
		# dazed, it runs a little slower and rocks on its feet
		_run = fposmod(_run + dt * float(_d.run_fps) / float(KIND_SCALE[kind]) * (0.85 if bandit.hurt else 1.0), _run_frames)
		frame = int(_d.run) + int(_run)
		if bandit.hurt:
			rock = DAZE_ROCK * sin(_star_turn * 0.8)
		if not _grounded:  # in the air (a leap over a pool or a ring, onto a wall, off a ledge): its jump
			frame = _jump_frame()
		var swing := _swing_frame()
		if swing >= 0 and _grounded:
			frame = int(_d.swing) + swing
		if _hit_left > 0.0 or bandit.stagger > 0:  # stopped by a ring for as long as the rules stop it
			frame = int(_d.hit)
			rock = 0.0
		_sprite.scale = Vector2.ONE * _scale
	# a leap's arc: it leans along it (nose up as it rises, down as it comes in to land)
	var lean_to := 0.0
	if bandit.arc > 0 and not caught:
		lean_to = clampf(-bandit.vy * ARC_LEAN, -ARC_LEAN_MAX, ARC_LEAN_MAX)
	_lean = lerpf(_lean, lean_to, 1.0 - exp(-dt * 14.0))
	# a guard turns to watch him once he is past it (a quick turn through its edge)
	var face := 1.0
	if bandit.holding and world.x > bandit.x - world.scroll + TURN_PAST:
		face = -1.0
	_facing = move_toward(_facing, face, delta * 2.0 / TURN_TIME)
	var head: Array = _d.head[frame]
	_head = Vector2(head[0], head[1]) * _scale
	var lift := 0.0
	_lift = 0.0
	# (a guard too: its blow landed, it springs up on the spot and he runs on under it: he ran through its body)
	if bandit.touched_hero and _vault < 1.0:
		if _vault < 0.0:  # the blow: it rears back, then leaps
			_vault = 0.0
			_squash = Vector2(0.86, 1.14)
		_vault = minf(_vault + dt / VAULT_TIME, 1.0)
		lift = VAULT_HEIGHT * 4.0 * _vault * (1.0 - _vault)
		_lift = lift
		# the leap over him, drawn through its jump: off the ground, rising, tucked over his head, coming down
		frame = _jump_frame(0 if _vault < 0.1 else (1 if _vault < 0.36 else (2 if _vault < 0.68 else 3)))
		rotation = -0.3 * sin(_vault * PI)
		if _vault >= 1.0:
			touched_down(0.7)
	elif _vault >= 1.0:
		rotation = 0.0
	_show(frame)
	_sprite.scale *= _squash
	_sprite.scale.x *= signf(_facing) * maxf(absf(_facing), 0.08)
	_sprite.position = Vector2(_jolt * signf(_facing), -lift)
	_sprite.rotation = rock + _lean * signf(_facing)
	_material.set_shader_parameter(&"amount", _flash * 0.85)
	queue_redraw()
	_front.queue_redraw()
	_ground_shadow.queue_redraw()


## The frame of the punch (0: drawn back, 1: thrown) over gameplay's strike() (its last
## World.STRIKE_TICKS before the fist reaches him), or -1. Once it has struck, it vaults and runs on.
func _swing_frame() -> int:
	if bandit.hurt or not bandit.active or bandit.touched_hero or world.state != World.State.RUNNING:
		return -1
	var k := world.strike(bandit)
	if k < 0.0:
		return -1
	return 0 if k < 0.45 else 1


func _draw() -> void:
	if _ko:
		return
	_draw_stars(false)


## A soft shadow on the ground under him (only while he stands on it; vaulting over Panoramic, smaller and
## lighter the higher he is): the hero's (HeroView.contact_shadow), so all of them stand on the same ground.
func _draw_shadow() -> void:
	if _ko or not _grounded:
		return
	var k := 1.0 - clampf(_lift / VAULT_HEIGHT, 0.0, 1.0) * 0.7
	HeroView.contact_shadow(_ground_shadow, Vector2(_jolt * 0.5 + SHADOW_SHIFT, -1.0), SHADOW_WIDTH * (1.15 if bandit.strong else 1.0), k)


## Dazed stars on a ring above its hair: those behind it drawn under the sprite, the rest over it.
func _draw_stars(front: bool) -> void:
	if front and _spot > 0.0 and not _ko:
		_draw_spot()
	if _stars <= 0.01 or _ko:
		return
	var target: CanvasItem = _front if front else self
	var centre := _head.rotated(_sprite.rotation) + Vector2(_jolt + 4.0, -STAR_RISE)
	for i in STAR_COUNT:
		var a := _star_turn + i * TAU / STAR_COUNT
		var depth := sin(a)  # > 0: in front
		if (depth > 0.0) != front:
			continue
		var p := centre + Vector2(cos(a) * 19.0, depth * 5.0)
		var size := (3.8 + 1.2 * depth) * _stars
		_star(target, p, size, a * 0.6, Color(1, 0.86, 0.3, _stars * (0.75 + 0.25 * depth)))


## The "!" over its head as it wakes: it pops up, holds, and fades (a stroke and a dot, gold in dark ink).
func _draw_spot() -> void:
	var t := 1.0 - _spot / SPOT_TIME
	var pop := 1.0 + 0.5 * maxf(1.0 - t / 0.18, 0.0)
	var a := clampf(_spot / 0.15, 0.0, 1.0)
	var at := _head + Vector2(_jolt + 2.0, -SPOT_RISE - 6.0 * minf(t / 0.18, 1.0))
	var ink := Color(0.2, 0.06, 0.02, a)
	var gold := Color(1.0, 0.84, 0.25, a)
	for pass_i in 2:
		var grow := 2.2 if pass_i == 0 else 0.0
		var c := ink if pass_i == 0 else gold
		var w := (4.6 + grow) * pop
		var h := 15.0 * pop
		var bar := PackedVector2Array([at + Vector2(-w, -h - grow), at + Vector2(w, -h - grow),
				at + Vector2(w * 0.45, grow * 0.5), at + Vector2(-w * 0.45, grow * 0.5)])
		_front.draw_colored_polygon(bar, c)
		_front.draw_circle(at + Vector2(0.0, 7.0 * pop), (3.4 + grow) * pop, c)


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


## Shows a frame of the sheet, placed so the node sits on its pivot (the ground under its body).
func _show(index: int) -> void:
	var f: Array = _d.frames[index]
	_sprite.region_rect = Rect2(f[0], f[1], f[2], f[3])
	_sprite.offset = -Vector2(f[4], f[5])
	# (round 23) its frame (the ink's samples kept in it; the disappearance turns it about its own middle) and its head
	# (where its accent is)
	var size := Vector2(_tex.get_width(), _tex.get_height())
	_material.set_shader_parameter(&"region", Vector4(f[0] / size.x, f[1] / size.y, f[2] / size.x, f[3] / size.y))
	var head: Array = _d.head[index]
	_material.set_shader_parameter(&"head", Vector2(head[0], head[1]))
	if _ko:
		_material.set_shader_parameter(&"aspect", float(f[2]) / float(f[3]))


## Knocked out: frozen on the blow in its recoil, then thrown back off its feet along a low arc, turning over
## backward about its middle, in its own colours; at the arc's end it shrinks into a puff of dust, a ring of light
## and a few sparks in the chakram's colours (it is in the level by then: WorldView).
func _disappear(delta: float) -> void:
	_ko_time += delta
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	_material.set_shader_parameter(&"amount", _flash * 0.85)
	var side := signf(_facing)
	if _ko_time < KO_HOLD:
		_sprite.scale = Vector2(_scale * 1.14 * side, _scale * 0.88)
		_sprite.position = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))  # the blow shakes it
		return
	var t := (_ko_time - KO_HOLD) / KO_FLIGHT
	if t >= 1.0:
		queue_free()
		return
	if not _lit:
		_lit = true
		_material.set_shader_parameter(&"sil_colour", KO_LINE)
		_material.set_shader_parameter(&"sil_out_px", float(_material.get_shader_parameter(&"sil_out_px")) * KO_LINE_WIDTH)
	# thrown back fast, slowing; up and down its arc
	var k := 1.0 - pow(1.0 - t, 2.2)
	position.x += KO_BACK * (k - _pushed)
	_pushed = k
	var rise := KO_UP * 4.0 * t * (1.0 - t) + 10.0 * t
	# turning about its middle (its node is at its feet): its head goes back, the way it is thrown
	var middle := Vector2(0.0, -_middle())
	var turn := KO_TURN * smoothstep(0.05, 0.8, t)
	_sprite.rotation = turn
	_sprite.position = middle - middle.rotated(turn) + Vector2(0.0, -rise)
	# stretched along its flight off the blow, then itself; at the end it shrinks into the puff
	var out := clampf((t - (1.0 - KO_POOF / KO_FLIGHT)) / (KO_POOF / KO_FLIGHT), 0.0, 1.0)
	var stretch := lerpf(1.1, 1.0, minf(t * 3.0, 1.0))
	# (never see-through: a fading bandit read as a ghost in a still; it shrinks into its puff of dust, solid)
	var size := _scale * (1.0 - KO_AWAY * t) * (1.0 - 0.8 * out * out)
	_sprite.scale = Vector2(size * stretch * side, size * (2.0 - stretch))
	if out > 0.0 and not _poofed:
		_poofed = true
		var at := position + _sprite.position + middle.rotated(turn)
		var parent := get_parent()
		Fx.dust(parent, at, 14, 230.0, 0.0, 1.5)
		Confetti.make(parent, at).sparkle(7, KO_SPARKS, Vector2(150, 400), 0.9, Vector2(0.3, 0.55))


## How far over its feet its middle is, in units (what it turns about as it is thrown).
func _middle() -> float:
	return (World.STRONG_BODY.size.y if bandit.strong else World.BANDIT_BODY.size.y) * 0.5

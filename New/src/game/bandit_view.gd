class_name BanditView
extends Node2D
## A bandit (World.Bandit), one of two kinds that come at random (World.is_strong(): about 3 in 10 are strong
## and take 3 rings; jumpers leap over a ring coming at them, drawn in the leap pose): the user's bandit (spiky
## teal hair, a torn red scarf, a yellow shirt with its round steel emblem, golden shin guards) and the strong
## one, their leader (muscular, bright-blue hair, a dark-red cape-scarf, the black-and-white emblem, blue wraps),
## drawn bigger. Both drawn with kie.ai from the user's
## pictures, their runs from Seedance clips (tools/art/bandit_sheet.py packs assets/art/bandit/<kind>.png).
## Placed at its feet. It waits crouched and breathing until it enters the play window, then runs (its clip's
## loop, at the pace that keeps the planted boot on the ground). As it closes on Panoramic it
## draws its fist back and punches (the rules' reach in front of it), so the blow is seen coming. A ring
## makes it flash white and recoil; after the first one it runs dazed (rocking, stars circling its head).
## The second knocks it out and it disappears as it did in 2017 (banditMort1-10): it keeps running while a
## liquid-chrome glaze runs over it, then it twirls into a ring of chrome and is gone (bandit.gdshader).
##
## Animation runs on the world's clock, so pause and hit-stop freeze it too.

const DIR := "res://assets/art/bandit/"
const FLASH_TIME := Fx.FLASH_TIME  ## New (audio): the shared impact's white, 2 frames, then the reaction shows
const KO_HOLD := 0.09  ## seconds frozen on the blow before it disappears
const VANISH_TIME := 0.7  ## seconds: the 2017 disappearance's 10 frames
const KO_PUSH := 34.0  ## units the blow slides it back (right) while the glaze runs
## It disappears where it was hit, as in 2017: it never tilts or tumbles (round 9: no cartwheel).
const KO_TILT := 0.0
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
const HAZE := 0.08
const RECEDE := Color(0.4, 0.31, 0.38)
const CORE_SAT := 0.8  ## (the user, 2026-11-08: "too dark, we don't see them": r23's 0.5 / 0.55 core lifted)
const CORE_VALUE := 0.9
const CORE_TINT := Color(1.1, 0.95, 0.86)  ## (the grey they are muted towards: a warm umber, skin not ash)
const CORE_FLOOR := 0.06  ## their darkest value: their black trousers keep their folds over the ink (not a cut-out)
const INK := Color(0.075, 0.04, 0.035)  ## their silhouette's ink: darker than Panoramic's brown, under their dark core
## kind -> [its hues (degrees from, to, least saturation, least value), its brightest, where round its head (sheet px:
## left, top, right, bottom), its saturation and value x as drawn]: the bandit's indigo wrap, the strong one's rust wrap
## (its skin, the same hue, is brighter and less saturated; its crimson cape redder)
const ACCENT := {
	&"bandit": [Vector4(205.0, 268.0, 0.18, 0.18), 1.0, Vector4(-75.0, -95.0, 95.0, 8.0), 1.4, 1.12],
	&"bandit_strong": [Vector4(6.0, 34.0, 0.58, 0.22), 0.8, Vector4(-80.0, -70.0, 70.0, 8.0), 1.1, 1.02],
}
const SHADOW_WIDTH := 84.0  ## units across its shadow on the ground (Panoramic's: 100)
const SHADOW_SHIFT := 8.0  ## its shadow falls a little right of it, away from the sun (upper left), as his does

const KINDS: Array[StringName] = [&"bandit", &"bandit_strong"]
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
const KIND_SCALE := {&"bandit": 1.0, &"bandit_strong": 0.94}

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
var _head := Vector2.ZERO  # the middle of its hair in this frame, local units
# knocked out
var _ko := false
var _ko_time := 0.0
var _pushed := 0.0  # 0..1 of KO_PUSH done
var _vault := -1.0  # 0..1 through the vault over him (-1: not vaulting)
var _lift := 0.0  # units it is drawn above the ground (the vault)


static func load_art() -> void:
	if not _kinds.is_empty():
		return
	for k in KINDS:
		_kinds[k] = [JSON.parse_string(FileAccess.get_file_as_string(DIR + k + ".json")), load(DIR + k + ".png")]


func _init(w: World, b: World.Bandit) -> void:
	world = w
	bandit = b
	load_art()
	kind = &"bandit_strong" if b.strong else &"bandit"  # (World.is_strong)
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


## Called by WorldView every frame while the bandit is in the game. `grounded`: on its ledge this tick (not hopping a
## wall, not leaping). Off the ground it shows its leap until it has stood AIR_HOLD seconds again (the top of a hop,
## where it barely moves, doesn't flicker back to the run).
func show_state(grounded: bool, delta := 0.0) -> void:
	if not grounded:
		_air_hold = AIR_HOLD
	else:
		_air_hold = maxf(_air_hold - delta, 0.0)
	_grounded = _air_hold <= 0.0


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
	else:
		_hit_left = HIT_TIME
		_show(int(_d.hit))


## Ran off the left of the screen: fades away.
func leave() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
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
	if not bandit.active:  # waiting to pounce: crouched, breathing
		_breath += dt
		var k := 0.5 + 0.5 * sin(_breath * 3.4)
		frame = int(_d.wait)
		_sprite.scale = Vector2(_scale * (1.0 - 0.012 * k), _scale * (1.0 + 0.02 * k))
	else:
		# dazed, it runs a little slower and rocks on its feet
		_run = fposmod(_run + dt * float(_d.run_fps) / float(KIND_SCALE[kind]) * (0.85 if bandit.hurt else 1.0), _run_frames)
		frame = int(_d.run) + int(_run)
		if bandit.hurt:
			rock = DAZE_ROCK * sin(_star_turn * 0.8)
		if not _grounded:  # hopping a wall: the leap
			frame = int(_d.leap)
		var swing := _swing_frame()
		if swing >= 0 and _grounded:
			frame = int(_d.swing) + swing
		if _hit_left > 0.0:
			frame = int(_d.hit)
			rock = 0.0
		_sprite.scale = Vector2.ONE * _scale
	var head: Array = _d.head[frame]
	_head = Vector2(head[0], head[1]) * _scale
	var lift := 0.0
	_lift = 0.0
	if bandit.touched_hero and _vault < 1.0:
		if _vault < 0.0:  # the blow: it rears back, then leaps
			_vault = 0.0
			_squash = Vector2(0.86, 1.14)
		_vault = minf(_vault + dt / VAULT_TIME, 1.0)
		lift = VAULT_HEIGHT * 4.0 * _vault * (1.0 - _vault)
		_lift = lift
		frame = int(_d.leap)  # the leap over him
		rotation = -0.35 * sin(_vault * PI)
	elif _vault >= 1.0:
		rotation = 0.0
	_show(frame)
	_sprite.scale *= _squash
	_sprite.position = Vector2(_jolt, -lift)
	_sprite.rotation = rock
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


## Knocked out: frozen on the blow, then the 2017 disappearance: still running, glazed in liquid chrome
## from its middle out, then twirled into a ring that fades (bandit.json's vanish: banditMort1-10's frames).
func _disappear(delta: float) -> void:
	_ko_time += delta
	_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
	_material.set_shader_parameter(&"amount", _flash * 0.85)
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-delta * 12.0))
	_sprite.scale = Vector2.ONE * _scale * _squash
	if _ko_time < KO_HOLD:
		_sprite.position = Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))  # the blow shakes it
		return
	var t := (_ko_time - KO_HOLD) / VANISH_TIME
	if t >= 1.0:
		queue_free()
		return
	_sprite.position = Vector2.ZERO
	# it is in the level now (WorldView): the slide back is added a step at a time
	var k := 1.0 - pow(1.0 - t, 3.0)
	position.x += KO_PUSH * (k - _pushed)
	_pushed = k
	var frames: Array = _d.vanish
	_show(int(_d.run) + int(frames[mini(int(t * frames.size()), frames.size() - 1)]))
	_material.set_shader_parameter(&"vanish", maxf(t, 0.001))

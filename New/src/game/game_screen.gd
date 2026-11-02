extends Screen
## The level: the rules (World), their picture (WorldView), the HUD, the controls, pause and the
## end-of-run panel.
##
## Controls, as in 2017: swipe up to jump, tap to throw a ring, swipe down to crouch or let go of
## the top, swipe right to step forward (TouchReader). On a keyboard: arrows or WASD, space to
## throw, P or Esc.
##
## The run goes through phases (`phase`, `phase_changed`, `phase_time`), for the views and the HUD:
## READY (the start card; he waits, idle), PLAYING, PAUSED, COUNTDOWN (after Resume), DYING
## (caught or fallen: his death plays for World.DYING_TIME before the panel; a tap skips it),
## HOME (he lands at the door, celebrates and walks in: World.HOME_TIME), RESULTS (the panel).

signal phase_changed(phase: Phase)

enum Phase { READY, PLAYING, PAUSED, COUNTDOWN, DYING, HOME, RESULTS }

const SWIPE_MIN := 30.0  ## design units a finger must travel to be a swipe (when the screen's dpi is unknown)
const SWIPE_MM := 4.0  ## the same travel on any screen (30 units was 3 mm on a phone, 9 mm on an iPad)
## The camera: up high (hanging under the vine, on the tallest ledges) the world draws back from the
## top of the screen, sky above, so he stays out of the HUD band; the ground stays where it is.
const FRAME_TOP := 78.0  ## design units kept for the HUD when he is at the top
const FRAME_FROM := 260.0  ## his centre (play y) where the camera starts to draw back
const FRAME_FULL := 100.0  ## ... and where it is fully back (he hangs at World.VINE_DRAW_Y)
const HOME_PUSH := 1.4  ## at home the camera pushes in to the doorway, this much
const DEATH_PUSH := 1.2  ## caught: the camera closes in on him while he falls (World.DYING_TIME)
const HOME_CX := 800.0  ## play x drawn to the middle of the screen at home (the hut, him at its door)
const SHAKE := 22.0  ## design units of the strongest shake
const RESUME_COUNT := 3  ## after Resume: 3, 2, 1 before the world moves again
const RESUME_STEP := 0.5  ## seconds per number
const FALL_BEAT := 0.3  ## after a fall that costs a life, the world holds this long before he springs back
const KO_STOP := 0.1  ## hit-stop of a knock-out (s)
const RING_STOP := 0.035  ## of a ring that hits without knocking out (two frames)
const HURT_STOP := 0.12  ## of a hit
const CAUGHT_STOP := 0.2  ## of the last hit

var world: World
## Plays instead of the player (tests and screenshots): any object with act(world).
var autopilot: Object
var view: WorldView
var hud: Hud
var _stage: Node2D
var _clip: Control  # the world's area: nothing drawn under it (where the banner is)
var _below: ColorRect  # ground colour under the world when the ad banner takes the bottom
## What the run is doing now (see Phase), and for how long (seconds, real time).
var phase := Phase.READY
var phase_time := 0.0
var _reader := TouchReader.new()
var _paused := false
var _ended := false
var _results_shown := false
var _news := {}  # what record_run found new (for the panel)
var _end_wait := 0.0  # seconds of World.end_time before the panel
## Before the first touch the world waits (the 2017 "Ready" state): the start card shows the moves.
var _ready_to_start := true
var _start_card: Control
var _tutorial: Tutorial  # the first run's lessons (Tutorial), while some are left
var _overlay: Control
var _clock := 0.0
var _trauma := 0.0  # screen shake, 0..1 (decays)
var _kick := Vector2.ZERO  # a camera nudge (design units) that springs back (_jolt)
var _freeze := 0.0  # hit-stop: seconds the world waits
var _flash: TextureRect  # a red glow at the screen's edges when he is hurt
var _fliers: Node2D  # Red Bobs flying to the counter, over the HUD
var _combo := 0  # Red Bobs taken in a quick run: each one a note higher
var _last_bob := -10.0
var _k := 1.0  # the world's scale on screen (_layout)
var _countdown := 0.0  # after Resume: seconds before the world moves again
var _count_id := 0  # which Resume the countdown's numbers belong to
var _spring_due := false  # the spring's sound waits for the end of the fall's beat
var _frame := 1.0  # the camera drawn back (FRAME_TOP): 1 = the 640 units fill the screen
var _push := 1.0  # the camera pushed in at home (HOME_PUSH)
## New (UX): no ad banner while playing unless the config asks for one ([ads] banner_in_play): under
## the swipe area it invites accidental clicks (AdMob's placement policy); pause and results show it.
var _banner_in_play: bool = Config.value("ads", "banner_in_play", false)


func enter(data: Dictionary) -> void:
	world = data.get("world", null)
	if not world:
		world = World.new()
		world.stand_at_start()
		world.falls_cost_life = Config.value("rules", "falls_cost_life", false)
	_below = ColorRect.new()
	_below.color = Color("6b4418")
	_below.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_below)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_stage = Node2D.new()
	_clip.add_child(_stage)
	view = WorldView.new()
	_stage.add_child(view)
	view.setup(world)
	_flash = TextureRect.new()
	_flash.texture = Fx.vignette_texture()
	_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flash.stretch_mode = TextureRect.STRETCH_SCALE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.modulate = Color(1, 0.12, 0.06, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	hud = Hud.new()
	add_child(hud)
	hud.setup(world)
	hud.pause_pressed.connect(pause_game)
	_fliers = Node2D.new()
	add_child(_fliers)
	world.jumped.connect(func() -> void: Audio.play_sfx(&"jump"))
	world.landed.connect(_on_landed)
	world.hung.connect(func() -> void:
		Audio.play_sfx(&"hang")
		Haptics.hang())
	world.let_go.connect(func() -> void: Audio.play_sfx(&"let_go"))
	world.stepped.connect(func() -> void: Audio.play_sfx(&"step"))  # a swipe right answers
	world.thrown.connect(_on_thrown)
	add_child(Footsteps.new(world, view.get(&"_hero")))  # steps on the run animation's foot contacts
	world.splashed.connect(_on_splashed)
	world.fell.connect(_on_fell)
	world.sprang.connect(func() -> void: _spring_due = true)
	world.bandit_hit.connect(_on_bandit_hit)
	world.bob_collected.connect(_on_bob)
	view.bob_popped.connect(_on_bob_popped)
	world.hurt.connect(_on_hurt)
	world.died.connect(_on_died)
	world.won.connect(_on_won)
	Device.changed.connect(_layout)
	_layout()
	_start_card = _make_start_card()
	add_child(_start_card)
	if Tutorial.pending():
		_tutorial = Tutorial.new(self, world)
		add_child(_tutorial)
	Audio.play_music(&"game")
	Services.ads.show_banner(_banner_in_play)
	Services.analytics.log_event("level_start")


func _exit_tree() -> void:
	if Device.changed.is_connected(_layout):
		Device.changed.disconnect(_layout)


## Fits the 640-unit-tall world above the ad banner and right of a notch.
func _layout() -> void:
	var v := get_viewport_rect().size
	_reader.swipe_min = _physical_swipe_min()
	var insets := Device.insets()
	var k := (v.y - (Device.banner_height if _banner_in_play else 0.0)) / World.VIEW_H
	_k = k
	_stage.scale = Vector2(k, k)
	_stage.position = Vector2(insets.x, 0)
	view.view_left = insets.x / k
	view.view_width = v.x / k
	_clip.position = Vector2.ZERO
	_clip.size = Vector2(v.x, World.VIEW_H * k)
	_below.position = Vector2(0, World.VIEW_H * k)
	_below.size = Vector2(v.x, v.y - World.VIEW_H * k + 2)


func _process(delta: float) -> void:
	_clock += delta
	_freeze = maxf(_freeze - delta, 0.0)
	if _ready_to_start and autopilot:
		_start()
	_countdown = maxf(_countdown - delta, 0.0)
	var held := _freeze > 0.0 or (is_instance_valid(_tutorial) and _tutorial.holding)  # New: a lesson holds it too
	if not _paused and not held and not _ready_to_start and _countdown <= 0.0:
		if _spring_due:
			_spring_due = false
			Audio.play_sfx(&"spring")
			if world.water_at(world.scroll + world.x):  # out of a pool
				Audio.play_sfx(&"splash", 1.3, 0.55)
		world.advance(delta, autopilot.act if autopilot else Callable())
	if _ended and not _results_shown and world.end_time >= _end_wait:
		_show_results(_news)
	_track_phase(delta)
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-delta * 16.0))
	_place_camera(delta)
	view.refresh(0.0 if held else delta)  # a hit-stop (or a lesson) holds the picture too
	hud.hero_at(view.hero_screen_rect())
	hud.refresh()


## The world's place on screen: drawn back when he is up high, pushed in at home, and shaken (with
## just enough zoom that the shake never bares an edge). Each is a zoom about its own point.
func _place_camera(delta: float) -> void:
	var p := world.draw_hero()
	var high := smoothstep(FRAME_FROM, FRAME_FULL, 0.0 if world.hanging else p.y)
	if world.state == World.State.DEAD:
		high = 0.0
	_frame = lerpf(_frame, 1.0 - FRAME_TOP / World.VIEW_H * high, 1.0 - exp(-delta * 10.0))
	var home := world.state == World.State.WON
	var caught := world.state == World.State.DEAD and world.death_reason == &"bandit"
	var push := HOME_PUSH if home else (DEATH_PUSH if caught else 1.0)
	_push = lerpf(_push, push, 1.0 - exp(-delta * (2.6 if home else (1.6 if caught else 10.0))))
	var shake := _trauma * _trauma * SHAKE * Prefs.shake()  # New: the player can turn it off
	var zoom_k := _k
	var at := Vector2(Device.insets().x, 0)
	var door := at + Vector2(World.HOME_X + 30.0, World.VIEW_H - 100.0) * _k
	var fall := at + Vector2(p.x, p.y + 40.0) * _k  # caught: the push closes in about where he falls
	zoom_k *= _frame
	at = at * _frame + Vector2(0, _clip.size.y) * (1.0 - _frame)
	if _push > 1.0001 and home:  # New: the push draws the hut and him to the middle of the screen as it goes
		# in (about the doorway, a 4:3 iPad lost the hut's right half past its edge)
		var u := clampf((_push - 1.0) / (HOME_PUSH - 1.0), 0.0, 1.0)
		var c := Vector2(at.x + HOME_CX * zoom_k, door.y)
		var target := Vector2(lerpf(c.x, _clip.size.x / 2.0, u), c.y)
		zoom_k *= _push
		at = at * _push + target - c * _push
	elif _push > 1.0001:
		zoom_k *= _push
		at = at * _push + fall * (1.0 - _push)
	var z := 1.0 + 2.0 * shake / (World.VIEW_H * _k)
	zoom_k *= z
	at = at * z + _clip.size / 2.0 * (1.0 - z)
	_stage.scale = Vector2(zoom_k, zoom_k)
	_stage.position = at + Vector2(sin(_clock * 53.0), cos(_clock * 47.0)) * shake + _kick * _k
	view.view_left = at.x / zoom_k
	view.view_width = get_viewport_rect().size.x / zoom_k
	view.view_top = -at.y / zoom_k


## The phase now (see Phase): followed every frame, so no change is missed.
func _current_phase() -> Phase:
	if _results_shown:
		return Phase.RESULTS
	if _paused:
		return Phase.PAUSED
	if world.state == World.State.DEAD:
		return Phase.DYING
	if world.state == World.State.WON:
		return Phase.HOME
	if _ready_to_start:
		return Phase.READY
	if _countdown > 0.0:
		return Phase.COUNTDOWN
	return Phase.PLAYING


func _track_phase(delta: float) -> void:
	var now := _current_phase()
	if now == phase:
		phase_time += delta
		return
	phase = now
	phase_time = 0.0
	phase_changed.emit(phase)


# ------------------------------------------------------------------ controls

## Touches: each finger is read by the TouchReader into moves (times in _clock).
func _input(event: InputEvent) -> void:
	if _ended:
		var tap := event as InputEventScreenTouch
		if tap and tap.pressed and not _results_shown:
			skip_ending()
		return
	if _paused or _countdown > 0.0:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if hud.blocks(touch.position):
				return
			if _ready_to_start:
				_start()
			_reader.press(touch.index, touch.position, _clock)
		elif _reader.is_down(touch.index):
			_move(_reader.release(touch.index, touch.position, _clock))
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_move(_reader.drag(drag.index, drag.position, _clock))


## Gives the world a move read from the fingers (TouchReader).
func _move(action: StringName) -> void:
	match action:
		&"throw":
			world.throw()
		&"jump":
			world.jump()
		&"down":
			world.down()
		&"right":
			world.step_forward()


## What a swipe `d` (design units) asks for: jump, down, right or nothing (left): TouchReader's.
static func swipe_action(d: Vector2) -> StringName:
	var action := TouchReader.swipe_action(d)
	return &"" if action == &"left" else action


## The swipe distance in design units for SWIPE_MM on this screen (SWIPE_MIN if the dpi is unknown).
func _physical_swipe_min() -> float:
	if get_viewport() != get_tree().root:  # New: inside the tools' SubViewports (no warning there)
		return SWIPE_MIN
	var dpi := float(DisplayServer.screen_get_dpi())
	var px_per_unit := get_viewport().get_screen_transform().get_scale().y
	if dpi < 100.0 or px_per_unit <= 0.0:
		return SWIPE_MIN
	return clampf(SWIPE_MM / 25.4 * dpi / px_per_unit, 14.0, 40.0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if _ended:
		if not _results_shown:
			skip_ending()
		return
	if _paused or _countdown > 0.0:
		if key.keycode in [KEY_P, KEY_ESCAPE] and _paused:
			resume_game()
		return
	if _ready_to_start:
		_start()
	match key.keycode:
		KEY_UP, KEY_W:
			world.jump()
		KEY_DOWN, KEY_S:
			world.down()
		KEY_RIGHT, KEY_D:
			world.step_forward()
		KEY_SPACE, KEY_X, KEY_J:
			world.throw()
		KEY_P, KEY_ESCAPE:
			pause_game()


## The first touch starts the run (and still counts: a tap throws, a swipe moves).
func _start() -> void:
	if not _ready_to_start:
		return
	_ready_to_start = false
	if _start_card:
		var card := _start_card
		_start_card = null
		var t := card.create_tween()
		t.tween_property(card, "modulate:a", 0.0, 0.25)
		t.tween_callback(card.queue_free)


## Before the first touch: TAP TO START (and, after the first run, the five moves): StartCard.
func _make_start_card() -> Control:
	return StartCard.new(Tutorial.pending())


## True while the run is being played (not waiting for the first touch, paused, counting down
## after Resume, or over): the tutorial reads gestures only then.
func playing() -> bool:
	return not (_paused or _ended or _ready_to_start or _countdown > 0.0 or autopilot)


## The distance a finger must travel to be a swipe, in design units (for the tutorial).
func swipe_min() -> float:
	return _reader.swipe_min


# ------------------------------------------------------------------ events

const COMBO_WINDOW := 0.6  ## seconds between two Red Bobs that keep a combo going


## A blow felt by the camera: a shake (`trauma`, 0..1, decays) and a kick (design units, springs
## back). Neither with reduced motion.
func _jolt(trauma: float, kick := Vector2.ZERO) -> void:
	if Fx.calm():
		return
	_trauma = minf(_trauma + trauma, 1.0)
	_kick += kick


## A ring thrown: its whoosh, a flash at his hand, its light in flight, a small recoil.
func _on_thrown(r: World.Ring) -> void:
	Audio.play_sfx(&"throw")
	Fx.ring_launch(view.fx, Vector2(r.x + 12.0, r.y + 14.0) * 2.0)
	Fx.ring_flight(view.fx, world, r)
	_jolt(0.0, Vector2(-1.5, 0.0))


## A Red Bob: its chime climbs the A major scale (a take per step: sfx_bob_1..8) while they come
## quickly one after another, and its light grows with the streak (_on_bob_popped).
func _on_bob(_c: int, _r: int) -> void:
	_combo = _combo + 1 if _clock - _last_bob < COMBO_WINDOW else 0
	_last_bob = _clock
	Audio.play_tuned(&"bob", _combo)
	Haptics.pickup()
	if _combo >= 2:
		_combo_tag(_combo + 1)


## "×N" while Red Bobs come in a quick run: a gold badge pinned over the counter's lower right
## corner, that pops, bigger each time, and fades.
var _tag: Control


func _combo_tag(n: int) -> void:
	if is_instance_valid(_tag):
		_tag.queue_free()
	var chip := Ui.chip("×%d" % n, Ui.Tone.GOLD, 26 + mini(n, 10) * 2)
	_tag = Control.new()
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.size = chip.get_combined_minimum_size()
	_tag.add_child(chip)
	add_child(_tag)
	var corner := hud.counter_rect().end  # hanging from the plate's lower right corner, clear of the count
	_tag.position = corner - Vector2(_tag.size.x * 0.8, 8.0)
	_tag.pivot_offset = _tag.size / 2
	_tag.scale = Vector2.ONE * 0.4
	_tag.rotation = -0.2
	var tag := _tag
	var t := tag.create_tween()
	t.tween_property(tag, "scale", Vector2.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(tag, "rotation", -0.06, 0.2)
	t.tween_property(tag, "scale", Vector2.ONE, 0.1)
	t.tween_interval(0.45)
	t.tween_property(tag, "modulate:a", 0.0, 0.25)
	t.parallel().tween_property(tag, "scale", Vector2.ONE * 0.7, 0.25)
	t.tween_callback(tag.queue_free)


## The Red Bob flies from where it was (WorldView units) to the counter.
func _on_bob_popped(at: Vector2) -> void:
	var from := _stage.get_global_transform() * at
	hud.bob_launched()
	Fx.bob_flight(_fliers, from, hud.bob_target(), BobView.SIZE * _stage.scale.x, hud.BOB_ICON, hud.bob_arrived)
	Fx.bob_pop(view.fx, at * 2.0, _combo)


## A ring on a bandit: a short hit-stop, the camera kicked the way the ring flew; a knock-out holds
## longer, kicks harder and shakes.
func _on_bandit_hit(b: World.Bandit, knocked_out: bool) -> void:
	Audio.play_sfx(&"knock_out" if knocked_out else &"ring_hit")
	if knocked_out:
		Haptics.knock()
		_freeze = maxf(_freeze, KO_STOP)
		_jolt(0.5, Vector2(9.0, -3.0))
		Fx.plus_one(view.fx, Vector2(b.x - world.scroll, b.y - World.BANDIT_SIZE.y * 0.9) * 2.0)
	else:
		Haptics.select()
		_freeze = maxf(_freeze, RING_STOP)
		_jolt(0.0, Vector2(4.0, 0.0))


## The thud follows the drop (World.land_speed, units a tick): a climb or a step down lands softly,
## a hop (~37) or a drop from the vine (~40) firmly, a fall from a high ledge (45+) hard: lower,
## louder, with a jolt.
func _on_landed() -> void:
	var k := clampf((world.land_speed - 15.0) / 35.0, 0.0, 1.0)
	Audio.play_sfx(&"land", 1.1 - 0.2 * k, 0.3 + 0.7 * k)
	if k > 0.4:  # the camera dips with a firm landing
		_jolt(0.0, Vector2(0.0, 6.0 * k))
	if k > 0.8:
		_jolt(0.35 * k)
		Haptics.land()


func _on_splashed(_x: float, hero: bool) -> void:
	Audio.play_sfx(&"splash", 1.0 if hero else 1.25, 1.0 if hero else 0.6)


func _on_hurt(_b: World.Bandit, lives: int) -> void:
	if lives > 0:  # the last blow sounds in _on_died
		Audio.play_sfx(&"hurt")
		Haptics.hurt()
	_freeze = HURT_STOP if lives > 0 else CAUGHT_STOP
	_jolt(0.7, Vector2(-10.0, 0.0))
	_red_flash(0.25 if Fx.calm() else 0.5)


## A fall that cost a life: the heart goes, the world holds a beat, then he springs back up.
func _on_fell(_lives: int) -> void:
	Audio.play_sfx(&"fell")
	Haptics.fall()
	_freeze = FALL_BEAT
	_red_flash(0.4)


## The edges of the screen glow red for a moment (not a filter over the whole picture).
func _red_flash(alpha: float) -> void:
	_flash.modulate.a = alpha
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.25).set_delay(0.04)


## The end of a run: its sound, the music muffled (the stinger takes over with the results).
func _on_died(reason: StringName) -> void:
	Audio.play_sfx(&"fall" if reason == &"fall" else &"death")
	Audio.set_mood(&"paused")
	if reason == &"fall":
		Haptics.fall()
	else:
		Haptics.death()
		_jolt(1.0)
	_end_run(World.FALL_DEATH_TIME if reason == &"fall" else World.DYING_TIME)


## Home: the win stinger (its drum roll lands on his hop, 0.45 s), the doorway's light swelling
## with embers, the burst of light, a success buzz.
func _on_won() -> void:
	Audio.stinger(&"win")
	hud.leave()  # the picture is his arrival
	Fx.home_glow(view.fx, Vector2(World.HOME_X + 34.0, World.VIEW_H - 160.0) * 2.0)
	_end_run(World.HOME_TIME)
	await get_tree().create_timer(0.45).timeout  # he lands his hop: light from the doorway
	if is_inside_tree():
		Fx.rescue_burst(view.fx, Vector2(World.HOME_X + 34.0, World.VIEW_H - 150.0) * 2.0)
		Haptics.success()


## The run is over: saved at once (the app may be closed during the ending), the panel after
## `wait` seconds of the ending (World.end_time: hit-stops don't count), or at a tap (skip_ending).
func _end_run(wait: float) -> void:
	_ended = true
	_end_wait = wait
	_reader.clear()
	_news = Save.record_run(world)
	Services.analytics.log_event("level_end", {"won": world.state == World.State.WON, "bobs": world.bobs,
			"progress": snappedf(world.progress(), 0.01)})
	Services.leaderboards.submit(world.bobs)


## A tap during the ending (his death, or his arrival home) goes straight to the panel, once it has
## played SKIP_AFTER (the player was still tapping to throw when it happened).
func skip_ending() -> void:
	if _ended and not _results_shown and world.end_time >= World.SKIP_AFTER:
		_show_results(_news)


# ------------------------------------------------------------------ pause and results

func pause_game() -> void:
	if _paused or _ended:
		return
	_paused = true
	_reader.clear()
	Audio.duck_music(true)
	Audio.play_sfx(&"panel_open")
	Services.ads.show_banner(true)
	_overlay = PausePanel.open(self, resume_game, _go_home)


func resume_game() -> void:
	if not _paused:
		return
	_paused = false
	Audio.duck_music(false)
	Audio.play_sfx(&"panel_close")
	Services.ads.show_banner(_banner_in_play)
	if _overlay:
		var o := _overlay
		_overlay = null
		var t := o.create_tween()
		t.tween_property(o, "modulate:a", 0.0, 0.15)
		t.tween_callback(o.queue_free)
	if not _ready_to_start:  # a moment to find him again before the world moves
		_countdown = RESUME_COUNT * RESUME_STEP
		_count_id += 1
		for i in RESUME_COUNT:
			get_tree().create_timer(i * RESUME_STEP).timeout.connect(_count_pop.bind(RESUME_COUNT - i, _count_id))
		get_tree().create_timer(RESUME_COUNT * RESUME_STEP).timeout.connect(_count_go.bind(_count_id))


## One number of the resume countdown: it pops in the middle and fades.
func _count_pop(n: int, id: int) -> void:
	if not is_inside_tree() or _paused or id != _count_id:
		return
	Audio.play_tuned(&"count", RESUME_COUNT - n)  # 3, 2, 1 climb A, C#, E
	Haptics.select()
	var label := Ui.display_text(str(n), 96, Ui.WHITE, Ui.NIGHT, Ui.BRAND_LIGHT)
	label.depth = 4.0
	label.refresh()
	add_child(label)
	label.size = label.get_combined_minimum_size()
	label.position = get_viewport_rect().size / 2 - label.size / 2
	label.pivot_offset = label.size / 2
	label.scale = Vector2.ONE * 0.5
	var t := label.create_tween()
	t.tween_property(label, "scale", Vector2.ONE * 1.1, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "scale", Vector2.ONE, 0.08)
	t.tween_interval(RESUME_STEP - 0.4)
	t.tween_property(label, "modulate:a", 0.0, 0.18)
	t.parallel().tween_property(label, "scale", Vector2.ONE * 0.8, 0.18)
	t.tween_callback(label.queue_free)


## GO: the world moves again (the countdown's chord).
func _count_go(id: int) -> void:
	if is_inside_tree() and not _paused and id == _count_id:
		Audio.play_tuned(&"count", RESUME_COUNT)


## The end of a run (ResultsPanel): the stars, the counts, a new best, PLAY AGAIN. The HUD goes.
func _show_results(news: Dictionary) -> void:
	if _results_shown:
		return
	_results_shown = true
	hud.leave()
	Services.ads.show_banner(true)
	_overlay = ResultsPanel.open(self, world, news, _go_home, _play_again,
			func() -> void: Services.share.share_run(world.bobs, world.stars()))
	Services.push.request_permission_once()


func _play_again() -> void:
	_after_interstitial(func() -> void: Nav.go(&"game"))


func _go_home() -> void:
	_after_interstitial(func() -> void: Nav.go(&"menu"))


## An interstitial every few game overs, when leaving the end panel (never in the middle of play).
func _after_interstitial(next: Callable) -> void:
	if _ended:
		await Services.ads.maybe_show_interstitial()
	next.call()


## Android back button: pause, then back to the game; on the end panel, home.
func back() -> void:
	if _ended:
		_go_home()
	elif _paused:
		resume_game()
	else:
		pause_game()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if world and not Config.is_debug or Config.is_mobile:
			pause_game()

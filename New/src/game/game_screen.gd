extends Screen
## The level: the rules (World), their picture (WorldView), the HUD, the controls, pause and the
## end-of-run panel.
##
## Controls, as in 2017: swipe up to jump, tap to throw a ring, swipe down to crouch or let go of
## the top, swipe right to step forward. On a keyboard: arrows or WASD, space to throw, P or Esc.

const SWIPE_MIN := 30.0  ## design units a finger must travel to be a swipe (when the screen's dpi is unknown)
const SWIPE_MM := 4.0  ## the same travel on any screen (30 units was 3 mm on a phone, 9 mm on an iPad)
## Up and down win a slanted swipe up to this ratio |x| / |y| (about 58° from vertical): a thumb's
## jump often leans right, and a jump matters far more than the small step right.
const VERTICAL_BIAS := 1.6
const TAP_MAX_TIME := 0.45  ## longer touches that didn't move aren't taps
const END_DELAY := 1.1  ## seconds between the end of a run and its panel
const HOME_DELAY := 1.9  ## at home: the push to the door and the arrival first
## The camera: up high (hanging under the vine, on the tallest ledges) the world draws back from the
## top of the screen, sky above, so he stays out of the HUD band; the ground stays where it is.
const FRAME_TOP := 78.0  ## design units kept for the HUD when he is at the top
const FRAME_FROM := 260.0  ## his centre (play y) where the camera starts to draw back
const FRAME_FULL := 100.0  ## ... and where it is fully back (he hangs at World.VINE_DRAW_Y)
const HOME_PUSH := 1.4  ## at home the camera pushes in to the doorway, this much
const SHAKE := 22.0  ## design units of the strongest shake
const RESUME_COUNT := 3  ## after Resume: 3, 2, 1 before the world moves again
const RESUME_STEP := 0.5  ## seconds per number
const FALL_BEAT := 0.3  ## after a fall that costs a life, the world holds this long before he springs back
const KO_STOP := 0.1  ## hit-stop of a knock-out (s)
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
var _touches := {}  # touch index -> {"start": Vector2, "time": float, "used": bool}
var _paused := false
var _ended := false
## Before the first touch the world waits (the 2017 "Ready" state): the start card shows the moves.
var _ready_to_start := true
var _start_card: Control
var _overlay: Control
var _clock := 0.0
var _trauma := 0.0  # screen shake, 0..1 (decays)
var _freeze := 0.0  # hit-stop: seconds the world waits
var _flash: TextureRect  # a red glow at the screen's edges when he is hurt
var _fliers: Node2D  # Red Bobs flying to the counter, over the HUD
var _combo := 0  # Red Bobs taken in a quick run: each one a note higher
var _last_bob := -10.0
var _swipe_min := SWIPE_MIN  # set from the screen's dpi (_layout)
var _k := 1.0  # the world's scale on screen (_layout)
var _countdown := 0.0  # after Resume: seconds before the world moves again
var _count_id := 0  # which Resume the countdown's numbers belong to
var _spring_due := false  # the spring's sound waits for the end of the fall's beat
var _frame := 1.0  # the camera drawn back (FRAME_TOP): 1 = the 640 units fill the screen
var _push := 1.0  # the camera pushed in at home (HOME_PUSH)


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
		Haptics.tap())
	world.let_go.connect(func() -> void: Audio.play_sfx(&"let_go"))
	world.stepped.connect(func() -> void: Audio.play_sfx(&"step", 1.0, 0.8))  # a swipe right answers
	world.thrown.connect(func(_r: World.Ring) -> void: Audio.play_sfx(&"throw", 1.0, 0.8))
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
	Audio.play_music(&"game")
	Services.ads.show_banner(true)
	Services.analytics.log_event("level_start")


func _exit_tree() -> void:
	if Device.changed.is_connected(_layout):
		Device.changed.disconnect(_layout)


## Fits the 640-unit-tall world above the ad banner and right of a notch.
func _layout() -> void:
	var v := get_viewport_rect().size
	_swipe_min = _physical_swipe_min()
	var insets := Device.insets()
	var k := (v.y - Device.banner_height) / World.VIEW_H
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
	if not _paused and _freeze <= 0.0 and not _ready_to_start and _countdown <= 0.0:
		if _spring_due:
			_spring_due = false
			Audio.play_sfx(&"spring")
			if world.water_at(world.scroll + world.x):  # out of a pool
				Audio.play_sfx(&"splash", 1.3, 0.55)
		world.advance(delta, autopilot.act if autopilot else Callable())
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	_place_camera(delta)
	view.refresh(delta if _freeze <= 0.0 else 0.0)  # a hit-stop holds the picture too
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
	_push = lerpf(_push, HOME_PUSH if home else 1.0, 1.0 - exp(-delta * (2.6 if home else 10.0)))
	var shake := _trauma * _trauma * SHAKE
	var zoom_k := _k
	var at := Vector2(Device.insets().x, 0)
	var door := at + Vector2(World.HOME_X + 30.0, World.VIEW_H - 100.0) * _k
	for zoom: Array in [[_frame, Vector2(0, _clip.size.y)], [_push, door],
			[1.0 + 2.0 * shake / (World.VIEW_H * _k), _clip.size / 2.0]]:
		zoom_k *= zoom[0]
		at = at * zoom[0] + zoom[1] * (1.0 - zoom[0])
	_stage.scale = Vector2(zoom_k, zoom_k)
	_stage.position = at + Vector2(sin(_clock * 53.0), cos(_clock * 47.0)) * shake
	view.view_left = at.x / zoom_k
	view.view_width = get_viewport_rect().size.x / zoom_k
	view.view_top = -at.y / zoom_k


# ------------------------------------------------------------------ controls

func _input(event: InputEvent) -> void:
	if _paused or _ended or _countdown > 0.0:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if hud.blocks(touch.position):
				return
			if _ready_to_start:
				_start()
			_touches[touch.index] = {"start": touch.position, "time": _clock, "used": false}
		elif _touches.has(touch.index):
			var t: Dictionary = _touches[touch.index]
			_touches.erase(touch.index)
			if not t.used and _clock - t.time <= TAP_MAX_TIME and touch.position.distance_to(t.start) < _swipe_min:
				world.throw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var t: Dictionary = _touches.get(drag.index, {})
		if t.is_empty() or t.used:
			return
		var d: Vector2 = drag.position - t.start
		if d.length() >= _swipe_min:
			t.used = true  # one swipe per touch, as soon as the finger has moved far enough
			_swipe(d)


func _swipe(d: Vector2) -> void:
	match swipe_action(d):
		&"jump":
			world.jump()
		&"down":
			world.down()
		&"right":
			world.step_forward()


## What a swipe `d` (design units) asks for: jump, down, right or nothing (left). The 2017 game
## split at 45°; up and down now win slanted swipes (VERTICAL_BIAS).
static func swipe_action(d: Vector2) -> StringName:
	if absf(d.x) <= absf(d.y) * VERTICAL_BIAS:
		return &"jump" if d.y < 0 else &"down"
	return &"right" if d.x > 0 else &""


## The swipe distance in design units for SWIPE_MM on this screen (SWIPE_MIN if the dpi is unknown).
func _physical_swipe_min() -> float:
	var dpi := float(DisplayServer.screen_get_dpi())
	var px_per_unit := get_viewport().get_screen_transform().get_scale().y
	if dpi < 100.0 or px_per_unit <= 0.0:
		return SWIPE_MIN
	return clampf(SWIPE_MM / 25.4 * dpi / px_per_unit, 14.0, 40.0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if _paused or _ended or _countdown > 0.0:
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
	Save.set_option(&"tutorial_seen", true)
	if _start_card:
		var card := _start_card
		_start_card = null
		var t := card.create_tween()
		t.tween_property(card, "modulate:a", 0.0, 0.25)
		t.tween_callback(card.queue_free)


## A card in the middle: the moves (all four the first time, two after), each with its gesture in
## a gold badge, and "Tap to start" breathing below, a hand tapping beside it.
func _make_start_card() -> Control:
	var root := CenterContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var moves := [["hand-pointing-fill", tr("TUTORIAL_THROW")], ["arrow-up-bold", tr("TUTORIAL_JUMP")],
			["arrow-up-bold", tr("TUTORIAL_HANG")], ["arrow-down-bold", tr("TUTORIAL_LET_GO")]]
	if Save.tutorial_seen:
		moves = moves.slice(0, 2)
	var card := Card.new(Vector4(26, 34, 30, 20), true)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 10)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m: Array in moves:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_badge(m[0]))
		row.add_child(Ui.label(m[1], 22, Ui.WHITE, Ui.font_body_bold, HORIZONTAL_ALIGNMENT_LEFT))
		list.add_child(row)
	card.add_child(list)
	box.add_child(card)
	var go_row := HBoxContainer.new()
	go_row.alignment = BoxContainer.ALIGNMENT_CENTER
	go_row.add_theme_constant_override(&"separation", 10)
	go_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hand_box := Control.new()
	hand_box.custom_minimum_size = Vector2(44, 44)
	hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hand := Ui.bold_icon("hand-pointing-fill", 40, Ui.WHITE, Ui.NIGHT)
	hand.pivot_offset = Vector2(20, 36)
	hand_box.add_child(hand)
	go_row.add_child(hand_box)
	var go := Ui.display_text(tr("TAP_TO_START"), 40, Ui.WHITE, Ui.NIGHT, Ui.BRAND_LIGHT)
	go.tracking = 4.0  # the outlines of "a" and "p" fused at this size
	go.refresh()
	go_row.add_child(go)
	box.add_child(go_row)
	go.pivot_offset = Vector2(go.get_combined_minimum_size().x / 2, 24)
	var t := go.create_tween().set_loops()
	t.tween_property(go, "scale", Vector2.ONE * 1.08, 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(go, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	var tap := hand.create_tween().set_loops()  # the hand taps the screen
	tap.tween_property(hand, "position:y", 6.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tap.tween_property(hand, "scale", Vector2(1.1, 0.88), 0.06)
	tap.tween_property(hand, "scale", Vector2.ONE, 0.12)
	tap.parallel().tween_property(hand, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tap.tween_interval(0.55)
	# the card arrives: it rises and settles
	card.modulate.a = 0.0
	var arrive := card.create_tween().set_parallel(true)
	arrive.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.2)
	return root


## A gesture in a round gold badge (the start card).
func _badge(icon_name: String) -> Control:
	var badge := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color("f2b52a")
	s.border_color = Card.INK
	s.set_border_width_all(3)
	s.set_corner_radius_all(20)
	s.set_content_margin_all(5)
	badge.add_theme_stylebox_override(&"panel", s)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(Ui.bold_icon(icon_name, 26, Ui.WHITE, Card.INK))
	return badge


# ------------------------------------------------------------------ events

const COMBO_WINDOW := 0.6  ## seconds between two Red Bobs that keep a combo going
const SCALE_STEPS := [0, 2, 4, 5, 7, 9, 11, 12]  ## the A major scale, in semitones


## A Red Bob: its chime climbs the scale while they come quickly one after another.
func _on_bob(_c: int, _r: int) -> void:
	_combo = _combo + 1 if _clock - _last_bob < COMBO_WINDOW else 0
	_last_bob = _clock
	var step: int = SCALE_STEPS[mini(_combo, SCALE_STEPS.size() - 1)]
	Audio.play_sfx(&"bob", pow(2.0, step / 12.0), 1.0, false)
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
	BobView.flier(_fliers, from, hud.bob_target(), BobView.SIZE * _stage.scale.x, hud.BOB_ICON, hud.bob_arrived)


func _on_bandit_hit(b: World.Bandit, knocked_out: bool) -> void:
	Audio.play_sfx(&"knock_out" if knocked_out else &"ring_hit")
	if knocked_out:
		Haptics.knock()
		_freeze = maxf(_freeze, KO_STOP)
		_trauma = minf(_trauma + 0.45, 1.0)
		Fx.plus_one(view.fx, Vector2(b.x - world.scroll, b.y - World.BANDIT_SIZE.y * 0.9) * 2.0)


## The thud follows the drop (World.land_speed, units a tick): a climb or a step down lands softly,
## a hop (~37) or a drop from the vine (~40) firmly, a fall from a high ledge (45+) hard: lower,
## louder, with a jolt.
func _on_landed() -> void:
	var k := clampf((world.land_speed - 15.0) / 35.0, 0.0, 1.0)
	Audio.play_sfx(&"land", 1.12 - 0.27 * k, 0.35 + 0.65 * k)
	if k > 0.8:
		_trauma = minf(_trauma + 0.4 * k, 1.0)
		Haptics.land()


func _on_splashed(_x: float, hero: bool) -> void:
	Audio.play_sfx(&"splash", 1.0 if hero else 1.25, 1.0 if hero else 0.6)


func _on_hurt(_b: World.Bandit, lives: int) -> void:
	Audio.play_sfx(&"hurt")
	Haptics.hurt()
	_freeze = HURT_STOP if lives > 0 else CAUGHT_STOP
	_trauma = minf(_trauma + 0.7, 1.0)
	_red_flash(0.5)


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


func _on_died(reason: StringName) -> void:
	Audio.play_sfx(&"fall" if reason == &"fall" else &"hurt")
	Audio.duck_music(true)
	if reason == &"fall":
		Haptics.fall()
	else:
		_trauma = 1.0
	_end_run()


func _on_won() -> void:
	Audio.play_sfx(&"win")
	Audio.duck_music(true)
	Haptics.celebrate()
	hud.create_tween().tween_property(hud, "modulate:a", 0.0, 0.35)  # the picture is his arrival
	_end_run(HOME_DELAY)
	await get_tree().create_timer(0.45).timeout  # he lands his hop: light from the doorway
	if is_inside_tree():
		Fx.rescue_burst(view.fx, Vector2(World.HOME_X + 34.0, World.VIEW_H - 150.0) * 2.0)
		Haptics.tap()


func _end_run(delay := END_DELAY) -> void:
	_ended = true
	_touches.clear()
	var news := Save.record_run(world)
	Services.analytics.log_event("level_end", {"won": world.state == World.State.WON, "bobs": world.bobs,
			"progress": snappedf(world.progress(), 0.01)})
	Services.leaderboards.submit(world.bobs)
	await get_tree().create_timer(delay).timeout
	if is_inside_tree():
		_show_results(news)


# ------------------------------------------------------------------ pause and results

func pause_game() -> void:
	if _paused or _ended:
		return
	_paused = true
	_touches.clear()
	Audio.duck_music(true)
	Audio.play_sfx(&"panel_open")
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 18)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	var toggles := HBoxContainer.new()
	toggles.alignment = BoxContainer.ALIGNMENT_CENTER
	toggles.add_theme_constant_override(&"separation", 22)
	toggles.add_child(_sound_toggle("music-notes-fill", &"music_on"))
	toggles.add_child(_sound_toggle("speaker-high-fill", &"sounds_on"))
	body.add_child(toggles)
	body.add_child(_buttons([
		[tr("RESUME"), "play-fill", Ui.Tone.GREEN, resume_game],
		[tr("HOME"), "house-fill", Ui.Tone.WHITE, _go_home],
	]))
	_overlay = _panel(tr("PAUSED"), Ui.Tone.SUNSET, body)


## A round button that turns music or sounds on and off (crossed out when off).
func _sound_toggle(icon_name: String, option: StringName) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(64, 64)
	var on: bool = Save.get(option)
	var b := Ui.round_button(icon_name if on else "speaker-x-fill", 64)
	if not on:
		b.modulate = Color(1, 1, 1, 0.6)
	b.size = holder.custom_minimum_size
	b.pressed.connect(func() -> void:
		Save.set_option(option, not Save.get(option))
		Audio.apply_settings()
		var fresh := _sound_toggle(icon_name, option)
		holder.get_parent().add_child(fresh)
		holder.get_parent().move_child(fresh, holder.get_index())
		holder.queue_free())
	holder.add_child(b)
	return holder


func resume_game() -> void:
	if not _paused:
		return
	_paused = false
	Audio.duck_music(false)
	Audio.play_sfx(&"panel_close")
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


## One number of the resume countdown: it pops in the middle and fades.
func _count_pop(n: int, id: int) -> void:
	if not is_inside_tree() or _paused or id != _count_id:
		return
	Audio.play_sfx(&"tick", 1.0 + (RESUME_COUNT - n) * 0.12)
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


## The end of a run: the title on its ribbon; a win's three big stars over a slow sunburst; the
## Red Bobs as the big number in a sunken well with the bandits and the distance under it; a NEW
## BEST celebration; PLAY AGAIN big in the middle, Home and Share as round buttons beside it.
## Panoramic (a win) or a gloating bandit (a loss) stands at the side of the card. The HUD goes.
func _show_results(news: Dictionary) -> void:
	var won := world.state == World.State.WON
	var title := tr("HOME_REACHED") if won else (tr("FELL") if world.death_reason == &"fall" else tr("CAUGHT"))
	hud.create_tween().tween_property(hud, "modulate:a", 0.0, 0.2)
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 12)
	var stars: Array[Control] = []
	if won:
		var stage := Control.new()  # the stars, placed by hand: the middle one bigger and higher
		stage.custom_minimum_size = Vector2(0, 112)
		body.add_child(stage)
		var burst := Rays.new(460, Color(1, 0.85, 0.45, 0.34), 16)
		burst.material = Fx.additive()
		stage.add_child(burst)
		var spin := burst.create_tween().set_loops()
		spin.tween_property(burst, "rotation", TAU, 24.0).from(0.0)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override(&"separation", 4)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.add_child(row)
		for i in 3:
			var side := 108.0 if i == 1 else 84.0
			var slot := Control.new()
			slot.custom_minimum_size = Vector2(side, side)
			slot.size_flags_vertical = Control.SIZE_SHRINK_END if i != 1 else Control.SIZE_SHRINK_BEGIN
			slot.add_child(StarBadge.new(side, false))
			var star := StarBadge.new(side, true)
			star.visible = false
			slot.add_child(star)
			row.add_child(slot)
			stars.append(star)
		stage.resized.connect(func() -> void: burst.position = stage.size / 2 - burst.size / 2)
	var counters: Array = []
	var well := PanelContainer.new()
	well.add_theme_stylebox_override(&"panel", Card.well())
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 6)
	well.add_child(lines)
	var big := HBoxContainer.new()  # the Red Bobs: the run's big number
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	big.add_theme_constant_override(&"separation", 14)
	var bob := _icon_bob()
	bob.custom_minimum_size = Vector2(60, 60)
	big.add_child(bob)
	var bobs := Ui.display_text("0 / %d" % world.level.bobs_total, 52, Ui.WHITE, Card.INK, Color("ffd36b"))
	bobs.depth = 4.0
	bobs.refresh()
	bobs.custom_minimum_size.x = maxf(bobs.custom_minimum_size.x, 230.0)
	big.add_child(bobs)
	lines.add_child(big)
	counters.append([bobs, world.bobs, " / %d" % world.level.bobs_total])
	var small := HBoxContainer.new()
	small.alignment = BoxContainer.ALIGNMENT_CENTER
	small.add_theme_constant_override(&"separation", 34)
	for line: Array in [["trophy-fill", Ui.GOLD, tr("BANDITS"), world.knocked_out, ""],
			["house-fill", Ui.WHITE, tr("DISTANCE"), roundi(world.progress() * 100.0), " %"]]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override(&"separation", 8)
		item.add_child(Ui.bold_icon(line[0], 36, line[1], Card.INK))
		item.add_child(Ui.label(line[2], 30, Color("ffe9d6"), Ui.font_strong, HORIZONTAL_ALIGNMENT_LEFT))
		var value := Ui.display_text("0" + line[4], 38, Ui.GOLD, Card.INK, Color("ffab24"))
		value.align = HORIZONTAL_ALIGNMENT_LEFT
		value.depth = 3.0
		value.shadow = Color(0, 0, 0, 0)
		value.refresh()
		value.custom_minimum_size.x = maxf(value.custom_minimum_size.x, 76.0)
		item.add_child(value)
		small.add_child(item)
		counters.append([value, line[3], line[4]])
	lines.add_child(small)
	body.add_child(well)
	var best := Control.new()  # the NEW BEST chip's place (it pops in at the end)
	best.custom_minimum_size = Vector2(0, 50)
	body.add_child(best)
	var buttons := _buttons([
		["", "house-fill", Ui.Tone.SUNSET, _go_home],
		[tr("PLAY_AGAIN"), "arrow-counter-clockwise-bold", Ui.Tone.GREEN, _play_again],
		["", "share-network-fill", Ui.Tone.SUNSET, func() -> void: Services.share.share_run(world.bobs, world.stars())],
	])
	body.add_child(buttons)
	_overlay = _panel(title, Ui.Tone.SUNSET if won else Ui.Tone.CRIMSON, body, _hero_art() if won else _bandit_art(), won)
	_reveal_results(stars, counters, best if news.best_bobs else null, buttons)
	Services.push.request_permission_once()


func _icon_bob() -> TextureRect:
	var bob := TextureRect.new()
	bob.texture = BobView.texture()
	bob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bob.custom_minimum_size = Vector2(32, 32)
	return bob


## Panoramic's portrait (the user's art) beside a won run's card, lit by the sunset, his chest
## fading out (portrait.gdshader).
func _hero_art() -> Control:
	var art := TextureRect.new()
	art.texture = load("res://assets/art/hero/portrait.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	var lit := ShaderMaterial.new()
	lit.shader = preload("res://src/ui/portrait.gdshader")
	lit.set_shader_parameter(&"fade_to_clear", true)
	lit.set_shader_parameter(&"fade_from", 0.7)
	art.material = lit
	return art


## A bandit, club raised, gloating beside a lost run's card (a frame of its sheet).
func _bandit_art() -> Control:
	var sheet: Texture2D = load("res://assets/art/bandit/bandit.png")
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(2 * 190, 2 * 280, 190, 280)
	var art := TextureRect.new()
	art.texture = frame
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	return art


## The results' choreography: the stars land one after the other while the counts tick up side
## by side; the buttons are there from the start of it; a new best ends it (each step is skipped
## if the panel is gone): after a win, confetti bursts from behind the stars; the NEW BEST chip
## pops over a burst of light behind it.
func _reveal_results(stars: Array[Control], counters: Array, best: Control, buttons: Control) -> void:
	var panel := _overlay
	if world.state != World.State.WON:
		Audio.play_sfx(&"game_over")
	buttons.modulate.a = 0.0
	buttons.create_tween().tween_property(buttons, "modulate:a", 1.0, 0.25).set_delay(0.45)
	(buttons.get_child(1) as JuicyButton).idle(0.05)
	for i in world.stars():
		_drop_star(stars[i], i, 0.3 + i * 0.2, panel)
	for i in counters.size():
		var c: Array = counters[i]
		_count_up(c[0], c[1], c[2], 0.35 + i * 0.12, i == 0, panel)
	if world.state == World.State.WON and not stars.is_empty():  # confetti from behind the stars
		get_tree().create_timer(0.45 + world.stars() * 0.2).timeout.connect(func() -> void:
			if not is_instance_valid(panel):
				return
			var back := Node2D.new()  # behind the card: it flies out from under its top
			back.scale = Vector2.ONE * 0.5
			panel.add_child(back)
			panel.move_child(back, 1)
			Fx.confetti_burst(back, stars[1].get_global_rect().get_center() * 2.0))
	if not best:
		return
	await get_tree().create_timer(1.15).timeout
	if not is_instance_valid(panel):
		return
	var chip := Ui.chip(tr("NEW_BEST"), Ui.Tone.CRIMSON, 27, "crown-fill")
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	best.add_child(holder)
	var pop := Control.new()
	pop.custom_minimum_size = chip.get_combined_minimum_size()
	holder.add_child(pop)
	pop.add_child(chip)
	pop.pivot_offset = pop.custom_minimum_size / 2
	pop.scale = Vector2.ZERO
	pop.create_tween().tween_property(pop, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_sfx(&"new_best")
	Haptics.celebrate()
	var behind := Node2D.new()  # under the chip: the light never covers its words
	behind.scale = Vector2.ONE * 0.5
	best.add_child(behind)
	best.move_child(behind, 0)
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	behind.position = best.size / 2
	Fx.badge_burst(behind, Vector2.ZERO)



## A star thumps into its socket: from big and turned to its place, a chime a third higher each,
## a flash and sparkles as it lands.
func _drop_star(star: Control, i: int, delay: float, panel: Control) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(panel):
		return
	star.visible = true
	star.scale = Vector2.ONE * 2.6
	star.modulate.a = 0.0
	star.rotation = -0.6
	var t := star.create_tween().set_parallel(true)
	t.tween_property(star, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(star, "modulate:a", 1.0, 0.1)
	t.tween_property(star, "rotation", 0.0, 0.28)
	await get_tree().create_timer(0.17).timeout
	if not is_instance_valid(panel):
		return
	Audio.play_sfx(&"star", pow(2.0, [0, 4, 7][i] / 12.0), 1.0, false)
	Haptics.tap()
	var fx := Node2D.new()
	fx.scale = Vector2.ONE * 0.5
	panel.add_child(fx)
	Fx.counter_pop(fx, star.get_global_rect().get_center() * 2.0)
	# then it keeps catching the light now and then
	var shine := star.create_tween().set_loops()
	shine.tween_interval(1.4 + i * 0.35)
	shine.tween_property(star, "scale", Vector2.ONE * 1.08, 0.12).set_trans(Tween.TRANS_SINE)
	shine.tween_property(star, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)


## A number ticks up from 0 to `target` in half a second, then bumps.
func _count_up(value: DisplayText, target: int, suffix: String, delay: float, ticks: bool, panel: Control) -> void:
	await get_tree().create_timer(delay).timeout
	var steps := mini(target, 16)
	for k in range(1, steps + 1):
		if not is_instance_valid(panel):
			return
		value.text = str(roundi(float(target) * k / steps)) + suffix
		if ticks and k % 2 == 0:
			Audio.play_sfx(&"tick", 1.0 + 0.3 * k / steps, 0.6)
		await get_tree().create_timer(0.5 / steps).timeout
	if not is_instance_valid(panel):
		return
	value.text = str(target) + suffix
	value.pivot_offset = value.size / 2
	var bump := value.create_tween()
	bump.tween_property(value, "scale", Vector2.ONE * 1.2, 0.06)
	bump.tween_property(value, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A row of candy buttons [text, icon, tone, action]: a button with words is the big one (the
## main action); one with an icon only is a round button beside it.
func _buttons(list: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 18)
	var words := list.filter(func(b: Array) -> bool: return not (b[0] as String).is_empty()).size()
	for b: Array in list:
		var button: JuicyButton
		if (b[0] as String).is_empty():
			button = Ui.icon_button(b[1], b[2], 78.0, 39.0)
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		elif words == 1:
			button = Ui.candy_button(b[0], b[1], b[2], 78, 32)
			button.custom_minimum_size.x = 300
			button.shine()
		else:
			button = Ui.candy_button(b[0], b[1], b[2], 64, 27)
			button.custom_minimum_size.x = 200
		button.pressed.connect(b[3])
		row.add_child(button)
	return row


## A veil over the game and a Card in the middle, its title on a ribbon over the card's top edge;
## `art` (a character) stands at the card's left side (`art_left`) or right, its feet on the card's
## bottom. The card pops in.
func _panel(title: String, tone: Ui.Tone, body: Control, art: Control = null, art_left := true) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var veil := Ui.frosted_veil(Color(0.1, 0.07, 0.22, 0.42))  # the game stays colourful behind
	root.add_child(veil)
	var pop := Control.new()  # placed by hand in the safe area (place): what the entrance animates
	root.add_child(pop)
	var card := Card.new(Vector4(44, 58, 44, 40))
	card.add_child(body)
	var banner := Banner.new(title, tone, 40)
	var banner_size := banner.custom_minimum_size
	banner.size = banner_size
	var top := banner_size.y * 0.55
	var min_w := maxf(banner_size.x + 40.0, 560.0)
	var ground: TextureRect  # a soft shadow under a standing character's feet
	if art:
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not art_left:
			ground = TextureRect.new()
			ground.texture = Fx.glow_texture()
			ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ground.modulate = Color(0.05, 0.0, 0.05, 0.55)
			ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pop.add_child(ground)
		pop.add_child(art)
	pop.add_child(card)
	pop.add_child(banner)
	# placed from the card's real size (it settles once its content is in the tree), in the middle
	# of the safe area, shrunk to fit a narrow screen (state.k), on top of the entrance's pop (state.u)
	var state := {"k": 1.0, "u": 0.75}
	var place := func() -> void:
		var card_size := Vector2(maxf(card.size.x, min_w), card.size.y)
		if card.size.x < min_w:
			card.size.x = min_w
		var art_w := 0.0
		if art:  # as tall as most of the card, beside it (clear of it)
			var tex_size: Vector2 = art.texture.get_size()
			var h := minf(card_size.y * 1.08, 400.0)
			art.size = Vector2(h * tex_size.x / tex_size.y, h)
			art_w = art.size.x + 10.0
		var left := art_w if art_left else 0.0
		var whole := Vector2(card_size.x + art_w, card_size.y + top)
		var insets := Device.insets()
		var free := Rect2(insets.x + 10.0, insets.y + 10.0, root.size.x - insets.x - insets.z - 20.0,
				root.size.y - insets.y - Device.bottom_with_banner() - 20.0)
		pop.size = whole
		pop.pivot_offset = whole / 2
		pop.position = free.get_center() - whole / 2
		if free.size.x > 0.0:
			state.k = minf(1.0, minf(free.size.x / whole.x, free.size.y / whole.y))
		pop.scale = Vector2.ONE * state.u * state.k
		card.position = Vector2(left, top)
		banner.position = Vector2(left + (card_size.x - banner_size.x) / 2, 0)
		if art:
			art.position = Vector2(0.0 if art_left else card_size.x + 10.0, top + card_size.y - art.size.y * 0.97)
		if ground:
			ground.size = Vector2(art.size.x * 0.8, art.size.x * 0.18)
			ground.position = art.position + Vector2(art.size.x * 0.1, art.size.y * 0.94 - ground.size.y / 2)
	card.resized.connect(place)
	root.resized.connect(place)
	card.size = card.get_combined_minimum_size()
	place.call()
	pop.modulate.a = 0.0
	var t := pop.create_tween().set_parallel(true)
	t.tween_method(func(u: float) -> void:
		state.u = u
		pop.scale = Vector2.ONE * u * state.k, 0.75, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(pop, "modulate:a", 1.0, 0.15)
	veil.modulate.a = 0.0
	t.tween_property(veil, "modulate:a", 1.0, 0.25)
	banner.scale = Vector2(0.4, 0.4)
	banner.pivot_offset = banner_size / 2
	t.tween_property(banner, "scale", Vector2.ONE, 0.4).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if art:  # the character fades in beside the card
		art.modulate.a = 0.0
		t.tween_property(art, "modulate:a", 1.0, 0.25).set_delay(0.15)
	return root


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

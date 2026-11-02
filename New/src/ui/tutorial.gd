class_name Tutorial
extends Control
## The first run's lessons, each at the moment its move is needed: the world holds still, the
## screen dims a little, a hint names the move and a big hand plays its gesture on the right of
## the screen (where the thumb is), and the run goes on as soon as the player makes that move
## (another gesture only nudges the hint). A lesson learned is saved and never comes back; Skip
## ends them all; Settings › Replay the tutorial brings them back.
##
## When a move is needed is found by looking ahead on copies of the world, as the bot does: the
## run would go wrong if nothing is done, and goes right if the move is made now. The throw is
## taught when the first bandit comes into view, the step forward at a calm moment once the jump
## is known.

enum Move { JUMP = 1, HANG = 2, LET_GO = 4, STEP = 8, THROW = 16 }

const ALL := 31
const LOOK_AHEAD := 30  ## ticks looked ahead (0.75 s; a look costs about 1.5 ms on a desktop)
const CHECK_EVERY := 4  ## ticks between two looks (every needed jump has a window of 7 ticks or more)
const STEP_EVERY := 20  ## ticks between two looks for a calm moment to teach the step
const CALM_STEP := 200  ## ticks without a lesson before the step forward is taught (5 s)
const HANG_LESSON := 30  ## ticks hanging before letting go is taught, if nothing forces it sooner
const TEXTS := {Move.JUMP: "TUTORIAL_JUMP", Move.HANG: "TUTORIAL_HANG", Move.LET_GO: "TUTORIAL_LET_GO",
		Move.STEP: "TUTORIAL_STEP", Move.THROW: "TUTORIAL_THROW"}
const GESTURES := {Move.JUMP: Gesture.Kind.UP, Move.HANG: Gesture.Kind.TOP, Move.LET_GO: Gesture.Kind.DOWN,
		Move.STEP: Gesture.Kind.RIGHT, Move.THROW: Gesture.Kind.TAP}
const ACTIONS := {Move.JUMP: &"jump", Move.HANG: &"jump", Move.LET_GO: &"down", Move.STEP: &"right",
		Move.THROW: &"throw"}

## True while a lesson holds the world still.
var holding := false
var lesson := 0  ## the Move being taught (0: none)
var game: Control  ## the game screen (playing(), hud, swipe_action(), swipe_min())
var world: World
var _hint: Control
var _card: Control
var _hand: Gesture
var _skip: JuicyButton
var _last_check := -100
var _last_step_look := -100
var _calm := 0  # ticks since the last lesson
var _hung := 0  # ticks hanging
var _seen_tick := -1
var _touch := {}  # the touch read during a lesson: index -> {start, time, moved}
var _clock := 0.0


func _init(screen: Control, w: World) -> void:
	game = screen
	world = w
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Whether the tutorial still has something to teach.
static func pending() -> bool:
	return not Save.tutorial_seen and (Save.tutorial_learned & ALL) != ALL


## Forgets every lesson learned (Settings › Replay the tutorial).
static func replay() -> void:
	Save.tutorial_learned = 0
	Save.set_option(&"tutorial_seen", false)


## The lesson the world needs now (a Move), or 0. `calm`: ticks since the last lesson; `hung`:
## ticks he has been hanging; `look_step`: look for a calm moment too (costlier, done less often).
## Looks ahead only for what is left to learn, the cheapest look first.
static func lesson_for(w: World, learned: int, calm: int, hung: int, look_step := true) -> int:
	if w.state != World.State.RUNNING or w.at_end:
		return 0
	if w.hanging:
		if not learned & Move.LET_GO and (hung >= HANG_LESSON or not _safe(w, &"", LOOK_AHEAD)) \
				and _safe(w, &"down", LOOK_AHEAD * 2):
			return Move.LET_GO
		return 0
	if not w.on_ground or w.climbing:
		return 0
	if not learned & Move.THROW and _bandit_coming(w):
		return Move.THROW
	if (learned & (Move.JUMP | Move.HANG)) != (Move.JUMP | Move.HANG):
		if (w.blocked or not _safe(w, &"", LOOK_AHEAD)) and _safe(w, &"jump", LOOK_AHEAD):
			var hangs := _hangs(w)
			if hangs and not learned & Move.HANG:
				return Move.HANG
			if not hangs and not learned & Move.JUMP:
				return Move.JUMP
			return 0
	if look_step and not learned & Move.STEP and learned & Move.JUMP and calm >= CALM_STEP \
			and w.x + World.STEP * 2.0 < World.MAX_X and _safe(w, &"right", LOOK_AHEAD * 2) \
			and _safe(w, &"", LOOK_AHEAD * 2):
		return Move.STEP
	return 0


## A bandit on his way, in view ahead of Panoramic, still standing.
static func _bandit_coming(w: World) -> bool:
	for b in w.bandits:
		if b.gone or not b.active or b.health <= 0:
			continue
		var ahead := b.x - w.scroll - w.x
		if ahead > 140.0 and ahead < 560.0 and absf(b.y - w.y) < 150.0:
			return true
	return false


## Whether doing `action` now (or nothing) keeps the run going for `ticks`, without a hit.
static func _safe(w: World, action: StringName, ticks: int) -> bool:
	var sim := w.clone()
	_apply(sim, action)
	var lives := sim.lives
	for i in ticks:
		sim.tick()
		if sim.state == World.State.DEAD or sim.lives < lives:
			return false
		if sim.state == World.State.WON:
			return true
	return true


## Whether a jump now ends hanging from the vine.
static func _hangs(w: World) -> bool:
	var sim := w.clone()
	sim.jump()
	for i in 30:
		sim.tick()
		if sim.hanging:
			return true
		if sim.on_ground and i > 2:
			return false
	return false


static func _apply(w: World, action: StringName) -> void:
	match action:
		&"jump": w.jump()
		&"down": w.down()
		&"right": w.step_forward()
		&"throw": w.throw()


func _process(delta: float) -> void:
	_clock += delta
	if holding or not game.playing() or world.ticks == _seen_tick:
		return
	var passed := world.ticks - maxi(_seen_tick, 0)
	_seen_tick = world.ticks
	_calm += passed
	_hung = _hung + passed if world.hanging else 0
	if world.ticks - _last_check < CHECK_EVERY:
		return
	_last_check = world.ticks
	var look_step := world.ticks - _last_step_look >= STEP_EVERY
	if look_step:
		_last_step_look = world.ticks
	var next := lesson_for(world, Save.tutorial_learned, _calm, _hung, look_step)
	if next != 0:
		_begin(next)


## Holds the world and shows the hint of `move`.
func _begin(move: int) -> void:
	lesson = move
	holding = true
	_touch.clear()
	Audio.play_sfx(&"panel_open", 1.2, 0.6)
	Haptics.tap()
	_hint = Control.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	var dim := TextureRect.new()
	dim.texture = Fx.vignette_texture()
	dim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dim.stretch_mode = TextureRect.STRETCH_SCALE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.modulate = Color(0.05, 0.0, 0.05, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(dim)
	# the words, on dark glass under the HUD, with the gesture's badge
	_card = Card.new(Vector4(22, 16, 30, 18), true)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := Gesture.new(GESTURES[move], 70.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var words := Ui.display_text(tr(TEXTS[move]), 40, Ui.WHITE, Ui.NIGHT, Color("ffe2a8"))
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	_card.add_child(row)
	_hint.add_child(_card)
	# the big hand playing the gesture, where the thumb is
	_hand = Gesture.new(GESTURES[move], 230.0, true)
	_hand.badge = false
	_hint.add_child(_hand)
	_skip = Ui.candy_button(tr("TUTORIAL_SKIP"), "", Ui.Tone.WHITE, 62, 26)
	_skip.custom_minimum_size.x = 170
	_skip.pressed.connect(skip)
	_hint.add_child(_skip)
	_place()
	if not Device.changed.is_connected(_place):
		Device.changed.connect(_place)
	# it arrives: the card drops in, the hand fades in
	var fit: float = _card.get_meta(&"fit", 1.0)
	_card.scale = Vector2.ONE * 0.6 * fit
	_card.modulate.a = 0.0
	var t := _card.create_tween().set_parallel(true)
	t.tween_property(_card, "scale", Vector2.ONE * fit, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "modulate:a", 1.0, 0.15)
	dim.modulate.a = 0.0
	t.tween_property(dim, "modulate:a", 0.7, 0.25)
	_hand.modulate.a = 0.0
	t.tween_property(_hand, "modulate:a", 1.0, 0.3).set_delay(0.15)


func _exit_tree() -> void:
	if Device.changed.is_connected(_place):
		Device.changed.disconnect(_place)


## The card in the middle under the HUD, the hand on the right half, Skip in the lower right
## corner, all inside the safe area and above the banner.
func _place() -> void:
	if not is_instance_valid(_hint):
		return
	var v := get_viewport_rect().size
	var insets := Device.insets()
	_card.size = _card.get_combined_minimum_size()
	var room := v.x - insets.x - insets.z - 40.0  # long French hints shrink to fit a narrow screen
	var k := minf(1.0, room / _card.size.x)
	_card.position = Vector2((v.x - _card.size.x) / 2, insets.y + 96.0 - _card.size.y * (1.0 - k) / 2)
	_card.pivot_offset = _card.size / 2
	_card.set_meta(&"fit", k)
	_hand.size = _hand.custom_minimum_size
	_hand.position = Vector2(v.x * 0.7 - _hand.size.x / 2, v.y * 0.56 - _hand.size.y / 2)
	_skip.size = _skip.get_combined_minimum_size()
	_skip.position = Vector2(v.x - insets.z - 24.0 - _skip.size.x, v.y - Device.bottom_with_banner() - 24.0 - _skip.size.y)


## Ends every lesson (the Skip button).
func skip() -> void:
	Save.tutorial_learned = ALL
	Save.set_option(&"tutorial_seen", true)
	_end()


func _learn() -> void:
	var learned := Save.tutorial_learned | lesson
	if lesson == Move.HANG:
		learned |= Move.JUMP  # the same swipe
	Save.tutorial_learned = learned
	Save.set_option(&"tutorial_seen", (learned & ALL) == ALL)
	Audio.play_sfx(&"toggle_on")
	_end()


func _end() -> void:
	holding = false
	lesson = 0
	_calm = 0
	_touch.clear()
	if is_instance_valid(_hint):
		var h := _hint
		_hint = null
		var t := h.create_tween()
		t.tween_property(h, "modulate:a", 0.0, 0.18)
		t.tween_callback(h.queue_free)
	if not pending():
		var t2 := create_tween()
		t2.tween_interval(0.3)
		t2.tween_callback(queue_free)


## The wrong gesture: the card shakes its head.
func _nudge() -> void:
	if not is_instance_valid(_card):
		return
	var x := _card.position.x
	var t := _card.create_tween()
	for k in 4:
		t.tween_property(_card, "position:x", x + (12.0 if k % 2 == 0 else -12.0), 0.05)
	t.tween_property(_card, "position:x", x, 0.05)
	Haptics.tap()


## During a lesson, gestures are read here first: the right one makes the move and ends the
## lesson, others only nudge the hint (the HUD's pause and Skip still take their touches).
func _input(event: InputEvent) -> void:
	if not holding or not game.playing():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if game.hud.blocks(touch.position) or _skip.global_hit_rect().has_point(touch.position):
				return
			_touch[touch.index] = {"start": touch.position, "time": _clock, "moved": false}
		elif _touch.has(touch.index):
			var t: Dictionary = _touch[touch.index]
			_touch.erase(touch.index)
			if not t.moved and _clock - t.time <= 0.45:
				_try(&"throw")
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var t: Dictionary = _touch.get(drag.index, {})
		if t.is_empty():
			return
		get_viewport().set_input_as_handled()
		var d: Vector2 = drag.position - t.start
		if not t.moved and d.length() >= game.swipe_min():
			t.moved = true
			_try(game.swipe_action(d))
	elif event is InputEventKey and event.pressed and not event.echo:
		var action := &""
		match (event as InputEventKey).keycode:
			KEY_UP, KEY_W: action = &"jump"
			KEY_DOWN, KEY_S: action = &"down"
			KEY_RIGHT, KEY_D: action = &"right"
			KEY_SPACE, KEY_X, KEY_J: action = &"throw"
			_: return
		get_viewport().set_input_as_handled()
		_try(action)


func _try(action: StringName) -> void:
	if action != ACTIONS.get(lesson, &"x"):
		_nudge()
		return
	_apply(world, action)
	_learn()

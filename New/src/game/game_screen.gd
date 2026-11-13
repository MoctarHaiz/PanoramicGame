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
## The camera (New, env). On a screen wider than the 2017 play window it closes in, as far as still
## shows VIEW_AHEAD units right of the play window's left edge (the 2017 game showed 960, and a
## bandit starts running as it crosses 960), at most ZOOM_MAX; a 4:3 iPad draws back instead to
## show the whole 960. The bottom of the level stays on the bottom of the screen (the ground, the
## pools, the bandits on it are always in view); when he goes up (a high ledge, a jump, the vine)
## the camera draws back just enough to keep his head HEAD_ROOM under the top of the screen, and
## the vine under the HUD (HUD_BAND) while he can reach it or hangs from it.
## (2026-11-12, both blind judges: "bring the camera in: the hero 25 to 28 % of the screen's height"; the user: "yes,
## closer camera") Closer on the ground: 1.4 on a phone (1.24 before), still showing everything the 2017 screen did.
## What held it back was showing the play window's 960 units inside the screen's safe margins: _keep_fair now lets
## them reach the screen's own right edge (the 96 units under a phone's right inset: bandits wake there, on the ground,
## clear of a camera cut-out at mid height), and the base no longer keeps 80 units more than the window in view.
const VIEW_AHEAD := 900.0  ## play units at least, right of the play window's left edge (_keep_fair: all 960 of them)
const ZOOM_MAX := 1.4
const HEAD_ROOM := 132.0  ## screen units (of 640) over his head
## ... and over his head at the top of a jump: just under the HUD's band (at 132 every jump drew the closer camera
## back by a sixth and let it creep in again)
const APEX_ROOM := 92.0
const HEAD := 74.0  ## play units from his centre up to the top of his head (drawn 150 tall from his feet)
const HUD_BAND := 78.0  ## screen units kept for the HUD over the vine
const VINE_GAP := 30.0  ## round 5: and this much more, so his hands on the vine never touch the HUD
const VINE_TOP := -8.0  ## play y of the top of the vine (VineView)
const ZOOM_OUT_RATE := 9.0  ## how fast the camera draws back (1/s; round 4: faster, GP-1), and closes in again
const ZOOM_IN_RATE := 1.4
const HIGH_FROM := 340.0  ## play y of his feet where the camera starts to rise with him (a high ledge)
const HIGH_FULL := 270.0  ## ... and where it has fully risen
const HIGH_FEET := 0.74  ## risen, his feet this share of the screen down
const HIGH_RATE := 2.5  ## how fast it rises and comes back down (1/s)
const HIGH_DROP := 14.0  ## ... and how fast it comes down when what must be seen no longer fits
const HIGH_LOOKAHEAD := 330.0  ## units further than the rules look for a drop ahead (~1.4 s of run)
const HOME_PUSH := 1.78  ## at home the camera pushes in to the doorway, to this zoom (1: 640 units tall; round 6: closer; round 19: 1.6 -> 1.78, "the hero small at home")
const DEATH_PUSH := 1.2  ## caught: the camera closes in on him while he falls (World.DYING_TIME)
const START_PUSH := 1.3  ## (round 19) on the start card the camera opens pushed in this much on him, about his feet,
const START_HOLD := 1.6  ## ... holds it this many seconds,
const START_REVEAL := 1.0  ## ... then draws back to the run's framing over this many (the first touch: at once)
const HOME_CX := 800.0  ## play x drawn to the middle of the screen at home (the hut, him at its door)
const SHAKE := 22.0  ## design units of the strongest shake
const RESUME_COUNT := 3  ## after Resume: 3, 2, 1 before the world moves again
const RESUME_STEP := 0.5  ## seconds per number
const FALL_BEAT := 0.3  ## after a fall that costs a life, the world holds this long before he springs back

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
var _zoom := 0.0  # the camera's zoom (1: the 640 units fill the screen's height); 0: not placed yet
var _support := 0.0  # play y of the feet he last stood on (in the air only a fall moves it)
var _high := 0.0  # 0..1: how far the camera has risen with him on a high ledge
var _push := 1.0  # the camera pushed in at home (HOME_PUSH), or on him when caught (DEATH_PUSH)
var _start_push := 1.0  # the camera pushed in on him on the start card (START_PUSH .. 1)
var _zoom_placed_ready := false  # the camera was first placed on the start card
var _start_clock := 0.0  # seconds the start card has shown
var _pit_scroll := -1.0  # the scroll the camera holds at while he drops into a pit (_gameplay_camera)
var _pit_time := 0.0  # seconds since it began holding
var _pit_seen := false  # the hold began while he was still in the picture, dropping in
var _need := Rect2()  # what must be seen (World.camera_must_see()), eased
var _dt := 0.0  # this frame's seconds (_process's delta: a test may step it by hand)
const NEED_EASE := 12.0  ## 1/s: how fast the camera lets go of what needn't be seen any more (~0.2 s)
const NEED_GROW := 40.0  ## 1/s: how fast it takes in more (~0.06 s)
## Caught: his last beat is framed with him this far across the screen (he fell near its left edge),
## brought there over DEATH_FRAME_TIME seconds of the ending.
const DEATH_FRAME := 0.4
## The panels, the start card, the lessons and the resume countdown are drawn over the world's effects
## (WorldView.fx is at z 10: a knock-out's "+1" landed on the pause panel's buttons).
const OVERLAY_Z := 20
const DEATH_FRAME_TIME := 0.5
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
	_flash.texture = Fx.edge_texture()  # New (audio): the red of a blow at the edges only
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
	_fliers.z_index = 11  # New (audio): over the effects layer (view.fx, z 10): the pickup's ring never covers its face
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
	add_child(Feel.new(self, world, view))  # knockbacks, climb grabs, vine creaks, the music's drive
	Fx.warm_glyphs(self)  # the "+1" and "×N" glyphs now, not at the first knock-out or streak
	world.bumped.connect(_on_bumped)
	world.splashed.connect(_on_splashed)
	world.fell.connect(_on_fell)
	world.sprang.connect(func() -> void: _spring_due = true)
	world.bandit_hit.connect(_on_bandit_hit)
	world.bob_collected.connect(_on_bob)
	view.bob_popped.connect(_on_bob_popped)
	# (2026-11-10) the bandits' leaps are heard: a lighter, higher take-off than his, a thud as they land
	view.bandit_leapt.connect(func(strong: bool) -> void: Audio.play_sfx(&"jump", 0.78 if strong else 0.9, 0.4))
	view.bandit_landed.connect(func(strong: bool, hard: float) -> void: Audio.play_sfx(&"land", 0.95 if strong else 1.2, 0.35 * hard))
	world.hurt.connect(_on_hurt)
	world.died.connect(_on_died)
	world.won.connect(_on_won)
	Device.changed.connect(_layout)
	_layout()
	_start_card = _make_start_card()
	add_child(_start_card)
	_start_card.z_index = OVERLAY_Z
	if Tutorial.pending():
		_tutorial = Tutorial.new(self, world)
		add_child(_tutorial)
		_tutorial.z_index = OVERLAY_Z
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
	_dt = delta
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


## The world's place on screen: closed in on a wide screen and drawn back when he is up high (about
## the bottom of the play window's left edge: the ground stays put), pushed in at home or on him
## when caught, and shaken (with just enough zoom that the shake never bares an edge). Each is a
## zoom about its own point.
func _place_camera(delta: float) -> void:
	var p := world.draw_hero()
	var inset := Device.insets().x
	# round 4: up on a high ledge the camera stays close and rises with him (gameplay measured the
	# lower half of those shots free: _keep_fair still brings in whatever must be seen)
	var feet := p.y + World.HERO_SIZE.y / 2
	if _zoom <= 0.0 or (world.on_ground and not world.hanging) or feet > _support:
		_support = feet  # what he stands on (in the air, only a fall moves it)
	var vine_framed := world.state == World.State.RUNNING and (world.hanging or world.rising_to_vine())
	var high := 0.0 if vine_framed else smoothstep(HIGH_FROM, HIGH_FULL, _support)
	var base := base_zoom((_clip.size.x - inset) / _k)
	# only where all the player must see (gameplay: World.camera_must_see()) fits under the HUD up close
	var need := world.camera_must_see()
	# (looking further ahead than the rules: the camera is down again before a drop ahead must show)
	var low := maxf(need.end.y, _lowest_ahead(world, World.SEE_AHEAD_DOWN + HIGH_LOOKAHEAD) + 24.0)
	var fits := low - need.position.y + hud_band() / (_k * base) <= _clip.size.y / (_k * base) - 4.0
	if not fits:
		high = 0.0
	var goal := lerpf(minf(base, follow_zoom(world, p)), base, _high)
	if _zoom <= 0.0:  # the first frame: framed at once, no drift in from nowhere
		_zoom = goal
		_high = high
		_zoom_placed_ready = _ready_to_start  # (round 19) framed on the start card: pushed in on him
	_high = lerpf(_high, high, 1.0 - exp(-delta * (HIGH_RATE if fits else HIGH_DROP)))
	_zoom = lerpf(_zoom, goal, 1.0 - exp(-delta * (ZOOM_OUT_RATE if goal < _zoom else ZOOM_IN_RATE)))
	var home := world.state == World.State.WON
	var caught := world.state == World.State.DEAD and world.death_reason == &"bandit"
	var push := maxf(HOME_PUSH / _zoom, 1.0) if home else (DEATH_PUSH if caught else 1.0)
	_push = lerpf(_push, push, 1.0 - exp(-delta * (2.6 if home else (1.6 if caught else 10.0))))
	var shake := _trauma * _trauma * SHAKE * Prefs.shake()  # New: the player can turn it off
	var zoom_k := _k * _zoom
	var at := Vector2(inset, _clip.size.y - World.VIEW_H * zoom_k)
	if _high > 0.001:  # risen: his feet HIGH_FEET down the screen, never above the vine under the HUD
		var bottom_top := World.VIEW_H - _clip.size.y / zoom_k  # (the play y at the top, ground on the bottom)
		var vine_top := VINE_TOP - (hud_band() + VINE_GAP) / zoom_k
		var top := clampf(_support - HIGH_FEET * _clip.size.y / zoom_k, vine_top, bottom_top)
		if world.state == World.State.RUNNING and _vine_in_reach(world):
			top = vine_top  # where a jump reaches the vine: it shows under the HUD
		# and what must be seen stays in view, the whole time (under the HUD band, above the bottom)
		top = clampf(top, need.end.y - _clip.size.y / zoom_k, need.position.y - hud_band() / zoom_k)
		at.y = -lerpf(bottom_top, top, _high) * zoom_k
	if _push > 1.0001 and home:  # New: the push draws the hut and him to the middle of the screen as it goes
		# in (about the doorway, a 4:3 iPad lost the hut's right half past its edge)
		var u := clampf((_push - 1.0) / maxf(HOME_PUSH / _zoom - 1.0, 0.01), 0.0, 1.0)
		var c := at + Vector2(HOME_CX, World.VIEW_H - 100.0) * zoom_k
		var target := Vector2(lerpf(c.x, _clip.size.x / 2.0, u), c.y)
		zoom_k *= _push
		at = at * _push + target - c * _push
	elif _push > 1.0001:
		var fall := at + Vector2(p.x, p.y + 40.0) * zoom_k  # caught: the push closes in about where he falls
		zoom_k *= _push
		at = at * _push + fall * (1.0 - _push)
	var fair := _gameplay_camera(zoom_k, at)
	zoom_k = fair[0]
	at = fair[1]
	# (round 19, the judges: "the hero small on the start card") on his marks the camera opens pushed in on him, about
	# his feet (the ground stays on the bottom of the screen), then draws back to reveal the run's framing while the
	# card waits; the first touch ends it at once (while he runs the whole play window shows: _keep_fair's rules)
	if _zoom_placed_ready:
		_start_push = START_PUSH
		_start_clock = 0.0
		_zoom_placed_ready = false
	if _ready_to_start and _start_push > 1.0:
		_start_clock += delta
		_start_push = lerpf(START_PUSH, 1.0, smoothstep(START_HOLD, START_HOLD + START_REVEAL, _start_clock))
	else:
		_start_push = 1.0
	if _start_push > 1.0005:
		var mark := Vector2(at.x + p.x * zoom_k, _clip.size.y)
		at = mark + (at - mark) * _start_push
		zoom_k *= _start_push
	var z := 1.0 + 2.0 * shake / (World.VIEW_H * _k)
	zoom_k *= z
	at = at * z + _clip.size / 2.0 * (1.0 - z)
	_stage.scale = Vector2(zoom_k, zoom_k)
	_stage.position = at + Vector2(sin(_clock * 53.0), cos(_clock * 47.0)) * shake + _kick * _k
	view.view_left = at.x / zoom_k
	view.view_width = get_viewport_rect().size.x / zoom_k
	view.view_top = -at.y / zoom_k
	# (round 10, QA ENV-1) the start card's frame: no bandit cut by the right edge of the safe area
	view.start_hold = _ready_to_start
	view.safe_right = (_clip.size.x - Device.insets().z - _stage.position.x) / _stage.scale.x


## (gameplay) The rules' say over the camera, after its framing: it holds still while he drops into
## a pit he can't get out of (World.falling_to_death(): he is seen falling in, not scrolled away);
## caught or dropping into a pit, it brings him in from the edge of the screen for his last beat
## (DEATH_FRAME); then it keeps what must be seen on screen (_keep_fair). Takes and returns [zoom, at].
func _gameplay_camera(zoom: float, at: Vector2) -> Array:
	if _pit_scroll < 0.0 and world.falling_to_death():
		_pit_scroll = world.draw_scroll()
		_pit_seen = world.state == World.State.RUNNING  # (known only once he was gone: no framing)
	var u := 0.0  # how far his last beat's framing has come
	if _pit_scroll >= 0.0:
		at.x += (world.draw_scroll() - _pit_scroll) * zoom
		_pit_time += _dt
		u = smoothstep(0.0, DEATH_FRAME_TIME, _pit_time) if _pit_seen else 0.0
	if world.state == World.State.DEAD and world.death_reason == &"bandit":
		u = smoothstep(0.0, DEATH_FRAME_TIME, world.end_time)
		at.y += (_clip.size.y - (at.y + World.VIEW_H * zoom)) * u  # as high as the ground allows
	if u > 0.0:
		at.x += (_clip.size.x * DEATH_FRAME - (at.x + world.draw_hero().x * zoom)) * u
	return _keep_fair(zoom, at)


## New (gameplay, the camera's limits): whatever the framing, what the player must see stays on
## screen: World.camera_must_see() inside the safe area and under the HUD band, the camera zooming
## out and sliding only as much as that needs (and never baring the bottom of the world). So a close
## camera never shows a bandit later than the 2017 screen did, nor hides the vine he can catch or
## the ground he will land on. Takes and returns the stage's zoom and position ([zoom, at]).
func _keep_fair(zoom: float, at: Vector2) -> Array:
	var need := world.camera_must_see()
	if _need.size != Vector2.ZERO:  # eased: quickly where more must be seen, gently where less (no snap)
		var dt := _dt
		var grow := 1.0 - exp(-dt * NEED_GROW)
		var shrink := 1.0 - exp(-dt * NEED_EASE)
		var lo := Vector2(lerpf(_need.position.x, need.position.x, grow if need.position.x < _need.position.x else shrink),
				lerpf(_need.position.y, need.position.y, grow if need.position.y < _need.position.y else shrink))
		var hi := Vector2(lerpf(_need.end.x, need.end.x, grow if need.end.x > _need.end.x else shrink),
				lerpf(_need.end.y, need.end.y, grow if need.end.y > _need.end.y else shrink))
		need = Rect2(lo, hi - lo)
	_need = need
	var insets := Device.insets()
	# (to the screen's right edge, not its safe margin: what comes in there is a bandit on the ground)
	var area := Rect2(insets.x, hud_band(), _clip.size.x - insets.x, _clip.size.y - hud_band())
	var fit := minf(area.size.x / need.size.x, area.size.y / need.size.y)
	if zoom > fit:  # zoomed out about the middle of what must be seen
		var c := at + need.get_center() * zoom
		zoom = fit
		at = c - need.get_center() * zoom
	var lo := area.position - need.position * zoom
	var hi := area.end - need.end * zoom
	at.x = clampf(at.x, lo.x, hi.x)
	at.y = clampf(at.y, maxf(lo.y, _clip.size.y - World.VIEW_H * zoom), hi.y)
	return [zoom, at]


## For the framing (env): the part of the screen that matters for play now (screen units): what
## World.camera_must_see() asks, where the camera puts it. Outside it, and outside the HUD, nothing
## the player needs is ever drawn: behind his back, above the vine, below the ground he can come
## down to, right of the play window's edge (960; bandits wait there on a wide screen: a bonus, not
## a need). Foreground framing (leaves, rocks, a vignette) may cover the rest of the screen.
func play_area_on_screen() -> Rect2:
	var zoom := _stage.scale.x
	return Rect2(_stage.position + _need.position * zoom, _need.size * zoom)


## The play window's part on screen now (play units): what the camera shows.
func visible_play_rect() -> Rect2:
	var zoom := _stage.scale.x
	var at := _stage.position
	return Rect2(-at / zoom, _clip.size / zoom)


## The screen units the HUD takes at the top: HUD_BAND under the screen's top safe inset (round 5,
## QA: on an iPad the inset put the vine and his hands under the progress plate).
static func hud_band() -> float:
	return HUD_BAND + Device.insets().y


## The camera's zoom on a screen showing `width` play units right of the play window's left edge
## (at zoom 1: the 640 units fill its height): closed in as far as still shows VIEW_AHEAD (at most
## ZOOM_MAX), or drawn back on a narrow screen (a 4:3 iPad) to show the whole 960 of the 2017 game.
static func base_zoom(width: float) -> float:
	return minf(maxf(width / VIEW_AHEAD, minf(1.0, width / World.VIEW_W)), ZOOM_MAX)


## The closest the camera may come (zoom), the bottom of the level on the bottom of the screen: his
## head HEAD_ROOM under the top of the screen (in a jump, the top of the jump, from take-off), and
## the vine under the HUD while he hangs from it, rises to it, or stands where a jump reaches it.
static func follow_zoom(w: World, p: Vector2) -> float:
	var vine := (World.VIEW_H - hud_band() - VINE_GAP) / (World.VIEW_H - VINE_TOP)
	if w.state == World.State.RUNNING and (w.hanging or w.rising_to_vine()):
		return vine  # (the rules hold him at y 0 up there: he is drawn hanging under the vine)
	var z := (World.VIEW_H - HEAD_ROOM) / maxf(World.VIEW_H - (p.y - HEAD), 1.0)
	if w.state == World.State.RUNNING and not w.on_ground and w.vy < 0.0:
		z = minf(z, (World.VIEW_H - APEX_ROOM) / maxf(World.VIEW_H - (_jump_top(p.y, w.vy) - HEAD), 1.0))
	return minf(z, vine) if w.state == World.State.RUNNING and _vine_in_reach(w) else z


## The highest centre y a jump going up at `vy` (units a tick) from `y` reaches (the 40 Hz rules).
static func _jump_top(y: float, vy: float) -> float:
	while vy < 0.0:
		y += vy
		vy += World.GRAVITY
	return y


## The lowest grass top or pool surface within `reach` units ahead of him (play y), at least his feet
## (World._ground_ahead()'s look, further).
static func _lowest_ahead(w: World, reach: float) -> float:
	var feet := w.y + World.HERO_SIZE.y / 2
	var lowest := feet
	var c0 := floori((w.scroll + w.x - World.HERO_SIZE.x / 2) / Level.TILE)
	var c1 := floori((w.scroll + w.x + reach) / Level.TILE)
	for c in range(maxi(c0, 0), mini(c1, Level.COLS - 1) + 1):
		for r in range(clampi(floori((feet - 1.0) / Level.TILE), 0, Level.ROWS - 1), Level.ROWS):
			var k := w.level.kind_at(c, r)
			if k == Level.Kind.TOP or k == Level.Kind.WATER:
				lowest = maxf(lowest, r * Level.TILE)
				break
	return minf(lowest, World.VIEW_H - 24.0)


## Standing where a jump takes him to the top of the screen (the vine), under open sky.
static func _vine_in_reach(w: World) -> bool:
	return w.on_ground and not w.climbing and _jump_top(w.ground_y, -World.JUMP_SPEED) <= 0.0 \
			and w.ceiling_above(w.x, w.ground_y - World.HERO_SIZE.y / 2, w.scroll) < 0.0


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


## Gives the world a move read from the fingers (TouchReader). Not while he drops into a pit he
## can't get out of: nothing changes it, the drop plays out.
func _move(action: StringName) -> void:
	if world.falling_to_death():
		return
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
## back). Neither with reduced motion or the screen shake off (Prefs.shake).
func _jolt(trauma: float, kick := Vector2.ZERO) -> void:
	if Prefs.shake() <= 0.0:
		return
	_trauma = minf(_trauma + trauma, 1.0)
	_kick += kick


## An impact (Fx.IMPACTS: small, medium, fatal): its hit-stop (3-5 frames) and its shake (about
## 4-8 px on a phone, gone in 8-12 frames) and kick (neither with reduced motion or the shake off). Its light is
## drawn where it lands (Fx.ring_hit, Fx.knock_out, Fx.impact), its knock by Feel (Fx.knock).
func _impact(kind: StringName, kick := Vector2.ZERO) -> void:
	var preset: Dictionary = Fx.IMPACTS[kind]
	_freeze = maxf(_freeze, preset.stop)
	if Prefs.shake() > 0.0:
		_trauma = maxf(_trauma, sqrt(preset.shake / SHAKE))
		_kick += kick


## A ring thrown: its whoosh, its light in flight (following RingView, which launches it from his
## hand with its own flash), a small recoil.
func _on_thrown(r: World.Ring) -> void:
	Audio.play_sfx(&"throw")
	Fx.ring_flight(view.fx, world, r)
	_jolt(0.0, Vector2(-1.5, 0.0))


## A Red Bob: its chime climbs the A major scale (a take per step: sfx_bob_1..8) while they come
## quickly one after another, and its light grows with the streak (_on_bob_popped).
func _on_bob(_c: int, _r: int) -> void:
	_combo = _streak()
	_last_bob = _clock
	Audio.play_tuned(&"bob", _combo)
	Haptics.pickup()
	_bob_serial += 1
	var t := create_tween()  # a streak of 3 or more that ends: its chord
	t.tween_interval(COMBO_WINDOW + 0.02)
	t.tween_callback(_streak_end.bind(_bob_serial, _combo + 1))


## The streak a Red Bob taken now belongs to (0: the first of a run).
func _streak() -> int:
	return _combo + 1 if _clock - _last_bob < COMBO_WINDOW else 0


## No Red Bob since the one numbered `serial`: a run of 3 or more ends on a chord.
func _streak_end(serial: int, length: int) -> void:
	if serial == _bob_serial and length >= 3:
		Audio.play_sfx(&"streak")


var _bob_serial := 0  # Red Bobs taken (the streak's chord waits for the last of a run)



## The Red Bob flies from where it was (WorldView units) to the counter.
func _on_bob_popped(at: Vector2) -> void:
	var from := _stage.get_global_transform() * at
	# counted as it is taken (the HUD reads world.bobs): the flier is the show, landing with a pop
	Fx.bob_flight(_fliers, from, hud.bob_target(), BobView.SIZE * _stage.scale.x, hud.BOB_ICON, hud.bob_arrived)
	var streak := _streak()  # (this runs before _on_bob counts it)
	Fx.bob_pop(view.fx, at * 2.0, streak)
	if streak >= 1:  # "×2", "×3"... at the pickup, beside him, where the eye is
		Fx.streak_pop(view.fx, at * 2.0, streak + 1)


## A ring on a bandit: the small impact (3 frames held, a light shake, the bandit knocked back the
## way the ring flew and springing back); a knock-out is the medium one (it tumbles away: BanditView).
func _on_bandit_hit(b: World.Bandit, knocked_out: bool) -> void:
	Audio.play_sfx(&"knock_out" if knocked_out else &"ring_hit")
	if knocked_out:
		Haptics.knock()
		_impact(&"medium", Vector2(7.0, -2.0))
		# (over its head, clear of its face and of the blow: the judges, "the +1 sits on the enemy's face"; blind round 11:
		# "+1 is stamped over the enemy's head": higher, and on his side of it: it is thrown back the other way)
		Fx.plus_one(view.fx, Vector2(b.x - world.scroll - 64.0, b.y - (168.0 if b.strong else 136.0)) * 2.0)
	else:
		Haptics.select()
		_impact(&"small", Vector2(3.0, 0.0))
		Fx.knock(b, Vector2(Fx.IMPACTS[&"small"].knock, -4.0), 0.35)


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


## A blow: the medium impact, Panoramic knocked back and up (springing back to his place), the
## heart cracking; down to the last one, a heartbeat warning. The last blow is the fatal impact
## (its sound in _on_died; the death animation knocks him down).
func _on_hurt(_b: World.Bandit, lives: int) -> void:
	Audio.play_sfx(&"heart_break")
	if lives > 0:
		Audio.play_sfx(&"hurt")
		Haptics.hurt()
		_impact(&"medium", Vector2(-6.0, 0.0))
		Fx.knock(&"hero", Vector2(-Fx.IMPACTS[&"medium"].knock, -12.0), 0.45)
		if lives == 1:
			_last_heart_warning()
	else:
		# (the user, 2026-11-08: "when the hero dies it shakes: remove it") the last blow holds the beat, no shake or kick
		_freeze = maxf(_freeze, Fx.IMPACTS[&"fatal"].stop)
	_red_flash(0.25 if Fx.calm() else 0.5)


## Down to the last heart: a heartbeat, once the blow has passed.
func _last_heart_warning() -> void:
	var t := create_tween()
	t.tween_interval(0.45)
	t.tween_callback(Audio.play_sfx.bind(&"last_heart"))


## His head hit a ceiling: a bonk, a little dirt falling from it, the camera nudged up.
func _on_bumped() -> void:
	Audio.play_sfx(&"bump")
	var head := world.draw_hero() - Vector2(0.0, World.HERO_SIZE.y / 2.0)
	Fx.dust(view.fx, head * 2.0, 6, 140.0, 0.0, 0.7)
	_jolt(0.0, Vector2(0.0, -3.0))


## A fall that cost a life: the heart goes, the world holds a beat, then he springs back up.
func _on_fell(lives: int) -> void:
	Audio.play_sfx(&"fell")
	Audio.play_sfx(&"heart_break")
	if lives == 1:
		_last_heart_warning()
	Haptics.fall()
	_freeze = FALL_BEAT
	_red_flash(0.4)


## The edges of the screen glow red for 2-3 frames (Fx.edge_texture: never a wash over the picture,
## so the blow itself reads).
func _red_flash(alpha: float) -> void:
	_flash.modulate.a = alpha
	var t := create_tween()
	t.tween_interval(0.017)
	t.tween_property(_flash, "modulate:a", 0.0, 0.05)


## The end of a run: its sound, the music muffled (the stinger takes over with the results).
func _on_died(reason: StringName) -> void:
	Audio.play_sfx(&"fall" if reason == &"fall" else &"death")
	Audio.set_mood(&"paused")
	if reason == &"fall":
		Haptics.fall()
	else:
		Haptics.death()
	_end_run(World.FALL_DEATH_TIME if reason == &"fall" else World.DYING_TIME)


## Home: over the threshold (a whoosh and a warm swell), the win stinger (its drum roll lands on
## his hop, 0.45 s), the doorway's light swelling with embers, then the burst of light from the
## doorway itself, a success buzz.
func _on_won() -> void:
	Audio.play_sfx(&"door")
	Audio.stinger(&"win")
	hud.leave()  # the picture is his arrival
	var door := Vector2(HomeView.DOOR_RIGHT - 40.0, HomeView.GROUND - 70.0) * 2.0  # its middle (effects units)
	Fx.home_glow(view.fx, door + Vector2(0.0, 40.0))
	_end_run(World.HOME_TIME)
	await get_tree().create_timer(0.45).timeout  # he lands his hop: light from the doorway
	if is_inside_tree():
		Fx.rescue_burst(view.fx, door)
		Haptics.success()


## The run is over: saved at once (the app may be closed during the ending), the panel after
## `wait` seconds of the ending (World.end_time: hit-stops don't count), or at a tap (skip_ending).
func _end_run(wait: float) -> void:
	_ended = true
	if is_instance_valid(_start_card):  # New: a run that ends before its first touch (tests)
		_start_card.queue_free()
		_start_card = null
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
	_overlay = PausePanel.open(self, resume_game, _go_home, [hud, _fliers, view.fx, _tutorial, _start_card])  # New: a clean picture behind
	_overlay.z_index = OVERLAY_Z
	(_overlay as GamePanel).hide_when_covered([_clip, _below])  # New (UX): the world is not drawn under its picture


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
		if o is GamePanel:  # New (UX): the world back under it before it fades
			(o as GamePanel).uncover()
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
	# New (UX): drawn at a size the font has cached already (64, "Tap to start") and scaled up, so
	# no new 96 px glyph atlas is made (about 8 MB of texture)
	var label := Ui.display_text(str(n), 64, Ui.WHITE, Ui.NIGHT, Ui.BRAND_LIGHT)
	label.depth = 4.0
	label.refresh()
	add_child(label)
	label.z_index = OVERLAY_Z
	label.size = label.get_combined_minimum_size()
	label.position = get_viewport_rect().size / 2 - label.size / 2
	label.pivot_offset = label.size / 2
	var k := 1.5
	label.scale = Vector2.ONE * 0.5 * k
	var t := label.create_tween()
	t.tween_property(label, "scale", Vector2.ONE * 1.1 * k, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "scale", Vector2.ONE * k, 0.08)
	t.tween_interval(RESUME_STEP - 0.4)
	t.tween_property(label, "modulate:a", 0.0, 0.18)
	t.parallel().tween_property(label, "scale", Vector2.ONE * 0.8 * k, 0.18)
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
			func() -> void: Services.share.share_run(world.bobs, world.stars()), [hud, _fliers, view.fx, _tutorial, _start_card])
	_overlay.z_index = OVERLAY_Z
	(_overlay as GamePanel).hide_when_covered([_clip, _below])  # New (UX): the world is not drawn under its picture
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

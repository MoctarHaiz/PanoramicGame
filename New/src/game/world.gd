class_name World
extends RefCounted
## The rules of the 2017 game, without any drawing: Panoramic, the scrolling level, bandits, rings
## and Red Bobs. Views read it; input calls jump(), down(), step_forward() and throw().
##
## The level was tuned on the old game's fixed 40 updates a second: walls up to exactly 10 tiles
## can be climbed and the top of the screen can only be reached from some ledges. So the rules run
## that same 40 Hz step (advance() takes real time and runs whole ticks); views interpolate between
## ticks with `alpha`, so the picture is smooth at 60, 90 or 120 Hz.
##
## Units: the 960 x 640 design (30 x 20 tiles). The old code moved things by raw screen pixels per
## tick, so its speed changed with the phone. These values are its pixels converted at the phone
## the level was made on (the 2019 screenshots: a 1320 x 720 play area, so x / 1.375, y / 1.125).
## Positions of Panoramic and the rings are in the play window (0..960, 0..640); bandits and tiles
## use level coordinates; `scroll` is the level x at the window's left edge.

signal jumped
signal landed
signal hung
signal let_go
signal crouched
signal stepped
signal thrown(ring: Ring)
signal bandit_hit(bandit: Bandit, knocked_out: bool)
signal bob_collected(col: int, row: int)
signal hurt(bandit: Bandit, lives_left: int)
signal fell(lives_left: int)  ## a fall that cost a life (not the last): he springs back up next
signal sprang  ## out of the pit, back up towards the vine
signal splashed(level_x: float, hero: bool)  ## Panoramic or a bandit dropped into a pool
signal bumped  ## New: his head hit a ceiling on the way up (he drops back)
signal died(reason: StringName)
signal won

const TICK := 1.0 / 40.0
const MAX_TICKS_PER_ADVANCE := 6  ## a long hitch doesn't run the game ahead in a burst
const KX := 960.0 / 1320.0
const KY := 640.0 / 720.0

const TILE := Level.TILE
const VIEW_W := 960.0  ## the play window the rules use (wider phones show more, nothing else)
const VIEW_H := 640.0

const SCROLL_SPEED := 8.0 * KX  ## old: tiles 8 px/tick (233 u/s)
const BACKGROUND_FACTOR := 0.25  ## old: background 2 px/tick against the tiles' 8
const GRAVITY := 3.0 * KY  ## old: speedY += 3 per tick (4,267 u/s²)
const JUMP_SPEED := 720.0 / 20.0 * KY  ## old: VITESSESAUT = -WINDOW_HEIGHT / 20 (32 u/tick, 6.5 tiles high)
const STEP := 15.0 * KX  ## old: VITESSEMOUVEMENT = 15 px per swipe right
const MIN_X := 61.0 * KX  ## old: never left of x = 61 px
## New: the old game let swipes walk him off the right of the screen (and out of the map). He now
## stops at the middle of the play window, except on the run home.
const MAX_X := VIEW_W / 2
const HERO_SIZE := Vector2(64, 128)  ## old: RECT_PANORAMIC = 960 / 7.5 / 2 by 640 / 2.5 / 2
const HERO_START := Vector2(150.0 * KX, 100.0 * KY)  ## old: centerX = 150, centerY = 100
const LIVES := 3  ## old: lifePan3 -> lifePan2 -> lifePan1 -> game over
const COVER_TICKS := 10  ## old: the brown cover shows 10 updates after a Red Bob
## New: a swipe up made just before landing (the old game dropped it) jumps on landing.
const JUMP_BUFFER := 6  ## ticks (0.15 s)
## New: after a hit, a second in which bandits can't take another life (he flickers meanwhile).
const MERCY_TICKS := 40
## New: the old rules lifted him onto a ledge the tick his body touched its grass, up to 5 tiles at
## once (a teleport on screen). He now climbs it over a few ticks; the same ledges are in reach.
const CLIMB_SNAP := 20.0  ## units: a smaller lift (or one no bigger than his fall this tick) is a landing
const CLIMB_SPEED := 36.0  ## units per tick at most; slower near the top
## New, behind a switch (falls_cost_life, config/game_config.cfg [rules]; off: the 2017 rule): a
## fall cost the whole run, hearts or not. With it on, it costs a life: he springs back up out of the
## pit to the vine (safe while he rises and for a second after) and lets go over ground.
const FALL_MERCY := 40  ## ticks of mercy after he is back on the vine
const SPRING_X := 230.0  ## he springs back at least this far in (not under the hearts in the corner)
## Hanging, the rules keep him at y 0 (half above the screen, as in 2017) but he is drawn hanging
## under the vine from his staff, his centre this far down (HeroView's hanging pose).
const VINE_DRAW_Y := 92.0
## New: he lets go from there, where he is seen (the old game dropped him from y 1, so the picture
## jumped up half his height before he fell). He lands about 2 ticks sooner. He throws from there
## too (the old rings flew along the top edge, through the HUD, and could hit nothing).
const LET_GO_Y := VINE_DRAW_Y
const VINE_EASE := 200.0  ## units: the end of a rise to the vine is drawn easing into the hang

const BANDIT_SIZE := Vector2(48.0 * KX, 96.0 * KY)  ## old: bandit image 48 x 96 px, not scaled
const BANDIT_COUNT := 50  ## old: nbEnnemies, one every LEVEL_WIDTH / 50
## New: none starts on the first screen (the first one hit 0.7 s after "Tap to start").
const FIRST_BANDIT_X := VIEW_W
const BANDIT_START_Y := VIEW_H - TILE * 3  ## old: WINDOW_HEIGHT - 3 tiles
const BANDIT_RUN := 10.0 * KX  ## old: vitesseDeMouvement = 10 px/tick against the ground (291 u/s)
const BANDIT_GRAVITY := 4.0 * KY  ## old: EnemyPesanteur = 4
const BANDIT_HOP := 10.0 * KY  ## old: EnemyJumpSpeed = -10 when a wall stops them
const BANDIT_HEALTH := 2  ## old: sante = 2, one ring takes one
## New (the user, 2026-11-07): two kinds of bandit, and bandits that jump. About 3 in 10 are strong (their leader,
## drawn bigger: is_strong()), and take STRONG_HEALTH rings. Jumpers (every strong one, and one in three of the
## others) see a ring coming and leap over it, DODGES times each: the player throws again, or as it lands.
const STRONG_HEALTH := 3
const BANDIT_JUMP := 28.0 * KY  ## a jumper's leap: its feet rise ~87 units, over a ring thrown from his middle
const DODGES := 1
const DODGE_LOOK := 14  ## ticks ahead a jumper on the ground looks for a ring that would hit it
## New: the bandits and Panoramic are drawn a quarter larger than their 2017 boxes, the club held
## out in front: a bandit that only hurt with its old box was seen running into him for 0.13 s
## before the blow. It now hurts with its club's reach in front of it (to its left, the way it
## runs), on first contact with his drawn body; its body (walls, ground, rings) keeps the old box.
const CLUB_REACH := 56.0

const RING_SPEED := 20.0 * KX  ## old: Projectile speedX = 20 px/tick (582 u/s)
const RING_OFFSET := 40.0 * KX  ## old: thrown from centerX + 40
const RING_HIT_SIZE := Vector2(34.0 * KX, 50.0 * KY)  ## old: r.set(x, y, x + 34, y + 50)
const RING_WALL_SIZE := 64.0 / 5.0  ## old: RECT_FIRE = hero width / 5
const SIDE_SHRINK := 10.0 * KX  ## old: wall tiles are tested 10 px smaller on the right and bottom

const SURFACE_Y := (Level.ROWS - 2) * TILE + 6.0  ## the water line of the pools (play y)

const SCROLL_END := Level.WIDTH - VIEW_W  ## old: the screen stops when the last screen is in view
const HOME_X := 790.0  ## Panoramic is home when his centre passes this x of the last screen
## New: the screen stopped dead at the last screen, and he then sprinted to the hut (a swipe step,
## 11 units, every tick) and stopped dead in the doorway. Now the screen slows to a stop over its
## last END_EASE units while he keeps his pace, he runs across at HOME_PACE and slows into the
## doorway to the pace HeroView walks him in at.
const END_EASE := 60.0  ## units of scroll
const HOME_PACE := 9.0  ## units a tick
const HOME_DOOR_PACE := 4.0  ## units a tick in the doorway
## New: this close to the doorway he only goes in: swipes and taps are ignored (they made him hop
## and throw rings at the hut as he arrived; the last bandit is long past by then).
const HOME_REACH := 160.0
const HOME_DOOR_X := HOME_X + 34.0  ## for views: the middle of the doorway he walks into (play x)

## The end of a run, in seconds of `end_time` (the game screen waits this long before its panel;
## views time the hero's last moves on it). Caught: he falls to the ground (the death animation)
## and lies there. Into a pit: shorter, he is gone. Home: he lands at the door (HOME_LAND), the
## victory beat (to HOME_CHEER), then he walks in (to HOME_TIME). From SKIP_AFTER a fresh tap skips to
## the panel: not sooner, a player tapping to throw when it happened would skip his last beat.
const DYING_TIME := 2.0
const FALL_DEATH_TIME := 0.7
const HOME_LAND := 0.25
const HOME_CHEER := 1.3
const HOME_TIME := 2.1
const SKIP_AFTER := 1.2

## What he is doing, for the views' animations (move_phase()): idle before the start, run, land
## (LAND_TICKS after touching down), takeoff (TAKEOFF_TICKS after leaving the ground in a jump),
## rise, apex (|vy| under APEX_VY), fall, climb, hang, crouch, then dead or home.
const LAND_TICKS := 4  ## 0.1 s
const TAKEOFF_TICKS := 2  ## 0.05 s
const APEX_VY := 6.0  ## units a tick: about 0.11 s around the top of a jump
const JUMP_RISE := 208.0  ## units a jump rises (the old integration: 32 + 29.3 + ... 6.5 tiles)

## For views: a bandit's blow is drawn back over its last STRIKE_TICKS before its club reaches him
## (strike()), so it can be seen coming; the rules still land it on first contact, as in 2017.
const STRIKE_TICKS := 6  ## 0.15 s
## For the camera (camera_must_see()): what the 2017 screen always showed must stay on screen.
const SEE_BEHIND := 72.0  ## units behind his centre (his back, his scarf)
const SEE_AHEAD_DOWN := 320.0  ## units ahead in which the grass or water he could drop to is shown
const SEE_ABOVE := 24.0  ## units over his head
const VINE_SEEN := -12.0  ## play y shown when the vine matters (it hangs at 0..8)

## Red Bobs that can't be taken alive (tests/probes.gd --probe=bobs, falls_cost_life off): over the
## river after the pillars a drop is fatal; over the island's left end getting off again takes 8
## swipes right in one jump. For views: drawn as out of reach (is_risky_bob()). Positions kept.
const RISKY_BOBS: Array[Vector2i] = [
	Vector2i(201, 17), Vector2i(202, 16), Vector2i(202, 17), Vector2i(203, 16),
	Vector2i(596, 12), Vector2i(597, 12), Vector2i(607, 12), Vector2i(608, 12), Vector2i(609, 12),
	Vector2i(610, 12), Vector2i(611, 12), Vector2i(612, 12), Vector2i(613, 12), Vector2i(614, 12),
	Vector2i(619, 12), Vector2i(621, 12), Vector2i(622, 12), Vector2i(624, 12), Vector2i(625, 12),
	Vector2i(628, 12),
]

enum State { RUNNING, DEAD, WON }


class Bandit:
	var x := 0.0  ## level x of the centre
	var y := 0.0
	var prev_x := 0.0
	var prev_y := 0.0
	var vy := 0.0
	var health := BANDIT_HEALTH
	var strong := false  ## New: the strong kind (STRONG_HEALTH rings)
	var jumper := false  ## New: leaps over a ring coming at it (dodges times)
	var dodges := 0
	var leap := false  ## New: leaps on its next move
	var hurt := false  ## hit once: drawn hurt
	var touched_hero := false  ## each bandit can take only one life
	var gone := false
	var active := false  ## has entered the play window (runs from then on)
	var id := 0
	## For views: where to draw it while it waits for the play window (see World._place_bandits).
	var wait_x := 0.0
	var wait_y := 0.0

	func copy() -> Bandit:
		var b := Bandit.new()
		b.x = x; b.y = y; b.prev_x = prev_x; b.prev_y = prev_y; b.vy = vy; b.health = health; b.hurt = hurt
		b.strong = strong; b.jumper = jumper; b.dodges = dodges; b.leap = leap
		b.touched_hero = touched_hero; b.gone = gone; b.active = active; b.id = id
		b.wait_x = wait_x; b.wait_y = wait_y
		return b


class Ring:
	var x := 0.0  ## play-window x of the top left of its hit box
	var y := 0.0
	var prev_x := 0.0
	var id := 0

	func copy() -> Ring:
		var r := Ring.new()
		r.x = x; r.y = y; r.prev_x = prev_x; r.id = id
		return r


var level: Level
var state := State.RUNNING
var ticks := 0
var scroll := 0.0
var blocked := false  ## a wall is holding Panoramic: the level doesn't move
var at_end := false  ## the last screen is in view: Panoramic runs home

# Panoramic
var x := HERO_START.x
var y := HERO_START.y
var vy := 0.0
var jumping := false  ## old Saute: set by a jump, cleared by landing (a fall can still jump once)
var crouching := false
var hanging := false
## Standing on a grass top. The old rules snap him onto the grass, then gravity pulls him 2.7 units
## into it the next tick before the next snap, so the raw contact flickers every other tick: count
## him grounded when the grass held him this tick or the one before.
var on_ground := false
var ground_y := 0.0  ## y he stands at when grounded (draw there, not in the flicker)
var lives := LIVES
var cover := 0  ## ticks left of the Red Bob glow
var mercy := 0  ## ticks left in which bandits can't hurt him
var climbing := false  ## pulling himself up onto a ledge (see CLIMB_SNAP)
var land_speed := 0.0  ## units per tick he was falling at when he last landed (for sound and shake)
var falls := 0  ## lives lost to falls
var falls_cost_life := false  ## the switch above (GameScreen sets it from the config)
var bobs := 0
var knocked_out := 0
var death_reason := &""
## Seconds since the run ended (died or won), for views and the game screen (see DYING_TIME).
var end_time := 0.0
## For views: the last blow, as views should knock him back (the rules don't move him): its
## direction (unit, from the bandit to him, mostly back and a little up) and 0..1 its strength
## (0.6 a blow, 1 the last one).
var hit_dir := Vector2.ZERO
var hit_strength := 0.0
## For views: where he was when the run ended (play units; his centre), and the scroll then.
var end_at := Vector2.ZERO

var bandits: Array[Bandit] = []
var rings: Array[Ring] = []

## Previous tick, for drawing between ticks.
var prev_x := x
var prev_y := y
var prev_scroll := 0.0
var alpha := 0.0  ## 0..1: how far real time is past the last tick
var _time := 0.0
var _actions: Array[StringName] = []
var _next_id := 0
var _air_ticks := 99
var _jump_buffer := 0  # ticks left of a jump asked for in the air
var _climb_to := 0.0  # the y he is climbing up to
var _home_pace := SCROLL_SPEED  # units a tick on the run home
var _since_land := 0  # ticks since he last touched down
var _phase := &"idle"  # move_phase() at the last tick, and the tick it began
var _phase_tick := 0
var _jump_tick := -99  # the tick of the last jump
var _land_tick := -1  # ticks_to_land(), worked out at this tick
var _land_in := -1
var _land_y := 0.0  # where the last look-ahead's landing stands him (his centre y)
var _doom_tick := -1  # falling_to_death(), worked out at this tick
var _doomed := false


func _init(map: Level = null, with_bandits := true) -> void:
	level = map if map else Level.load_default()
	if not with_bandits:  # (a clone copies them)
		return
	for i in range(1, BANDIT_COUNT + 1):
		if i * Level.WIDTH / BANDIT_COUNT < FIRST_BANDIT_X:
			continue
		var b := Bandit.new()
		b.x = i * Level.WIDTH / BANDIT_COUNT
		b.y = BANDIT_START_Y
		b.prev_x = b.x
		b.prev_y = b.y
		b.id = i
		b.strong = is_strong(i)
		b.jumper = b.strong or posmod(i, 3) == 0
		b.dodges = DODGES if b.jumper else 0
		b.health = STRONG_HEALTH if b.strong else BANDIT_HEALTH
		bandits.append(b)
	_place_bandits()


## New: whether the bandit with this id is of the strong kind: about 3 in 10, scattered along the level.
static func is_strong(id: int) -> bool:
	return posmod(id * 7 + 3, 10) < 3


## New: the old rules placed every bandit 3 tiles above the bottom of the screen and sorted it out
## on its first tick in the play window: shoved out of a wall it stood in, onto its grass, or down
## into a pool. On a phone wider than the play window that happened in plain view: 18 of the 49
## appeared at the window's edge only to drop into the river. Those aren't placed now. The others
## run exactly as in 2017; `wait_x`, `wait_y` say where views draw one still waiting (where its first
## tick will put it: out of the rock, on the grass).
func _place_bandits() -> void:
	var at := scroll
	for b in bandits:
		scroll = b.x - VIEW_W  # (the moment it comes into the window)
		var trial := b.copy()
		var lands := false
		var placed := false
		for t in 24:
			if not _move_bandit(trial):
				break
			var box := bandit_rect(trial)
			box.position.x += BANDIT_RUN  # (before its step left)
			if not placed and _find(box, Level.Kind.SIDE, SIDE_SHRINK).x < 0:
				placed = true
				b.wait_x = trial.x + BANDIT_RUN
				b.wait_y = trial.y
				var c := floori(b.wait_x / TILE)
				for r in range(maxi(floori((trial.y + BANDIT_SIZE.y / 2 - 8.0) / TILE), 0), Level.ROWS):
					if level.kind_at(c, r) == Level.Kind.TOP:
						b.wait_y = r * TILE - BANDIT_SIZE.y / 2
						break
			if _find(bandit_rect(trial), Level.Kind.TOP).x >= 0:
				lands = true
				if placed:
					break
		b.gone = not lands
	scroll = at


# ------------------------------------------------------------------ input (applied next tick)

func jump() -> void:
	_ask(&"jump")


## Swipe down: let go of the top of the screen, or crouch.
func down() -> void:
	_ask(&"down")


func step_forward() -> void:
	_ask(&"right")


func throw() -> void:
	_ask(&"throw")


## New: the same move asked twice before a tick (two fingers swiping together, a swipe and a key)
## is one move: two jumps used to leave a jump buffered for the next landing.
func _ask(action: StringName) -> void:
	if action not in _actions:
		_actions.append(action)


# ------------------------------------------------------------------ time

## Runs as many 40 Hz ticks as real time allows. Returns the number of ticks run.
## `before_tick` (optional) is called before each tick: a bot gives its input there.
func advance(delta: float, before_tick := Callable()) -> int:
	if state != State.RUNNING:
		end_time += delta
	_time += minf(delta, TICK * MAX_TICKS_PER_ADVANCE)
	var n := 0
	while _time >= TICK:
		_time -= TICK
		if before_tick.is_valid() and state == State.RUNNING:
			before_tick.call(self)
		tick()
		n += 1
	alpha = _time / TICK
	return n


func tick() -> void:
	if state != State.RUNNING:
		return
	prev_x = x
	prev_y = y
	prev_scroll = scroll
	for b in bandits:
		b.prev_x = b.x
		b.prev_y = b.y
	for r in rings:
		r.prev_x = r.x
	ticks += 1
	_apply_actions()
	_update_rings()
	_update_hero()
	if state != State.RUNNING:
		return
	if cover > 0:
		cover -= 1
	if mercy > 0:
		mercy -= 1
	_update_bandits()
	if state != State.RUNNING:
		return
	_collide_hero()
	_since_land += 1
	var phase := _current_phase()
	if phase != _phase:
		_phase = phase
		_phase_tick = ticks


func _apply_actions() -> void:
	if at_end and x >= HOME_X - HOME_REACH:
		_actions.clear()
		_jump_buffer = 0
		return
	if _jump_buffer > 0 and not climbing:
		_jump_buffer -= 1
		if not jumping and not hanging:
			_jump_buffer = 0
			_jump()
	for a in _actions:
		match a:
			&"jump":
				if hanging:
					pass  # already as high as he goes: nothing to do (the old game played a jump)
				elif climbing:  # New: kept for the top of the ledge (the climb used it up, unseen)
					_jump_buffer = JUMP_BUFFER
				elif not jumping:  # old sauter(): one jump until the next landing
					_jump()
				else:
					_jump_buffer = JUMP_BUFFER
			&"down":
				if hanging:  # old: setCenterY(centerY + 1), then gravity takes him
					_let_go()
				elif on_ground and not crouching:  # new: not in the air (he landed kneeling, stuck)
					crouching = true
					crouched.emit()
			&"right":
				crouching = false
				_move_right()
				stepped.emit()
			&"throw":
				var r := Ring.new()
				r.x = x + RING_OFFSET
				r.prev_x = r.x - RING_SPEED
				r.y = VINE_DRAW_Y if hanging else y  # new: hanging, from his hand under the vine
				r.id = _new_id()
				rings.append(r)
				thrown.emit(r)
	_actions.clear()


func _jump() -> void:
	vy = -JUMP_SPEED
	jumping = true
	crouching = false
	on_ground = false
	_jump_tick = ticks
	jumped.emit()


func _let_go() -> void:
	hanging = false
	y = LET_GO_Y
	prev_y = y
	let_go.emit()


## Across the last screen to the hut: up to HOME_PACE, slowing into the doorway.
func _run_home() -> void:
	crouching = false  # New: a swipe down on the last screen left him kneeling there for good
	_home_pace = minf(minf(_home_pace + 0.4, HOME_PACE), HOME_DOOR_PACE + (HOME_X - x) * 0.06)
	x = minf(x + maxf(_home_pace, HOME_DOOR_PACE), HOME_X + 1.0)


func _move_right() -> void:
	if not crouching:
		var was := x
		# On the run home he stops at the doorway, so a jump can't carry him past the hut.
		x = minf(x + STEP, HOME_X + 1.0) if at_end else minf(x + STEP, maxf(MAX_X, x))
		# New: not into a wall (the old game let a few swipes right walk him through one).
		if _find(chest_rect(), Level.Kind.SIDE, SIDE_SHRINK).x >= 0 or _find(feet_rect(), Level.Kind.SIDE, SIDE_SHRINK).x >= 0:
			x = was


func _update_rings() -> void:
	for r in rings.duplicate():
		r.x += RING_SPEED
		if r.x > VIEW_W:
			rings.erase(r)
			continue
		var box := Rect2(r.x, r.y, RING_HIT_SIZE.x, RING_HIT_SIZE.y)
		for b in bandits:
			if b.gone or not b.active or not _hits(box, bandit_rect(b)):
				continue
			rings.erase(r)
			b.hurt = true
			b.health -= 1
			if b.health <= 0:
				b.gone = true
				knocked_out += 1
			bandit_hit.emit(b, b.gone)
			break


func _update_hero() -> void:
	var feet := y + HERO_SIZE.y / 2
	if climbing:  # gathers speed from the jump's, then eases onto the top
		vy = -minf(minf(CLIMB_SPEED, absf(vy) + 10.0), maxf((y - _climb_to) * 0.6, 10.0))
		y = maxf(y + vy, _climb_to)
		if y <= _climb_to:
			_land(_climb_to)
			vy = GRAVITY  # settles into the grass next tick, like any landing
	elif y <= 0.0:
		if not hanging:
			hanging = true
			hung.emit()
		jumping = false
		y = 0.0
		vy = 0.0
	else:
		var head := y - HERO_SIZE.y / 2
		y += vy
		vy += GRAVITY
		var ceiling := ceiling_above(x, head, scroll) if vy < GRAVITY else -1.0
		if ceiling >= 0.0 and y - HERO_SIZE.y / 2 < ceiling:  # New: the 2017 rules let him rise through it
			y = ceiling + HERO_SIZE.y / 2
			vy = 0.0
			bumped.emit()
	x = maxf(x, MIN_X)
	if feet < SURFACE_Y and y + HERO_SIZE.y / 2 >= SURFACE_Y and water_at(scroll + x):
		splashed.emit(scroll + x, true)
	if chest_rect().position.y > VIEW_H:
		_fall()


## Out of the bottom of the screen: a life lost, then a spring back up to the vine (or the end).
func _fall() -> void:
	if not falls_cost_life:  # old: the run ends at once
		_die(&"fall")
		return
	lives -= 1
	falls += 1
	if lives <= 0:
		_die(&"fall")
		return
	fell.emit(lives)
	x = maxf(x, SPRING_X)
	prev_x = x
	# from below the screen, just fast enough to reach the top (position first, then speed: the
	# old integration rises v²/2g + v/2)
	y = VIEW_H + HERO_SIZE.y / 2
	vy = -(sqrt(GRAVITY * GRAVITY / 4.0 + 2.0 * GRAVITY * (y + 8.0)) - GRAVITY / 2.0)
	jumping = true
	crouching = false
	climbing = false
	_jump_buffer = 0
	mercy = ceili(-vy / GRAVITY) + FALL_MERCY
	sprang.emit()


## A pool's surface at level x?
func water_at(level_x: float) -> bool:
	return level.kind_at(int(level_x / TILE), Level.ROWS - 2) == Level.Kind.WATER


func _update_bandits() -> void:
	var hero_chest := chest_rect()
	var hero_feet := feet_rect()
	for b in bandits:
		if b.gone:
			continue
		var r := bandit_rect(b)
		if not b.active:
			if r.end.x > 0.0 and r.position.x < VIEW_W:
				b.active = true
			else:
				continue
		if b.dodges > 0 and _ring_coming(b):  # New: a jumper leaps over the ring (on this move)
			b.dodges -= 1
			b.leap = true
		if not _move_bandit(b):
			continue
		r = bandit_rect(b)
		var club := Rect2(r.position.x - CLUB_REACH, r.position.y, CLUB_REACH, r.size.y)
		if _find(club, Level.Kind.SIDE, SIDE_SHRINK).x < 0:  # (never through a wall)
			r = r.merge(club)
		# old isCollidingWith: the chest, or the feet when Panoramic is behind and below its centre
		var touches := _hits(r, hero_chest) or (_hits(r, hero_feet) and x >= b.x - scroll and y >= b.y)
		if touches and not b.touched_hero:
			b.touched_hero = true
			if mercy > 0:
				continue
			mercy = MERCY_TICKS
			lives -= 1
			hit_dir = Vector2(-1.0 if b.x - scroll > x else 1.0, -0.35).normalized()
			hit_strength = 1.0 if lives <= 0 else 0.6
			hurt.emit(b, lives)
			if lives <= 0:
				_die(&"bandit")
				return


## One tick of a bandit's run (old Enemy.update): onto the grass, off a wall with a hop, then left
## and down. False if it is gone (off the left of the screen or down a hole).
func _move_bandit(b: Bandit) -> bool:
	var r := bandit_rect(b)
	var top := _find(r, Level.Kind.TOP)
	if top.x >= 0:
		b.vy = 0.0
		b.y = top.y * TILE - BANDIT_SIZE.y / 2
	var wall := _find(r, Level.Kind.SIDE, SIDE_SHRINK)
	if wall.x >= 0:  # old: pushed back to the right of the wall, with a hop
		b.x = wall.x * TILE + TILE - SIDE_SHRINK + BANDIT_SIZE.x
		b.vy = -BANDIT_HOP
	if b.leap:  # New: a jumper's leap over a ring
		b.leap = false
		b.vy = -BANDIT_JUMP
	r = bandit_rect(b)
	if r.end.x < 0.0 or r.position.y > VIEW_H:
		b.gone = true
		return false
	var feet := b.y + BANDIT_SIZE.y / 2
	b.x -= BANDIT_RUN
	b.y += b.vy
	b.vy += BANDIT_GRAVITY
	if feet < SURFACE_Y and b.y + BANDIT_SIZE.y / 2 >= SURFACE_Y and water_at(b.x):
		splashed.emit(b.x, false)
	return true


## New: a jumper on the ground, with a ring coming that would hit it if it ran on, and that a leap now would clear.
func _ring_coming(b: Bandit) -> bool:
	if rings.is_empty():
		return false
	var top := _find(bandit_rect(b), Level.Kind.TOP)
	if top.x < 0:  # (in the air already)
		return false
	var ground := top.y * TILE - BANDIT_SIZE.y / 2
	return _ring_meets(b, ground, 0.0) and not _ring_meets(b, ground, -BANDIT_JUMP)


## Whether a ring flying now meets bandit `b` in the next DODGE_LOOK ticks, if it makes this tick's move from
## `ground` with vertical speed `vy0` (0: running on along the ground). In the rules' order: it moves now; each
## tick after, the rings move and hit, the scroll moves on (as it did this tick), then it moves.
func _ring_meets(b: Bandit, ground: float, vy0: float) -> bool:
	var ds := scroll - prev_scroll
	var sc := scroll
	var bx := b.x
	var by := ground
	var vy := vy0
	var xs: Array[float] = []
	for r in rings:
		xs.append(r.x)
	for k in DODGE_LOOK + 1:
		if k > 0:
			for i in rings.size():
				xs[i] += RING_SPEED
				var box := Rect2(bx - sc - BANDIT_SIZE.x / 2, by - BANDIT_SIZE.y / 2, BANDIT_SIZE.x, BANDIT_SIZE.y)
				if xs[i] <= VIEW_W and _hits(Rect2(xs[i], rings[i].y, RING_HIT_SIZE.x, RING_HIT_SIZE.y), box):
					return true
			sc += ds
		bx -= BANDIT_RUN
		if vy != 0.0 or by < ground:
			by += vy
			vy += BANDIT_GRAVITY
			if by >= ground:
				by = ground
				vy = 0.0
	return false


func _collide_hero() -> void:
	var top := _find(body_rect(), Level.Kind.TOP)
	var stand := top.y * TILE - HERO_SIZE.y / 2
	if top.x >= 0 and not climbing and y - stand > maxf(vy, 0.0) + CLIMB_SNAP:
		climbing = true  # a ledge his body reached from below or beside it: he pulls himself up
		_climb_to = stand
		_air_ticks += 1
	elif top.x >= 0 and not climbing:
		_land(stand)
	else:
		_air_ticks += 1
	on_ground = _air_ticks <= 1

	var wall := _find(chest_rect(), Level.Kind.SIDE, SIDE_SHRINK)
	if wall.x < 0:
		wall = _find(feet_rect(), Level.Kind.SIDE, SIDE_SHRINK)
	blocked = wall.x >= 0
	if not blocked:
		if scroll >= SCROLL_END:
			scroll = SCROLL_END
			at_end = true
			_run_home()  # old: the screen stops, Panoramic keeps running (_move_right)
			if hanging and x >= HOME_X:  # New: over the doorway he lets go (he hung there for good)
				_let_go()
		else:
			var step := minf(SCROLL_SPEED, SCROLL_END - scroll)
			if SCROLL_END - scroll < END_EASE:  # slowing: he takes up the rest of the pace
				step = minf(maxf(SCROLL_SPEED * sqrt((SCROLL_END - scroll) / END_EASE), 0.5), SCROLL_END - scroll)
				x += SCROLL_SPEED - step
			scroll += step

	var bob := _find(body_rect(), Level.Kind.BOB)
	if bob.x >= 0:
		level.clear(bob.x, bob.y)
		bobs += 1
		cover = COVER_TICKS
		bob_collected.emit(bob.x, bob.y)

	for r in rings.duplicate():
		if _find(Rect2(r.x, r.y, RING_WALL_SIZE, RING_WALL_SIZE), Level.Kind.SIDE, SIDE_SHRINK).x >= 0:
			rings.erase(r)

	if at_end and x >= HOME_X and on_ground:
		end_at = Vector2(x, y)
		state = State.WON
		won.emit()


## On the grass at `stand` (his centre y): the end of a jump, a fall or a climb.
func _land(stand: float) -> void:
	if _air_ticks > 1:
		land_speed = 0.0 if climbing else maxf(vy, 0.0)
	climbing = false
	jumping = false
	vy = 0.0
	y = stand
	ground_y = y
	if _air_ticks > 1:
		_since_land = 0
		landed.emit()
	_air_ticks = 0


func _die(reason: StringName) -> void:
	end_at = Vector2(x, y)
	state = State.DEAD
	death_reason = reason
	died.emit(reason)


# ------------------------------------------------------------------ geometry
## His boxes (the 2017 ones, in play units; x, y is his centre). Views must draw him around them:
## - body_rect, 64 x 128: stands on grass (its bottom is his feet, y + 64), picks up Red Bobs,
##   climbs ledges. Generous: a Red Bob anywhere in it is his.
## - chest_rect and feet_rect, 32 x 64 each, the middle half of the body: walls stop them, bandits
##   hurt them (the feet only from behind and below a bandit's centre, old isCollidingWith). Half
##   as wide as the body: a club that only brushes his drawn arm, staff or back foot doesn't count.
## - bandit_rect, 35 x 85 (+ CLUB_REACH in front of it, never through a wall).
## Drawn: his feet on the bottom of the body box, his torso over the chest box. Drawn bigger than
## the box (HeroView.DRAW_SCALE 1.25: ~160 tall) is fine and fair as long as the torso stays within
## about 24 units of x: what touches a bandit on screen is what the rules count, give or take the
## limbs. Hanging, the rules hold him at y 0 but he is drawn under the vine at VINE_DRAW_Y.

func body_rect() -> Rect2:
	return Rect2(x - HERO_SIZE.x / 2, y - HERO_SIZE.y / 2, HERO_SIZE.x, HERO_SIZE.y)


func chest_rect() -> Rect2:
	return Rect2(x - HERO_SIZE.x / 4, y - HERO_SIZE.y / 2, HERO_SIZE.x / 2, HERO_SIZE.y / 2)


func feet_rect() -> Rect2:
	return Rect2(x - HERO_SIZE.x / 4, y, HERO_SIZE.x / 2, HERO_SIZE.y / 2)


## A bandit's box in the play window.
func bandit_rect(b: Bandit) -> Rect2:
	return Rect2(b.x - scroll - BANDIT_SIZE.x / 2, b.y - BANDIT_SIZE.y / 2, BANDIT_SIZE.x, BANDIT_SIZE.y)


## Strict overlap, like Android's RectF.intersects (touching edges don't count).
static func _hits(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x and a.position.y < b.end.y and b.position.y < a.end.y


## The tile of `kind` that `rect` (play window) overlaps, as the old code found it: the last one in
## column order, then row order. (-1, -1) if none. Wall tiles are tested `shrink` smaller.
## `at_scroll`: the level's scroll to test at (the current one if negative).
func _find(rect: Rect2, kind: int, shrink := 0.0, at_scroll := -1.0) -> Vector2i:
	var sc := scroll if at_scroll < 0.0 else at_scroll
	var left := rect.position.x + sc
	var c0 := maxi(floori(left / TILE), 0)
	var c1 := mini(floori((left + rect.size.x) / TILE), Level.COLS - 1)
	var r0 := maxi(floori(rect.position.y / TILE), 0)
	var r1 := mini(floori(rect.end.y / TILE), Level.ROWS - 1)
	var found := Vector2i(-1, -1)
	for c in range(c0, c1 + 1):
		for r in range(r0, r1 + 1):
			if level.kind_at(c, r) != kind:
				continue
			var tile := Rect2(c * TILE - sc, r * TILE, TILE - shrink, TILE - shrink)
			if _hits(rect, tile):
				found = Vector2i(c, r)
	return found


## The 2017 run began with him falling from the sky; with the start card he waits on the grass.
func stand_at_start() -> void:
	y = 18 * TILE - HERO_SIZE.y / 2
	prev_y = y
	ground_y = y
	vy = 0.0
	_air_ticks = 0
	on_ground = true


# ------------------------------------------------------------------ for views and tests

## Interpolated positions for drawing between ticks.
func draw_scroll() -> float:
	return lerpf(prev_scroll, scroll, alpha)


func draw_hero() -> Vector2:
	var p := Vector2(lerpf(prev_x, x, alpha), lerpf(prev_y, y, alpha))
	if on_ground and not hanging:
		p.y = minf(p.y, ground_y)
	elif p.y < VINE_EASE and rising_to_vine():  # meets the hanging picture (VINE_DRAW_Y) at the top
		p.y += VINE_DRAW_Y * pow(1.0 - maxf(p.y, 0.0) / VINE_EASE, 2.0)
	return p


## Whether the rise in progress ends hanging from the vine (the top of the screen).
func rising_to_vine() -> bool:
	if hanging or climbing or vy >= 0.0 or ceiling_above(x, y - HERO_SIZE.y / 2, scroll) >= 0.0:
		return false
	var py := y
	var v := vy
	while v < 0.0:
		py += v
		v += GRAVITY
		if py <= 0.0:
			return true
	return false


## For views: the play x of the face of the first wall within `reach` ahead of x = `from`, at the
## height of his body (centre y = `at_y`); -1 if none. `at_scroll` is the drawn scroll.
func wall_ahead(from: float, at_y: float, reach: float, at_scroll: float) -> float:
	var r0 := maxi(floori((at_y - HERO_SIZE.y / 2) / TILE), 0)
	var r1 := mini(floori((at_y + HERO_SIZE.y / 2 - 1.0) / TILE), Level.ROWS - 1)
	for c in range(maxi(floori((at_scroll + from) / TILE), 0), mini(floori((at_scroll + from + reach) / TILE), Level.COLS - 1) + 1):
		for r in range(r0, r1 + 1):
			if level.kind_at(c, r) == Level.Kind.SIDE:
				return c * TILE - at_scroll
	return -1.0


## For views: the play x of the right face of the first wall within `reach` behind (left of) x =
## `from`, between heights at_y ± half_h (a bandit pressed on a wall); -1 if none.
func wall_behind(from: float, at_y: float, half_h: float, reach: float, at_scroll: float) -> float:
	var r0 := maxi(floori((at_y - half_h) / TILE), 0)
	var r1 := mini(floori((at_y + half_h - 1.0) / TILE), Level.ROWS - 1)
	for c in range(mini(floori((at_scroll + from) / TILE), Level.COLS - 1), maxi(floori((at_scroll + from - reach) / TILE), 0) - 1, -1):
		for r in range(r0, r1 + 1):
			if level.kind_at(c, r) == Level.Kind.SIDE:
				return (c + 1) * TILE - at_scroll
	return -1.0


## New, for views: the bottom of the first ceiling above a head at `head_y` (a wall tile with
## nothing solid under it, over his chest at play x `at_x`), or -1 if open sky. The tunnel's roof
## (columns 336-405) is the only one he can reach.
func ceiling_above(at_x: float, head_y: float, at_scroll: float) -> float:
	var c0 := maxi(floori((at_scroll + at_x - HERO_SIZE.x / 4) / TILE), 0)
	var c1 := mini(floori((at_scroll + at_x + HERO_SIZE.x / 4 - 0.01) / TILE), Level.COLS - 1)
	for r in range(floori((head_y + 0.01) / TILE) - 1, -1, -1):
		for c in range(c0, c1 + 1):
			if level.kind_at(c, r) == Level.Kind.SIDE and level.kind_at(c, r + 1) not in [Level.Kind.SIDE, Level.Kind.TOP]:
				return (r + 1) * TILE
	return -1.0


## For views: what he is doing (see LAND_TICKS): &"idle" (before the first tick), &"run", &"land",
## &"crouch", &"takeoff", &"rise", &"apex", &"fall", &"climb", &"hang", &"dead" or &"home".
func move_phase() -> StringName:
	return _current_phase() if state != State.RUNNING else _phase


## For views: seconds since move_phase() began (between ticks too); since the end of the run once
## it is over.
func phase_time() -> float:
	if state != State.RUNNING:
		return end_time
	return (ticks - _phase_tick + alpha) * TICK


func _current_phase() -> StringName:
	if state == State.DEAD:
		return &"dead"
	if state == State.WON:
		return &"home"
	if ticks == 0:
		return &"idle"
	if hanging:
		return &"hang"
	if climbing:
		return &"climb"
	if jumping and vy < 0.0 and ticks - _jump_tick < TAKEOFF_TICKS:
		return &"takeoff"
	if on_ground and not (jumping and vy < 0.0):
		if _since_land <= LAND_TICKS:
			return &"land"
		return &"crouch" if crouching else &"run"
	if absf(vy) < APEX_VY:
		return &"apex"
	return &"rise" if vy < 0.0 else &"fall"


## For views: ticks until his feet touch grass if nobody touches the screen (0 on the ground), or
## -1 if no landing comes within 60 ticks (a pit, the vine, or a ledge he will climb). Worked out
## once a tick (a look-ahead: about 0.1 ms in the air).
func ticks_to_land() -> int:
	if _land_tick != ticks:
		_land_tick = ticks
		_land_in = _look_for_landing(60)
	return maxi(_land_in, -1)


## For views and the camera: true while he is falling into a pit he can't get out of, even with
## the jump a fall may still have (the camera holds still and shows him drop in). Worked out once a
## tick, only when no landing is ahead.
func falling_to_death() -> bool:
	if _doom_tick == ticks:
		return _doomed
	_doom_tick = ticks
	_doomed = false
	if state == State.DEAD:
		_doomed = death_reason == &"fall"
	elif state == State.RUNNING and not on_ground and vy > 0.0 and not hanging and not climbing \
			and (not falls_cost_life or lives <= 1) and _look_for_landing(90) == OUT:
		_doomed = jumping or _look_for_landing(90, -JUMP_SPEED) == OUT
	return _doomed


## The ends of a fall that aren't a landing (_look_for_landing).
const VINE := -1
const CLIMB := -2
const OUT := -3  ## out of the bottom of the screen
const NONE := -4


## What a fall comes to if nobody touches the screen (from `start_vy` if given: a jump now): the
## ticks to the landing, 0 on the ground, or VINE, CLIMB, OUT or NONE.
func _look_for_landing(horizon: int, start_vy := NAN) -> int:
	if hanging or climbing or state != State.RUNNING:
		return NONE
	var v := vy if is_nan(start_vy) else start_vy
	if is_nan(start_vy) and on_ground and not (jumping and vy < 0.0):
		return 0
	var py := y
	var sc := scroll
	for t in range(1, horizon + 1):
		var head := py - HERO_SIZE.y / 2
		py += v
		v += GRAVITY
		if v < GRAVITY:
			var ceiling := ceiling_above(x, head, sc)
			if ceiling >= 0.0 and py - HERO_SIZE.y / 2 < ceiling:
				py = ceiling + HERO_SIZE.y / 2
				v = 0.0
			elif py <= 0.0:
				return VINE
		var body := Rect2(x - HERO_SIZE.x / 2, py - HERO_SIZE.y / 2, HERO_SIZE.x, HERO_SIZE.y)
		var top := _find(body, Level.Kind.TOP, 0.0, sc)
		if top.x >= 0:
			if py - (top.y * TILE - HERO_SIZE.y / 2) > maxf(v, 0.0) + CLIMB_SNAP:
				return CLIMB
			if is_nan(start_vy):  # (not a jump being tried out)
				_land_y = top.y * TILE - HERO_SIZE.y / 2
			return t
		if py - HERO_SIZE.y / 2 > VIEW_H:
			return OUT
		var chest := Rect2(x - HERO_SIZE.x / 4, py - HERO_SIZE.y / 2, HERO_SIZE.x / 2, HERO_SIZE.y)
		if _find(chest, Level.Kind.SIDE, SIDE_SHRINK, sc).x < 0 and not at_end:
			sc = minf(sc + SCROLL_SPEED, SCROLL_END)
	return NONE


## For views: 0..1 through his time in the air (0 leaving the ground, about 0.5 at the top of a
## hop, 1 touching down), from ticks_to_land(); -1 on the ground, hanging, climbing, or with no
## landing ahead (a fall into a pit: flail).
func air_progress() -> float:
	var left := ticks_to_land()
	if left <= 0 or (on_ground and not jumping):
		return -1.0
	var done := maxf(float(ticks - maxi(_jump_tick, ticks - _air_ticks)) + alpha, 0.0)
	return clampf(done / (done + float(left) - alpha), 0.0, 1.0)


## For views: his centre y standing on the first grass top at or below `from_y` (his centre) at play
## x `at_x`, or -1 over a pit (where he falls when caught in the air, for the death animation).
func ground_below(at_x: float, from_y: float) -> float:
	var c := floori((scroll + at_x) / TILE)
	for r in range(maxi(floori((from_y + HERO_SIZE.y / 2 - 8.0) / TILE), 0), Level.ROWS):
		if level.kind_at(c, r) == Level.Kind.TOP:
			return r * TILE - HERO_SIZE.y / 2
	return -1.0


## For the camera: whether the vine matters now: he hangs from it, rises to it, or a jump from where
## he is would reach it (a ledge high enough; a fall that still has its jump), or will from where he
## is about to stand (the top of the ledge he climbs, the ledge a fall comes down on): so the camera
## has drawn back by the time he stands there (the 10-tile wall's top is 2 tiles wide: 0.3 s).
func vine_catchable() -> bool:
	if hanging or rising_to_vine():
		return true
	if state != State.RUNNING:
		return false
	var stand := y
	if climbing:
		stand = _climb_to
	elif not on_ground and vy >= 0.0 and ticks_to_land() > 0:
		stand = _land_y
	elif jumping:
		return false
	return stand - JUMP_RISE <= 0.0 and ceiling_above(x, stand - HERO_SIZE.y / 2, scroll) < 0.0


## For the camera (GameScreen keeps it on screen whatever the framing): the part of the play window,
## in play units, the player must see now, so a closer camera never shows less than the 2017 screen
## where it matters:
## - across, from just behind him to the play window's right edge: bandits wake there, so the
##   time they are seen before they reach him is never shorter than in 2017;
## - down, the grass or water he stands on or could drop to in the next SEE_AHEAD_DOWN units;
## - up, what a jump from here reaches (Red Bobs, ledges), or the vine when it matters
##   (vine_catchable()).
## The run over: caught, him where he lies; into a pit, him and the water; home, him and the door.
func camera_must_see() -> Rect2:
	var top := y - HERO_SIZE.y / 2 - SEE_ABOVE
	if state == State.RUNNING and falling_to_death():  # nothing can come of the rest: him and the water
		return Rect2(x - 110.0, minf(top, SURFACE_Y - HERO_SIZE.y - SEE_ABOVE), 220.0, VIEW_H - minf(top, SURFACE_Y - HERO_SIZE.y - SEE_ABOVE))
	if state == State.WON:
		return Rect2(HOME_X - 150.0, VIEW_H - 320.0, 270.0, 290.0)
	if state == State.DEAD:
		var bottom := VIEW_H if death_reason == &"fall" else minf(end_at.y + HERO_SIZE.y / 2 + 40.0, VIEW_H)
		top = minf(end_at.y, VIEW_H - HERO_SIZE.y) - HERO_SIZE.y / 2 - SEE_ABOVE
		return Rect2(end_at.x - 110.0, top, 220.0, bottom - top)
	# up to his head, and to whatever a jump from here can go for (a Red Bob, a ledge and who stands on
	# it); nothing over the vine matters (rising to it, his box goes past the top: he is drawn under it)
	top = minf(y - HERO_SIZE.y / 2, _reachable_top()) - SEE_ABOVE
	top = VINE_SEEN if vine_catchable() else maxf(top, VINE_SEEN)
	return Rect2(x - SEE_BEHIND, top, VIEW_W - (x - SEE_BEHIND), _ground_ahead() + 24.0 - top)


## The top of the highest thing a jump from here can go for in the next SEE_AHEAD_DOWN units: a Red
## Bob, or a ledge's grass less the height of whoever may stand on it, between his head and the top
## of the jump (from where he stands or climbs to, or of the jump he is in); INF if none.
func _reachable_top() -> float:
	var apex := y
	if climbing:
		apex = _climb_to - JUMP_RISE
	elif not jumping:
		apex = y - JUMP_RISE
	else:
		var v := vy
		while v < 0.0:
			apex += v
			v += GRAVITY
	var head := y - HERO_SIZE.y / 2
	var r0 := maxi(floori((apex - HERO_SIZE.y / 2) / TILE), 0)
	var r1 := mini(floori(head / TILE), Level.ROWS - 1)
	var c0 := maxi(floori((scroll + x - HERO_SIZE.x / 2) / TILE), 0)
	var c1 := mini(floori((scroll + x + SEE_AHEAD_DOWN) / TILE), Level.COLS - 1)
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var k := level.kind_at(c, r)
			if k == Level.Kind.BOB:
				return r * TILE
			if k == Level.Kind.TOP:
				return r * TILE - HERO_SIZE.y
	return INF


## The lowest grass top or pool surface he could come down to within SEE_AHEAD_DOWN units ahead (play
## y), at least his feet.
func _ground_ahead() -> float:
	var feet := y + HERO_SIZE.y / 2
	var lowest := feet
	var c0 := floori((scroll + x - HERO_SIZE.x / 2) / TILE)
	var c1 := floori((scroll + x + SEE_AHEAD_DOWN) / TILE)
	for c in range(maxi(c0, 0), mini(c1, Level.COLS - 1) + 1):
		for r in range(clampi(floori((feet - 1.0) / TILE), 0, Level.ROWS - 1), Level.ROWS):
			var k := level.kind_at(c, r)
			if k == Level.Kind.TOP or k == Level.Kind.WATER:
				lowest = maxf(lowest, r * TILE)
				break
	return minf(lowest, VIEW_H - 24.0)


## For views: a bandit's blow, 0..1, over the last STRIKE_TICKS before its club would reach him at
## the speed they close in now (club drawn back from 0, the blow at 1), or -1 when none is coming
## (behind him, above or below him, it hit him already, knocked out, or the run is over).
func strike(b: Bandit) -> float:
	if b.gone or not b.active or b.touched_hero or b.health <= 0 or state != State.RUNNING:
		return -1.0
	var r := bandit_rect(b)
	var body := body_rect()
	if r.end.y <= body.position.y or r.position.y >= body.end.y or b.x - scroll < x:
		return -1.0
	var closing := BANDIT_RUN + (0.0 if blocked or at_end else SCROLL_SPEED)
	var left := (r.position.x - CLUB_REACH - chest_rect().end.x) / closing - alpha
	if left > STRIKE_TICKS:
		return -1.0
	return clampf(1.0 - left / STRIKE_TICKS, 0.0, 1.0)


## For views: a Red Bob that can't be taken alive (RISKY_BOBS).
static func is_risky_bob(col: int, row: int) -> bool:
	return Vector2i(col, row) in RISKY_BOBS


## 0..1: how far into the level.
func progress() -> float:
	return clampf(scroll / SCROLL_END, 0.0, 1.0)


## New: of the 104 Red Bobs only 84 can be taken alive (tests/probes.gd --probe=bobs): 16 hang over
## the river after the pillars (row 12, cols 596-628: the drop is fatal) and 4 over the left end
## of the island at cols 201-203 need 8 swipes right in one jump to get off it again. 80 % of all
## 104 asked for every one of the 84, without a hit: no player's 3 stars.
const BOBS_REACHABLE := 84


## Stars for a finished level: 1 for getting home, 1 for half the Red Bobs he can take, 1 for 80 %
## of them without losing a life.
func stars() -> int:
	if state != State.WON:
		return 0
	var share := float(bobs) / mini(BOBS_REACHABLE, maxi(level.bobs_total, 1))
	return 1 + int(share >= 0.5) + int(share >= 0.8 and lives == LIVES)


## A deep copy without signal connections (for the bot's look-ahead).
func clone() -> World:
	var w := World.new(level.copy(), false)
	w.state = state; w.ticks = ticks; w.scroll = scroll; w.blocked = blocked; w.at_end = at_end
	w.x = x; w.y = y; w.vy = vy; w.jumping = jumping; w.crouching = crouching; w.hanging = hanging
	w.on_ground = on_ground; w.ground_y = ground_y; w._air_ticks = _air_ticks; w._jump_buffer = _jump_buffer; w.lives = lives; w.cover = cover; w.mercy = mercy; w.bobs = bobs
	w.climbing = climbing; w._climb_to = _climb_to; w.land_speed = land_speed; w.falls = falls; w._home_pace = _home_pace
	w._since_land = _since_land; w._phase = _phase; w._phase_tick = _phase_tick; w._jump_tick = _jump_tick; w.end_time = end_time
	w.prev_x = prev_x; w.prev_y = prev_y; w.prev_scroll = prev_scroll; w.alpha = alpha; w._time = _time
	w.hit_dir = hit_dir; w.hit_strength = hit_strength; w.end_at = end_at  # New: drawn where it is
	w.falls_cost_life = falls_cost_life
	w.knocked_out = knocked_out; w.death_reason = death_reason
	w.bandits.clear()
	for b in bandits:
		w.bandits.append(b.copy())
	for r in rings:
		w.rings.append(r.copy())
	w._next_id = _next_id
	return w


func _new_id() -> int:
	_next_id += 1
	return _next_id

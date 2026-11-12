extends Node
## Headless checks of the rules, the level, saves, settings and texts. Run from New/:
##   Godot --headless --path . res://tests/run_tests.tscn [-- --bot]
## --bot also lets the bot play the whole level (a few minutes). Prints each failure and exits
## with code 1 if anything failed.
##
## Release checks (QA, at the end of the list): every screen at every device size of
## tests/capture.gd in English and French (loads without an error, buttons and texts inside the safe
## area and on screen, no text cut, no raw key), no node left behind after a run and back to the
## menu, the save round trip, pausing at random moments changes nothing, the same game at 30, 60,
## 120 and 144 Hz and with an uneven frame rate, and the bot's recorded run getting home through the
## real game screen (when the recording is in build/qa/; --bot records it). About 40 s; -- --quick
## leaves out the ones that open screens (a few seconds: for quick checks while working; the full
## run is the release gate).
## About 100 checks (the user's call, 2026-11-07: the 100 most important): the rules, saves and release
## checks one by one; the bigger groups (FOLDED, the gameplay groups) as one check each.

var _failures := 0
var _checks := 0
var _batch: Variant = null  # the failures gathered by _folded() (null: checks count one by one)

## The bigger groups count as ONE check each, naming their first failures (the rules count one by one).
const FOLDED := {
	&"_test_scripts_compile": "every script compiles",
	&"_test_translations": "the texts in English and French",
	&"_test_config": "the settings file",
	&"_test_screens": "every screen at every device size, in English and French",
	&"_test_home_door": "on the run home he can't pass the doorway, even jumping",
	&"_test_hud_band": "the HUD fits in its band on every device",
	&"_test_ux": "the tutorial, the comfort options, the touch areas, French typography",
	&"_test_audio": "sounds, music, buses, settings, haptics, footsteps",
	&"_test_art": "the hero's frames: every animation, inside its page, the run's pace, a pose for each state",
	&"_test_shine_sweeps": "the buttons' sweep of light: no slice Godot can't draw",
}


func _ready() -> void:
	Save.persist = false
	var tests := [_test_scripts_compile, _test_speeds, _test_level, _test_landing, _test_jump_height, _test_jump_buffer, _test_climb_wall,
			_test_hang, _test_fall, _test_landing_weight, _test_bandits, _test_club_reach, _test_mercy, _test_calm_start, _test_swipes, _test_rings, _test_home_door, _test_run_home, _test_step_cap, _test_frame_rates, _test_idle,
			_test_stars, _test_save, _test_translations, _test_config, _test_preload, _test_debug_silent,
			_test_translation_formats, _test_sounds, _test_save_round_trip, _test_determinism, _test_screens, _test_shine_sweeps, _test_no_leaks,
			_test_pause_anywhere, _test_replay_home, _test_contracts, _test_hud_band, _test_audio, _test_gameplay]
	tests.append(_test_ux)
	tests.append(_test_art)
	if "--bot" in OS.get_cmdline_user_args():
		tests.append(_test_bot)
	if "--quick" in OS.get_cmdline_user_args():  # without the screens (seconds instead of ~40 s)
		tests = tests.filter(func(t: Callable) -> bool: return t not in [_test_screens, _test_shine_sweeps, _test_no_leaks, _test_pause_anywhere,
				_test_replay_home, _test_contracts, _test_hud_band])
	for test: Callable in tests:  # (the release checks wait for frames)
		if FOLDED.has(test.get_method()):
			await _folded(FOLDED[test.get_method()], test)
		else:
			await test.call()
	print("%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if _batch != null:
		if not ok:
			(_batch as Array).append(what)
		return
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FAIL: ", what)


## Runs a group of checks as one check: it fails when any of them fails, and names the first three.
func _folded(what: String, test: Callable) -> void:
	_batch = []
	await test.call()
	var failed: Array = _batch
	_batch = null
	_check(failed.is_empty(), what + ("" if failed.is_empty() else ": " + " | ".join(failed.slice(0, 3))))


func _near(a: float, b: float, tolerance := 0.01) -> bool:
	return absf(a - b) <= tolerance * maxf(absf(b), 1.0)


## Every script parses (a broken script still loads in an export, as an empty class).
func _test_scripts_compile() -> void:
	for path in _scripts("res://src") + _scripts("res://tests"):
		var script: GDScript = load(path)
		_check(script != null and script.can_instantiate(), "%s compiles" % path)


## The 2017 values per 40 Hz tick, converted at the reference phone (x / 1.375, y / 1.125).
func _test_speeds() -> void:
	_check(_near(World.SCROLL_SPEED / World.TICK, 232.7), "tiles scroll 8 px/tick = 233 u/s")
	_check(_near(World.GRAVITY / World.TICK / World.TICK, 4266.7), "gravity 3 px/tick² = 4,267 u/s²")
	_check(_near(World.JUMP_SPEED / World.TICK, 1280.0), "jump H/20 per tick = 1,280 u/s")
	_check(_near(World.BANDIT_RUN / World.TICK, 290.9), "bandits run 10 px/tick = 291 u/s")
	_check(_near(World.RING_SPEED / World.TICK, 581.8), "rings fly 20 px/tick = 582 u/s")
	_check(World.HERO_SIZE == Vector2(64, 128), "Panoramic's box is 64 x 128")


func _test_level() -> void:
	var l := Level.load_default()
	_check(l.ids.size() == Level.COLS * Level.ROWS, "the map is 800 x 20 tiles")
	_check(l.bobs_total == 104, "104 Red Bobs (found %d)" % l.bobs_total)
	_check(l.kind_at(0, 18) == Level.Kind.TOP, "the level starts on grass at row 18")
	_check(l.kind_at(75, 18) == Level.Kind.WATER, "water at column 75")
	_check(l.kind_at(33, 8) == Level.Kind.TOP and l.kind_at(33, 12) == Level.Kind.SIDE, "a 10-tile wall at column 33")
	_check(Level.kind_of(89) == Level.Kind.NONE, "ids above 85 draw nothing (old Tile.java)")
	var bare := []
	for c in Level.COLS:
		var solid := func(r: int) -> bool: return l.kind_at(c, r) in [Level.Kind.TOP, Level.Kind.SIDE]
		if not solid.call(Level.ROWS - 2) and not solid.call(Level.ROWS - 1) and l.kind_at(c, Level.ROWS - 2) != Level.Kind.WATER:
			bare.append(c)
	_check(bare.is_empty(), "every pit is a pool, none looks like ground (bare: %s)" % [bare])
	_check(l.kind_at(560, 18) == Level.Kind.WATER and l.kind_at(610, 18) == Level.Kind.WATER, "the pillars stand in a river")


func _test_landing() -> void:
	var w := World.new()
	var landed := []
	w.landed.connect(func() -> void: landed.append(w.ticks))
	for i in 40:
		w.tick()
	_check(w.on_ground and _near(w.ground_y, 18 * 32 - 64.0), "Panoramic falls onto the row-18 grass (y=%.1f)" % w.y)
	_check(landed.size() == 1, "one landing sound, not one every other tick (%d)" % landed.size())


## The old integration (position, then speed) gives a 208-unit jump: 6.5 tiles.
func _test_jump_height() -> void:
	var w := _standing_world()
	var start := w.y
	w.jump()
	var top := start
	for i in 40:
		w.tick()
		top = minf(top, w.y)
	_check(_near(start - top, 208.0, 0.02), "a jump rises 208 units (rose %.1f)" % (start - top))


## A swipe up just before landing jumps on landing; one long before is forgotten. No jump while
## hanging (no sound either), and a swipe down in the air doesn't leave him kneeling.
func _test_jump_buffer() -> void:
	var w := _standing_world()
	w.jump()
	w.tick()
	var landings := []  # (a lambda can't assign an outer local: it captures a copy)
	w.landed.connect(func() -> void: landings.append(w.ticks))
	var jumps := []
	w.jumped.connect(func() -> void: jumps.append(w.ticks))
	var asked := false
	while landings.is_empty() and w.ticks < 200:
		if w.vy > 0.0 and w.y > w.ground_y - 40.0 and not asked:
			w.jump()  # a few ticks before the grass
			asked = true
		w.tick()
	w.tick()
	_check(asked and jumps.size() == 1 and jumps[0] - landings[0] <= 1, "a swipe up just before landing jumps on landing")
	var v := _standing_world()
	v.jump()
	for i in 4:
		v.tick()
	v.jump()  # far too early: at the start of the rise
	var again := []
	v.jumped.connect(func() -> void: again.append(true))
	for i in 60:
		v.tick()
	_check(again.is_empty(), "a swipe up long before landing is forgotten")
	var u := _standing_world()
	u.jump()
	u.tick()
	u.down()  # in the air
	for i in 60:
		u.tick()
	_check(not u.crouching, "a swipe down in the air doesn't leave him kneeling")
	var h := _standing_world()
	h.y = 0.0
	h.hanging = true
	var sounds := []
	h.jumped.connect(func() -> void: sounds.append(true))
	h.jump()
	h.tick()
	_check(sounds.is_empty(), "a swipe up while hanging plays no jump")


## Walls up to 10 tiles are climbed: touching the grass on top lifts him onto it.
func _test_climb_wall() -> void:
	var w := _standing_world()
	var t := 0
	while not w.blocked and t < 400:
		w.tick()
		t += 1
	_check(w.blocked and int((w.scroll + w.x) / 32.0) in [31, 32], "the wall at column 33 stops him")
	var level_x := w.scroll + w.x
	for i in 12:
		w.step_forward()
		w.tick()
	_check(w.blocked and _near(w.scroll + w.x, level_x), "swiping right doesn't walk him through the wall")
	var face := w.wall_ahead(w.x, w.y, 80.0, w.scroll)
	_check(face > w.x and _near(face + w.scroll, 33 * 32.0), "views find the face of the wall he is pushing on")
	# the tower is two tiles wide (columns 33 and 34): a bandit meets its far face
	_check(_near(w.wall_behind(face + 100.0, w.y, 40.0, 40.0, w.scroll), face + 64.0), "and the face a bandit coming the other way meets")
	w.jump()
	var on_top := false
	var lift := 0.0
	var landings := []
	w.landed.connect(func() -> void: landings.append(w.ticks))
	for i in 30:
		var before := w.y
		w.tick()
		lift = maxf(lift, before - w.y)
		on_top = on_top or (w.on_ground and _near(w.y, 8 * 32 - 64.0))
	_check(on_top, "one jump puts him on top of the 10-tile wall")
	_check(lift <= World.CLIMB_SPEED + 0.01, "he climbs onto it, no lift of more than %d units a tick (%.0f)" % [World.CLIMB_SPEED, lift])
	_check(landings.size() == 1, "and lands on top once (%d)" % landings.size())


func _test_hang() -> void:
	var w := _standing_world()
	w.y = 120.0  # high up, as on top of a tower
	w.vy = 0.0
	w.on_ground = false
	w.jump()
	var hung := []
	w.hung.connect(func() -> void: hung.append(true))
	for i in 30:
		w.tick()
	_check(w.hanging and w.y == 0.0 and hung.size() == 1, "reaching the top of the screen, he hangs")
	var scroll := w.scroll
	for i in 20:
		w.tick()
	_check(w.hanging and w.scroll > scroll, "hanging, the level keeps moving under him")
	w.jump()
	w.tick()
	_check(w.hanging, "jumping while hanging does nothing")
	w.throw()
	w.tick()
	_check(not w.rings.is_empty() and w.rings[-1].y == World.VINE_DRAW_Y, "hanging, he throws from his hand under the vine, not along the top")
	w.down()
	w.tick()
	w.tick()
	_check(not w.hanging and w.y > 0.0, "swipe down lets go")
	# round 22: the vine is drawn with swags of its own away from his hands; at his hands it is where the rules hang him
	var vine := VineView.new()
	var meets := true
	for at: float in [0.0, 777.0, 4321.0, 18050.0]:
		vine.scroll = at
		vine.hold(true, 300.0, 0.0)
		meets = meets and is_equal_approx(vine._drawn_sag(300.0), vine.sag_at(300.0))
	vine.free()
	_check(meets, "the vine as drawn meets his hands where he hangs")


## A fall ends the run, hearts or not (2017), unless falls_cost_life is on (config [rules], off by
## default): then it costs a life, a splash, and he springs back up to the vine, safe from bandits
## while he rises and for a while after; with the last life a fall ends the run.
func _test_fall() -> void:
	_check(Config.value("rules", "falls_cost_life", true) == false, "falls end the run by default (the 2017 rule)")
	var o := _standing_world()
	o.scroll = 76 * 32.0 - o.x
	o.y = 380.0
	o.on_ground = false
	for i in 40:
		o.tick()
	_check(o.state == World.State.DEAD and o.death_reason == &"fall" and o.lives == World.LIVES, "switch off: a fall ends the run, three hearts or not")
	var w := _standing_world()
	w.falls_cost_life = true
	w.scroll = 600 * 32.0 - w.x  # over the long river after the pillars (columns 583 to 641)
	w.y = 380.0
	w.on_ground = false
	var events := []
	w.splashed.connect(func(_x: float, hero: bool) -> void: events.append(&"splash" if hero else &"bandit"))
	w.fell.connect(func(lives: int) -> void: events.append(lives))
	w.sprang.connect(func() -> void: events.append(&"sprang"))
	w.hung.connect(func() -> void: events.append(&"hung"))
	for i in 90:
		w.tick()
		if w.hanging:
			break
	_check(w.state == World.State.RUNNING and w.lives == World.LIVES - 1, "a fall costs one life (%d left)" % w.lives)
	_check(events == [&"splash", World.LIVES - 1, &"sprang", &"hung"], "splash, a life, the spring, the vine (%s)" % [events])
	_check(w.hanging and w.mercy >= World.FALL_MERCY - 2, "back on the vine and still safe (%d ticks)" % w.mercy)
	_check(w.x >= World.SPRING_X, "clear of the hearts in the corner (x=%.0f)" % w.x)
	var v := _standing_world()
	v.falls_cost_life = true
	v.scroll = 76 * 32.0 - v.x
	v.y = 380.0
	v.on_ground = false
	v.lives = 1
	for i in 40:
		v.tick()
	_check(v.state == World.State.DEAD and v.death_reason == &"fall", "a fall with the last life ends the run")


## Landings report how hard they were: a climb is soft, a hop lands at its take-off speed, a fall
## from high up harder still (sound, shake and haptics follow it). Letting go of the vine, he drops
## from where he is drawn hanging.
func _test_landing_weight() -> void:
	var w := _standing_world()
	w.jump()
	for i in 40:
		w.tick()
	var hop := w.land_speed
	w.y = 40.0
	w.vy = 0.0
	w.jumping = true
	for i in 40:
		w.tick()
	_check(hop > 25.0 and w.land_speed > hop + 5.0, "a fall from high up lands harder than a hop (%.0f, %.0f)" % [hop, w.land_speed])
	w.y = 0.0
	w.hanging = true
	w.down()
	w.tick()
	_check(w.y >= World.LET_GO_Y and w.y < World.LET_GO_Y + World.GRAVITY * 2.0, "letting go, he drops from his hanging picture (y=%.0f)" % w.y)


func _test_bandits() -> void:
	var w := _standing_world()
	_bandit_ahead(w, 20.0)
	var hits := []
	w.hurt.connect(func(_b: World.Bandit, lives: int) -> void: hits.append(lives))
	for i in 10:
		w.tick()
	_check(hits == [2], "a bandit takes one life, once (%s)" % [hits])
	# New (the user, 2026-11-07): the strong kind takes 3 rings; a jumper leaps over the first ring coming at it,
	# and the next one hits it
	var s := _standing_world()
	var sb := _bandit_ahead(s, 420.0)
	sb.strong = true
	sb.health = World.STRONG_HEALTH
	var outs := []
	s.bandit_hit.connect(func(_b: World.Bandit, out: bool) -> void: outs.append(out))
	for t in 40:
		if t % 4 == 0:
			s.throw()
		s.tick()
	_check(outs == [false, false, true], "a strong bandit takes 3 rings (%s)" % [outs])
	var open := Level.load_default().copy()  # (open sky over the start: no leap under a ledge's roof)
	for c in range(8, 45):
		for row in 18:
			open.clear(c, row)
	var j := World.new(open)
	for b in j.bandits:
		b.gone = true
	for t in 30:
		j.tick()
	var jb := _bandit_ahead(j, 500.0)
	jb.jumper = true
	jb.dodges = World.DODGES
	var struck := []
	j.bandit_hit.connect(func(_b: World.Bandit, _out: bool) -> void: struck.append(j.ticks))
	var leapt := false
	j.throw()
	for t in 60:
		j.tick()
		leapt = leapt or jb.vy < -World.BANDIT_HOP
		if leapt and j.rings.is_empty():
			break
	var dodged := leapt and struck.is_empty() and j.rings.is_empty()
	for t in 10:  # (it lands)
		j.tick()
	j.throw()
	for t in 30:
		j.tick()
	_check(dodged and struck.size() == 1, "a jumper leaps over the first ring and the next one hits it (leapt %s, hits %s)" % [leapt, struck])


## A bandit's club (drawn out in front of it) hurts him as it reaches him, not once its body is in
## his; jumping over a bandit coming at him still leaves plenty of time (> 0.4 s of take-off ticks).
func _test_club_reach() -> void:
	var gap := -1.0
	var clear := 0
	for jump_at in range(-1, 60):
		var w := _standing_world()
		var b := _bandit_ahead(w, 600.0)
		var hurt := []
		w.hurt.connect(func(_b: World.Bandit, _l: int) -> void: hurt.append(b.x - w.scroll - w.x))
		for t in 80:
			if t == jump_at:
				w.jump()
			w.tick()
		if jump_at < 0 and hurt.size() == 1:
			gap = hurt[0]
		elif jump_at >= 0 and hurt.is_empty():
			clear += 1
	_check(gap >= 40.0, "the club hurts him at its reach (centre gap %.0f units)" % gap)
	_check(clear * World.TICK >= 0.35, "a jump clears a running bandit from %d take-off ticks (%.0f ms)" % [clear, clear * World.TICK * 1000.0])
	var w := _standing_world()
	while not w.blocked and w.ticks < 400:
		w.tick()
	var b := _bandit_ahead(w, 120.0)  # on the far side of the first wall (two tiles thick)
	b.y = w.y + 10.0
	var hits := []
	w.hurt.connect(func(_b: World.Bandit, _l: int) -> void: hits.append(true))
	for i in 30:
		w.tick()
	_check(hits.is_empty(), "the club never reaches him through a wall")


## Two bandits on top of each other take one life, not two: a second of mercy after a hit.
func _test_mercy() -> void:
	var w := _standing_world()
	var lost := []
	w.hurt.connect(func(_b: World.Bandit, l: int) -> void: lost.append(l))
	_bandit_ahead(w, 20.0, 10)
	_bandit_ahead(w, 26.0, 11)
	for i in 10:
		w.tick()
	_check(lost == [World.LIVES - 1], "two bandits at once take one life (%s)" % [lost])
	for i in World.MERCY_TICKS:
		w.tick()
	_bandit_ahead(w, 20.0, 12)
	for i in 10:
		w.tick()
	_check(w.lives == World.LIVES - 2, "after the mercy second, a bandit hurts again")


## A new player's first touch is the "Tap to start" tap (it throws a ring): no bandit may reach
## him before he has had time to see it coming.
func _test_calm_start() -> void:
	var w := World.new()
	w.stand_at_start()
	w.throw()
	var hurt_at := []
	w.hurt.connect(func(_b: World.Bandit, _l: int) -> void: hurt_at.append(w.ticks * World.TICK))
	for i in 160:
		w.tick()
	_check(hurt_at.is_empty() or hurt_at[0] >= 1.5, "no bandit within 1.5 s of the start (%s)" % [hurt_at])


## Swipes: straight ones as in 2017; a jump leaning right (a thumb) is still a jump.
func _test_swipes() -> void:
	var game: GDScript = load("res://src/game/game_screen.gd")
	var cases := {Vector2(0, -40): &"jump", Vector2(0, 40): &"down", Vector2(40, 0): &"right",
			Vector2(-40, 0): &"", Vector2(30, -40): &"jump", Vector2(50, -36): &"jump", Vector2(40, 18): &"right"}
	var wrong := []
	for d: Vector2 in cases:
		if game.swipe_action(d) != cases[d]:
			wrong.append(d)
	_check(wrong.is_empty(), "swipes read as meant, slanted jumps too (%s)" % [wrong])


func _test_rings() -> void:
	var w := _standing_world()
	var b := _bandit_ahead(w, 400.0)
	w.throw()
	var stood := 0  # (2026-11-10) ticks the blow stops it
	for i in 16:
		var was := b.x
		w.tick()
		stood += int(b.hurt and b.x == was)
	_check(b.hurt and not b.gone and b.health == 1 and stood > 0 and stood + b.stagger == World.STAGGER_TICKS,
			"one ring hurts a bandit, and stops it %d ticks (%d done, %d to go)" % [World.STAGGER_TICKS, stood, b.stagger])
	w.throw()
	for i in 12:
		w.tick()
	_check(b.gone and w.knocked_out == 1, "a second ring knocks it out")


## On the run home he can't pass the doorway, even jumping: he lands in it and is home.
func _test_home_door() -> void:
	var w := _standing_world()
	w.scroll = World.SCROLL_END
	w.at_end = true
	w.jump()
	for i in 120:
		w.tick()
		_check(w.x <= World.HOME_X + 1.0, "never past the doorway (x=%.0f)" % w.x)
		if w.state != World.State.RUNNING:
			break
	_check(w.state == World.State.WON and absf(w.x - World.HOME_X) < 12.0, "he lands in the doorway and is home (x=%.0f)" % w.x)


## At the end the screen slows to a stop (no dead stop) while he keeps his pace through the level,
## then he runs to the hut and slows into the doorway (no dead stop there either).
func _test_run_home() -> void:
	var w := _standing_world()
	w.scroll = World.SCROLL_END - 200.0
	var steps := []
	var paces := []
	while not w.at_end and w.ticks < 2000:
		var s0 := w.scroll
		var p0 := w.scroll + w.x
		w.tick()
		steps.append(w.scroll - s0)
		paces.append(w.scroll + w.x - p0)
	var slowing := true
	for i in range(1, steps.size()):
		slowing = slowing and steps[i] <= steps[i - 1] + 0.001
	_check(slowing and steps[-1] < 1.5 and steps[0] > 5.0, "the screen slows to a stop (%.1f to %.1f units a tick)" % [steps[0], steps[-1]])
	var easing := paces.slice(0, paces.size() - 1)  # (the last tick is the first of the run home)
	_check(easing.all(func(p: float) -> bool: return _near(p, World.SCROLL_SPEED)), "while he keeps his pace through the level")
	var last := 0.0
	var top := 0.0
	while w.state == World.State.RUNNING and w.ticks < 3000:
		var x0 := w.x
		w.tick()
		last = w.x - x0
		top = maxf(top, last)
	_check(w.state == World.State.WON and top <= World.HOME_PACE + 0.01 and last <= World.HOME_DOOR_PACE + 1.5,
			"he runs home and slows into the doorway (top %.1f, last %.1f units a tick)" % [top, last])


func _test_step_cap() -> void:
	var w := _standing_world()
	for i in 200:
		w.step_forward()
		w.tick()
	_check(w.x <= World.MAX_X + 0.01, "swipes can't walk him past the middle of the screen (x=%.0f)" % w.x)


## The rules run whole 40 Hz ticks whatever the frame rate: the same input on the same tick gives
## the same game at 30, 60, 120 and 144 Hz.
func _test_frame_rates() -> void:
	var results := []
	for hz in [30.0, 60.0, 120.0, 144.0]:
		var w := World.new()
		var seen := []
		var input := func(world: World) -> void:
			if world.ticks == 119:
				world.jump()
			if world.ticks == 300:
				seen.append([snappedf(world.scroll, 0.001), snappedf(world.y, 0.001), world.lives])
		for f in int(hz * 8.0):
			w.advance(1.0 / hz, input)
		results.append(seen)
	_check(results.all(func(r: Array) -> bool: return r == results[0] and r.size() == 1),
			"same game at 30/60/120/144 Hz %s" % [results])
	var w := World.new()
	w.advance(5.0)  # a long hitch doesn't run the game ahead in a burst
	_check(w.ticks <= World.MAX_TICKS_PER_ADVANCE, "a hitch runs at most %d ticks" % World.MAX_TICKS_PER_ADVANCE)


## Doing nothing: the first wall stops him and the two bandits before it take two lives.
func _test_idle() -> void:
	var w := World.new()
	for i in 1200:
		w.tick()
	# (2017: 1 life left; the first-screen bandit is gone now)
	_check(w.state == World.State.RUNNING and w.blocked and w.lives == 2, "idle: stopped at the first wall with 2 lives left (%d)" % w.lives)


func _test_stars() -> void:
	var w := World.new()
	w.state = World.State.WON
	w.bobs = 30
	_check(w.stars() == 1, "home with few Red Bobs: 1 star")
	w.bobs = 60
	_check(w.stars() == 2, "half the Red Bobs: 2 stars")
	w.bobs = 90
	_check(w.stars() == 3, "80 % of them without losing a life: 3 stars")
	w.lives = 2
	_check(w.stars() == 2, "80 % but hurt: 2 stars")


func _test_save() -> void:
	var before := Save.games_played
	var w := World.new()
	w.bobs = 12
	w.state = World.State.DEAD
	var news := Save.record_run(w)
	_check(Save.games_played == before + 1 and Save.best_bobs >= 12, "a run is recorded")
	_check(news.best_bobs or Save.best_bobs > 12, "a better count is a new best")


func _test_translations() -> void:
	var rows := []
	var f := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
	var header := f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= header.size() and not row[0].is_empty():
			rows.append(row)
	for row: PackedStringArray in rows:
		_check(not row[1].is_empty() and not row[2].is_empty(), "%s has English and French" % row[0])
	for locale in ["en", "fr"]:
		TranslationServer.set_locale(locale)
		_check(tr("PLAY") != "PLAY", "%s translation is loaded" % locale)
	# Every key the code asks for exists.
	var keys := {}
	for row: PackedStringArray in rows:
		keys[row[0]] = true
	var used := RegEx.create_from_string("tr\\(\"([A-Z_]+)\"\\)")
	for path in _scripts("res://src"):
		for m in used.search_all(FileAccess.get_file_as_string(path)):
			_check(keys.has(m.get_string(1)), "%s used in %s is translated" % [m.get_string(1), path.get_file()])
	Save.apply_language()


func _test_config() -> void:
	_check(Config.value("ads", "interstitial_every_game_overs", 0) == 5, "an interstitial every 5 game overs")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == "gl_compatibility",
			"Compatibility renderer on phones")
	_check(ProjectSettings.get_setting("display/window/handheld/orientation") == 4, "landscape, both ways")
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") == OK:
		for section in presets.get_sections():
			if presets.get_value(section, "platform", "") == "Android":
				var opts := section + ".options"
				_check(presets.get_value(opts, "version/code", 0) >= 10, "Android version code above the old 3")
				_check(presets.get_value(opts, "gradle_build/target_sdk", "") == "36", "target SDK 36")
				_check(presets.get_value(opts, "package/unique_name", "") == "com.HaizStudio.ChakaZulu", "same package")


func _test_bot() -> void:
	var r := Bot.new(1).play(World.new())
	_check(r.state == World.State.WON, "the bot gets home (%s)" % [r])
	print("  bot: ", r)


## A world where Panoramic stands on the starting grass, no bandit around.
func _standing_world() -> World:
	var w := World.new()
	for b in w.bandits:
		b.gone = true
	for i in 30:
		w.tick()
	return w


## Brings a bandit back `ahead` units in front of Panoramic, on his ground.
func _bandit_ahead(w: World, ahead: float, index := 10) -> World.Bandit:
	var b: World.Bandit = w.bandits[index]
	b.gone = false
	b.active = true
	b.health = World.BANDIT_HEALTH
	b.strong = false  # (the plain kind, no leap: the tests of other things)
	b.jumper = false
	b.dodges = 0
	b.x = w.scroll + w.x + ahead
	b.y = w.y + 10.0
	return b


func _scripts(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out += _scripts(dir.path_join(d))
	return out


## The art preloaded during the logo and menu is all there (one thread per picture, then kept).
func _test_preload() -> void:
	GameArt.preload_art()
	var t := Time.get_ticks_msec()
	while GameArt.preloaded_count() < 40 and Time.get_ticks_msec() - t < 20000:
		GameArt.collect_preloaded()
		OS.delay_msec(20)
	_check(GameArt.preloaded_count() >= 40, "the game's pictures preload in the background (%d)" % GameArt.preloaded_count())
	# Every load finished before anything else runs: the headless renderer's texture table is not
	# thread-safe, and a picture still loading on a thread while a screen opens could fail it (the
	# intermittent "Parameter t is null" in texture_2d_initialize; phones' renderers lock it).
	while not GameArt._pending.is_empty() and Time.get_ticks_msec() - t < 30000:
		GameArt.collect_preloaded()
		OS.delay_msec(20)
	_check(GameArt._pending.is_empty(), "every preload has finished")


func _test_debug_silent() -> void:
	var silent := OS.is_debug_build() and not EngineDebugger.is_active()
	_check(AudioServer.is_bus_mute(0) == silent, "silent only in debug runs started outside the Godot editor")


# ------------------------------------------------------------------ release checks (QA)

const Capture := preload("res://tests/capture.gd")
const RAW_KEY := "^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$"  ## a translation key shown as is (TAP_TO_START)
const CARD_FRAME := 12.0  ## units of a card's frame a stamp may not cover
var _layout_checked := 0  # buttons, texts and lists checked by _layout_problems
const FAST := 20.0  ## Engine.time_scale while screens are tested (tweens, timers and the world)


## Collects the errors and warnings Godot prints (push_error, failed checks, script errors).
## Errors raised inside the headless stand-in renderer (servers/rendering/dummy) are its own, not the
## game's: it creates textures without a lock, so a picture loading on a thread can collide with one made
## on the main thread ("Parameter t is null" in texture_2d_initialize, once in a while on a cold disk
## cache). They are counted in `harness` and printed, not failed; every windowed capture, strip and perf
## run (the real renderer) would show a real one.
class ErrorLog extends Logger:
	var lines := PackedStringArray()
	var harness := PackedStringArray()
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if "/rendering/dummy/" in file:
			_mutex.lock()
			harness.append("%s (%s:%d)" % [rationale if rationale else code, file.get_file(), line])
			_mutex.unlock()
			return
		# where in our scripts it came from (the innermost frame), and from which thread
		var at := ""
		for bt in script_backtraces:
			if bt.get_frame_count() > 0:
				at = " from %s:%d" % [bt.get_frame_file(0).get_file(), bt.get_frame_line(0)]
				break
		_mutex.lock()
		lines.append("%s%s (%s:%d %s%s%s)" % ["WARNING: " if error_type == ERROR_TYPE_WARNING else "", rationale if rationale else code,
				file.get_file(), line, function, at, "" if OS.get_thread_caller_id() == OS.get_main_thread_id() else ", a loading thread"])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := lines.duplicate()
		lines.clear()
		_mutex.unlock()
		return out


## Plays like a player who taps every few ticks and jumps now and then, the same on every run
## (cheap, unlike Bot): an autopilot for the game screen.
class Scripted extends RefCounted:
	func act(w: World) -> void:
		if w.ticks % 6 == 0:
			w.throw()
		if w.ticks % 47 == 11:
			w.jump()
		if w.ticks % 131 == 60:
			w.step_forward()
		if w.hanging and w.ticks % 89 == 0:
			w.down()


## EN and FR texts take the same placeholders (%s, %d): a missing one breaks the text at run time.
## Every key is in the compiled translations of both languages.
func _test_translation_formats() -> void:
	var f := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
	f.get_csv_line()
	var holes := RegEx.create_from_string("%[0-9.]*[sdf%]")
	var wrong := []
	var missing := []
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 3 or row[0].is_empty():
			continue
		var en := holes.search_all(row[1]).map(func(m: RegExMatch) -> String: return m.get_string())
		var fr := holes.search_all(row[2]).map(func(m: RegExMatch) -> String: return m.get_string())
		en.sort()
		fr.sort()
		if en != fr:
			wrong.append(row[0])
		for locale in ["en", "fr"]:
			TranslationServer.set_locale(locale)
			if tr(row[0]) == row[0]:
				missing.append("%s/%s" % [locale, row[0]])
	Save.apply_language()
	_check(wrong.is_empty(), "English and French texts take the same %%s and %%d (%s)" % [wrong])
	_check(missing.is_empty(), "every key is in the compiled translations (re-import the CSV) (%s)" % [missing])


## Every sound the code plays exists, every variant file Audio lists is there (a missing one is
## skipped in silence), and both screens have their music.
func _test_sounds() -> void:
	var played := RegEx.create_from_string("play_sfx\\(&\"([a-z_0-9]+)\"")
	var unknown := []
	for path in _scripts("res://src"):
		for m in played.search_all(FileAccess.get_file_as_string(path)):
			if not Audio.has_sfx(StringName(m.get_string(1))):
				unknown.append("%s (%s)" % [m.get_string(1), path.get_file()])
	_check(unknown.is_empty(), "every sound the code plays has a file %s" % [unknown])
	var missing := []
	for name: StringName in Audio.SFX:
		for file: String in Audio.SFX[name]:
			if not ResourceLoader.exists("res://assets/audio/%s.wav" % file):
				missing.append(file)
	_check(missing.is_empty(), "every variant Audio lists is there %s" % [missing])
	var music := Audio.MUSIC.keys().filter(func(n: StringName) -> bool: return not Audio._music_streams.has(n))
	_check(music.is_empty(), "the menu and the game have music %s" % [music])


## Every setting and record survives a save and a load with its type, through the real files
## (Save.write() and Save._load() on a scratch path, not the player's save), and every variable of
## Save that should last is saved (not `persist`, `path`, `loaded_from` nor the session's ad counter).
func _test_save_round_trip() -> void:
	var script: GDScript = load("res://src/autoload/save.gd")
	var a: Node = script.new()
	var b: Node = script.new()
	var keys: Array = a.get("_KEYS")
	var unsaved := []
	for p: Dictionary in script.get_script_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not p.name.begins_with("_") \
				and not StringName(p.name) in keys and p.name not in ["persist", "game_overs_since_ad", "path", "loaded_from"]:
			unsaved.append(p.name)
	_check(unsaved.is_empty(), "every lasting variable of Save is saved (%s)" % [unsaved])
	for key: StringName in keys:  # values unlike the defaults, and valid (Save checks ranges on load)
		var v: Variant = a.get(key)
		match typeof(v):
			TYPE_BOOL: a.set(key, not v)
			TYPE_INT: a.set(key, 2 if key == &"best_stars" else v + 7)
			TYPE_FLOAT: a.set(key, 0.375)
			TYPE_STRING: a.set(key, "fr")
	var dir := "user://qa_save_round_trip"
	DirAccess.make_dir_recursive_absolute(dir)
	for x in [a, b]:
		x.path = dir.path_join("save.cfg")
		x.persist = true
	a.write()
	b._load()
	var differ := keys.filter(func(key: StringName) -> bool: return typeof(a.get(key)) != typeof(b.get(key)) or a.get(key) != b.get(key))
	_check(b.loaded_from == "save" and differ.is_empty(), "a save loads back the same, types too (from %s, %s)" % [b.loaded_from, differ])
	a.write()  # a second save keeps the first as the backup
	_check(FileAccess.file_exists(a.path + ".bak") and not FileAccess.file_exists(a.path + ".tmp"), "saving again keeps a backup, no stray .tmp")
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	a.free()
	b.free()


## The same input gives the same game at 30, 60, 120 and 144 Hz and at an uneven frame rate (a phone
## dropping frames), checked every 2.5 s: a scripted player until he is caught, and the bot's
## recorded run through the whole level (when it is in build/qa/).
func _test_determinism() -> void:
	var pilots := {"scripted": Scripted.new()}
	if FileAccess.file_exists("%s/bot_1_%s.json" % [BotReplay.CACHE_DIR, BotReplay._sources_hash()]):
		pilots["bot"] = BotReplay.recorded(1)
	for pilot_name: String in pilots:
		var pilot: Object = pilots[pilot_name]
		var runs := {}
		var jitter := RandomNumberGenerator.new()
		jitter.seed = 3
		for hz: float in [30.0, 60.0, 120.0, 144.0, 0.0]:
			var w := World.new()
			var seen := []
			var mark := func(world: World) -> void:
				pilot.act(world)
				if world.ticks % 100 == 99:
					seen.append(_fingerprint(world))
			while w.ticks < 9000 and w.state == World.State.RUNNING:
				w.advance(1.0 / hz if hz > 0.0 else jitter.randf_range(1.0 / 144.0, 1.0 / 24.0), mark)
			seen.append(_fingerprint(w))
			runs[hz] = seen
		var same := runs.values().all(func(r: Array) -> bool: return r == runs[30.0])
		_check(same and runs[30.0].size() >= 3, "%s: same game at 30/60/120/144 Hz and an uneven rate (%d marks)" % [pilot_name, runs[30.0].size()])


func _fingerprint(w: World) -> String:
	var parts := [w.ticks, w.state, snappedf(w.scroll, 0.001), snappedf(w.x, 0.001), snappedf(w.y, 0.001), snappedf(w.vy, 0.001),
			w.lives, w.bobs, w.knocked_out, w.hanging, w.rings.size()]
	for b in w.bandits:
		if not b.gone:
			parts.append_array([b.id, snappedf(b.x, 0.01), snappedf(b.y, 0.01), b.health])
	return str(parts)


## Every screen at every device size, in English and French.
func _test_screens() -> void:
	var log := ErrorLog.new()
	OS.add_logger(log)
	Engine.time_scale = FAST
	var shown := 0
	for lang in ["en", "fr"]:
		Save.language = lang
		Save.apply_language()
		for device: String in Capture.DEVICES:
			var vp := _device_viewport(device)
			for shot in ["boot", "menu", "settings", "start", "game", "pause", "gameover", "win"]:
				await _open(shot)
				var where := "%s %s %s" % [lang, device, shot]
				var errors := log.take()
				_check(errors.is_empty(), "%s: no error or warning %s" % [where, errors])
				var problems := _layout_problems(Capture.DEVICES[device])
				_check(problems.is_empty(), "%s: buttons and texts in the safe area, whole, translated %s" % [where, problems])
				if shot in ["gameover", "win"]:
					var results := _results_problems(Capture.DEVICES[device])
					_check(results.is_empty(), "%s: the new best's stamp centred in its row, clear of the card's frame; the hero on screen %s" % [where, results])
				shown += 1
			await _close(vp)
	Engine.time_scale = 1.0
	OS.remove_logger(log)
	if not log.harness.is_empty():
		print("  (headless renderer, not the game: %s)" % [log.harness])
	Save.language = ""
	Save.apply_language()
	print("  %d screens checked (%d buttons, texts and lists), %d frames a second" % [shown, _layout_checked, Engine.get_frames_per_second()])


## The buttons' sweep of light at every moment of its way across: no slice Godot cannot draw (at random moments of
## the screen checks it logged "Invalid polygon data, triangulation failed" from juicy_button.gd), and the band still
## lights the face, on faces where the clipped band leaves such slivers. (The per-device sweep of every shining
## button was left out when the tests were cut to the 100 most important.)
func _test_shine_sweeps() -> void:
	for spec in [[Rect2(0, 0, 300, 80), 40.0], [Rect2(4, 3, 236, 62), 31.0], [Rect2(0, 0, 200, 60), 18.0]]:
		var bad := _sweep_problems(spec[0], spec[1])
		_check(bad.is_empty(), "the sweep of light leaves out the slivers on a %s face %s" % [spec[0].size, bad])


## What is wrong with the sweep of light on a face: a slice Godot cannot triangulate, or (almost) no light. Tried every
## 1000th of the way, and where a slice's edge crosses a point of the face's rounded outline, and a hair either side
## (the slivers, about 0.05 px wide, were there).
func _sweep_problems(face: Rect2, radius: float) -> PackedStringArray:
	var ks := PackedFloat64Array()
	for i in 1000:
		ks.append(i / 1000.0)
	var w := face.size.y * 1.1  # (the band's width, slant and travel, as JuicyButton._Shine.sweep())
	var start := face.position.x - w * 2
	var span := face.end.x + w - start
	for v in GlossStyle.rounded_points(face, radius):
		for edge in 7:
			var x := v.x - w * edge / 6.0 - face.size.y * 0.5 * (face.end.y - v.y) / face.size.y
			for e in [0.0, 1e-7, -1e-7, 1e-5, -1e-5, 1e-3, -1e-3]:
				var k: float = (x - start) / span + e
				if k >= 0.0 and k < 1.0:
					ks.append(k)
	var bad := PackedStringArray()
	var lit := 0
	for k in ks:
		for poly in JuicyButton._Shine.sweep(face, radius, k):
			if Geometry2D.triangulate_polygon(poly).is_empty():
				bad.append("k=%.9f" % k)
			lit += 1
	if lit < 100:
		bad.append("only %d slices of light" % lit)
	return bad


## Back on the menu after a run (paused, resumed, lost) nothing of it is left: not a node, not an
## orphan; and a second run leaves no more than the first.
func _test_no_leaks() -> void:
	Engine.time_scale = FAST
	var vp := _device_viewport("iphone15_2556x1179")
	await _open("menu")
	await _frames(10)
	var counts := [_counts()]
	var bests := [Save.best_bobs, Save.best_stars, Save.games_played]
	for run in 2:
		await _open("game")
		Nav.current.autopilot = Scripted.new()
		await _wait(4.0)
		Nav.current.pause_game()
		await _wait(0.5)
		Nav.current.resume_game()
		await _wait(3.0)
		Nav.current.world._die(&"bandit")
		await _wait(3.0)
		Save.best_bobs = bests[0]  # (a new best changes the menu: not a leak)
		Save.best_stars = bests[1]
		Save.games_played = bests[2]
		await _open("menu")
		await _frames(10)
		counts.append(_counts())
	await _close(vp)
	Engine.time_scale = 1.0
	_check(counts[1].nodes <= counts[0].nodes and counts[1].orphans <= counts[0].orphans,
			"back on the menu after a run, no node is left behind (%s)" % [counts])
	_check(counts[2].nodes <= counts[1].nodes and counts[2].orphans <= counts[1].orphans and counts[2].objects - counts[1].objects < 50,
			"a second run leaves nothing more (%s)" % [counts])


func _counts() -> Dictionary:
	return {"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT))}


## Pausing at random moments (on a hit-stop, in the countdown, in the air) stops the world while
## paused and through the countdown, and changes nothing in the game: it ends up where the same
## input takes it without pauses.
func _test_pause_anywhere() -> void:
	Engine.time_scale = FAST
	var vp := _device_viewport("iphone15_2556x1179")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	await _open("game")
	var game: Node = Nav.current
	game.autopilot = Scripted.new()
	var held := true
	for i in 6:
		await _wait(rng.randf_range(0.05, 2.0))
		if game.world.state != World.State.RUNNING:
			break
		game.pause_game()
		var ticks: int = game.world.ticks
		await _wait(rng.randf_range(0.1, 1.0))
		held = held and game.world.ticks == ticks
		game.resume_game()
		await _wait(0.3)  # in the countdown
		held = held and game.world.ticks == ticks
	await _wait(2.0)
	var played: World = game.world
	var alone := World.new()
	alone.stand_at_start()  # as the game screen's own world
	var pilot := Scripted.new()
	while alone.ticks < played.ticks and alone.state == World.State.RUNNING:
		pilot.act(alone)
		alone.tick()
	_check(held, "paused and counting down, the world doesn't move")
	_check(played.ticks > 200 and _fingerprint(alone) == _fingerprint(played),
			"pausing at random moments changes nothing (%d ticks)" % played.ticks)
	await _close(vp)
	Engine.time_scale = 1.0


## The bot's recorded run gets home through the real game screen, and the end panel shows. Needs
## the recording (build/qa/, made by --bot or by the first capture or perf run).
func _test_replay_home() -> void:
	if "--bot" not in OS.get_cmdline_user_args() and not FileAccess.file_exists(
			"%s/bot_1_%s.json" % [BotReplay.CACHE_DIR, BotReplay._sources_hash()]):
		print("  (the bot's run through the game screen skipped: no recording yet; run with --bot once)")
		return
	var replay := BotReplay.recorded(1)
	Engine.time_scale = 20.0
	var vp := _device_viewport("iphone15_2556x1179")
	await _open("level", {"world": World.new()})  # the world the bot was recorded on, no autopilot yet
	var game: Node = Nav.current
	game.autopilot = replay
	var t0 := Time.get_ticks_msec()
	while game.world.state == World.State.RUNNING and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().process_frame
	await _wait(4.0)
	var buttons := game.find_children("*", "BaseButton", true, false).filter(func(n: Control) -> bool: return n.is_visible_in_tree())
	_check(game.world.state == World.State.WON and game.world.lives == replay.result.lives,
			"the bot's run gets home through the game screen (%s, %d lives)" % [World.State.keys()[game.world.state], game.world.lives])
	_check(buttons.size() >= 2, "and the end panel shows its buttons (%d)" % buttons.size())
	await _close(vp)
	Engine.time_scale = 1.0


## What the tracks' pieces expect of each other, in the real game (merges have dropped them before):
## the footsteps follow the hero's run (Footsteps reads HeroView.run_frame(), or run_a/run_b poses).
func _test_contracts() -> void:
	Engine.time_scale = FAST
	var vp := _device_viewport("iphone15_2556x1179")
	await _open("game")
	var game: Node = Nav.current
	var hero: Node = game.view.get(&"_hero")
	var poses := {}
	var frames := 0
	for i in 60:
		await get_tree().process_frame
		if game.world.on_ground and not game.world.jumping:
			poses[hero.pose()] = true
			if hero.has_method(&"run_frame") and hero.run_frame() >= 0.0:
				frames += 1
	var steps := frames > 0 or Footsteps.RUN_POSES.any(func(p: StringName) -> bool: return poses.has(p))
	_check(steps, "the footsteps can follow the hero's run (run_frame() or run_a/run_b; poses seen %s)" % [poses.keys()])
	await _close(vp)
	Engine.time_scale = 1.0


## The HUD fits in the band the camera keeps free for it over the vine (GameScreen.HUD_BAND), on
## every device: with a status bar or a notch at the top (the iPad's 48 px) the plates move down by
## that inset, and hanging from the vine he would touch them. (2 units of slack: the plates' shadows.)
func _test_hud_band() -> void:
	Engine.time_scale = FAST
	for device: String in Capture.DEVICES:
		var vp := _device_viewport(device)
		await _open("level")
		var game: Node = Nav.current
		await _frames(3)
		var bottom := 0.0
		for name: StringName in [&"_lives_glass", &"_track_glass", &"_count_box", &"_pause"]:
			var plate: Control = game.hud.get(name)
			if plate and plate.is_visible_in_tree():
				bottom = maxf(bottom, plate.get_global_rect().end.y)
		var band: float = GameScreenScript().hud_band()  # (env: the band with the screen's top inset)
		_check(bottom <= band + 2.0, "%s: the HUD (down to y %.1f) fits in the band kept for it over the vine (%.0f)" % [device, bottom, band])
		await _close(vp)
	Engine.time_scale = 1.0


## A viewport at a device's size and notches (tests/capture.gd), holding the screens.
func _device_viewport(device: String) -> SubViewport:
	var px: Vector2i = Capture.DEVICES[device].size
	var design := Vector2(640.0 * px.x / px.y, 640.0)
	Device.debug_insets = Capture.DEVICES[device].insets * (design.y / px.y)
	Device.banner_height = 0.0
	var holder := SubViewportContainer.new()  # (a bare SubViewport has no screen transform)
	add_child(holder)
	var vp := SubViewport.new()
	vp.size = px
	vp.size_2d_override = Vector2i(design.round())
	vp.size_2d_override_stretch = true
	holder.add_child(vp)
	var host := Control.new()
	host.size = design
	vp.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Nav.custom_viewport = vp
	Nav.attach(host)
	return vp


func _close(vp: SubViewport) -> void:
	if Nav.current:
		Nav.current.queue_free()
	Nav.reset()
	Nav.custom_viewport = get_tree().root
	vp.get_parent().queue_free()
	Device.debug_insets = Vector4(-1, -1, -1, -1)
	get_tree().paused = false
	await _frames(2)


## Opens a screen (or a moment of the game: pause, the end panels; "level": the game waiting on its
## start card) and lets it settle.
func _open(shot: String, data := {}) -> void:
	while Nav.is_busy():
		await get_tree().process_frame
	Save.tutorial_seen = shot != "start"
	match shot:
		"boot", "menu", "settings":
			Nav.go(StringName(shot))
		_:
			Nav.go(&"game", data)
	while Nav.is_busy():
		await get_tree().process_frame
	await _wait(1.6)  # the menu's arrival, the start card
	var game: Node = Nav.current if Nav.current_name == &"game" else null
	match shot:
		"game":
			game.autopilot = Scripted.new()
			await _wait(2.0)
		"pause":
			game.autopilot = Scripted.new()
			await _wait(1.0)
			game.pause_game()
			await _wait(0.6)
		"gameover":
			game.autopilot = Scripted.new()
			await _wait(1.0)
			Save.best_bobs = 0  # a new best: its stamp is part of the panel to check
			game.world.bobs = maxi(game.world.bobs, 5)  # (however few the autopilot took in its second: a slow machine)
			game.world._die(&"bandit")
			await _wait(World.DYING_TIME + Capture.REVEAL)  # his death, then the panel and its whole reveal
		"win":
			game._start()  # (a run is under way: the start card has gone)
			Save.best_bobs = 0
			Save.best_stars = 0
			game.world.bobs = 40
			game.world.state = World.State.WON
			game.world.won.emit()
			await _wait(World.HOME_TIME + Capture.REVEAL + 0.6)


## What's wrong with the layout on screen: buttons and texts outside the safe area or the screen,
## cut texts, raw keys. Texts in a scrolling list count as the list.
func _layout_problems(device: Dictionary) -> Array:
	var screen: Control = Nav.current
	var px: Vector2i = device.size
	var design := Vector2(640.0 * px.x / px.y, 640.0)
	var k := design.y / px.y
	var insets: Vector4 = device.insets * k
	var safe := Rect2(insets.x, insets.y, design.x - insets.x - insets.z, design.y - insets.y - insets.w).grow(1.0)
	var raw := RegEx.create_from_string(RAW_KEY)
	var problems := []
	for c: Control in screen.find_children("*", "Control", true, false):
		if not c.is_visible_in_tree() or c.modulate.a < 0.05 or c.size == Vector2.ZERO:
			continue
		var text: String = c.text if c is Label or c is BaseButton or c is DisplayText else ""
		if raw.search(text):
			problems.append("raw key %s" % text)
		if not (c is BaseButton or c is Label or c is DisplayText or c is ScrollContainer):
			continue
		if _in_scroll(c, screen) or (c is DisplayText and text.strip_edges().is_empty()):
			continue
		var r: Rect2 = c.get_global_transform() * Rect2(Vector2.ZERO, c.size)
		_layout_checked += 1
		if not safe.encloses(r):
			problems.append("%s '%s' at %s outside %s" % [c.get_class() if not c.get_script() else c.get_script().resource_path.get_file(),
					text.left(20), r, safe])
		if c is Label and c.autowrap_mode != TextServer.AUTOWRAP_OFF and c.get_visible_line_count() < c.get_line_count():
			problems.append("'%s' cut: %d of %d lines" % [text.left(20), c.get_visible_line_count(), c.get_line_count()])
	return problems


## What's wrong with an end panel (a new best forced): its badge (BurstBadge) off the middle of the
## place kept for it or over the card's frame (a stamp was once centred from its size before it
## entered the tree), the hero's picture or his dais off the screen.
func _results_problems(device: Dictionary) -> Array:
	var px: Vector2i = device.size
	var screen := Rect2(Vector2.ZERO, Vector2(640.0 * px.x / px.y, 640.0))
	var panel: GamePanel = null
	for c: Control in Nav.current.find_children("*", "Control", true, false):
		if c is GamePanel:
			panel = c
	if panel == null:
		return ["no end panel"]
	var problems := []
	var card: Rect2 = panel.card.get_global_transform() * Rect2(Vector2.ZERO, panel.card.size)
	var stamps := 0
	for badge: Control in panel.find_children("*", "Control", true, false):
		if not badge is BurstBadge:
			continue
		stamps += 1
		var slot := badge.get_parent() as Control
		var r: Rect2 = badge.get_global_transform() * Rect2(Vector2.ZERO, badge.size)  # as drawn, tilted
		var middle: float = (slot.get_global_transform() * Rect2(Vector2.ZERO, slot.size)).get_center().x
		if absf(r.get_center().x - middle) > 4.0:
			problems.append("stamp centred at x %.0f, its place at %.0f (placed for %s)" % [r.get_center().x, middle,
					badge.size.round()])
		if not card.grow(-CARD_FRAME).encloses(r):
			problems.append("stamp %s over the card's frame (card %s)" % [r, card])
	if stamps == 0:
		problems.append("no new best stamp")
	if panel.art:
		var a: Rect2 = panel.art.get_global_transform() * Rect2(Vector2.ZERO, panel.art.size)
		if not screen.grow(1.0).encloses(a):
			problems.append("the hero's picture %s off the screen %s" % [a, screen])
		var dais: Variant = panel.get(&"_dais")  # (UI r21) the ground he stands on, whole on the screen
		if dais is Control and (dais as Control).visible:
			var d: Rect2 = (dais as Control).get_global_transform() * (dais as Control).call(&"drawn_rect")
			if not screen.grow(1.0).encloses(d):
				problems.append("his dais %s off the screen %s" % [d, screen])
	return problems


static func _in_scroll(c: Control, top: Node) -> bool:
	var p := c.get_parent()
	while p and p != top:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, false).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ------------------------------------------------------------------ audio track

class _FakeHero extends Node:
	var p := &"run_a"

	func pose() -> StringName:
		return p


class _FakeRun3D extends Node:
	var frame := -1.0

	func run_frame() -> float:
		return frame


class _FakeHeroClock extends Node:  # the 3D hero before run_frame(): its run clock and its animation
	var _run := 0.0
	var anim := &"run"

	func pose() -> StringName:
		return anim


## Sounds, music, buses, settings, haptics, footsteps and reduced motion (the audio track).
func _test_audio() -> void:
	for name: StringName in Audio.SFX:
		var takes: Array = Audio._streams.get(name, [])
		_check(takes.size() == Audio.SFX[name].size(), "every take of the sound %s exists" % name)
		for s: AudioStream in takes:
			var limit := 0.75 if name in [&"footstep", &"jump", &"land", &"throw", &"step", &"tick", &"button", &"hang"] else 4.0
			_check(s.get_length() > 0.03 and s.get_length() < limit, "%s is %.2f s (frequent sounds stay short)" % [s.resource_path, s.get_length()])
	for name: StringName in [&"menu", &"game"]:
		var m: AudioStreamOggVorbis = Audio._music_streams.get(name)
		_check(m != null and m.loop and m.get_length() > 30.0, "the %s theme exists and loops" % name)
	_check(Audio._ambience.stream != null and Audio._ambience.stream.loop, "the savanna ambience loops")
	for name: StringName in Audio.STINGERS:
		_check(Audio.has_sfx(name), "the %s stinger exists" % name)
	for bus in [&"Music", &"Ambience", &"SFX", &"UI"]:
		_check(AudioServer.get_bus_index(bus) > 0, "bus %s exists" % bus)
	var limiter: AudioEffectHardLimiter = null
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			limiter = AudioServer.get_bus_effect(0, i)
	_check(limiter != null and limiter.ceiling_db <= -1.0, "Master ends in a limiter at -1 dB")
	# the settings mute the right buses
	var music: bool = Save.music_on
	var sounds: bool = Save.sounds_on
	Save.music_on = false
	Save.sounds_on = true
	Audio.apply_settings()
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")),
			"music off mutes only the music")
	Save.music_on = true
	Save.sounds_on = false
	Audio.apply_settings()
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")) and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX"))
			and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"UI")) and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambience")),
			"sounds off mutes the effects, the interface and the ambience")
	Save.music_on = music
	Save.sounds_on = sounds
	Audio.apply_settings()
	# a burst of one sound stays within its voices; the tuned takes are picked by the game
	for i in 6:
		Audio.play_sfx(&"footstep")
	var steps := Audio._sfx.filter(func(p: AudioStreamPlayer) -> bool: return p.playing and p.get_meta(&"name", &"") == &"footstep").size()
	_check(steps <= Audio.HOW[&"footstep"].voices, "a burst of footsteps stays within its voices (%d)" % steps)
	for p in Audio._sfx:
		p.stop()
	for i in 8:
		Audio.play_tuned(&"bob", i)
		_check(Audio._sfx.any(func(p: AudioStreamPlayer) -> bool: return p.playing and p.stream.resource_path.ends_with("sfx_bob_%d.wav" % (i + 1))),
				"Red Bob %d of a streak plays step %d of the scale" % [i + 1, i + 1])
	Audio._duck = 0.0
	Audio.play_sfx(&"knock_out")
	_check(Audio._duck >= 4.0, "the music dips under a knock-out")
	Audio.stinger(&"win")
	_check(Audio._after_stinger == &"menu" and Audio._current.is_empty(), "a stinger makes the music wait, then the menu theme")
	Audio.play_music(&"game")
	_check(Audio._after_stinger.is_empty() and Audio._current == &"game", "playing again cancels the music after the stinger")
	# footsteps follow the run animation's foot contacts
	var even := Footsteps.CONTACTS.size() == 2 and Footsteps.RUN_FRAMES == HeroView.RUN_FRAMES
	for i in Footsteps.CONTACTS.size() - 1:
		even = even and absf(Footsteps.CONTACTS[i + 1] - Footsteps.CONTACTS[i] - Footsteps.RUN_FRAMES / 2.0) < 0.01
	_check(even, "the run's two foot contacts are half a loop apart (one stride: both steps)")
	_check(Footsteps.crossed(4.0, 6.0, 5.0) and not Footsteps.crossed(6.0, 12.0, 5.0) and Footsteps.crossed(12.5, 1.0, 13.0)
			and not Footsteps.crossed(15.5, 1.0, 5.0), "a contact counts once as the frame passes it, across the loop")
	var w := _standing_world()
	var hero := _FakeHero.new()
	var feet := Footsteps.new(w, hero)
	feet._process(0.0)
	var before := Audio.sfx_count
	hero.p = &"run_b"
	feet._process(0.0)
	_check(Audio.sfx_count == before + 1 and Audio.last_sfx == &"footstep", "a foot landing in the drawn run sounds a step")
	hero.p = &"crouch"
	feet._process(0.0)
	hero.p = &"run_a"
	feet._process(0.0)
	_check(Audio.sfx_count == before + 1, "no step out of a crouch")
	var run3d := _FakeRun3D.new()
	var feet3d := Footsteps.new(w, run3d)
	before = Audio.sfx_count
	for f in [0.5, 1.5, 4.5, 6.9, 7.2, 9.0, 11.8, 0.4]:
		run3d.frame = f
		feet3d._process(0.0)
	_check(Audio.sfx_count == before + 2, "the drawn run sounds a step as a boot comes down, at drawings 1 and 7 (%d)" % (Audio.sfx_count - before))
	for n: Node in [hero, run3d, feet, feet3d]:
		n.free()
	# haptics: off when the setting is off; a light one never cuts into a heavy one
	var vib: bool = Save.vibration_on
	Haptics.record = true
	Haptics.played.clear()
	Haptics._busy_until = 0
	Save.vibration_on = false
	Haptics.hurt()
	_check(Haptics.played.is_empty(), "no vibration when vibration is off")
	Save.vibration_on = true
	Haptics.hurt()
	Haptics.pickup()
	_check(Haptics.played == ["hurt"], "a light vibration doesn't cut into a heavy one (%s)" % [Haptics.played])
	Haptics._busy_until = 0
	Haptics._last.clear()  # (no pickup from an earlier test inside the repeat window)
	Haptics.played.clear()
	Haptics.pickup()
	Haptics.pickup()
	_check(Haptics.played == ["pickup"], "the same light vibration waits before it plays again")
	Haptics.record = false
	Haptics._busy_until = 0
	Save.vibration_on = vib
	# reduced motion (Settings: Save.reduce_motion)
	var calm: bool = Save.reduce_motion
	Save.reduce_motion = true
	_check(Fx.calm(), "reduced motion turns the camera's shake and kicks off")
	Save.reduce_motion = false
	_check(not Fx.calm(), "full motion by default")
	Save.reduce_motion = calm
	# round 2: the player's volumes stay theirs; the mood and the dips work on the Music bus's gain
	var music_bus := AudioServer.get_bus_index(&"Music")
	var fader := AudioServer.get_bus_volume_db(music_bus)
	AudioServer.set_bus_volume_db(music_bus, -12.0)
	Audio.duck(6.0)
	Audio.set_mood(&"paused")
	Audio._process(0.1)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), -12.0) and Audio._gain.volume_db < -1.0,
			"the music's mood and dips leave the player's music volume alone")
	AudioServer.set_bus_volume_db(music_bus, fader)
	Audio.set_mood(&"play")
	Audio._duck = 0.0
	for bus: StringName in [&"UI", &"Ambience"]:
		_check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) == &"SFX", "%s goes through the sounds' bus (its volume, its switch)" % bus)
	_check(Audio.MUSIC_DB[&"game"] <= Audio.MUSIC_DB[&"menu"] - 5.0, "in play the music sits well under the effects")
	for name: StringName in [&"hurt", &"knock_out", &"death"]:
		_check(Audio._how(name).get("duck", 0.0) >= 4.0, "the music dips 4-6 dB under %s" % name)
	# lengths: the frequent ones never run over the next event
	for pair: Array in [[&"bob", 0.26], [&"knock_out", 0.52], [&"hurt", 0.42], [&"death", 0.9], [&"ring_hit", 0.37]]:
		for st: AudioStream in Audio._streams[pair[0]]:
			_check(st.get_length() <= pair[1], "%s lasts %.2f s (at most %.2f)" % [st.resource_path.get_file(), st.get_length(), pair[1]])
	for name: StringName in [&"footstep", &"jump", &"land", &"throw", &"ring_hit", &"knock_out", &"hurt", &"splash", &"hang", &"grab"]:
		_check(Audio._streams[name].size() >= 4, "%s has 4 takes or more" % name)
	for name: StringName in [&"streak", &"heart_break", &"last_heart", &"bump", &"grab", &"mantle", &"vine_creak", &"door", &"coins"]:
		_check(Audio.has_sfx(name), "the %s sound exists" % name)
	_check(Audio._drive.stream != null and is_equal_approx(Audio._drive.stream.get_length(), Audio._music_streams[&"game"].get_length()),
			"the game theme's drive layer is there, as long as the theme (they loop in sync)")
	Audio.play_music(&"menu")
	Audio.play_music(&"game")
	_check(Audio._drive.playing and Audio._music.playing, "the drive layer starts with the game theme")
	Audio.set_intensity(1.0)
	Audio._process(0.5)
	_check(Audio._drive.volume_db > Audio.SILENT_DB + 10.0, "on the home stretch the drive layer comes in")
	Audio.set_intensity(0.0)
	# the impacts: 3-5 frames of hit-stop, small < medium < fatal; a knock springs back
	var last := 0.0
	for kind: StringName in [&"small", &"medium", &"fatal"]:
		var preset: Dictionary = Fx.IMPACTS[kind]
		_check(preset.stop >= 2.9 / 60.0 and preset.stop <= 5.1 / 60.0 and preset.shake > last, "the %s impact holds 3-5 frames" % kind)
		last = preset.shake
	Fx.knock(&"test", Vector2(30, 0), 0.4)
	Fx.advance_knocks(0.08)
	var out := Fx.knock_offset(&"test")
	Fx.advance_knocks(0.4)
	_check(out.x > 15.0 and Fx.knock_offset(&"test") == Vector2.ZERO, "a knock pushes out fast, then springs back to its place")
	# footsteps on the new hero's run clock (until it has run_frame()), the throw included
	var w2 := _standing_world()
	var hero3d := _FakeHeroClock.new()
	var feet2 := Footsteps.new(w2, hero3d)
	before = Audio.sfx_count
	for f in [0.5, 1.5, 4.5, 6.9, 7.2, 11.0]:  # (steps at 1 running, at 7 throwing)
		hero3d._run = f
		hero3d.anim = &"throw" if f > 5.0 else &"run"
		feet2._process(0.0)
	_check(Audio.sfx_count == before + 2, "footsteps follow the hero's run clock, through a throw too")
	for n: Node in [hero3d, feet2]:
		n.free()
	# round 3: fireworks have a sound; the confetti has streamers
	_check(Audio.has_sfx(&"firework") and Confetti.SIZES.has(Confetti.Shape.STREAMER), "fireworks sound; the confetti has streamers")
	for p: AudioStreamPlayer in Audio._sfx + Audio._ui + [Audio._music, Audio._music_out, Audio._drive, Audio._ambience]:
		p.stop()


func _test_gameplay() -> void:
	await _folded("saves survive a killed app, a damaged file and an older version", _gp_saves)
	await _folded("taps, swipes, flicks and two thumbs read right", _gp_touches)
	await _folded("a move asked twice counts once; a swipe shows within 2 frames", _gp_input_rules)
	await _folded("the level's fixes (the roof, the last screen, the pools)", _gp_level_fixes)
	await _folded("what is drawn touching is what counts: rings, rock, blows", _gp_collisions)
	await _folded("what the views read: phases, the landing foreseen, progress in the air", _gp_view_hooks)
	await _folded("the game screen: dying, home, pausing at any moment", _gp_flow)
	if "--quick" not in OS.get_cmdline_user_args():
		await _folded("the camera shows what the player must see, on every device", _gp_camera)


## The camera's limits on every device (tests/capture.gd): through the real game screen, from moments
## that test them (running at the start and stepped right to the middle, on the high platform at
## column 180 where a jump reaches the vine, hanging over the pillars, caught, home), stepped by hand
## at a fixed CAMERA_STEP (the same frames on any machine, whatever its frame rate):
## - while he plays, the screen shows the whole play window's width (960): no bandit is seen later
##   than in 2017;
## - the camera always shows what it is easing toward (its eased must-see rect);
## - and what World.camera_must_see() asks, inside the safe area under the HUD band, no later than
##   CAMERA_GRACE after it grew (it eases in, never snaps; a Red Bob arc entering the 320 units ahead
##   raises it ~200 units at once, more than a second before he gets there).
const CAMERA_STEP := 1.0 / 30.0
const CAMERA_STEPS := 90
const CAMERA_GRACE := 0.15


func _gp_camera() -> void:
	Engine.time_scale = 4.0  # (the screens' opening tweens; the camera is stepped by hand)
	var moments := {
		"start": func(w: World) -> void: pass,
		"stepped right": func(w: World) -> void: w.x = World.MAX_X,
		"high platform": func(w: World) -> void:
			w.scroll = 180 * 32.0 - w.x
			w.y = 6 * 32 - 64.0
			w.ground_y = w.y,
		"hanging": func(w: World) -> void:
			w.scroll = 560 * 32.0 - w.x
			w.y = 0.0
			w.hanging = true
			w.on_ground = false,
		"caught": func(w: World) -> void: w._die(&"bandit"),
		"home": func(w: World) -> void:
			w.scroll = World.SCROLL_END
			w.at_end = true
			w.x = World.HOME_X
			w.end_at = Vector2(w.x, w.y)
			w.state = World.State.WON,
	}
	for device: String in Capture.DEVICES:
		var vp := _device_viewport(device)
		for name: String in moments:
			var w := World.new()
			w.stand_at_start()
			for b in w.bandits:
				b.gone = true
			(moments[name] as Callable).call(w)
			w.prev_scroll = w.scroll
			w.prev_x = w.x
			w.prev_y = w.y
			await _open("level", {"world": w})
			var game: Node = Nav.current
			game._start()
			game.set_process(false)  # stepped here, CAMERA_STEP at a time
			var bad := []
			var raw_before := w.camera_must_see()
			var since_grew := CAMERA_GRACE
			for f in CAMERA_STEPS:
				game._process(CAMERA_STEP)
				await get_tree().process_frame
				if w.state == World.State.RUNNING and not (name == "high platform" and not w.on_ground):
					var seen: Rect2 = game.visible_play_rect()
					if seen.end.x < World.VIEW_W - 0.5:
						bad.append("step %d shows play x to %.0f only" % [f, seen.end.x])
				var raw := w.camera_must_see()
				var grew := raw.position.x < raw_before.position.x - 2.0 or raw.position.y < raw_before.position.y - 2.0 \
						or raw.end.x > raw_before.end.x + 2.0 or raw.end.y > raw_before.end.y + 2.0
				since_grew = 0.0 if grew else since_grew + CAMERA_STEP
				raw_before = raw
				var zoom: float = game._stage.scale.x
				var insets := Device.insets()
				var area := Rect2(insets.x, GameScreenScript().hud_band(), game._clip.size.x - insets.x - insets.z,
						game._clip.size.y - GameScreenScript().hud_band()).grow(1.5)
				var eased: Rect2 = game._need
				var target := Rect2(game._stage.position + eased.position * zoom, eased.size * zoom)
				if f > 3 and not area.encloses(target):
					bad.append("step %d: easing toward %s, on screen %s, area %s" % [f, eased, target, area])
				var on_screen := Rect2(game._stage.position + raw.position * zoom, raw.size * zoom)
				if f > 3 and since_grew >= CAMERA_GRACE - 0.001 and not area.encloses(on_screen):
					bad.append("step %d (%.2f s after it grew): must see %s, on screen %s, area %s" % [f, since_grew, raw, on_screen, area])
			_check(bad.is_empty(), "%s, %s: the camera shows what the player must see %s" % [device, name, bad.slice(0, 2)])
			if name == "caught":  # his last beat away from the edge of the screen
				var sx: float = game._stage.position.x + w.end_at.x * game._stage.scale.x
				_check(absf(sx / game._clip.size.x - GameScreenScript().DEATH_FRAME) < 0.08,
						"%s: caught, he is framed %.0f %% across the screen for his last beat" % [device, sx / game._clip.size.x * 100.0])
			game.set_process(true)
		await _close(vp)
	Engine.time_scale = 1.0


## Fingers: taps, swipes in the middle of the move, short flicks, two thumbs, a second swipe
## without lifting (TouchReader, design units; swipe_min 30).
func _gp_touches() -> void:
	var r := TouchReader.new()
	r.swipe_min = 30.0
	var read := func(points: Array, dt := 0.016) -> Array:  # one finger: press, moves, release
		var out := []
		r.press(0, points[0], 0.0)
		for i in range(1, points.size()):
			var a: StringName = r.drag(0, points[i], i * dt)
			if a != &"":
				out.append(a)
		var last: StringName = r.release(0, points[-1], points.size() * dt)
		if last != &"":
			out.append(last)
		return out
	var o := Vector2(400, 300)
	_check(read.call([o, o + Vector2(2, 1)]) == [&"throw"], "a tap throws")
	_check(read.call([o, o + Vector2(0, -10), o + Vector2(0, -20), o + Vector2(0, -31)], 0.05) == [&"jump"], "a swipe up jumps")
	_check(read.call([o, o + Vector2(0, -10), o + Vector2(0, -20)], 0.008) == [&"jump"], "a fast flick jumps before the full swipe (%s)" % [read.call([o, o + Vector2(0, -10), o + Vector2(0, -20)], 0.008)])
	_check(read.call([o, o + Vector2(0, -8), o + Vector2(0, -16)], 0.06) == [&"jump"], "a short flick lifted early is a jump, not a ring")
	_check(read.call([o, o + Vector2(18, -26), o + Vector2(36, -52)], 0.03) == [&"jump"], "a thumb's slanted jump is a jump")
	_check(read.call([o, o + Vector2(0, -20), o + Vector2(0, -40), o + Vector2(0, -80), o + Vector2(0, -120)]) == [&"jump"], "one long swipe is one jump")
	_check(read.call([o, o + Vector2(0, -32), o + Vector2(0, -40), o + Vector2(0, -20), o + Vector2(0, 0), o + Vector2(0, 8)]) == [&"jump", &"down"],
			"up then down without lifting: jump, then let go")
	_check(read.call([o, o + Vector2(0, -32), o + Vector2(3, -40), o + Vector2(2, -34)]).size() == 1, "a wobble after a swipe adds nothing")
	_check(read.call([o, o + Vector2(-35, 0)]) == [&"left"] and GameScreenScript().swipe_action(Vector2(-35, 0)) == &"", "a swipe left does nothing")
	r.press(0, o, 0.0)
	_check(r.release(0, o, 0.8) == &"", "a long press isn't a tap")
	r.press(0, o, 0.0)  # two thumbs: one swipes up while the other taps
	r.press(1, o + Vector2(300, 0), 0.02)
	var both := [r.drag(0, o + Vector2(0, -35), 0.05), r.release(1, o + Vector2(301, 0), 0.08), r.release(0, o + Vector2(0, -35), 0.1)]
	_check(both == [&"jump", &"throw", &""], "a tap with one thumb while the other swipes: both count (%s)" % [both])


func GameScreenScript() -> GDScript:
	return load("res://src/game/game_screen.gd")


## Moves asked twice before a tick count once; a jump asked while climbing comes on the top; the
## picture answers a swipe within 2 frames at 60 Hz, 4 at 120; the same game at 90 Hz.
func _gp_input_rules() -> void:
	var w := _standing_world()
	var jumps := []
	w.jumped.connect(func() -> void: jumps.append(w.ticks))
	w.jump()
	w.jump()  # a second thumb
	for i in 60:
		w.tick()
	_check(jumps.size() == 1, "two fingers swiping up together jump once (%d)" % jumps.size())
	# a climb that began from a fall (no jump): a swipe up during it isn't lost
	var c := _standing_world()
	while not c.blocked and c.ticks < 400:
		c.tick()
	c.y = 300.0  # beside the wall, his body across its top's grass: he climbs onto it
	c.vy = 0.0
	c.on_ground = false
	c._air_ticks = 5
	c.jumping = false
	var cj := []
	c.jumped.connect(func() -> void: cj.append(c.ticks))
	var tops := []
	c.landed.connect(func() -> void: tops.append(c.ticks))
	var climbed := false
	for i in 40:
		if c.climbing and not climbed:
			climbed = true
			c.jump()
		c.tick()
	_check(climbed and cj.size() == 1 and tops.size() >= 1 and cj[0] - tops[0] <= 1,
			"a swipe up while climbing jumps from the top (jump %s, on top %s)" % [cj, tops])
	# latency: frames from a swipe (between two frames) to his picture moving
	for hz: float in [60.0, 120.0]:
		var worst := 0
		for k in 12:
			var v := _standing_world()
			v.advance(k / 12.0 * World.TICK)
			for f in 3:
				v.advance(1.0 / hz)
			var y0 := v.draw_hero().y
			v.jump()
			var frames := 0
			while v.draw_hero().y > y0 - 0.5 and frames < 20:
				v.advance(1.0 / hz)
				frames += 1
			worst = maxi(worst, frames)
		_check(worst <= (2 if hz == 60.0 else 4), "a swipe shows within %d frames at %d Hz (%.0f ms)" % [worst, hz, worst * 1000.0 / hz])
	var results := []
	for hz in [60.0, 90.0]:
		var g := World.new()
		var seen := []
		var input := func(world: World) -> void:
			if world.ticks == 119:
				world.jump()
			if world.ticks == 300:
				seen.append([snappedf(world.scroll, 0.001), snappedf(world.y, 0.001), world.lives])
		for f in int(hz * 8.0):
			g.advance(1.0 / hz, input)
		results.append(seen)
	_check(results[0] == results[1] and results[0].size() == 1, "the same game at 90 Hz")


## New (collision pass): rings and blows meet the bodies as drawn (CollisionOverlay, F3, draws the boxes). A ring at
## a strong bandit's face, over its 2017 box, hits it; one over the tips of its hair doesn't. A ring stops at the
## grass top of a step (it flew through). A blow lands as its fist reaches his body, not 20 units short; a hop as
## its fist reaches his legs no longer clears it (2017: his chest rose out of its box, fist and head through his legs).
func _gp_collisions() -> void:
	var hits := []
	for over: float in [16.0, -24.0]:  # the ring's middle that far under the top of its body (its face; over its hair)
		var w := _standing_world()
		var b := _bandit_ahead(w, 300.0)
		b.strong = true
		b.health = World.STRONG_HEALTH
		b.y = w.y + World.HERO_SIZE.y / 2 - World.BANDIT_SIZE.y / 2  # on his grass
		var struck := [false]
		w.bandit_hit.connect(func(_b: World.Bandit, _o: bool) -> void: struck[0] = true)
		w.throw()
		w.tick()
		w.rings[-1].y = b.y + World.STRONG_BODY.position.y + over - World.RING_CENTRE.y
		for t in 30:
			w.tick()
		hits.append(struck[0])
	_check(hits == [true, false], "a ring at a strong bandit's face hits it, one over its hair doesn't (%s)" % [hits])
	var s := _standing_world()
	s.scroll = 151 * 32.0 - s.x  # before the steps up out of the river (each two tiles up, columns 157-167)
	s.throw()
	var far := 0.0
	for t in 30:
		s.tick()
		for r in s.rings:
			far = maxf(far, s.scroll + r.x + World.RING_CENTRE.x)
	_check(far > 155 * 32.0 and far < 157 * 32.0, "a ring stops at the grass top of a step, not through it (to x %.0f)" % far)
	var gap := [INF]
	var f := _standing_world()
	var fb := _bandit_ahead(f, 300.0)
	f.hurt.connect(func(_b: World.Bandit, _l: int) -> void: gap[0] = fb.x - f.scroll - f.x)
	for t in 40:
		f.tick()
	_check(gap[0] < -World.BANDIT_FIST.position.x + 24.0, "a blow lands as its fist (drawn 50 ahead) reaches his body (drawn 24 ahead of his middle; gap %.0f)" % gap[0])
	var h := _standing_world()
	var hb := _bandit_ahead(h, 75.0)  # (its fist on his knees: 2017's hop lifted his chest out of its box)
	hb.y = h.y + World.HERO_SIZE.y / 2 - World.BANDIT_SIZE.y / 2
	var lost := [0]
	h.hurt.connect(func(_b: World.Bandit, _l: int) -> void: lost[0] += 1)
	h.jump()
	for t in 30:
		h.tick()
	_check(lost[0] == 1, "a hop as its fist reaches his legs doesn't clear a bandit: a blow (%d)" % lost[0])


## The tunnel's roof stops a jump; no kneeling or hanging for good on the last screen; no bandit
## appears at the window's edge only to drop into a pool, the others run as in 2017.
func _gp_level_fixes() -> void:
	var w := _standing_world()
	w.scroll = 360 * 32.0 - w.x  # on the tunnel's floor (row 8), under its roof (row 3)
	w.y = 8 * 32 - 64.0
	w.prev_y = w.y
	w.ground_y = w.y
	var bumps := []
	w.bumped.connect(func() -> void: bumps.append(w.ticks))
	_check(not w.rising_to_vine(), "under the roof no rise is drawn to the vine")
	w.jump()
	var highest := w.y
	for i in 20:
		w.tick()
		highest = minf(highest, w.y)
	_check(bumps.size() == 1 and highest - 64.0 >= 4 * 32.0 - 0.01 and not w.hanging and w.on_ground,
			"in the tunnel a jump bumps the roof and comes down (head at %.0f, %d bumps)" % [highest - 64.0, bumps.size()])
	_check(_near(w.ceiling_above(w.x, w.y - 64.0, w.scroll), 4 * 32.0) and w.ceiling_above(w.x, 400.0, 100.0 * 32.0 - w.x) < 0.0,
			"the roof is found over him, open sky elsewhere")
	var e := _standing_world()
	e.scroll = World.SCROLL_END
	e.at_end = true
	e.down()
	for i in 200:
		e.tick()
		if e.state != World.State.RUNNING:
			break
	_check(e.state == World.State.WON, "a swipe down on the last screen doesn't leave him kneeling there")
	var h := _standing_world()
	h.scroll = World.SCROLL_END
	h.at_end = true
	h.y = 0.0
	h.hanging = true
	h.on_ground = false
	for i in 300:
		h.tick()
		if h.state != World.State.RUNNING:
			break
	_check(h.state == World.State.WON and not h.hanging, "hanging on the last screen, he lets go over the doorway and is home")
	var n := _standing_world()
	n.scroll = World.SCROLL_END
	n.at_end = true
	n.x = World.HOME_X - World.HOME_REACH + 10.0
	var hops := []
	n.jumped.connect(func() -> void: hops.append(true))
	n.jump()
	n.throw()
	n.tick()
	_check(hops.is_empty() and n.rings.is_empty(), "by the doorway he only goes in: no hop, no ring at the hut")
	var st := World.new()
	st.state = World.State.WON
	st.bobs = 68
	_check(st.stars() == 3, "3 stars for 80 %% of the %d Red Bobs that can be taken alive (68), not all of them" % World.BOBS_REACHABLE)
	st.bobs = 67
	_check(st.stars() == 2, "and 2 for 67")
	var b := World.new()
	var drowned := b.bandits.filter(func(x: World.Bandit) -> bool: return x.gone)
	# (2026-11-10) bandits read the ground: with the level scrolling by, none of the others runs into a pool any more
	# (12 of 31 did): they leap the pools and walls in their way, or hold their bank as guards
	var c := World.new()
	c.mercy = 1 << 30
	c.y = 5000.0  # (out of every blow's reach, and under every leap: none holds back for him)
	var sunk := []
	var leapt := {}
	var guards := {}
	while c.scroll < World.SCROLL_END:
		for x: World.Bandit in c.bandits:
			x.prev_x = x.x
			x.prev_y = x.y
		c.scroll = minf(c.scroll + World.SCROLL_SPEED, World.SCROLL_END)
		c.ticks += 1
		c._update_bandits()
		for x: World.Bandit in c.bandits:
			if x.arc > 0:
				leapt[x.id] = true
			if x.holding:
				guards[x.id] = true
			if x.gone and x.active and c.bandit_rect(x).position.y > World.VIEW_H and x.id not in sunk:
				sunk.append(x.id)
	# a ring on one in the middle of its leap over a pool knocks it out of the air: into the water, his knock-out
	var k := World.new()
	k.mercy = 1 << 30
	k.y = 5000.0
	var outs := []
	k.bandit_hit.connect(func(_x: World.Bandit, out: bool) -> void: outs.append(out))
	var ringed := false
	while k.scroll < World.SCROLL_END and outs.size() < 2:
		for x: World.Bandit in k.bandits:
			x.prev_x = x.x
			x.prev_y = x.y
			if not ringed and x.arc > 0 and absi(x.arc - x.arc_n / 2) <= 1 and is_equal_approx(x.arc_from.y, x.arc_to.y) and k.water_at(x.x):  # (bank to bank, over the middle of the pool)
				ringed = true
				var ring := World.Ring.new()
				ring.x = x.x - k.scroll - World.RING_SPEED
				ring.y = x.y - World.RING_CENTRE.y
				k.rings.append(ring)
		k.scroll = minf(k.scroll + World.SCROLL_SPEED, World.SCROLL_END)
		k.ticks += 1
		k._update_rings()
		k._update_bandits()
	_check(drowned.size() == 20 and sunk.is_empty() and leapt.size() >= 9 and guards.size() >= 6 and outs == [false, true] and k.knocked_out == 1,
			"the 20 bandits with nowhere to stand aren't placed (%d); none of the others runs into a pool (%s): %d leap, %d hold a bank; one ringed over a pool drops in, knocked out (%s)"
			% [drowned.size(), sunk, leapt.size(), guards.size(), outs])
	var odd := []
	for x: World.Bandit in b.bandits:
		if x.gone:
			continue
		var at := b.scroll
		b.scroll = x.wait_x - World.VIEW_W
		var wait := Rect2(x.wait_x - b.scroll - World.BANDIT_SIZE.x / 2, x.wait_y - World.BANDIT_SIZE.y / 2, World.BANDIT_SIZE.x, World.BANDIT_SIZE.y)
		if b._find(wait, Level.Kind.SIDE, World.SIDE_SHRINK).x >= 0:
			odd.append(x.id)
		b.scroll = at
	_check(odd.is_empty(), "a waiting bandit is drawn out of the rock, where its first tick puts it (%s)" % [odd])


## What views read: the move phases of a hop, the landing foreseen to the tick, the progress
## through the air, the grass under him, the time since the end.
func _gp_view_hooks() -> void:
	var w := _standing_world()
	for i in 10:
		w.tick()
	var phases: Array[StringName] = [w.move_phase()]
	w.jump()
	var predicted := -1
	var landed_at := [-1]
	var progress := []
	w.landed.connect(func() -> void: landed_at[0] = w.ticks)
	for i in 40:
		w.tick()
		if i == 0:
			predicted = w.ticks + w.ticks_to_land()
		if w.air_progress() >= 0.0:
			progress.append(w.air_progress())
		if w.move_phase() != phases[-1]:
			phases.append(w.move_phase())
	_check(phases == [&"run", &"takeoff", &"rise", &"apex", &"fall", &"land", &"run"], "a hop's phases for the animations (%s)" % [phases])
	_check(predicted == landed_at[0], "the landing is foreseen to the tick (%d, %d)" % [predicted, landed_at[0]])
	var rising := true
	for i in range(1, progress.size()):
		rising = rising and progress[i] >= progress[i - 1]
	_check(rising and progress.size() > 10 and progress[0] < 0.15 and progress[-1] > 0.85, "progress through the air goes 0 to 1 (%s)" % [progress.size()])
	var d := _standing_world()
	d.scroll = 30 * 32.0 - d.x  # by the first wall: off its top, a drop of 10 tiles
	d.y = 8 * 32 - 64.0
	d.on_ground = false
	d._air_ticks = 5
	var foreseen := d.ticks_to_land()
	var t0 := d.ticks
	var down := [-1]
	d.landed.connect(func() -> void: down[0] = d.ticks - t0)
	for i in 60:
		d.tick()
	_check(foreseen > 0 and foreseen == down[0], "a long drop's landing is foreseen too (%d, %d)" % [foreseen, down[0]])
	_check(_near(d.ground_below(d.x, 100.0), 18 * 32 - 64.0) and d.ground_below(76 * 32.0 - d.scroll, 100.0) < 0.0, "the grass under him, none over a pool")
	var p := _standing_world()
	p.scroll = 76 * 32.0 - p.x
	p.y = 300.0
	p.on_ground = false
	p._air_ticks = 5
	_check(p.ticks_to_land() == -1 and p.air_progress() == -1.0, "no landing foreseen over a pool (flail)")
	_check(World.new().move_phase() == &"idle", "before the first tick: idle")
	var x := _standing_world()
	x.advance(0.5)
	_check(x.end_time == 0.0, "no end time while running")
	x._die(&"bandit")
	x.advance(0.5)
	x.advance(0.25)
	_check(_near(x.end_time, 0.75) and x.move_phase() == &"dead" and _near(x.phase_time(), 0.75), "the end time counts from the death")


## The game screen: the dying phase holds the panel back for the death animation, a tap skips it
## (not too soon), home the same; pausing (or the app going to the background) at any moment.
func _gp_flow() -> void:
	var make := func() -> Node:
		var w := World.new()
		w.stand_at_start()
		for b in w.bandits:
			b.gone = true
		var g: Node = GameScreenScript().new()
		add_child(g)
		g.enter({"world": w})
		return g
	var g: Node = make.call()
	var phases := []
	g.phase_changed.connect(func(ph: int) -> void: phases.append(ph))
	g._process(0.02)
	_check(g.phase == g.Phase.READY, "before the first touch: ready (he waits)")
	g._start()
	g._process(0.02)
	g.world._die(&"bandit")
	g._process(0.02)
	_check(g.phase == g.Phase.DYING, "caught: dying")
	g._process(0.3)  # the hit-stop
	for i in 10:
		g._process(0.1)
	_check(not g._results_shown, "the panel waits for the death animation (%.1f s of it)" % g.world.end_time)
	g.skip_ending()
	_check(g._results_shown and g.phase == g.Phase.DYING, "a tap skips to the panel")
	g._process(0.02)
	_check(phases == [g.Phase.PLAYING, g.Phase.DYING, g.Phase.RESULTS], "ready, playing, dying, results (%s)" % [phases])
	g.queue_free()
	var h: Node = make.call()
	h._start()
	h._process(0.02)
	h.world._die(&"fall")
	h._process(0.02)
	h.skip_ending()
	_check(not h._results_shown, "a tap right at the death doesn't skip it (it was a throw)")
	var waited := 0.0
	while not h._results_shown and waited < 5.0:
		h._process(0.05)
		waited += 0.05
	_check(h._results_shown and waited >= World.FALL_DEATH_TIME - 0.06 and waited <= World.FALL_DEATH_TIME + 0.15, "fallen: the panel after %.2f s" % waited)
	h.queue_free()
	var k: Node = make.call()
	k._start()
	k._process(0.02)
	k.world.state = World.State.WON
	k.world.won.emit()
	k._process(0.02)
	_check(k.phase == k.Phase.HOME, "home: the arrival phase")
	waited = 0.0
	while not k._results_shown and waited < 5.0:
		k._process(0.05)
		waited += 0.05
	_check(waited >= World.HOME_TIME - 0.06, "home: the panel after the walk in (%.2f s)" % waited)
	k.queue_free()
	var p: Node = make.call()  # pausing at every moment
	p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	p._process(0.02)
	var paused_ready: bool = p._paused or not (Config.is_mobile or not Config.is_debug)
	p.resume_game()
	p._start()
	p._process(0.02)
	p.pause_game()
	_check(_absolute_z(p._overlay) > _absolute_z(p.view.fx), "the pause panel is drawn over the world's effects (z %d over %d)" % [_absolute_z(p._overlay), _absolute_z(p.view.fx)])
	var t: int = p.world.ticks
	for i in 20:
		p._process(0.05)
	_check(paused_ready and p.phase == p.Phase.PAUSED and p.world.ticks == t, "paused: the world waits")
	p.resume_game()
	p._process(0.02)
	_check(p.phase == p.Phase.COUNTDOWN and p.world.ticks == t, "resumed: a countdown first")
	p.pause_game()  # the phone rings during the countdown
	p._process(0.02)
	_check(p.phase == p.Phase.PAUSED, "a pause during the countdown pauses")
	p.resume_game()
	for i in 40:
		p._process(0.05)
	_check(p.phase == p.Phase.PLAYING and p.world.ticks > t, "then the run goes on")
	p.world.hurt.emit(p.world.bandits[0], 2)  # a hit-stop
	p.pause_game()
	p.resume_game()
	for i in 40:
		p._process(0.05)
	_check(p.phase == p.Phase.PLAYING, "a pause during a hit-stop comes back to the run")
	p.world._die(&"bandit")
	p.pause_game()
	_check(not p._paused, "no pause once the run is over")
	p.queue_free()


## Saves survive a killed app, a damaged file and an older version; bad values are dropped one by one.
func _gp_saves() -> void:
	var dir := "user://gameplay_tests_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	var file := dir.path_join("save.cfg")
	var make := func() -> Node:
		var s: Node = load("res://src/autoload/save.gd").new()
		s.path = file
		s.persist = true
		return s
	var a: Node = make.call()
	a.best_bobs = 61
	a.best_stars = 2
	a.best_progress = 0.1 + 0.2  # (a fraction the text doesn't keep to the last bit)
	a.music_on = false
	a.language = "fr"
	a.write()
	a.best_bobs = 70
	a.write()
	var b: Node = make.call()
	b._load()
	_check(b.loaded_from == "save" and b.best_bobs == 70 and b.best_stars == 2 and not b.music_on and b.language == "fr"
			and _near(b.best_progress, 0.3), "a save reads back whole (%s, %d)" % [b.loaded_from, b.best_bobs])
	_check(not FileAccess.file_exists(file + ".tmp") and Save.decode(FileAccess.get_file_as_string(file + ".bak")).get(&"best_bobs") == 61,
			"no temporary file is left, the save before is the backup")
	# killed while writing the new file: save.cfg is untouched
	var cut: String = a.encode().substr(0, 120)
	FileAccess.open(file + ".tmp", FileAccess.WRITE).store_string(cut)
	var c: Node = make.call()
	c._load()
	_check(c.loaded_from == "save" and c.best_bobs == 70, "killed mid-write: the last save is read (%s)" % c.loaded_from)
	# killed between the two renames: save.cfg gone, the new file complete
	a.best_bobs = 75
	FileAccess.open(file + ".tmp", FileAccess.WRITE).store_string(a.encode())
	DirAccess.remove_absolute(file)
	var d: Node = make.call()
	d._load()
	_check(d.loaded_from == "tmp" and d.best_bobs == 75 and FileAccess.file_exists(file), "killed between the renames: the new save is read and put back (%s)" % d.loaded_from)
	# damaged: garbage, cut short, emptied
	for damage: String in ["garbage[[ = ]] ;;", a.encode().substr(0, a.encode().length() - 30), ""]:
		FileAccess.open(file, FileAccess.WRITE).store_string(damage)
		var e: Node = make.call()
		e._load()
		_check(e.loaded_from == "bak" and e.best_bobs >= 61 and e.language == "fr", "a damaged save (%d chars) falls back to the backup (%s)" % [damage.length(), e.loaded_from])
		e.free()
	_check(FileAccess.file_exists(file + ".corrupt"), "and the damaged file is kept aside")
	for f in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(file + f)
	FileAccess.open(file, FileAccess.WRITE).store_string("")
	var g: Node = make.call()
	g._load()
	_check(g.loaded_from == "" and g.best_bobs == 0 and g.music_on, "an empty save with no backup starts fresh")
	# version 1 (the first release): no version, no checksum; settings and bests are kept
	FileAccess.open(file, FileAccess.WRITE).store_string("[save]\n\nbest_bobs=44\nbest_stars=1\nbest_progress=0.62\nsounds_on=false\nlanguage=\"en\"\ntutorial_seen=true\n")
	var h: Node = make.call()
	h._load()
	_check(h.loaded_from == "save" and h.best_bobs == 44 and h.best_stars == 1 and not h.sounds_on and h.language == "en" and h.tutorial_seen,
			"a version 1 save is migrated, settings and bests kept")
	h.write()
	_check(FileAccess.get_file_as_string(file).contains("version=%d" % Save.VERSION), "and saved again as version %d" % Save.VERSION)
	# values of the wrong type or out of range are dropped one by one
	var k: Node = make.call()
	k.apply({&"best_stars": 9, &"best_bobs": -5, &"music_on": "yes", &"language": "de", &"best_progress": 3.0, &"wins": 4.0})
	_check(k.best_stars == 3 and k.best_bobs == 0 and k.music_on and k.language == "" and k.best_progress == 1.0 and k.wins == 4,
			"bad values are clamped or dropped, not loaded")
	var writes := []
	k.changed.connect(func() -> void: writes.append(true))
	k.set_option(&"music_on", true)
	_check(writes.is_empty(), "a setting set to what it already is writes nothing")
	for s: Node in [a, b, c, d, g, h, k]:
		s.free()
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


## UX: the tutorial teaches each move when it is needed (and the move it asks for works), learned
## lessons never come back, the comfort options, thumb-sized touch areas, French typography and
## every text the interface asks for.
func _test_ux() -> void:
	var all := Tutorial.ALL
	# the first bandit in view: the throw is taught first
	var w := World.new()
	w.stand_at_start()
	var first := 0
	for i in 160:
		w.tick()
		if i % Tutorial.CHECK_EVERY == 0:
			first = Tutorial.lesson_for(w, 0, 0, 0)
			if first != 0:
				break
	_check(first == Tutorial.Move.THROW, "the throw is taught when the first bandit comes (%d)" % first)
	# no bandits: the first wall or gap brings the jump, at a moment where jumping works
	w = _standing_world()
	var lesson := 0
	for i in 900:
		w.tick()
		if w.state != World.State.RUNNING:
			break
		if i % Tutorial.CHECK_EVERY == 0:
			lesson = Tutorial.lesson_for(w, Tutorial.Move.THROW, 0, 0, false)
			if lesson != 0:
				break
	_check(lesson == Tutorial.Move.JUMP, "the jump is taught before the first obstacle (%d at %.1f s)" % [lesson, w.ticks * World.TICK])
	if lesson != 0:
		_check(w.blocked or not Tutorial._safe(w, &"", Tutorial.LOOK_AHEAD), "the jump lesson comes when a jump is needed")
		_check(Tutorial._safe(w, &"jump", Tutorial.LOOK_AHEAD * 2), "the jump it asks for clears the obstacle")
	# a calm moment on the first grass: the step forward
	w = _standing_world()
	var known := all & ~Tutorial.Move.STEP
	_check(Tutorial.lesson_for(w, known, Tutorial.CALM_STEP, 0) == Tutorial.Move.STEP, "the step forward is taught at a calm moment")
	_check(Tutorial.lesson_for(w, known, 10, 0) == 0, "not right after another lesson")
	# hanging a while over safe ground: letting go
	w = _standing_world()
	w.hanging = true
	w.on_ground = false
	w.y = World.VINE_DRAW_Y
	_check(Tutorial.lesson_for(w, all & ~Tutorial.Move.LET_GO, 0, Tutorial.HANG_LESSON) == Tutorial.Move.LET_GO,
			"letting go is taught after hanging a while")
	_check(Tutorial.lesson_for(w, all, 999, 999) == 0 and Tutorial.lesson_for(_standing_world(), all, 999, 999) == 0,
			"a lesson learned never comes back")
	var seen := Save.tutorial_seen
	var learned := Save.tutorial_learned
	Save.tutorial_seen = true
	_check(not Tutorial.pending(), "no tutorial once it is seen")
	Tutorial.replay()
	_check(Tutorial.pending() and Save.tutorial_learned == 0, "Settings can replay the tutorial")
	Save.tutorial_seen = seen
	Save.tutorial_learned = learned
	# comfort options
	var shake := Save.screen_shake
	var calm := Save.reduce_motion
	Save.screen_shake = true
	Save.reduce_motion = false
	_check(Prefs.shake() == 1.0 and Prefs.motion(), "shake and motion on by default")
	Save.screen_shake = false
	_check(Prefs.shake() == 0.0, "the screen shake can be turned off")
	Save.screen_shake = true
	Save.reduce_motion = true
	_check(Prefs.shake() == 0.0 and not Prefs.motion(), "reduced motion stops the shake and the decorations")
	Save.screen_shake = shake
	Save.reduce_motion = calm
	for key: StringName in [&"music_volume", &"sounds_volume", &"screen_shake", &"reduce_motion", &"tutorial_learned"]:
		_check(Save._KEYS.has(key), "%s is saved" % key)
	# a small button still takes a thumb-sized touch
	var b := JuicyButton.new()
	b.size = Vector2(40, 40)
	var hit := b.hit_rect()
	_check(hit.size.x >= Ui.MIN_TOUCH and hit.size.y >= Ui.MIN_TOUCH, "touch area at least %d units" % Ui.MIN_TOUCH)
	_check(b._has_point(Vector2(-20, 20)) and not b._has_point(Vector2(-40, 20)), "the touch area is centred on the button")
	b.free()
	# French typography and the interface's texts
	var f := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
	var header := f.get_csv_line()
	var keys := {}
	var bad := []
	var mark := RegEx.create_from_string("[^\u00a0][!?:;]|[!?:;]\\S|'")
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < header.size() or row[0].is_empty():
			continue
		keys[row[0]] = true
		if mark.search(row[2] + " "):
			bad.append(row[0])
	_check(bad.is_empty(), "French: a no-break space before ! ? : ; and typographic apostrophes (%s)" % [bad])
	var wanted := ["TAP_TO_START", "TUTORIAL_SKIP", "REPLAY_TUTORIAL", "TUTORIAL_AGAIN", "SCREEN_SHAKE", "REDUCE_MOTION",
			"SOUND_AND_FEEL", "MORE", "CREDITS_BUTTON", "GAME_OVER", "RESUME", "PAUSED", "MUSIC", "SOUNDS"]
	wanted.append_array(Tutorial.TEXTS.values())
	for m: Array in PausePanel.moves_list():
		wanted.append(m[1])
	for key: String in wanted:
		_check(keys.has(key), "%s is translated" % key)
	# (UI r22, the judges of j18: "no visible on/off state") the settings' switches say it in words, translated; (UI r23)
	# the pause's music and sounds tiles show it themselves, lit or unlit
	var switch := ToggleSwitch.new()
	var music: bool = Save.music_on
	Save.music_on = false
	var tile := PausePanel.SoundSwitch.new("music-notes-fill", "", &"music_on", "x")
	var unlit := not tile.lit()
	Save.music_on = music
	_check(keys.has("STATE_ON") and keys.has("STATE_OFF") and switch._words[0] != switch._words[1] and unlit,
			"switches say on or off in words, translated (%s, %s); a sound switched off is an unlit tile" % switch._words)
	switch.free()
	tile.free()


# ------------------------------------------------------------------ art track

## The 3D hero's frames (assets/art/hero/hero_frames.json): every animation HeroView plays is there,
## every frame lies inside its atlas page, the run's pace keeps the planted boot on the ground, and
## each state of the rules shows the animation made for it. The ring's spin frames, the stacks.
func _test_art() -> void:
	var data := HeroView.frames_data()
	var anims: Dictionary = data.anims
	for name in ["run", "throw", "jump", "land", "idle", "die", "hang", "catch", "crouch", "hurt", "climb", "win"]:
		_check(anims.has(name) and not (anims[name].frames as Array).is_empty(), "hero animation %s" % name)
	_check((anims.run.frames as Array).size() == HeroView.RUN_FRAMES, "the run has %d frames" % HeroView.RUN_FRAMES)
	_check((anims.throw.frames as Array).size() == HeroView.RUN_FRAMES * 2, "the throw: wind-up and release over each run frame")
	_check((anims.jump.frames as Array).size() > HeroView.JUMP_THROW and (anims.land.frames as Array).size() >= HeroView.LAND_CROUCH,
			"the jump has its air poses (the rise to the brace, a throw), the landing at home its crouch")
	_check((anims.win.frames as Array).size() > HeroView.WIN_LOOP, "the cheer at home loops inside the win")
	var inside := true
	for name: String in anims:
		for f: Dictionary in anims[name].frames:
			var page: Texture2D = load(HeroView.DIR + str(data.pages[int(f.page)]))
			var r: Array = f.region
			inside = inside and r[0] >= 0 and r[1] >= 0 and r[0] + r[2] <= page.get_width() and r[1] + r[3] <= page.get_height()
			# (round 23) each frame's soles (their contact on the ground), each hanging frame's two fists (on the vine)
			inside = inside and f.has("soles") and (name not in ["hang", "catch"] or (f.get("fists", []) as Array).size() == 2)
	_check(inside, "every hero frame lies inside its atlas page, with its soles (and fists on the vine)")
	# the planted boot moves back with the ground: the drawn run plays at the user's choice, 16 frames a second
	# (2026-11-07); the stride of 2026-11-12 holds its boot on the ground at 14 (at 16: 1.14 times the ground's speed)
	var steps: Array[float] = []
	var run: Array = anims.run.frames
	var ground := 0.0
	# (each frame's points are relative to its own trimmed region: measured from its origin)
	for f: Dictionary in run:
		ground = maxf(ground, maxf(f.toe_r[1] - f.origin[1], f.toe_l[1] - f.origin[1]))
	for i in run.size():
		var a: Dictionary = run[i]
		var b: Dictionary = run[(i + 1) % run.size()]
		for toe in ["toe_r", "toe_l"]:
			if a[toe][1] - a.origin[1] > ground - 2.5 and b[toe][1] - b.origin[1] > ground - 2.5:  # (round 17: 2 px sat on a step's edge at the finer atlas)
				steps.append((a[toe][0] - a.origin[0]) - (b[toe][0] - b.origin[0]))
	var mean := 0.0
	for d in steps:
		mean += d / steps.size()
	var boot := mean * float(data.units_per_px) * float(data.run_fps)
	var ground_speed := World.SCROLL_SPEED / World.TICK
	_check(boot >= ground_speed * 0.95 and boot <= ground_speed * 1.25,
			"the planted boot moves back with the ground, at most a quarter faster (%.0f units/s, ground %.0f)" % [boot, ground_speed])
	_check(is_equal_approx(float(data.run_fps), HeroView.RUN_FPS), "the atlas' run pace is HeroView's (%.1f fps)" % float(data.run_fps))
	# each state of the rules shows its animation (gameplay's move_phase(): set as a tick would)
	var holder := Node2D.new()
	add_child(holder)
	var hero := HeroView.new()
	holder.add_child(hero)
	var w := _standing_world()
	var show := func(expect: StringName, what: String) -> void:
		w._phase = w._current_phase()
		w._phase_tick = w.ticks - 8  # (begun 0.2 s ago)
		hero.show_state(w, w.draw_hero(), 0.2)
		_check(hero.pose() == expect, "%s: %s (%s)" % [what, expect, hero.pose()])
	w.ticks = 0
	show.call(&"idle", "on his marks")
	w.ticks = 10
	show.call(&"run", "running")
	_check(hero.run_frame() >= 0 and hero.run_frame() < HeroView.RUN_FRAMES, "run_frame() while running (%d)" % hero.run_frame())
	# (round 20, "a sticker lit flat from the front") his side away from the sun in shade, measured across the frame shown
	var form: float = hero._material.get_shader_parameter(&"form_amount")
	var box: Vector4 = hero._material.get_shader_parameter(&"figure_box")
	_check(form > 0.0 and Vector2(box.z, box.w) == hero._sprite.region_rect.size, "a shade side across the frame he shows (form %.2f)" % form)
	# (round 21, "lit flat, the bandits read first") a warm key on his sun side; (round 23, "a dark smudge with thin
	# ink") his silhouette inked heavier than the lines inside him; (the user, 2026-11-08: "the bandits too dark, we
	# don't see them") their own colours kept: muted a little under him, never near-black
	var key: float = hero._material.get_shader_parameter(&"key_amount")
	var sil: float = hero._material.get_shader_parameter(&"sil_out_px")
	_check(key > 0.0 and BanditView.CORE_VALUE >= 0.8 and BanditView.CORE_VALUE < 1.0 and sil > 1.0,
			"a warm key on his sun side (%.2f), the bandits' grade readable (%.2f), his outer ink (%.1f px)"
			% [key, BanditView.CORE_VALUE, sil])
	# (round 22, "a jog, not a sprint") at the ground's pace the drawing leans into the stride; (2026-11-12) the new
	# stride is drawn as a sprint, his chest forward: a slight slant from the ground line, his chest no longer bent
	for i in 16:
		w.tick()
		hero.show_state(w, w.draw_hero(), World.TICK)
	_check(hero.skew > 0.01 and hero.skew <= HeroView.LEAN_SLANT and not hero._material.get_shader_parameter(&"bend_on"),
			"the run slants a little into the stride (%.2f), the sprint as drawn (no bend)" % hero.skew)
	hero.threw()
	hero.show_state(w, w.draw_hero(), 0.01)
	_check(hero.pose() == &"throw", "throwing: throw (%s)" % hero.pose())
	w.jumping = true
	w.on_ground = false
	w.vy = -World.JUMP_SPEED * 0.5
	w.y = 300.0
	w.prev_y = w.y
	w.ticks = 40
	show.call(&"jump", "in the air")
	_check(hero.run_frame() == -1, "no run_frame() in the air")
	w.hanging = true
	w.jumping = false
	w.y = 0.0
	w.prev_y = 0.0
	show.call(&"hang", "at the top")
	w.hanging = false
	w.climbing = true
	show.call(&"climb", "up a ledge")
	w.climbing = false
	w.state = World.State.WON
	w.end_time = (World.HOME_LAND + World.HOME_CHEER) / 2.0
	show.call(&"win", "home, the victory beat")
	w.state = World.State.DEAD
	w.death_reason = &"bandit"
	w.end_time = 0.5
	show.call(&"die", "caught")
	holder.queue_free()
	# the ring tumbles through its spin frames; the river's poles are sandstone stacks
	_check(RingView.TEXTURE.get_width() == RingView.TEXTURE.get_height() * RingView.SPIN_FRAMES, "ring_spin.png holds %d square frames" % RingView.SPIN_FRAMES)
	var terrain := TerrainView.new()
	terrain.build(Level.load_default(), 0, Level.COLS)
	var stacks := 0
	var river := 0
	for c in Level.COLS:
		var span: int = terrain._pole_column(c)
		if span >= 0:
			stacks += 1
			river += 1 if span % 100 == Level.ROWS else 0
	_check(stacks >= 5 and river >= 5, "the poles are drawn as stacks (%d, %d standing in the river)" % [stacks, river])
	# round 20 ("the two river pillars identical chimneys"): each stack a carved column of its own (spire.gdshader)
	terrain.ensure(0.0, Level.WIDTH)
	var widths := []  # (each one's width and seed)
	for rock: Node in terrain._layers[&"spires"].get_children():
		var m := (rock as CanvasItem).material
		widths.append(Vector2(m.get(&"shader_parameter/half_w"), m.get(&"shader_parameter/seed")))
	var twins := 0
	for i in range(1, widths.size()):
		twins += 1 if widths[i] == widths[i - 1] else 0
	_check(widths.size() >= 5 and twins == 0, "each stack is its own carved column, no two neighbours alike (%d)" % widths.size())
	terrain.free()


func _absolute_z(item: CanvasItem) -> int:
	var z := 0
	var n: Node = item
	while n is CanvasItem:
		z += (n as CanvasItem).z_index
		if not (n as CanvasItem).z_as_relative:
			break
		n = n.get_parent()
	return z

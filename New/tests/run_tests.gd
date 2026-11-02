extends Node
## Headless checks of the rules, the level, saves, settings and texts. Run from New/:
##   Godot --headless --path . res://tests/run_tests.tscn [-- --bot]
## --bot also lets the bot play the whole level (a few minutes). Prints each failure and exits
## with code 1 if anything failed.

var _failures := 0
var _checks := 0


func _ready() -> void:
	Save.persist = false
	var tests := [_test_scripts_compile, _test_speeds, _test_level, _test_landing, _test_jump_height, _test_jump_buffer, _test_climb_wall,
			_test_hang, _test_fall, _test_landing_weight, _test_bandits, _test_club_reach, _test_mercy, _test_calm_start, _test_swipes, _test_rings, _test_home_door, _test_run_home, _test_step_cap, _test_frame_rates, _test_idle,
			_test_stars, _test_save, _test_translations, _test_config, _test_preload, _test_debug_silent]
	if "--bot" in OS.get_cmdline_user_args():
		tests.append(_test_bot)
	for test: Callable in tests:
		test.call()
	print("%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FAIL: ", what)


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
	for i in 16:
		w.tick()
	_check(b.hurt and not b.gone and b.health == 1, "one ring hurts a bandit")
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


func _test_debug_silent() -> void:
	var silent := OS.is_debug_build() and not EngineDebugger.is_active()
	_check(AudioServer.is_bus_mute(0) == silent, "silent only in debug runs started outside the Godot editor")

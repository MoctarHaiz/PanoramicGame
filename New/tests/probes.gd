extends SceneTree
## Feel and fairness numbers from the rules, for the gameplay review (not part of the test suite):
##   Godot --headless --path . -s tests/probes.gd -- [--probe=climb,falls,bot,windows] [--seeds=1,2,3]
## climb: his height tick by tick while he climbs the first wall; bandit: the jump window over a
## running bandit; hops: the take-off window of each hop across the small platforms at cols 456-503;
## falls: every landing of a bot run with its drop height; bot: where a bot run loses lives, per
## seed; windows: for each pit, how long the window is in which a jump still clears it.
## bobs: which Red Bobs can be taken and survived (a bot aimed at each, from moments of a bot run;
##   --from=COL,--to=COL to share the level between runs); warning: the bot's recorded run played
##   through the real game screen on every device of tests/capture.gd (--devices=a,b for some), each
##   bandit's first moment on screen (inside the safe area) against the 2017 screen's (the 960-unit
##   play window): none may be seen later (the camera's zoom and follow are checked this way);
## latency: frames from a swipe to his picture moving, at 30/60/90/120 Hz.



func _initialize() -> void:
	var a := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			a[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	var probes: PackedStringArray = String(a.get("probe", "climb,falls,bot")).split(",")
	if "climb" in probes:
		_climb()
	if "bandit" in probes:
		_bandit_window()
	if "hops" in probes:
		for col in [456, 465, 474, 483, 492]:
			_hop_window(col, 16, col + 9, 16)
		_hop_window(724, 18, 735, 17)  # onto the block in the last long pool
		_hop_window(735, 17, 745, 18)  # and off it
	if "falls" in probes or "bot" in probes:
		for s in String(a.get("seeds", "1")).split(","):
			_bot_run(int(s), "falls" in probes)
	if "bobs" in probes:
		_bobs_reach(int(a.get("from", "0")), int(a.get("to", "800")))
	if "latency" in probes:
		_latency()
	if "warning" in probes:
		await process_frame  # (the autoloads are in the tree from the first frame)
		var devices: Array = String(a.get("devices", ",".join(_devices().keys()))).split(",")
		for device: String in devices:
			await _warning_on(device)
	quit()


func _climb() -> void:
	var w := World.new()
	for b in w.bandits:
		b.gone = true
	while not w.blocked and w.ticks < 400:
		w.tick()
	print("climb: blocked at tick %d, y=%.1f" % [w.ticks, w.y])
	w.jump()
	var last := w.y
	for i in 20:
		w.tick()
		print("  +%2d  y=%6.1f  dy=%6.1f  vy=%5.1f  ground=%s" % [i + 1, w.y, w.y - last, w.vy, w.on_ground])
		last = w.y


## A bandit running at him on flat ground: at which ticks a jump clears it, and when it hits if he
## doesn't jump (centre distance at the hit).
func _bandit_window() -> void:
	var ok := []
	var hit_at := -1
	var hit_gap := 0.0
	for jump_at in range(-1, 60):
		var w := World.new()
		for b in w.bandits:
			b.gone = true
		for i in 30:
			w.tick()
		var b: World.Bandit = w.bandits[10]
		b.gone = false
		b.active = true
		b.x = w.scroll + w.x + 600.0
		b.y = w.y + 10.0
		var hurt := [false]
		w.hurt.connect(func(_b: World.Bandit, _l: int) -> void: hurt[0] = true)
		for t in 80:
			if t == jump_at:
				w.jump()
			w.tick()
			if hurt[0] and jump_at < 0 and hit_at < 0:
				hit_at = t
				hit_gap = b.x - w.scroll - w.x
		if jump_at >= 0 and not hurt[0]:
			ok.append(jump_at)
	print("bandit: hits at tick %d (centre gap %.0f units); jumps that clear it: ticks %s..%s (%d ticks, %.0f ms)" % [
			hit_at, hit_gap, ok[0] if ok else -1, ok[-1] if ok else -1, ok.size(), ok.size() * 25.0])


## Standing on grass at `from_col`, `from_row`, running right: at which ticks a jump (no swipes
## right) lands him on the grass at `to_col`, `to_row`, counting jumps made after walking off.
func _hop_window(from_col: int, from_row: int, to_col: int, to_row: int) -> void:
	var ok := []
	for jump_at in 40:
		var w := World.new()
		for b in w.bandits:
			b.gone = true
		w.scroll = from_col * 32.0 + 8.0 - w.x
		w.y = from_row * 32 - 64.0
		w.on_ground = true
		w._air_ticks = 0
		var arrived := [-1]
		w.landed.connect(func() -> void: arrived[0] = int((w.scroll + w.x) / 32.0) if is_equal_approx(w.ground_y, to_row * 32 - 64.0) else -2)
		for t in 80:
			if t == jump_at:
				w.jump()
			w.tick()
			if arrived[0] != -1 or w.lives < World.LIVES:
				break
		if arrived[0] >= to_col - 1 and arrived[0] <= to_col + 3:
			ok.append(jump_at)
	print("hop %d -> %d: lands from take-off ticks %s (%d ticks, %.0f ms)" % [from_col, to_col, ok, ok.size(), ok.size() * 25.0])


## A bot run: each landing's drop (units) and each life lost (where and how).
func _bot_run(seed_value: int, landings: bool) -> void:
	var w := World.new()
	var bot := Bot.new(seed_value)
	var peak := [w.y]
	var drops := []
	w.landed.connect(func() -> void:
		drops.append(w.ground_y - peak[0])
		peak[0] = w.y)
	w.hurt.connect(func(_b: World.Bandit, l: int) -> void:
		print("  seed %d: hit at %.1f s, col %d, %d lives left" % [seed_value, w.ticks * World.TICK, int((w.scroll + w.x) / 32), l]))
	w.fell.connect(func(l: int) -> void:
		print("  seed %d: fell at %.1f s, col %d, %d lives left" % [seed_value, w.ticks * World.TICK, int((w.scroll + w.x) / 32), l]))
	while w.state == World.State.RUNNING and w.ticks < 9000:
		bot.act(w)
		w.tick()
		if not w.on_ground:
			peak[0] = minf(peak[0], w.y)
	print("bot %d: %s (%s) %.1f s, %.1f %%, bobs %d, lives %d, KO %d" % [seed_value, World.State.keys()[w.state],
			w.death_reason, w.ticks * World.TICK, w.progress() * 100, w.bobs, w.lives, w.knocked_out])
	if landings:
		drops.sort()
		print("  landings %d, drops (units): min %.0f, median %.0f, max %.0f; over 200: %d" % [drops.size(), drops[0],
				drops[drops.size() / 2], drops[-1], drops.filter(func(d: float) -> bool: return d > 200.0).size()])


## Red Bobs a player can take and live: from moments of a bot run 0.8 to 2.5 s before each Red Bob,
## a bot that wants that one above all plays on; it counts if he is still running 2 s after taking
## it (every Red Bob taken on such a run counts). Prints the ones no try could take.
func _bobs_reach(from_col: int, to_col: int) -> void:
	var t0 := Time.get_ticks_msec()
	var w := World.new()
	var bot := Bot.new(1)
	var moments: Array[World] = []
	while w.state == World.State.RUNNING and w.ticks < 9000:
		if w.ticks % 20 == 0:
			moments.append(w.clone())
		bot.act(w)
		w.tick()
	var targets: Array[Vector2i] = []
	for c in range(from_col, mini(to_col, Level.COLS)):
		for r in Level.ROWS:
			if w.level.ids[r * Level.COLS + c] in [84, 85] or Level.load_default().kind_at(c, r) == Level.Kind.BOB:
				targets.append(Vector2i(c, r))
	var proven := {}
	var missing: Array[Vector2i] = []
	for bob in targets:
		if proven.has(bob):
			continue
		var bob_x := (bob.x + 0.5) * Level.TILE
		var tries := moments.filter(func(m: World) -> bool:
			var ahead := bob_x - (m.scroll + m.x)
			return ahead > 180.0 and ahead < 600.0 and m.level.kind_at(bob.x, bob.y) == Level.Kind.BOB)
		tries.reverse()  # the nearest moment first
		var ok := false
		for i in mini(tries.size(), 4):
			var sim: World = tries[i].clone()
			var aim := Bot.new(11 + i)
			aim.target = bob
			aim.plans = 30
			var taken := -1
			var before := sim.level.copy()
			while sim.state == World.State.RUNNING and sim.ticks < 9000:
				aim.act(sim)
				sim.tick()
				if taken < 0 and sim.level.kind_at(bob.x, bob.y) != Level.Kind.BOB:
					taken = sim.ticks
				if taken >= 0 and sim.ticks - taken >= 80:
					break
				if taken < 0 and bob_x < sim.scroll + sim.x - 260.0:
					break
			if taken >= 0 and sim.state != World.State.DEAD:
				ok = true
				for c in range(maxi(bob.x - 40, 0), mini(bob.x + 60, Level.COLS)):
					for r in Level.ROWS:
						if before.kind_at(c, r) == Level.Kind.BOB and sim.level.kind_at(c, r) != Level.Kind.BOB:
							proven[Vector2i(c, r)] = true
				break
		if not ok:
			missing.append(bob)
			print("  bob col %d row %d: not taken alive in %d tries" % [bob.x, bob.y, mini(tries.size(), 4)])
	print("bobs %d-%d: %d of %d taken alive, %d not: %s (%d s)" % [from_col, to_col, targets.size() - missing.size(), targets.size(),
			missing.size(), missing, (Time.get_ticks_msec() - t0) / 1000])


## The bot's recorded run (BotReplay) through the real game screen at `device`'s size and notches:
## for each bandit, the tick it is first on screen (its body's front inside the safe area) and the
## tick the 2017 screen showed it (its body inside the 960-unit play window), until its club would
## reach him or it is knocked out. Prints the bandits seen later than in 2017 (none expected) and
## the shortest time any bandit was on screen before its club reached him.
func _warning_on(device: String) -> void:
	var Device: Node = root.get_node("Device")  # (autoloads: by node in a -s script)
	var Nav: Node = root.get_node("Nav")
	var Save: Node = root.get_node("Save")
	var d: Dictionary = _devices()[device]
	var px: Vector2i = d.size
	var design := Vector2(640.0 * px.x / px.y, 640.0)
	Device.debug_insets = d.insets * (design.y / px.y)
	Device.banner_height = 0.0
	Save.persist = false
	Save.tutorial_seen = true
	Save.tutorial_learned = 31
	var vp := SubViewport.new()
	vp.size = px
	vp.size_2d_override = Vector2i(design.round())
	vp.size_2d_override_stretch = true
	root.add_child(vp)
	var host := Control.new()
	host.size = design
	vp.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Nav.custom_viewport = vp
	Nav.attach(host)
	Nav.go(&"game", {"world": World.new()})
	var t0 := Time.get_ticks_msec()
	while (Nav.current == null or Nav.is_busy()) and Time.get_ticks_msec() - t0 < 10000:
		await process_frame
	var game: Node = Nav.current
	var watch := Watch.new(BotReplay.recorded(1), game, Device.debug_insets)
	game.autopilot = watch
	Engine.time_scale = 6.0
	while game.world.state == World.State.RUNNING and game.world.ticks < 9000:
		await process_frame
	for i in 40:  # home: his arrival framed (the watch looks on: the world calls it no more)
		watch.act(game.world) if game.world.state == World.State.WON else null
		await process_frame
	Engine.time_scale = 1.0
	var late: Array = watch.rows.filter(func(r: Array) -> bool: return r[1] > r[0])
	var warn: Array = watch.rows.filter(func(r: Array) -> bool: return r[2] >= 0).map(func(r: Array) -> float: return (r[2] - r[1]) * World.TICK)
	warn.sort()
	var leads: Array = watch.rows.filter(func(r: Array) -> bool: return r[0] >= 0 and r[1] >= 0).map(func(r: Array) -> int: return r[0] - r[1])
	leads.sort()
	print("warning %s: %d bandits seen, %d later than on the 2017 screen %s; seen earlier than in 2017 by %s s (least) to %s s (most); shortest time on screen before a club reached him: %s s; %s, %d lives" % [
			device, watch.rows.size(), late.size(), late.map(func(r: Array) -> String: return "#%d %d ticks late" % [r[3], r[1] - r[0]]),
			"%.2f" % (leads[0] * World.TICK) if not leads.is_empty() else "-", "%.2f" % (leads[-1] * World.TICK) if not leads.is_empty() else "-",
			"%.2f" % warn[0] if not warn.is_empty() else "-", World.State.keys()[game.world.state], game.world.lives])
	print("  camera %s: base zoom %.3f, zoom %.3f..%.3f; play x shown to %.0f at least (2017: 960); the vine at %.0f at the highest (HUD band ends at %.0f), under the HUD %d ticks in all, %.2f s at most at once (tick %d, %s); a landing's ground down to %.0f (screen %.0f tall); at home %d frames with him outside the safe area" % [
			device, game.base_zoom((game._clip.size.x - Device.insets().x) / game._k), watch.zooms.x, watch.zooms.y, watch.least_right,
			watch.vine_top, game.HUD_BAND, watch.vine_hidden, watch.vine_longest[0] * World.TICK, watch.vine_longest[1], watch.vine_longest[2],
			watch.landing_low, game._clip.size.y, watch.home_out])
	game.queue_free()
	Nav.reset()
	Nav.custom_viewport = root
	vp.queue_free()
	for i in 3:
		await process_frame


## Plays a recorded run and, before each tick, notes what the screen shows of each bandit.
class Watch extends RefCounted:
	var replay: BotReplay
	var game: Node
	var insets: Vector4
	var seen := {}  # bandit id -> [tick in the 2017 window, tick on screen, tick its club reached him (-1)]
	var rows: Array = []  # [2017 tick, screen tick, reach tick, id] per bandit that came
	## Over the run, from the real camera: the least play x shown at the safe area's right edge while
	## he plays (2017: 960), the highest the vine came on screen when it mattered (screen units; the
	## HUD band ends at HUD_BAND), the lowest a landing's grass went (screen units; the screen ends at
	## the clip's height), the zooms seen, and his body's screen box at home (inside the safe area?).
	var least_right := INF
	var vine_top := INF
	var landing_low := -INF
	var zooms := Vector2(INF, -INF)
	var home_out := 0
	var vine_hidden := 0  # ticks the vine was under the HUD band while it mattered
	var vine_run := 0  # the current run of such ticks, and the longest (with its tick and what he did)
	var vine_longest := [0, 0, ""]

	func _init(r: BotReplay, g: Node, ins: Vector4) -> void:
		replay = r
		game = g
		insets = ins

	func act(w: World) -> void:
		var zoom: float = game._stage.scale.x
		var at: Vector2 = game._stage.position
		var right: float = (game._clip.size.x - insets.z - at.x) / zoom  # the safe area's edge, play x
		least_right = minf(least_right, right)
		zooms = Vector2(minf(zooms.x, zoom), maxf(zooms.y, zoom))
		if w.hanging or w.vine_catchable():
			var vy: float = at.y + World.VINE_SEEN * zoom
			vine_top = minf(vine_top, vy)
			if vy < game.HUD_BAND - 2.0:
				vine_hidden += 1
				vine_run += 1
				if vine_run > vine_longest[0]:
					vine_longest = [vine_run, w.ticks, "hanging" if w.hanging else ("rising" if w.rising_to_vine() else "on a ledge, y %.0f" % w.y)]
			else:
				vine_run = 0
		else:
			vine_run = 0
		var land := w.ticks_to_land()
		if land > 0:
			landing_low = maxf(landing_low, at.y + w._ground_ahead() * zoom)
		if w.state == World.State.WON:
			var p := w.draw_hero()
			var box := Rect2(at + Vector2(p.x - 40.0, p.y - 80.0) * zoom, Vector2(80.0, 144.0) * zoom)
			var safe := Rect2(insets.x, 0.0, game._clip.size.x - insets.x - insets.z, game._clip.size.y)
			home_out += 0 if safe.encloses(box) else 1
		for b in w.bandits:
			if not b.active or b.health <= 0:
				continue
			var front := b.x - w.scroll - World.BANDIT_SIZE.x / 2
			if not seen.has(b.id):
				if b.gone:
					continue
				seen[b.id] = [-1, -1, -1]
				rows.append(seen[b.id])
				seen[b.id].append(b.id)
			var row: Array = seen[b.id]
			if row[0] < 0 and front < World.VIEW_W:
				row[0] = w.ticks
			if row[1] < 0 and front < right:
				row[1] = w.ticks
			if row[2] < 0 and (w.strike(b) >= 1.0 or b.touched_hero):
				row[2] = w.ticks
		replay.act(w)


## Frames from a swipe (made at any moment between two frames) to his picture moving.
func _latency() -> void:
	for hz in [30.0, 60.0, 90.0, 120.0]:
		var worst := 0
		var total := 0
		for k in 24:
			var v := World.new()
			for b in v.bandits:
				b.gone = true
			for i in 30:
				v.tick()
			v.advance(k / 24.0 * World.TICK)
			var y0 := v.draw_hero().y
			v.jump()
			var frames := 0
			while v.draw_hero().y > y0 - 0.5 and frames < 20:
				v.advance(1.0 / hz)
				frames += 1
			worst = maxi(worst, frames)
			total += frames
		print("latency at %3d Hz: the jump shows %.1f frames after the swipe on average, %d at worst (%.0f / %.0f ms)" % [hz,
				total / 24.0, worst, total / 24.0 * 1000.0 / hz, worst * 1000.0 / hz])


## The devices of tests/capture.gd (loaded when the autoloads it uses exist).
func _devices() -> Dictionary:
	return load("res://tests/capture.gd").DEVICES

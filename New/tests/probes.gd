extends SceneTree
## Feel and fairness numbers from the rules, for the gameplay review (not part of the test suite):
##   Godot --headless --path . -s tests/probes.gd -- [--probe=climb,falls,bot,windows] [--seeds=1,2,3]
## climb: his height tick by tick while he climbs the first wall; bandit: the jump window over a
## running bandit; hops: the take-off window of each hop across the small platforms at cols 456-503;
## falls: every landing of a bot run with its drop height; bot: where a bot run loses lives, per
## seed; windows: for each pit, how long the window is in which a jump still clears it.
## bobs: which Red Bobs can be taken and survived (a bot aimed at each, from moments of a bot run;
##   --from=COL,--to=COL to share the level between runs); warning: how long each bandit is in view
##   before it reaches him, on the narrowest (iPad, 853 units) and widest (iPhone 15) screens;
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
	if "warning" in probes:
		_bandit_warning()
	if "latency" in probes:
		_latency()
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


## Each bandit that comes at him in a bot run: seconds between first showing at the right edge (the
## narrowest screen: iPad 4:3, 853 units of play; the widest: iPhone 15, about 1290) and reaching
## the front of his body, or being knocked out first. Flags any under 1 s on the iPad.
func _bandit_warning() -> void:
	var w := World.new()
	var bot := Bot.new(1)
	var seen := {}  # id -> [tick in view on an iPad, tick in view on an iPhone]
	var rows := []
	while w.state == World.State.RUNNING and w.ticks < 9000:
		bot.act(w)
		w.tick()
		for b in w.bandits:
			if b.gone or not b.active:
				if b.gone and seen.has(b.id) and seen[b.id].size() == 2:
					rows.append([b.id, -1.0, (w.ticks - seen[b.id][0]) * World.TICK, int(b.x / Level.TILE), "gone"])
					seen[b.id].append(true)
				continue
			var sx := b.x - w.scroll
			if not seen.has(b.id):
				seen[b.id] = [w.ticks if sx < 853.0 else -1, w.ticks]
			elif seen[b.id][0] < 0 and sx < 853.0:
				seen[b.id][0] = w.ticks
			if seen[b.id].size() == 2 and seen[b.id][0] >= 0 and sx - World.BANDIT_SIZE.x / 2 - World.CLUB_REACH < w.x + World.HERO_SIZE.x / 4:
				rows.append([b.id, (w.ticks - seen[b.id][0]) * World.TICK, (w.ticks - seen[b.id][1]) * World.TICK, int(b.x / Level.TILE),
						"high" if b.y < w.y - 60.0 else ("low" if b.y > w.y + 60.0 else "level")])
				seen[b.id].append(true)
	for r: Array in rows:
		if r[1] >= 0.0:
			print("  bandit %2d at col %3d: in view %.2f s (iPad), %.2f s (wide) before its club reaches him; %s%s" % [r[0], r[3], r[1], r[2], r[4],
					"   <-- under 1 s" if r[1] < 1.0 else ""])
	print("warning: %d bandits reached him (%d under 1 s on an iPad); lives %d" % [rows.filter(func(r: Array) -> bool: return r[1] >= 0.0).size(),
			rows.filter(func(r: Array) -> bool: return r[1] >= 0.0 and r[1] < 1.0).size(), w.lives])


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

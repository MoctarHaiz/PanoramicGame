extends SceneTree
## Feel and fairness numbers from the rules, for the gameplay review (not part of the test suite):
##   Godot --headless --path . -s tests/probes.gd -- [--probe=climb,falls,bot,windows] [--seeds=1,2,3]
## climb: his height tick by tick while he climbs the first wall; bandit: the jump window over a
## running bandit; hops: the take-off window of each hop across the small platforms at cols 456-503;
## falls: every landing of a bot run with its drop height; bot: where a bot run loses lives, per
## seed; windows: for each pit, how long the window is in which a jump still clears it.


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

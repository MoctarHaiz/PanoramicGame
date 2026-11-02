extends SceneTree
## Quick look at the rules from the command line (not part of the test suite):
##   Godot --headless --path . -s tests/explore.gd -- [--bot=SEED]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var w := World.new()
	print("bobs in level: ", w.level.bobs_total, ", bandits: ", w.bandits.size())
	# An idle player.
	var t0 := Time.get_ticks_msec()
	while w.state == World.State.RUNNING and w.ticks < 6000:
		w.tick()
	print("idle: %s (%s) after %.1f s at %.1f %%, blocked=%s, x=%.0f" % [
		World.State.keys()[w.state], w.death_reason, w.ticks * World.TICK, w.progress() * 100, w.blocked, w.x])
	for a in args:
		if a.begins_with("--bot="):
			var seed_value := a.trim_prefix("--bot=").to_int()
			var bw := World.new()
			var last_report := 0
			var bot := Bot.new(seed_value)
			while bw.state == World.State.RUNNING and bw.ticks < 9000:
				bot.act(bw)
				bw.tick()
				if bw.ticks - last_report >= 400:
					last_report = bw.ticks
					print("  t=%5.1f s  progress %5.1f %%  col %d  y=%.0f lives %d bobs %d hang=%s blocked=%s" % [
						bw.ticks * World.TICK, bw.progress() * 100, int((bw.scroll + bw.x) / 32), bw.y, bw.lives, bw.bobs, bw.hanging, bw.blocked])
			print("bot %d: %s (%s) after %.1f s, progress %.1f %%, bobs %d, lives %d, knocked out %d, stars %d, %d ms" % [
				seed_value, World.State.keys()[bw.state], bw.death_reason, bw.ticks * World.TICK, bw.progress() * 100,
				bw.bobs, bw.lives, bw.knocked_out, bw.stars(), Time.get_ticks_msec() - t0])
	quit()

class_name BotReplay
extends RefCounted
## A bot run recorded once and replayed: the input the bot gave on each tick, kept in
## build/qa/ (keyed on the rules, the level and the bot, so a change to any of them records again).
## Replaying costs nothing per tick, unlike the bot's look-ahead (about 70 ms a tick), so the
## performance scene, the captures and the tests can play the whole level fast and the same way
## every time.
##
##   var replay := BotReplay.recorded(1)  # Bot.new(1) on World.new(): about 5 minutes the first time
##   game.autopilot = replay              # anything with act(world), like Bot
##   replay.play(World.new())             # or headless, like Bot.play()

## Files the recording depends on: if one changes, the bot plays again.
const SOURCES := ["res://src/game/world.gd", "res://src/game/level.gd", "res://tests/bot.gd", Level.PATH]
const CACHE_DIR := "res://build/qa"

## tick -> the actions given before it ([&"jump", &"throw", ...])
var inputs := {}
## Bot.play()'s summary of the recorded run.
var result := {}


## The run of Bot.new(seed_value) from World.new(), from the cache or played now.
static func recorded(seed_value := 1, max_ticks := 9000) -> BotReplay:
	var replay := BotReplay.new()
	var path := "%s/bot_%d_%s.json" % [CACHE_DIR, seed_value, _sources_hash()]
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if data is Dictionary:
		for t: String in data.inputs:
			var actions: Array[StringName] = []
			for a: String in data.inputs[t]:
				actions.append(StringName(a))
			replay.inputs[int(t)] = actions
		replay.result = data.result
		return replay
	var w := World.new()
	var bot := Bot.new(seed_value)
	var t0 := Time.get_ticks_msec()
	while w.state == World.State.RUNNING and w.ticks < max_ticks:
		bot.act(w)
		if not w._actions.is_empty():
			replay.inputs[w.ticks] = w._actions.duplicate()
		w.tick()
	replay.result = {"state": w.state, "reason": w.death_reason, "ticks": w.ticks, "bobs": w.bobs, "lives": w.lives}
	print("  bot %d recorded in %d ms: %s" % [seed_value, Time.get_ticks_msec() - t0, replay.result])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"inputs": replay.inputs, "result": replay.result}))
	return replay


## Gives `w` the recorded input for its next tick (same signature as Bot.act).
func act(w: World) -> void:
	for a: StringName in inputs.get(w.ticks, []):
		match a:
			&"jump": w.jump()
			&"down": w.down()
			&"right": w.step_forward()
			&"throw": w.throw()


## Plays `w` (a World.new()) to the end of the recording, or until `until` (a Callable on the
## world) is true. Returns the world.
func play(w: World, until := Callable()) -> World:
	while w.state == World.State.RUNNING and w.ticks < 9000:
		if until.is_valid() and until.call(w):
			break
		act(w)
		w.tick()
	return w


## A copy of `w` to open a screen on. (World.clone() leaves the previous tick's positions at their
## defaults: the first frame drawn would sweep from the start of the level and the top left corner.)
static func snapshot(w: World) -> World:
	var c := w.clone()
	c.prev_x = w.prev_x
	c.prev_y = w.prev_y
	c.prev_scroll = w.prev_scroll
	return c


static func _sources_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for path: String in SOURCES:
		ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode().substr(0, 10)

extends Node
## Performance check: plays the level at a phone's size, off screen, the bot's recorded run giving
## the input (BotReplay: no look-ahead cost in the frame), and reports per phase (menu, the run,
## paused, the end panel, the menu again) the texture and video memory, draw calls, objects, the
## work done per frame (worst and 99th percentile) and the node count, against the budgets:
## texture memory under 80 MB, no frame of play over 16 ms of work (desktop), no node left behind
## once back on the menu. Exit code 1 if one fails. It also lists the pictures first loaded during
## the run (each one a hitch and more memory: they belong in the preload) and the memory over time.
##
## Work per frame = the wall time from one frame to the next, with vsync off and --fixed-fps 60
## (game time stays exact, frames don't wait for the screen): everything the frame did, scripts,
## drawing and the GPU, but also whatever else the machine did meanwhile. script_ms is the time of
## every node's _process (between a first and a last node), render_ms the CPU side of drawing the
## phone's screen, own_ms their sum. The budget holds when no frame's own_ms reaches 16 ms and the
## wall time's 99th percentile stays under 16 ms (single long wall frames with a small own_ms are
## other programs: they are listed, not counted). Godot's TIME_PROCESS monitor is the worst of the
## last second, not a frame's time: not used.
##
## Godot --path . --fixed-fps 60 --resolution 200x200 --always-on-top res://tests/perf.tscn -- \
##     [--device=iphone15_2556x1179 | --size=2556x1179] [--seconds=40] [--pause-at=20] [--ads=on]
##     [--jump-mb=4] [--out=build/perf/perf.json]
## --device takes a size and notches from tests/capture.gd (default iphone15_2556x1179); --seconds
## plays that much of the run (default: the whole level, about 2 minutes); --pause-at pauses the
## run that many seconds in (default 20); --ads=on keeps room for the ad banner; --jump-mb lists every
## frame whose texture memory grew by more than that (default 4 MB), with the nodes added then.
## macOS skips drawing a covered window: such frames are drawn on demand (force_draw), so the
## numbers hold, but keep --always-on-top. The first run records the bot (about 5 minutes, then
## kept in build/qa/). Frame times are only meaningful on a quiet machine (others' renders and
## builds show up as long frames: compare script_ms and render_ms).
##
## Texture memory counts what Godot allocates, minus this tool's own off-screen picture of the
## phone's screen (measured before the game loads; a phone draws straight to its screen).

const Capture := preload("res://tests/capture.gd")
const TEXTURE_BUDGET_MB := 80.0  ## at 2556 x 1179 (the brief)
const FRAME_BUDGET_MS := 16.0  ## work per frame during play, on a desktop
const SETTLE := 0.6  ## seconds after a screen change before its frames count
const MB := 1024.0 * 1024.0

var _vp: SubViewport
var _phase := ""  # the phase being sampled ("" = none)
var _samples := {}  # phase -> metric -> Array of values
var _own_target := 0.0  # bytes of texture memory of this tool's SubViewport
var _engine_base := 0.0  # bytes of texture memory before anything was loaded
var _undrawn := 0  # frames macOS didn't draw (covered window)
var _nodes := {}  # phase -> node count at its end
var _last_frame := 0  # Time.get_ticks_usec() of the last frame
var _timeline := []  # every 5 s of the run: [seconds, texture MB, nodes, draw calls]
var _phase_wall := {}  # phase -> wall seconds it lasted
var _first := _First.new()  # processes before every other node: the start of the frame's scripts
var _all_pictures := PackedStringArray()  # every picture in res://assets
var _cached := {}  # picture path -> true once in the resource cache
var _late_loads := []  # [seconds into the run, path] of pictures first loaded during the run
var _run_clock := -1.0  # seconds into the run (-1: not in the run)
var _spikes := []  # frames of play over the budget (wall), or with 3/4 of it of own work: [s, work, script, render ms]
var _jumps := []  # texture memory jumps over 4 MB in a frame: [s, phase, MB, the nodes added then]
var _added := {}  # what entered the tree since the last frame: script or class -> count
var _added_before := {}  # ... and in the frame before (the one just drawn)
var _last_texture := 0.0
var _jump_mb := 4.0  # texture memory growth in one frame worth listing (--jump-mb)


## The first node to process each frame: notes the time.
class _First extends Node:
	var at := 0

	func _init() -> void:
		process_priority = -1000000
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		at = Time.get_ticks_usec()


func _ready() -> void:
	Save.persist = false
	Save.tutorial_seen = true
	var a := _args()
	var device: String = a.get("device", "iphone15_2556x1179")
	var px: Vector2i = Capture.DEVICES[device].size if Capture.DEVICES.has(device) else Vector2i(2556, 1179)
	var insets: Vector4 = Capture.DEVICES[device].insets if Capture.DEVICES.has(device) else Vector4.ZERO
	if a.has("size"):
		var parts: PackedStringArray = a.size.split("x")
		px = Vector2i(int(parts[0]), int(parts[1]))
		device = "%dx%d" % [px.x, px.y]
		insets = Vector4.ZERO
	var design := Vector2(640.0 * px.x / px.y, 640.0)
	var k := design.y / px.y
	Device.debug_insets = insets * k
	Device.banner_height = 50.0 * px.y / 411.0 * k if a.get("ads", "off") == "on" else 0.0
	var replay := BotReplay.recorded(1)  # before measuring: the first time it takes minutes
	_jump_mb = float(a.get("jump-mb", "4"))
	process_priority = 1000000  # last: _process measures the frame's scripts since _first
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_first)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_all_pictures = _pictures("res://assets")
	get_tree().node_added.connect(func(n: Node) -> void:
		var what: String = n.get_script().resource_path.get_file() if n.get_script() else n.get_class()
		_added[what] = _added.get(what, 0) + 1)

	for i in 3:
		await get_tree().process_frame
	_engine_base = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	_vp = SubViewport.new()
	_vp.size = px
	_vp.size_2d_override = Vector2i(design.round())
	_vp.size_2d_override_stretch = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	RenderingServer.viewport_set_measure_render_time(_vp.get_viewport_rid(), true)
	var host := Control.new()
	host.size = design
	_vp.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 3:
		await get_tree().process_frame
	_own_target = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - _engine_base
	Nav.custom_viewport = _vp
	Nav.attach(host)

	print("perf at %s (%d x %d), own render target %.1f MB, engine %.1f MB" % [device, px.x, px.y, _own_target / MB, _engine_base / MB])
	# The menu (the game's pictures preload meanwhile, as after the logo).
	GameArt.preload_art()
	Nav.go(&"menu")
	await _settle()
	await _sample("menu", 3.0)
	_note_loads(-1.0)  # what the menu and the preload brought in
	# The run: loading is timed apart (a screen change, not play).
	_phase = "load"
	var bests := [Save.best_bobs, Save.best_stars]
	Nav.go(&"game", {"world": World.new()})
	while Nav.is_busy() or Nav.current_name != &"game":
		await get_tree().process_frame
	var game: Node = Nav.current
	game.autopilot = replay
	await _wait(SETTLE)
	_phase = "run"
	_run_clock = 0.0
	var seconds := float(a.get("seconds", "0"))
	var pause_at := float(a.get("pause-at", "20"))
	var t := 0.0
	var paused := false
	var next_mark := 0.0
	while game.world.state == World.State.RUNNING and (seconds <= 0.0 or t < seconds):
		if t >= next_mark:
			next_mark += 5.0
			_note_loads(t)
			_timeline.append([snappedf(t, 0.1), snappedf((Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - _own_target) / MB, 0.1),
					Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
					_vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)])
		if not paused and t >= pause_at:
			paused = true
			_phase = ""
			game.pause_game()
			await _wait(SETTLE)
			await _sample("paused", 2.0)
			game.resume_game()
			_phase = "run"
		await get_tree().process_frame
		t += get_process_delta_time()
	_nodes["run"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_run_clock = -1.0
	_phase = ""
	if game.world.state != World.State.RUNNING:
		_phase = ""
		await _wait(3.5)  # the panel's arrival
		await _sample("results", 2.0)
	print("  the run: %s after %.1f s of play, %d Red Bobs" % [World.State.keys()[game.world.state], game.world.ticks * World.TICK, game.world.bobs])
	# Back on the menu: nothing of the run may stay behind. (The records go back as they were: a new
	# best adds a star to the menu, not a leak.)
	Save.best_bobs = bests[0]
	Save.best_stars = bests[1]
	Nav.go(&"menu")
	await _settle()
	await _wait(1.0)
	await _sample("menu_again", 2.0)
	var ok := _report(device, px, a.get("out", "build/perf/perf_%s.json" % device))
	get_tree().quit(0 if ok else 1)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_frame) / 1000.0
	_last_frame = now
	if not DisplayServer.window_can_draw():
		_undrawn += 1
		RenderingServer.force_draw(false)
	var texture := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - _own_target
	if _last_texture > 0.0 and texture - _last_texture > _jump_mb * MB:
		var added := _added_before.duplicate()
		added.merge(_added)
		_jumps.append([snappedf(_run_clock, 0.01), _phase, snappedf((texture - _last_texture) / MB, 0.1), added])
	_last_texture = texture
	_added_before = _added.duplicate()
	_added.clear()
	if _run_clock >= 0.0:
		_run_clock += get_process_delta_time()
	if _phase.is_empty():
		return
	_phase_wall[_phase] = _phase_wall.get(_phase, 0.0) + frame_ms / 1000.0
	var rid := _vp.get_viewport_rid()
	var scripts := (now - _first.at) / 1000.0
	var render := RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
	if _phase == "run" and (frame_ms > FRAME_BUDGET_MS or scripts + render > FRAME_BUDGET_MS * 0.75):
		_spikes.append([snappedf(_run_clock, 0.01), snappedf(frame_ms, 0.1), snappedf(scripts, 0.1), snappedf(render, 0.1)])
	var m: Dictionary = _samples.get_or_add(_phase, {})
	for pair: Array in [
			["work_ms", frame_ms],
			["own_ms", scripts + render],
			["script_ms", scripts],
			["render_cpu_ms", render],
			["gpu_ms", RenderingServer.viewport_get_measured_render_time_gpu(rid)],
			["draw_calls", _vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)],
			["objects", _vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_OBJECTS_IN_FRAME)],
			["primitives", _vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)],
			["texture_mb", (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - _own_target) / MB],
			["video_mb", (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) - _own_target) / MB],
			["buffer_mb", Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / MB],
			["nodes", Performance.get_monitor(Performance.OBJECT_NODE_COUNT)],
			["orphans", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)]]:
		m.get_or_add(pair[0], []).append(float(pair[1]))


## Notes the pictures that entered the resource cache since the last call (-1: before the run).
func _note_loads(t: float) -> void:
	if _all_pictures.is_empty():
		_all_pictures = _pictures("res://assets")
	for path in _all_pictures:
		if not _cached.has(path) and ResourceLoader.has_cached(path):
			_cached[path] = true
			if t >= 0.0:
				_late_loads.append([snappedf(t, 0.1), path])


func _pictures(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			out.append_array(_pictures(dir.path_join(f)))
		elif f.ends_with(".png") or f.ends_with(".webp") or f.ends_with(".jpg"):
			out.append(dir.path_join(f))
	return out


## Waits for the screen change, then lets the new screen settle.
func _settle() -> void:
	while Nav.is_busy():
		await get_tree().process_frame
	await _wait(SETTLE)


func _sample(phase: String, seconds: float) -> void:
	_phase = phase
	await _wait(seconds)
	_nodes[phase] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_phase = ""


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Prints the table and the verdicts, saves them as JSON. Returns true if every budget holds.
func _report(device: String, px: Vector2i, out: String) -> bool:
	var table := {}
	print("\n%-11s %6s %8s %8s %8s %7s %8s %8s %8s %6s %7s %7s %9s %7s" % ["phase", "frames", "work avg", "work p99", "work max", ">16ms",
			"script", "render", "texture", "video", "draws", "objects", "primitive", "nodes"])
	for phase: String in ["menu", "load", "run", "paused", "results", "menu_again"]:
		if not _samples.has(phase):
			continue
		var m: Dictionary = _samples[phase]
		var row := {"frames": m.work_ms.size(), "wall_s": snappedf(_phase_wall.get(phase, 0.0), 0.1)}
		for key: String in m:
			row[key + "_max"] = snappedf(m[key].max(), 0.01)
			row[key + "_mean"] = snappedf(_mean(m[key]), 0.01)
		row.work_ms_p99 = snappedf(_percentile(m.work_ms, 0.99), 0.01)
		row.script_ms_p99 = snappedf(_percentile(m.script_ms, 0.99), 0.01)
		row.render_cpu_ms_p99 = snappedf(_percentile(m.render_cpu_ms, 0.99), 0.01)
		row.frames_over_budget = m.work_ms.filter(func(v: float) -> bool: return v > FRAME_BUDGET_MS).size()
		table[phase] = row
		print("%-11s %6d %8.2f %8.2f %8.2f %7d %8.2f %8.2f %7.1fM %5.1fM %6.0f %7.0f %9.0f %7.0f" % [phase, row.frames, row.work_ms_mean,
				row.work_ms_p99, row.work_ms_max, row.frames_over_budget, row.script_ms_p99, row.render_cpu_ms_p99,
				row.texture_mb_max, row.video_mb_max, row.draw_calls_max, row.objects_max, row.primitives_max, row.nodes_max])
	print("(work: wall ms per frame; script and render: 99th percentile ms)")
	var texture_peak := 0.0
	for phase: String in table:
		if phase != "load":
			texture_peak = maxf(texture_peak, table[phase].texture_mb_max)
	var run: Dictionary = table.get("run", {})
	var own_worst: float = run.get("own_ms_max", 0.0)
	var leaked: int = int(_nodes.get("menu_again", 0) - _nodes.get("menu", 0))
	var orphans: float = table.get("menu_again", {}).get("orphans_max", 0.0)
	var checks := [
		["texture memory %.1f MB (budget %.0f MB at 2556 x 1179)" % [texture_peak, TEXTURE_BUDGET_MB], texture_peak < TEXTURE_BUDGET_MB],
		["frames of play: worst %.2f ms of the game's own work (scripts + drawing), wall time p99 %.2f ms (budget %.0f ms)" % [
				own_worst, run.get("work_ms_p99", 0.0), FRAME_BUDGET_MS],
				table.has("run") and own_worst < FRAME_BUDGET_MS and run.get("work_ms_p99", 99.0) < FRAME_BUDGET_MS],
		["back on the menu: %+d nodes, %d orphan nodes" % [leaked, orphans], leaked <= 0 and orphans == 0],
	]
	var ok := true
	print("")
	for c: Array in checks:
		print("%s  %s" % ["PASS" if c[1] else "FAIL", c[0]])
		ok = ok and c[1]
	print("loading the level: worst frame %.0f ms (not play: a screen change)" % table.get("load", {}).get("work_ms_max", 0.0))
	print("texture memory through the run (s, MB, nodes, draw calls): ", _timeline)
	print("pictures first loaded during the run (s, path): ", _late_loads)
	print("frames of play over %.0f ms (s, work, script, render): %s" % [FRAME_BUDGET_MS, _spikes])
	print("texture memory jumps (s into the run, phase, MB, nodes added that frame): ")
	for j: Array in _jumps:
		print("  ", j)
	if _undrawn > 0:
		print("(%d frames drawn on demand: the window was covered)" % _undrawn)
	var path := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"device": device, "size": [px.x, px.y], "own_target_mb": snappedf(_own_target / MB, 0.01),
				"engine_mb": snappedf(_engine_base / MB, 0.01), "undrawn_frames": _undrawn, "phases": table, "timeline": _timeline, "late_loads": _late_loads, "spikes": _spikes, "texture_jumps": _jumps,
				"checks": checks.map(func(c: Array) -> Dictionary: return {"what": c[0], "pass": c[1]}), "pass": ok}, "  "))
		print("saved ", path)
	return ok


static func _mean(values: Array) -> float:
	var s := 0.0
	for v: float in values:
		s += v
	return s / maxf(values.size(), 1)


static func _percentile(values: Array, p: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[int(round(p * (sorted.size() - 1)))] if not sorted.is_empty() else 0.0


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			out[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	return out

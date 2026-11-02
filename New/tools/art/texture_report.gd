extends Node
## Texture memory, texture by texture: shows the menu, then plays the level (the bot playing) at a
## phone's size off screen and prints, for each, the total (Performance.RENDER_TEXTURE_MEM_USED)
## (tools/art/texture_budget.py lists what each picture costs).
##
## Godot --path . --fixed-fps 60 --resolution 200x200 --always-on-top res://tools/art/texture_report.tscn -- \
##     [--size=2556x1179] [--seconds=12] [--top=40]

const MB := 1024.0 * 1024.0

var _vp: SubViewport


func _ready() -> void:
	Save.persist = false
	Save.tutorial_seen = true
	var a := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			a[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	var parts: PackedStringArray = a.get("size", "2556x1179").split("x")
	var px := Vector2i(int(parts[0]), int(parts[1]))
	var design := Vector2(640.0 * px.x / px.y, 640.0)
	Device.debug_insets = Vector4.ZERO
	Device.banner_height = 0.0
	for i in 3:
		await get_tree().process_frame
	var base := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	_vp = SubViewport.new()
	_vp.size = px
	_vp.size_2d_override = Vector2i(design.round())
	_vp.size_2d_override_stretch = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var host := Control.new()
	host.size = design
	_vp.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 3:
		await get_tree().process_frame
	var own := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - base
	Nav.custom_viewport = _vp
	Nav.attach(host)
	GameArt.preload_art()
	Nav.go(&"menu")
	await _wait(3.0)
	_report("menu", own, int(a.get("top", "40")))
	Nav.go(&"game", {"world": World.new()})
	while Nav.is_busy() or Nav.current_name != &"game":
		await get_tree().process_frame
	_report("game loaded", own, 0)
	Nav.current.autopilot = Bot.new(1)
	var w: World = Nav.current.world
	var last := 0.0
	for i in int(float(a.get("seconds", "12")) * 4.0):  # what arrives when (pickups, rings, bandits)
		await _wait(0.25)
		var mb := (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - own) / MB
		if absf(mb - last) > 0.5:
			print("  %.2f s: %.1f MB (bobs %d, rings %d, knocked out %d, lives %d)" % [w.ticks * World.TICK, mb, w.bobs, w.rings.size(), w.knocked_out, w.lives])
			last = mb
	_report("run", own, int(a.get("top", "40")))
	var hud: Node = Nav.current.get("hud")
	if hud:
		hud.queue_free()
		await _wait(0.5)
		_report("run without the HUD", own, 0)
	get_tree().quit()


func _report(phase: String, own: float, _top: int) -> void:
	var total := (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - own) / MB
	print("== %s: %.1f MB of textures (own target %.1f MB left out), video %.1f MB" % [phase, total, own / MB, (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) - own) / MB])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

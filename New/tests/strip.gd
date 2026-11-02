extends Node
## Motion review: plays the game off screen at a phone size and saves a contact sheet of frames
## (a strip of the motion), to judge timing, squash and effects frame by frame.
##
## Godot --path . --fixed-fps 60 --resolution 200x200 --always-on-top res://tests/strip.tscn -- \
##     --out=build/strips/run.png [--frames=12] [--every=2] [--crop=x,y,w,h] [--cols=6]
##     [--moment="ticks >= 250"] [--bot] [--warm=30] [--act=throw@0,jump@10]
##     [--bandit=220] [--hurt=1] [--bobs=90] [--hang=1] [--scale=0.5] [--size=1280x720]
##     [--at=2440] [--y=380] [--lives=1] [--falls=1]
## Each picture is drawn on demand (_draw_now): macOS skips drawing covered windows.
##
## --crop is in design units (the 640-tall screen); --act gives actions at frame numbers
## (throw, jump, down, right, hurt, win, die, fall, menu, pause, resume); --bandit puts a bandit that many units ahead of
## Panoramic; --hurt=1 makes it already hit once; --warm runs that many frames before the strip;
## --at puts him at that level x (his centre; the bandits near it are sent away), --y at that height
## (above the ground he falls), --lives leaves him that many, --falls=1 turns on falls_cost_life.

func _ready() -> void:
	Save.persist = false
	Save.tutorial_seen = true
	var a := _args()
	var px := Vector2i(1280, 720)
	if a.has("size"):
		var parts: PackedStringArray = a.size.split("x")
		px = Vector2i(int(parts[0]), int(parts[1]))
	var design := Vector2(640.0 * px.x / px.y, 640.0)
	Device.debug_insets = Vector4.ZERO
	Device.banner_height = 0.0

	var w := World.new()
	w.stand_at_start()
	if a.has("moment"):
		var bot := Bot.new(1)
		var e := Expression.new()
		e.parse(a.moment, ["ticks", "scroll", "x", "y", "hanging", "at_end", "on_ground", "bobs"])
		while w.state == World.State.RUNNING and w.ticks < 9000:
			bot.act(w)
			w.tick()
			if e.execute([w.ticks, w.scroll, w.x, w.y, w.hanging, w.at_end, w.on_ground, w.bobs]):
				break
		w = w.clone()
	if a.has("at"):
		w.scroll = float(a.at) - w.x
		w.prev_scroll = w.scroll
		for b in w.bandits:
			if absf(b.x - float(a.at)) < 1500.0:
				b.gone = true
	if a.has("y"):
		w.y = float(a.y)
		w.prev_y = w.y
		w.vy = 0.0
		w.on_ground = false
		w._air_ticks = 99
	w.falls_cost_life = a.has("falls") or Config.value("rules", "falls_cost_life", false)
	if a.has("lives"):
		w.lives = int(a.lives)
	if a.has("bobs"):
		w.bobs = int(a.bobs)
	if a.has("hang"):  # starts hanging from the vine
		w.y = 0.0
		w.prev_y = 0.0
		w.vy = 0.0
		w.hanging = true
		w.on_ground = false
		w._air_ticks = 99
	if a.has("bandit"):
		for b in w.bandits:
			if absf(b.x - w.scroll - w.x) < 1500.0:
				b.gone = true
		var b: World.Bandit = w.bandits[w.bandits.size() - 1]
		b.gone = false
		b.active = true
		b.health = World.BANDIT_HEALTH - int(a.get("hurt", "0"))
		b.hurt = b.health < World.BANDIT_HEALTH
		b.x = w.scroll + w.x + float(a.bandit)
		b.y = w.ground_y + 10.0
		b.prev_x = b.x
		b.prev_y = b.y

	var vp := SubViewport.new()
	vp.size = px
	vp.size_2d_override = Vector2i(design.round())
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var host := Control.new()
	host.size = design
	vp.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Nav.custom_viewport = vp
	Nav.attach(host)
	Nav.go(&"game", {"world": w})
	for i in 30:
		await get_tree().process_frame
	var game: Node = Nav.current
	if game._start_card:  # the "Tap to start" card belongs to the start of a run, not to a moment
		game._start_card.visible = false
		game._start_card.queue_free()
		game._start_card = null
	game._start()
	if a.has("bot"):
		game.autopilot = Bot.new(7)
	var acts := {}
	for item: String in String(a.get("act", "")).split(",", false):
		var at := item.split("@")
		acts[int(at[1])] = acts.get(int(at[1]), []) + [at[0]]
	for i in int(a.get("warm", "0")):
		await get_tree().process_frame

	var frames := int(a.get("frames", "12"))
	var every := int(a.get("every", "2"))
	var k := px.y / 640.0
	var crop := Rect2i(Vector2i.ZERO, px)
	if a.has("crop"):
		var c: PackedStringArray = a.crop.split(",")
		crop = Rect2i(Vector2i(int(float(c[0]) * k), int(float(c[1]) * k)), Vector2i(int(float(c[2]) * k), int(float(c[3]) * k)))
	var shots: Array[Image] = []
	for f in frames * every:
		for act: String in acts.get(f, []):
			_do(game, act)
		_draw_now()
		if f % every == 0:
			shots.append(vp.get_texture().get_image().get_region(crop))
		await get_tree().process_frame
	var cols := mini(int(a.get("cols", "6")), shots.size())
	var rows := ceili(shots.size() / float(cols))
	var cw := crop.size.x
	var ch := crop.size.y
	var sheet := Image.create_empty(cols * cw + (cols - 1) * 4, rows * ch + (rows - 1) * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in shots.size():
		var img := shots[i]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * (cw + 4), (i / cols) * (ch + 4)))
	var scale := float(a.get("scale", "1"))
	if scale != 1.0:
		sheet.resize(int(sheet.get_width() * scale), int(sheet.get_height() * scale), Image.INTERPOLATE_LANCZOS)
	var out: String = a.get("out", "build/strips/strip.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("strip saved: ", out, " ", sheet.get_size())
	get_tree().quit()


func _do(game: Node, act: String) -> void:
	var w: World = game.world
	match act:
		"throw":
			w.throw()
		"jump":
			w.jump()
		"down":
			w.down()
		"right":
			w.step_forward()
		"hurt":
			w.lives -= 1
			w.hurt.emit(w.bandits[0], w.lives)
		"win":
			w.state = World.State.WON
			w.won.emit()
		"die":
			w._die(&"bandit")
		"fall":
			w._die(&"fall")
		"menu":
			Nav.go(&"menu", {}, Vector2(400, 300))
		"pause":
			game.pause_game()
		"resume":
			game.resume_game()


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			out[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
		elif a.begins_with("--"):
			out[a.substr(2)] = "1"
	return out


## Draws this frame now. macOS doesn't draw a covered window, or one on another desktop, while the
## game keeps running: waiting for the next drawn frame could skip moments or wait forever.
func _draw_now() -> void:
	RenderingServer.force_draw(false)

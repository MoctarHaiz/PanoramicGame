extends Node
## (round 23) The characters' review picture: Panoramic at a moment of the bot's run with the two bandit kinds placed
## ahead of him, running on the same ground, rendered at a phone's size (tests/strip.gd's set-up, both kinds at once).
## Prints the camera's screen px per play unit, so heights measured on the atlases convert to screen px.
##
## Godot --path . --fixed-fps 60 --resolution 200x200 --always-on-top res://tools/art/char_lineup.tscn -- \
##     --out=FILE.png [--size=2556x1179] [--moment="ticks >= 250"] [--bandits=230:n,400:s] [--warm=20]
##     [--frames=1] [--every=4] [--crop=x,y,w,h (design units)] [--hide=Name,Name] [--idle=1] [--hang=1]


func _ready() -> void:
	Save.persist = false
	Save.tutorial_seen = true
	var a := _args()
	var px := Vector2i(2556, 1179)
	if a.has("size"):
		var parts: PackedStringArray = a.size.split("x")
		px = Vector2i(int(parts[0]), int(parts[1]))
	var design := Vector2(640.0 * px.x / px.y, 640.0)
	# the iPhone 15's safe area (tests/capture.gd), so the camera frames the play as on the phone
	var ins: PackedStringArray = String(a.get("insets", "177,0,177,63")).split(",")
	Device.debug_insets = Vector4(float(ins[0]), float(ins[1]), float(ins[2]), float(ins[3])) * (640.0 / px.y)
	Device.banner_height = 0.0
	var w := World.new()
	w.stand_at_start()
	if a.has("moment"):
		w = World.new()
		var replay := BotReplay.recorded(1)
		var e := Expression.new()
		e.parse(a.moment, ["ticks", "scroll", "x", "y", "hanging", "at_end", "on_ground", "bobs"])
		while w.state == World.State.RUNNING and w.ticks < 9000:
			replay.act(w)
			w.tick()
			if e.execute([w.ticks, w.scroll, w.x, w.y, w.hanging, w.at_end, w.on_ground, w.bobs]):
				break
		w = BotReplay.snapshot(w)
	if a.has("hang"):
		w.y = 0.0
		w.prev_y = 0.0
		w.vy = 0.0
		w.hanging = true
		w.on_ground = false
		w._air_ticks = 99
	var wanted: PackedStringArray = String(a.get("bandits", "")).split(",", false)
	if not wanted.is_empty():
		for b in w.bandits:
			if absf(b.x - w.scroll - w.x) < 1800.0:
				b.gone = true
		var spare := w.bandits.size() - 1
		for item in wanted:
			var parts := item.split(":")
			var b: World.Bandit = w.bandits[spare]
			spare -= 1
			b.gone = false
			b.active = true
			b.strong = parts.size() > 1 and parts[1] == "s"
			b.health = World.STRONG_HEALTH if b.strong else World.BANDIT_HEALTH
			b.hurt = false
			b.x = w.scroll + w.x + float(parts[0])
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
	if not a.has("idle"):
		if game._start_card:
			game._start_card.visible = false
			game._start_card.queue_free()
			game._start_card = null
		game._start()
	for name: String in String(a.get("hide", "")).split(",", false):
		for n: Node in game.find_children(name, "CanvasItem", true, false):
			n.visible = false
	for i in int(a.get("warm", "20")):
		await get_tree().process_frame
	var k := px.y / 640.0
	var crop := Rect2i(Vector2i.ZERO, px)
	if a.has("crop"):
		var c: PackedStringArray = a.crop.split(",")
		crop = Rect2i(Vector2i(int(float(c[0]) * k), int(float(c[1]) * k)), Vector2i(int(float(c[2]) * k), int(float(c[3]) * k)))
	var frames := int(a.get("frames", "1"))
	var every := int(a.get("every", "4"))
	var shots: Array[Image] = []
	for f in frames * every:
		RenderingServer.force_draw(false)
		if f % every == 0:
			shots.append(vp.get_texture().get_image().get_region(crop))
		await get_tree().process_frame
	print("screen px per unit: %.4f" % (px.y / 640.0 * float(game._zoom)))
	if a.has("measure"):  # each character's drawn height on screen: the picture with and without it
		var base := vp.get_texture().get_image()
		var kinds := {"hero": func(n: Node) -> bool: return n is HeroView,
				"bandit": func(n: Node) -> bool: return n is BanditView and not (n as BanditView).bandit.strong,
				"strong bandit": func(n: Node) -> bool: return n is BanditView and (n as BanditView).bandit.strong}
		var paused := game.get_tree().paused
		game.get_tree().paused = true  # (the same frame for each picture)
		for what: String in kinds:
			var hidden: Array[CanvasItem] = []
			for n: Node in game.find_children("*", "Node2D", true, false):
				if kinds[what].call(n):
					var sprite: CanvasItem = n.get(&"_sprite")  # (the figure alone: its shadow stays)
					if sprite.visible:
						sprite.visible = false
						hidden.append(sprite)
			if hidden.is_empty():
				continue
			RenderingServer.force_draw(false)
			var other := vp.get_texture().get_image()
			var top := px.y
			var bottom := -1
			for y in range(0, px.y, 1):
				for x in range(0, px.x, 2):
					var d := base.get_pixel(x, y) - other.get_pixel(x, y)
					if absf(d.r) + absf(d.g) + absf(d.b) > 0.12:
						top = mini(top, y)
						bottom = maxi(bottom, y)
						break
			for n in hidden:
				n.visible = true
			print("%s: drawn %d px tall on screen (rows %d-%d, its ink included)" % [what, bottom - top + 1, top, bottom])
		game.get_tree().paused = paused
	var cols := mini(int(a.get("cols", "4")), shots.size())
	var rows := ceili(shots.size() / float(cols))
	var sheet := Image.create_empty(cols * crop.size.x + (cols - 1) * 4, rows * crop.size.y + (rows - 1) * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in shots.size():
		var img := shots[i]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * (crop.size.x + 4), (i / cols) * (crop.size.y + 4)))
	var out: String = a.get("out", "build/strips/lineup.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	print("lineup saved: ", out, " ", sheet.get_size())
	get_tree().quit()


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			out[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
		elif a.begins_with("--"):
			out[a.substr(2)] = "1"
	return out

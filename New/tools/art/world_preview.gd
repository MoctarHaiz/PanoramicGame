extends Node
## Renders the level's world alone (no HUD, no bot run) at chosen scroll positions, for art review:
##
##   Godot --path . --resolution 200x200 res://tools/art/world_preview.tscn -- \
##       --out=build/world --at=0,5200,24640 [--size=2400x1080] [--hero=x,y] [--time=2.0]
##
## --at: level scroll values (24640 = the last screen; Panoramic then stands in the doorway).
## --hero: his play-window centre (default: on the ground at x 230, or 772 on the last screen).

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var out: String = args.get("out", "build/world")
	DirAccess.make_dir_recursive_absolute(out)
	var dims: PackedStringArray = String(args.get("size", "2400x1080")).split("x")
	var size := Vector2i(int(dims[0]), int(dims[1]))
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var w := World.new()
	w.stand_at_start()
	var stage := Node2D.new()
	vp.add_child(stage)
	var view := WorldView.new()
	stage.add_child(view)
	var t0 := Time.get_ticks_usec()
	view.setup(w)
	print("world view set up in %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var k := size.y / World.VIEW_H
	stage.scale = Vector2(k, k)
	view.view_left = 0.0
	view.view_width = size.x / k
	var settle := float(args.get("time", "2.0"))
	for at_text in String(args.get("at", "0")).split(","):
		var at := float(at_text)
		w.scroll = minf(at, World.SCROLL_END)
		w.prev_scroll = w.scroll
		w.at_end = at >= World.SCROLL_END
		var hero := Vector2(772.0 if w.at_end else 230.0, w.ground_y)
		if args.has("hero"):
			var h: PackedStringArray = String(args.hero).split(",")
			hero = Vector2(float(h[0]), float(h[1]))
		w.x = hero.x
		w.prev_x = hero.x
		w.y = hero.y
		w.prev_y = hero.y
		var t := 0.0
		while t < settle:
			view.refresh(1.0 / 60.0)
			await get_tree().process_frame
			t += 1.0 / 60.0
		# drawn on demand: macOS skips drawing a covered window (as tests/capture.gd)
		RenderingServer.force_draw(false)
		var img := vp.get_texture().get_image()
		var path := out.path_join("world_%d_%dx%d.png" % [int(at), size.x, size.y])
		img.save_png(path)
		print("saved ", path)
	get_tree().quit()

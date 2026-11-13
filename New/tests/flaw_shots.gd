extends Node
## Environment-art review: the level's world drawn as the level editor's preview draws it (the game's
## own views, no actors, no light grade), saved in overlapping windows along the whole level, to find
## seams, cut sprites and pieces drawn in another language than their neighbours.
##
## Godot --path . res://tests/flaw_shots.tscn -- --out=build/flaws/before [--x0=-200] [--x1=25800]
##     [--step=800] [--w=960] [--scale=2] [--y0=0]
## Each window is --w units wide and the level's 640 tall, at --scale pixels a unit, saved as
## <out>/x<left>.png. --y0 is the window's top in level units (-180: the vine and the canopy over it).


func _ready() -> void:
	var a := {"out": "build/flaws/shots", "x0": "-200", "x1": "25800", "step": "800", "w": "960", "scale": "2", "y0": "0"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var kv := arg.substr(2).split("=", true, 1)
			a[kv[0]] = kv[1]
	var k := float(a.scale)
	var w := float(a.w)
	var vp := SubViewport.new()
	vp.size = Vector2i(roundi(w * k), roundi(Level.HEIGHT * k))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	var level := Level.load_default()
	var view := WorldView.new()  # (assembled as the level editor's preview: level_editor.gd _rebuild())
	view.world = World.new(level, false)
	view.view_width = Level.WIDTH
	view._background = SavannaView.new()
	view._background.view_width = Level.WIDTH
	view.add_child(view._background)
	view._canopy = CanopyView.new()  # (as WorldView.setup(): the boughs the vine hangs from, behind the ground)
	view._canopy.view_width = Level.WIDTH + 1000.0
	view.add_child(view._canopy)
	view._level_root = Node2D.new()
	view.add_child(view._level_root)
	view._add_home()
	view._add_water()
	view._add_props()
	view._add_ground()
	view._add_water_front()
	view._level_root.add_child(view._home.yard)
	for c in Level.COLS:
		for r in Level.ROWS:
			if level.kind_at(c, r) == Level.Kind.BOB:
				var bob := BobView.new(c, r)
				bob.position = Vector2(c + 0.5, r + 0.5) * Level.TILE
				view._level_root.add_child(bob)
	view._vine = VineView.new()
	view._vine.view_width = Level.WIDTH
	view.add_child(view._vine)
	view.add_child(view._ground.front)
	view._home.front.visible = false
	view.add_child(view._home.front)
	var span := Vector2(-12.0, Level.COLS + WorldView.EXTRA_COLUMNS) * Level.TILE
	view._ground.ensure(span.x, span.y)
	view._props.ensure(span.x, span.y)
	vp.add_child(view)
	view._background.front.visible = false
	view.add_child(view._background.front)
	view._background._process(0.0)
	view._background.set_process(false)
	view._vine.set_process(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + a.out))
	var x := float(a.x0)
	while x < float(a.x1):
		vp.canvas_transform = Transform2D(0.0, Vector2(k, k), 0.0, Vector2(-x * k, -float(a.y0) * k))
		for i in 3:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("res://%s/x%05d.png" % [a.out, int(x)])
		x += float(a.step)
	print("flaw_shots: done")
	get_tree().quit()

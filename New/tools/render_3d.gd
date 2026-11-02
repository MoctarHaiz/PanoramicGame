extends SceneTree
## Renders a 3D model to transparent PNGs in the soft, toy-like "3D render" look, with Godot itself
## (free, already installed): matte materials, a soft key light from the upper left front, a warm
## rim light on the right, ambient occlusion, filmic tone mapping. Use it for characters, props,
## the icon subject and the logo art when no image generator is used.
##
##   Godot --path PROJECT --rendering-method forward_plus --resolution 256x256 --always-on-top \
##       -s tools/render_3d.gd -- --model=res://art3d/hero.tscn --out=DIR [--size=1024] [--frames=1]
##       [--yaw=0] [--spin=0] [--ortho=0] [--name=hero]
##
## The model scene's origin should be at its feet; it is framed automatically from its bounds.
## --frames > 1 with --spin=360 gives a turntable; for poses, put an AnimationPlayer named "Anim"
## in the model with one animation: frames are sampled evenly across it.
## Without --model, a demo toy (body, head, eyes) is built so the pipeline can be checked.
## Needs a window (not --headless: the headless driver draws nothing).

const KEY_DIR := Vector3(-35, -40, 0)  # pitch, yaw in degrees: from the upper left front
const RIM_COLOR := Color(1.0, 0.72, 0.45)


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var size := int(args.get("size", "1024"))
	var out: String = args.get("out", "user://renders")
	var frames := int(args.get("frames", "1"))
	var spin := float(args.get("spin", "0"))
	var name: String = args.get("name", "render")
	DirAccess.make_dir_recursive_absolute(out)

	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.84, 1.0)  # faintly violet fill, never neutral black shadows
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = KEY_DIR
	key.light_energy = 1.25
	key.light_color = Color(1.0, 0.97, 0.92)
	key.shadow_enabled = true
	key.directional_shadow_blend_splits = true
	key.light_angular_distance = 6.0  # soft shadow edges
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 120, 0)  # from behind, right
	rim.light_energy = 1.1
	rim.light_color = RIM_COLOR
	vp.add_child(rim)

	var model: Node3D
	if args.has("model"):
		model = (load(args.model) as PackedScene).instantiate()
	else:
		model = _demo_toy()
	var pivot := Node3D.new()
	pivot.rotation_degrees.y = float(args.get("yaw", "0"))
	pivot.add_child(model)
	vp.add_child(pivot)

	var cam := Camera3D.new()
	vp.add_child(cam)
	await process_frame
	var box := _bounds(model)
	var centre := box.get_center()
	var extent := maxf(box.size.y, box.size.x) * 0.5 * 1.12  # a little margin
	if args.get("ortho", "0") == "1":
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = extent * 2.0
		cam.position = centre + Vector3(0, 0, extent * 4.0)
	else:
		cam.fov = 30.0  # long lens: little distortion, like a product shot
		cam.position = centre + Vector3(0, extent * 0.15, extent / tan(deg_to_rad(cam.fov * 0.5)))
	cam.look_at(centre)

	var anim: AnimationPlayer = model.get_node_or_null("Anim")
	var clip := ""
	if anim and not anim.get_animation_list().is_empty():
		clip = anim.get_animation_list()[0]
	for i in frames:
		var t := float(i) / maxf(frames, 1)
		pivot.rotation_degrees.y = float(args.get("yaw", "0")) + spin * t
		if clip != "":
			anim.play(clip)
			anim.seek(anim.get_animation(clip).length * t, true)
			anim.pause()
		for _w in 3:  # let shadows and SSAO settle
			await process_frame
		RenderingServer.force_draw()
		await process_frame
		var img := vp.get_texture().get_image()
		var file := "%s/%s%s.png" % [out, name, "" if frames == 1 else "_%02d" % i]
		img.save_png(file)
		print("saved ", ProjectSettings.globalize_path(file))
	quit()


func _bounds(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for child in n.find_children("*", "VisualInstance3D", true, false) + ([n] if n is VisualInstance3D else []):
		var vi := child as VisualInstance3D
		var b := vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Matte "vinyl toy" material: soft, slightly glossy, no texture.
static func toy(color: Color, roughness := 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	return m


func _demo_toy() -> Node3D:
	var toy_root := Node3D.new()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.45
	capsule.height = 1.4
	body.mesh = capsule
	body.position.y = 0.7
	body.material_override = toy(Color("#987fff"))
	toy_root.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	head.mesh = sphere
	head.position.y = 1.7
	head.material_override = toy(Color("#c98a5c"), 0.6)
	toy_root.add_child(head)
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var e := SphereMesh.new()
		e.radius = 0.07
		e.height = 0.14
		eye.mesh = e
		eye.position = Vector3(0.14 * side, 1.76, 0.37)
		eye.material_override = toy(Color("#1f1a36"), 0.2)
		toy_root.add_child(eye)
	return toy_root

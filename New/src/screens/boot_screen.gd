extends Screen
## The first screen: the Haiz Studio logo on white while the game wakes up (and, later, the ad
## consent form runs), then the menu.

const HOLD := 1.3


func enter(_data: Dictionary) -> void:
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/art/haiz_studio.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(330, 180)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(logo)
	add_child(center)
	logo.pivot_offset = logo.custom_minimum_size / 2
	logo.scale = Vector2.ONE * 0.86
	logo.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(logo, "modulate:a", 1.0, 0.35)
	t.tween_property(logo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Google's consent form (and Apple's tracking prompt) runs while the logo shows; the effect
	# shaders compile meanwhile, so the first pickup doesn't stutter.
	Fx.warm_up(self)
	GameArt.preload_art()  # the game's pictures load on background threads meanwhile
	Services.ads.start()
	await get_tree().create_timer(HOLD).timeout
	if not Services.ads.consent_done:
		await Services.ads.consent_finished
	if is_inside_tree():
		Nav.go(&"menu")


func back() -> void:
	pass

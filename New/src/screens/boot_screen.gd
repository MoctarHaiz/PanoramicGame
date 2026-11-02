extends Screen
## The first screen: the Haiz Studio logo on warm paper (a soft light in the middle, the edges a
## little deeper) while the game wakes up (and the ad consent form runs), three sunset dots bouncing
## under it, then the menu.

const HOLD := 1.3

var _dots: Array[Control] = []
var _clock := 0.0


func enter(_data: Dictionary) -> void:
	var bg := ColorRect.new()
	bg.color = Color("fff8ee")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var light := TextureRect.new()  # the warm light in the middle
	light.texture = Fx.glow_texture()
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.stretch_mode = TextureRect.STRETCH_SCALE
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	light.modulate = Color(1, 1, 1, 0.9)
	add_child(light)
	var edges := TextureRect.new()
	edges.texture = Fx.vignette_texture()
	edges.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	edges.stretch_mode = TextureRect.STRETCH_SCALE
	edges.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edges.modulate = Color(0.85, 0.5, 0.25, 0.22)
	add_child(edges)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/art/haiz_studio.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(360, 200)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 34)
	column.add_child(logo)
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override(&"separation", 14)
	for i in 3:
		var d := Control.new()
		d.custom_minimum_size = Vector2(16, 16)
		d.draw.connect(func() -> void:
			d.draw_circle(Vector2(8, 10), 8.0, Color(Ui.BRAND_DARK, 0.35), true, -1, true)
			d.draw_circle(Vector2(8, 8), 8.0, Ui.BRAND, true, -1, true)
			d.draw_circle(Vector2(6, 6), 3.0, Color(1, 1, 1, 0.6), true, -1, true))
		dots.add_child(d)
		_dots.append(d)
	column.add_child(dots)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(column)
	add_child(center)
	logo.pivot_offset = logo.custom_minimum_size / 2
	logo.scale = Vector2.ONE * 0.86
	logo.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(logo, "modulate:a", 1.0, 0.35)
	t.tween_property(logo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Google's consent form (and Apple's tracking prompt) runs while the logo shows; the effect
	# shaders compile meanwhile, so the first pickup doesn't stutter.
	Prefs.apply_volumes()
	Fx.warm_up(self)
	GameArt.preload_art()  # the game's pictures load on background threads meanwhile
	Services.ads.start()
	await get_tree().create_timer(HOLD).timeout
	if not Services.ads.consent_done:
		await Services.ads.consent_finished
	if is_inside_tree():
		Nav.go(&"menu")


## The dots bounce one after the other (still, with reduced motion).
func _process(delta: float) -> void:
	if not Prefs.motion():
		return
	_clock += delta
	for i in _dots.size():
		_dots[i].position.y = -absf(sin(_clock * 5.0 - i * 0.7)) * 10.0


func back() -> void:
	pass

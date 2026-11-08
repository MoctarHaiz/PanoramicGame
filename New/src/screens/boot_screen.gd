extends Screen
## The first screen, a title card while the game wakes up (and the ad consent form runs): a deep
## warm dusk, a soft light swelling in the middle, and in it the Haiz Studio logo on a cream plaque
## in the kit's wooden frame (the logo's light colours need a light ground); under it a gold bar
## fills, then the menu.

const HOLD := 1.3

var _bar: Control
var _clock := 0.0


func enter(_data: Dictionary) -> void:
	var bg := TextureRect.new()  # dusk: plum above, warm brown below
	var g := GradientTexture2D.new()
	g.fill_from = Vector2(0.5, 0.0)
	g.fill_to = Vector2(0.5, 1.0)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color("2a0f22"))
	g.gradient.set_color(1, Color("4a1c10"))
	bg.texture = g
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var light := TextureRect.new()  # the warm light in the middle
	light.texture = Fx.glow_texture()
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.stretch_mode = TextureRect.STRETCH_SCALE
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	light.modulate = Color(1, 0.62, 0.32, 0.75)
	light.material = Fx.additive()
	add_child(light)
	var edges := TextureRect.new()
	edges.texture = Fx.vignette_texture()
	edges.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	edges.stretch_mode = TextureRect.STRETCH_SCALE
	edges.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edges.modulate = Color(0.05, 0.0, 0.03, 0.8)
	add_child(edges)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/art/haiz_studio.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(420, 250)
	var plaque := Card.new(Vector4(52, 44, 52, 44))
	plaque.add_child(logo)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 44)
	column.add_child(plaque)
	_bar = Control.new()  # the gold bar, filling
	_bar.custom_minimum_size = Vector2(300, 18)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.draw.connect(_draw_bar)
	column.add_child(_bar)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(column)
	add_child(center)
	column.pivot_offset = Vector2(260, 200)
	column.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(column, "modulate:a", 1.0, 0.35)
	light.modulate.a = 0.0
	t.tween_property(light, "modulate:a", 0.75, 0.8)
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


func _process(delta: float) -> void:
	_clock += delta
	if _bar:
		_bar.queue_redraw()


## A sunken groove and a gold fill growing to its end over HOLD (then it waits, full).
func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, _bar.size)
	var ci := _bar.get_canvas_item()
	GlossStyle.fill_rounded(ci, r.grow(2.0), r.size.y / 2 + 2.0, Card.INK, Card.INK)
	GlossStyle.fill_rounded(ci, r, r.size.y / 2, Color("3a1a10"), Color("5a2a18"))
	var k := clampf(_clock / HOLD, 0.0, 1.0)
	k = 1.0 - pow(1.0 - k, 2.0)
	var w := maxf(r.size.x * k, r.size.y)
	GlossStyle.fill_rounded(ci, Rect2(r.position, Vector2(w, r.size.y)), r.size.y / 2, Color("ffd34a"), Color("e8860e"))
	GlossStyle.fill_rounded(ci, Rect2(r.position + Vector2(4, 3), Vector2(maxf(w - 8, 0), 4)), 2.0,
			Color(1, 1, 0.9, 0.7), Color(1, 1, 0.9, 0.4))


func back() -> void:
	pass

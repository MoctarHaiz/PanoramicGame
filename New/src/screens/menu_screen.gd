extends Screen
## The menu: the sunset; Panoramic (the hero sheet's portrait) on the right in a slow halo of rays,
## lit by the sunset (portrait.gdshader: a warm rim on his sun side, the dusk in his shadows, his
## chest fading into the grass); on the left the CHAKA ZULU logo (gold letters, a Zulu shield and
## an assegai as its emblem, tools/art/logo.py) with its subtitle on a beadwork ribbon, a big PLAY,
## the best run and the settings. Dust drifts up through the
## light. Everything arrives in a short choreography: the hero slides in, the logo drops and
## bounces, the ribbon unrolls, PLAY pops, the rest fades in. Then the logo catches the light now
## and then and PLAY breathes.

const LOGO := preload("res://assets/art/ui/logo.png")
const RIBBON := preload("res://assets/art/ui/ribbon.png")

var _hero: TextureRect
var _halo: Rays
var _halo_glow: TextureRect
var _logo_box: Control  # sized by _layout; the logo and its ribbon inside
var _logo: TextureRect
var _ribbon: Control
var _play_box: Control
var _play_pop: Control  # unmanaged inside _play_box: what the entrance scales
var _play: JuicyButton
var _row: HBoxContainer
var _front_grass: TextureRect  # dark backlit grass in front of his chest
var _clock := 0.0


func enter(_data: Dictionary) -> void:
	add_child(SunsetBackdrop.new())
	# the hero's halo: a soft warm light and slow rays behind him
	_halo_glow = TextureRect.new()
	_halo_glow.texture = Fx.glow_texture()
	_halo_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo_glow.modulate = Color(1, 0.72, 0.4, 0.85)
	_halo_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo_glow.material = Fx.additive()
	add_child(_halo_glow)
	_halo = Rays.new(1200, Color(1, 0.86, 0.56, 0.1), 12)  # a soft breath of light, not a sunburst
	_halo.material = Fx.additive()
	add_child(_halo)
	add_child(Motes.new(30))
	_hero = TextureRect.new()
	_hero.texture = load("res://assets/art/hero/portrait.png")
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lit := ShaderMaterial.new()
	lit.shader = preload("res://src/ui/portrait.gdshader")
	_hero.material = lit
	add_child(_hero)
	_front_grass = _foreground()
	add_child(_front_grass)
	add_child(_vignette())

	var area := safe_area(true, 18.0)
	add_child(area)
	var columns := HBoxContainer.new()
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(columns)
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override(&"separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.1
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(left)
	columns.add_child(Ui.spacer(0.9))

	# the logo, its subtitle ribbon over its foot
	_logo_box = Control.new()
	_logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(_logo_box)
	var twinkles := Twinkles.new(6)
	twinkles.smallest = 12.0
	twinkles.largest = 30.0
	_logo_box.add_child(twinkles)
	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shine := ShaderMaterial.new()
	shine.shader = preload("res://src/ui/shine.gdshader")
	shine.set_shader_parameter(&"period", 4.5)
	shine.set_shader_parameter(&"offset", 1.2)
	_logo.material = shine
	_logo_box.add_child(_logo)
	_ribbon = ribbon(tr("MENU_SUBTITLE"), 31)
	_logo_box.add_child(_ribbon)
	twinkles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_play_box = Control.new()
	_play_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_box.custom_minimum_size = Vector2(390, 108)
	_play_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(_play_box)
	_play_pop = Control.new()
	_play_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_pop.size = _play_box.custom_minimum_size
	_play_pop.pivot_offset = _play_pop.size / 2
	_play_box.add_child(_play_pop)
	_play = Ui.candy_button(tr("PLAY"), "play-fill", Ui.Tone.GREEN, 108, 56)
	_play.size = _play_box.custom_minimum_size
	_play.pressed.connect(func() -> void: Nav.go(&"game", {}, _play.get_global_rect().get_center()))
	_play.idle(0.06)
	_play.shine()
	_play_pop.add_child(_play)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override(&"separation", 14)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Save.games_played > 0:
		_row.add_child(_best_plaque())
	var settings := _wood_button("gear-six-fill", 74.0)
	settings.pressed.connect(func() -> void: Nav.go(&"settings", {}, settings.get_global_rect().get_center()))
	_row.add_child(settings)
	left.add_child(_row)

	resized.connect(_layout)
	Device.changed.connect(_layout)
	_layout()
	_arrive()
	Audio.play_music(&"menu")
	Services.ads.show_banner(true)


func _exit_tree() -> void:
	if Device.changed.is_connected(_layout):
		Device.changed.disconnect(_layout)


## The best run on a plate of glazed wood (the HUD's plate): the Red Bob, "BEST" over the count,
## the stars.
func _best_plaque() -> PanelContainer:
	var s := Hud.plate(37.0)
	s.content_margin_left = 12
	s.content_margin_right = 22
	s.content_margin_top = 6
	s.content_margin_bottom = 11
	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override(&"panel", s)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bob := TextureRect.new()
	bob.texture = BobView.texture()
	bob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bob.custom_minimum_size = Vector2(56, 56)
	bob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bob)
	var words := VBoxContainer.new()
	words.add_theme_constant_override(&"separation", -6)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(Ui.label(tr("BEST").to_upper(), 19, Color("ffd9b0"), Ui.font_strong, HORIZONTAL_ALIGNMENT_LEFT))
	var count := Ui.display_text(str(Save.best_bobs), 36, Ui.WHITE, Ui.NIGHT, Ui.BRAND_LIGHT)
	count.align = HORIZONTAL_ALIGNMENT_LEFT
	count.depth = 2.0
	count.shadow = Color(0, 0, 0, 0)
	count.refresh()
	words.add_child(count)
	row.add_child(words)
	var stars := StarRow.new(Save.best_stars, 34)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stars)
	plaque.add_child(row)
	return plaque


## A square button on the HUD's wood plate with a white icon (the menu's settings): the quiet
## choice next to PLAY, the one bright button.
func _wood_button(icon_name: String, side: float) -> JuicyButton:
	var b := JuicyButton.new()
	b.custom_minimum_size = Vector2(side, side)
	for state in [&"normal", &"hover"]:
		b.add_theme_stylebox_override(state, Hud.plate(side * 0.32))
	b.add_theme_stylebox_override(&"pressed", Hud.plate(side * 0.32, true))
	var icon := Ui.bold_icon(icon_name, side * 0.48, Ui.WHITE, Hud.PLATE_LINE)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_top = 3.0
	holder.offset_bottom = -8.0
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(icon)
	b.add_child(holder)
	b.content = icon
	return b


## Dark backlit grass across the bottom, in front of Panoramic's chest (the backdrop's grass, a
## shade darker): he stands in the savanna rather than over it.
func _foreground() -> TextureRect:
	var g := TextureRect.new()
	g.texture = load("res://assets/art/world/sunset_grass.png")
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_TILE
	g.modulate = Color(0.7, 0.62, 0.68)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## The subtitle on the beadwork ribbon (its folded ends stay their size: 9-sliced).
static func ribbon(text: String, font_size: int) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Ui.display_text(text, font_size, Ui.WHITE, Color("5a0c04"), Color("ffe2c6"))
	label.depth = 2.0
	label.shadow = Color(0, 0, 0, 0)
	label.refresh()
	var h := font_size * 2.5
	var w := label.get_combined_minimum_size().x + h * 2.4
	var k := h / RIBBON.get_height()
	var band := NinePatchRect.new()
	band.texture = RIBBON
	band.patch_margin_left = 66
	band.patch_margin_right = 66
	band.patch_margin_top = 24
	band.patch_margin_bottom = 24
	band.size = Vector2(w, h) / k
	band.scale = Vector2(k, k)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(band)
	label.size = Vector2(w, h * 0.92)
	holder.add_child(label)
	holder.custom_minimum_size = Vector2(w, h)
	holder.size = holder.custom_minimum_size
	holder.pivot_offset = holder.size / 2
	return holder


func _vignette() -> TextureRect:
	var v := TextureRect.new()
	v.texture = Fx.vignette_texture()
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.modulate = Color(0.25, 0.05, 0.02, 0.35)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


## Sizes the logo to the height left by the safe area and the banner; places Panoramic on the
## right, his chest at the bottom edge, as tall as most of the screen but never wider than 45 %
## of it (tablets are narrower).
func _layout() -> void:
	var v := size
	var insets := Device.insets()
	var free := v.y - insets.y - Device.bottom_with_banner() - 36.0
	var logo_h := clampf(free - 108.0 - 74.0 - 24.0 - _ribbon.size.y * 0.55, 170.0, 330.0)
	var logo_w := logo_h * LOGO.get_width() / LOGO.get_height()
	var box_w := maxf(logo_w, _ribbon.size.x)
	_logo_box.custom_minimum_size = Vector2(box_w, logo_h + _ribbon.size.y * 0.55)
	_logo.size = Vector2(logo_w, logo_h)
	_logo.position = Vector2((box_w - logo_w) / 2, 0)
	_logo.pivot_offset = _logo.size / 2
	# under the words (the emblem takes the logo's left third)
	var under := clampf(_logo.position.x + logo_w * 0.66 - _ribbon.size.x / 2, 0.0, box_w - _ribbon.size.x)
	_ribbon.position = Vector2(under, logo_h - _ribbon.size.y * 0.45)

	var aspect := float(_hero.texture.get_width()) / _hero.texture.get_height()
	var h := minf(v.y * 0.98, v.x * (0.47 if v.x / v.y > 1.6 else 0.4) / aspect)  # narrower on tablets
	var w := h * aspect
	_hero.size = Vector2(w, h)
	_hero.position = Vector2(v.x - w - insets.z - v.x * 0.015, v.y - h)
	_hero.pivot_offset = Vector2(w / 2, h)
	var head := _hero.position + Vector2(w * 0.5, h * 0.32)
	_halo.position = head - _halo.size / 2
	_halo_glow.size = Vector2(h * 1.9, h * 1.9)
	_front_grass.size = Vector2(v.x, h * 0.3)
	_front_grass.position = Vector2(0, v.y - h * 0.3 + 6.0)
	_halo_glow.position = head - _halo_glow.size / 2


## The entrance, played as the transition opens.
func _arrive() -> void:
	var t := create_tween().set_parallel(true)
	_hero.modulate.a = 0.0
	var hero_x := _hero.position.x
	_hero.position.x += 160.0
	t.tween_property(_hero, "position:x", hero_x, 0.6).set_delay(0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_hero, "modulate:a", 1.0, 0.35).set_delay(0.1)
	_logo.position.y -= 420.0
	t.tween_property(_logo, "position:y", _logo.position.y + 420.0, 0.75).set_delay(0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ribbon.scale = Vector2(0.0, 1.0)
	t.tween_property(_ribbon, "scale", Vector2.ONE, 0.45).set_delay(0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play_pop.scale = Vector2.ZERO
	t.tween_property(_play_pop, "scale", Vector2.ONE, 0.5).set_delay(0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_row.modulate.a = 0.0
	t.tween_property(_row, "modulate:a", 1.0, 0.4).set_delay(0.9)


func _process(delta: float) -> void:
	GameArt.collect_preloaded()
	_clock += delta
	_halo.rotation = _clock * 0.05
	_halo.pivot_offset = _halo.size / 2
	# Panoramic breathes
	var b := sin(_clock * 1.6)
	_hero.scale = Vector2(1.0 + 0.004 * b, 1.0 + 0.008 * b)


func back() -> void:
	get_tree().quit()

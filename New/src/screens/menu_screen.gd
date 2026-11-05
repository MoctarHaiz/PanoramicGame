extends Screen
## The menu, composed as key art: on the left Panoramic in his fighting stance (the art track's
## render, assets/art/hero/hero_menu.png), full length on a backlit granite kopje, his shadow on
## the rock; the low sun between him and the title, blown out and blooming, shafts of light fanning
## from it, long rose-gold clouds, so he is rim-lit from that side (hero.gdshader) and the middle of
## the screen glows instead of lying empty; on the right the CHAKA ZULU logo (letters drawn for it,
## chiselled gold, locked up with a Zulu shield and an assegai, tools/art/ui_logo.py) with its
## subtitle on a ribbon across the shield's foot, a big green PLAY in a thin brass ring, and a row:
## the best run on a parchment plaque and the settings on a gold tile. Everything arrives in a
## short choreography: the hero rises onto the rock, the logo drops and bounces, the ribbon unrolls,
## PLAY pops, the rest fades in. Then the logo catches the light now and then and PLAY breathes.

const RIBBON := preload("res://assets/art/ui/ribbon_plain.png")  ## (its dashed stitch removed: tools/art/ui_kit.py)
const PLATE_H := 112.0  ## the Best plaque's height, and the gear's beside it
const TAIL_TRIM := 8  ## px cut off each end of the ribbon's tails (its notch is 24 deep)
const LOGO := "res://assets/art/ui/logo.png"  ## loaded with the menu (a preload held it, 3 MB, all run long)
const HERO_ART := "res://assets/art/hero/hero_menu.png"  ## the art track's render, when there
const HERO_STAND := "res://assets/art/ui/hero_stand.png"  ## the fallback crop, loaded only when used
const ROCK := "res://assets/art/ui/menu_rock.png"  ## loaded with the menu (7 MB: not held during play)
const ROCK_STAND := Vector2(1390, 152)  ## where his feet go on the rock, in its pixels (tools/art/ui_hero.py)
const ROCK_LEDGE := 660.0  ## the rock's flat top his stance spans, boot to boot, in its pixels
const ROCK_TILT := -0.066  ## the rock turned a little (radians) so its ledge is level under both boots
const STANCE := 0.693  ## his stance, boot to boot, as a share of the render's width (hero_menu.png; round 15's throw,
## its free arm and trail further out: 0.81 -> 0.693)
const FEET_X := 0.457  ## the point between his boots, as a share of its width (round 15: 0.515 -> 0.457)
const HERO_WIDE := 0.36  ## at most this share of the screen's width (round 15: 0.33; the wider throw kept as tall)
const HERO_TALL := 0.8  ## his height, as a share of the screen's
const FEET_AT := 0.9  ## where his feet stand, as a share of the screen's height

var _backdrop: SunsetBackdrop
var _hero: TextureRect
var _hero_tex: Texture2D
var _logo_tex: Texture2D
var _rock_tex: Texture2D
var _lit_crop := false  # the fallback crop (no art render): lit here by hero.gdshader
var _rock: TextureRect
var _shadow: TextureRect  # his shadow on the rock
var _front: TextureRect  # dark backlit grass across the bottom, in front of the rock's foot
var _halo_glow: ColorRect
var _logo_box: Control  # sized by _layout; the logo and its ribbon inside
var _logo: TextureRect
var _ribbon: Control
var _ribbon_fit: Control  # holds the ribbon, shrunk when the column is narrow (a tablet)
var _play_box: Control
var _play_pop: Control  # unmanaged inside _play_box: what the entrance scales
var _play: JuicyButton
var _row: HBoxContainer
var _row_fit: Control  # holds the Best plaque and the gear, shrunk when the column is narrow (a tablet)
var _left: VBoxContainer
var _hero_side: Control
var _clock := 0.0


func enter(_data: Dictionary) -> void:
	_backdrop = SunsetBackdrop.new()
	_backdrop.framing_tree = false  # he stands there
	_backdrop.motes = false  # no specks in a lit sky
	_backdrop.clouds = true
	_backdrop.shafts = 2.4
	_backdrop.horizon = 0.8  # more sky: the horizon doesn't cut the frame in half
	_backdrop.tree_x = 0.37  # the small acacia between him and the title, not behind the buttons
	add_child(_backdrop)
	_lit_crop = not ResourceLoader.exists(HERO_ART)
	_hero_tex = load(HERO_STAND if _lit_crop else HERO_ART)
	# the bloom around the low sun
	_halo_glow = ColorRect.new()  # worked out per pixel (a small gradient stretched stepped into rings)
	_halo_glow.color = Color(1, 0.7, 0.42, 0.6)
	_halo_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bloom := ShaderMaterial.new()
	bloom.shader = preload("res://src/ui/sun_glow.gdshader")
	bloom.set_shader_parameter(&"falloff", 1.8)
	_halo_glow.material = bloom
	add_child(_halo_glow)
	_rock_tex = load(ROCK)
	_rock = _picture(_rock_tex)
	add_child(_rock)
	_shadow = _picture(Fx.glow_texture())
	_shadow.modulate = Color(0.06, 0.0, 0.04, 0.85)
	add_child(_shadow)
	_front = _picture(load("res://assets/art/world/sunset_grass.png"))
	_front.stretch_mode = TextureRect.STRETCH_TILE
	_front.modulate = Color(0.55, 0.45, 0.52)
	_hero = _picture(_hero_tex)
	if _lit_crop:  # the art track's render carries its own backlight; the crop gets it here
		_hero.material = _backlit()
	add_child(_hero)
	add_child(_front)
	add_child(_vignette())

	var area := safe_area(true, 18.0)
	add_child(area)
	var columns := HBoxContainer.new()
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(columns)
	_hero_side = Control.new()  # Panoramic's side (he is placed by hand in _layout)
	_hero_side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(_hero_side)
	_left = VBoxContainer.new()
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_left.add_theme_constant_override(&"separation", 16)  # air between logo, Play and the plaque
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(_left)

	# the logo, its subtitle ribbon over its foot
	_logo_box = Control.new()
	_logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_left.add_child(_logo_box)
	_logo = TextureRect.new()
	_logo_tex = load(LOGO)
	_logo.texture = _logo_tex
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Prefs.motion():
		var shine := ShaderMaterial.new()
		shine.shader = preload("res://src/ui/shine.gdshader")
		shine.set_shader_parameter(&"period", 4.5)
		shine.set_shader_parameter(&"offset", 1.2)
		_logo.material = shine
	_logo_box.add_child(_logo)
	_ribbon = ribbon(tr("MENU_SUBTITLE"), 29)
	_ribbon_fit = Control.new()
	_ribbon_fit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon_fit.add_child(_ribbon)
	_logo_box.add_child(_ribbon_fit)

	_play_box = Control.new()
	_play_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_box.custom_minimum_size = Vector2(420, 124)
	_play_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_left.add_child(_play_box)
	_play_pop = Control.new()
	_play_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_pop.size = _play_box.custom_minimum_size
	_play_pop.pivot_offset = _play_pop.size / 2
	_play_box.add_child(_play_pop)
	_play = Ui.candy_button(tr("PLAY"), "play-fill", Ui.Tone.GREEN, 124, 62)
	_play.size = _play_box.custom_minimum_size
	_play.pressed.connect(func() -> void: Nav.go(&"game", {}, _play.get_global_rect().get_center()))
	_play.idle(0.06)
	_play.shine(3.2, 0)  # the sweep only: lens-flare glints read as stock
	_play_pop.add_child(_play)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override(&"separation", 18)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Save.games_played > 0:
		_row.add_child(_best_plaque())
	# the gear a gold tile of the kit (the pause's tiles), fixed at the plaque's fixed height: the
	# row's width is known from the first frame (grown to the plaque's height in a later resize, it
	# pushed the row past a French tablet's safe area while the menu came in)
	var settings := Ui.icon_button("gear-chunky", Ui.Tone.GOLD, PLATE_H, 32.0)  # as tall as the plaque
	settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings.pressed.connect(func() -> void: Nav.go(&"settings", {}, settings.get_global_rect().get_center()))
	_row.add_child(settings)
	_row_fit = Control.new()
	_row_fit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_fit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_row_fit.add_child(_row)
	_left.add_child(_row_fit)

	resized.connect(_layout)
	_row.minimum_size_changed.connect(_layout)  # (the holder takes the row's size from _layout)
	Device.changed.connect(_layout)
	_layout()
	_arrive()
	Audio.play_music(&"menu")
	Services.ads.show_banner(true)


## The sunset's light on the studio-lit crop: a warm rim all round his outline (the sun is right
## behind him), his front in warm shadow (hero.gdshader).
static func _backlit() -> ShaderMaterial:
	var lit := ShaderMaterial.new()
	lit.shader = preload("res://src/ui/hero.gdshader")
	# the sun right behind him: a warm rim all round his outline, his front in warm shadow
	lit.set_shader_parameter(&"rim_dir", Vector2(0.75, -0.65))
	lit.set_shader_parameter(&"rim_px", 8.0)
	lit.set_shader_parameter(&"sky_colour", Color(1.0, 0.66, 0.36))
	lit.set_shader_parameter(&"sky_rim", 0.85)
	lit.set_shader_parameter(&"shade", 0.42)
	return lit


func _exit_tree() -> void:
	if Device.changed.is_connected(_layout):
		Device.changed.disconnect(_layout)


func _picture(texture: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The best run on a parchment plaque in a brass ring: the Red Bob, "BEST" over the count, the stars
## (the missing ones dark sockets in gold rims).
func _best_plaque() -> PanelContainer:
	var s := Ui.plaque_style(30.0)
	s.content_margin_left = 22
	s.content_margin_right = 28
	s.content_margin_top = 8
	s.content_margin_bottom = 16
	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override(&"panel", s)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plaque.custom_minimum_size.y = PLATE_H
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)  # room: it read as cramped
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bob := TextureRect.new()
	bob.texture = BobView.texture()
	bob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bob.custom_minimum_size = Vector2(58, 58)
	bob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bob)
	# one type style: "Best" and the count in the same dark brown Fredoka, the count bigger
	var words := VBoxContainer.new()
	words.add_theme_constant_override(&"separation", -10)  # the two lines close, not touching
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	# a small spaced label over the big number, one brown family (a red "Best" fought the brown count)
	words.add_child(Ui.label(tr("BEST").to_upper(), 26, Color("b0682c"), Ui.title_font(580, 1), HORIZONTAL_ALIGNMENT_LEFT))
	words.add_child(Ui.label(str(Save.best_bobs), 52, Color("3a1404"), Ui.font_display, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(words)
	var stars := StarRow.new(Save.best_stars, 50)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars.add_theme_constant_override(&"separation", 4)
	row.add_child(stars)
	plaque.add_child(row)
	return plaque


## The subtitle on the beadwork ribbon (its folded ends stay their size: 9-sliced; trimmed a little:
## round 11's tails were oversized).
static func ribbon(text: String, font_size: int) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Ui.display_text(text, font_size, Ui.WHITE, Color("5a0c04"), Color("ffe2c6"))
	label.depth = 2.0
	label.shadow = Color(0, 0, 0, 0)
	label.refresh()
	var h := font_size * 2.5
	var w := label.get_combined_minimum_size().x + h * 2.0
	var k := h / RIBBON.get_height()
	var band := NinePatchRect.new()
	band.texture = RIBBON
	band.region_rect = Rect2(TAIL_TRIM, 0, RIBBON.get_width() - TAIL_TRIM * 2, RIBBON.get_height())
	band.patch_margin_left = 66 - TAIL_TRIM
	band.patch_margin_right = 66 - TAIL_TRIM
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


## Places Panoramic on the left, full length, his feet on the rock (never wider than a third of a
## tablet's screen); the sun low between him and the title; the title column on the right; the
## logo sized to the height left by the safe area and the banner.
func _layout() -> void:
	var v := size
	var insets := Device.insets()
	var aspect := float(_hero_tex.get_width()) / _hero_tex.get_height()
	# (the lunge and the ring make him wide; round 12: the deeper lunge is wider; the hero comes first:
	# where the title column is narrow, its Best row shrinks, not him)
	var h := minf(v.y * HERO_TALL, v.x * (HERO_WIDE if not _lit_crop else 0.33) / aspect)
	var w := h * aspect
	var fx := FEET_X if not _lit_crop else 0.515
	var feet := Vector2(insets.x + w * fx + 12.0, v.y * FEET_AT)  # between his boots
	_hero.size = Vector2(w, h)
	# the art track's render stands on its own contact shadow, both soles at 0.93 of its height; the
	# fallback crop's soles are at its foot
	_hero.position = feet - Vector2(w * fx, h * (0.985 if _lit_crop else 0.93))
	_hero.pivot_offset = Vector2(w / 2, h)
	# the rock's pixels to screen units: its ledge as wide as his stance, turned level, both boots on it
	var k := w * STANCE / ROCK_LEDGE if not _lit_crop else h * 0.62 / _rock_tex.get_height()
	_rock.size = Vector2(_rock_tex.get_width(), _rock_tex.get_height()) * k
	_rock.pivot_offset = ROCK_STAND * k
	_rock.rotation = 0.0 if _lit_crop else ROCK_TILT
	_rock.position = feet - ROCK_STAND * k
	_front.size = Vector2(v.x, v.y * 0.1)
	_front.position = Vector2(0, v.y * 0.92)
	_shadow.size = Vector2(w * 1.15, w * 0.16)  # under both boots of his wide stance
	_shadow.position = feet - Vector2(_shadow.size.x * 0.5, _shadow.size.y * 0.45)
	# the sun, low, between him and the title: it rims him and fills the middle with light
	# the sun right behind him, low: he stands against it, rim-lit, and the title column keeps calm
	# sky behind it
	var sun := _hero.position + Vector2(w * 0.5, h * 0.42)
	_backdrop.sun_at = sun / v
	_halo_glow.size = Vector2(v.y * 1.5, v.y * 1.5)
	_halo_glow.position = sun - _halo_glow.size / 2
	# the column on the right of the sun
	var column_left := minf(_hero.position.x + w + v.x * 0.06, v.x - insets.z - 18.0 - 470.0)
	_hero_side.custom_minimum_size.x = maxf(column_left - insets.x - 18.0, 0.0)
	var free := v.y - insets.y - Device.bottom_with_banner() - Device.ad_gap() - 36.0
	var column_w := v.x - insets.z - 18.0 - column_left
	# the Best plaque and the gear whole in the column: their full size on a phone, a little smaller
	# where a 4:3 tablet's column is narrower than them (the French "Record" is the widest)
	var row_size := _row.get_combined_minimum_size()
	var fit := minf(1.0, (column_w - 8.0) / row_size.x)
	_row.size = row_size
	_row.scale = Vector2(fit, fit)
	_row_fit.custom_minimum_size = row_size * fit
	var row_h := maxf(row_size.y * fit, 92.0)
	var logo_h := clampf(free - 124.0 - row_h - 48.0 - _ribbon.size.y * 0.5, 170.0, 330.0)  # air above and below
	var logo_w := logo_h * _logo_tex.get_width() / _logo_tex.get_height()
	if logo_w > column_w * 0.96:
		logo_w = column_w * 0.96
		logo_h = logo_w * _logo_tex.get_height() / _logo_tex.get_width()
	var rk := minf(1.0, column_w * 0.98 / _ribbon.size.x)
	_ribbon_fit.scale = Vector2(rk, rk)
	var ribbon_size := _ribbon.size * rk
	var box_w := maxf(logo_w, ribbon_size.x)
	_logo_box.custom_minimum_size = Vector2(box_w, logo_h + ribbon_size.y * 0.5)
	_logo.size = Vector2(logo_w, logo_h)
	_logo.position = Vector2((box_w - logo_w) / 2, 0)
	_logo.pivot_offset = _logo.size / 2
	# under the words, across the foot of the mark (the shield takes the logo's left quarter)
	var under := clampf(_logo.position.x + logo_w * 0.57 - ribbon_size.x / 2, 0.0, box_w - ribbon_size.x)
	_ribbon_fit.position = Vector2(under, logo_h - ribbon_size.y * 0.5)  # across the shield's foot


## The entrance, played as the transition opens.
func _arrive() -> void:
	var t := create_tween().set_parallel(true)
	_hero.modulate.a = 0.0
	var hero_y := _hero.position.y
	_hero.position.y += 40.0
	t.tween_property(_hero, "position:y", hero_y, 0.6).set_delay(0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
	if not Prefs.motion():
		return
	_clock += delta
	# Panoramic breathes
	var b := sin(_clock * 1.6)
	_hero.scale = Vector2(1.0 + 0.003 * b, 1.0 + 0.006 * b)


func back() -> void:
	get_tree().quit()

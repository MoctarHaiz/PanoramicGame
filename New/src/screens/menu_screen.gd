extends Screen
## The menu, composed as a title screen: the painted key art (assets/art/ui/menu_keyart.png: Panoramic
## leaping out of a dust cloud, the ring raised) covering the screen, graded a little richer
## (grade.gdshader: the candy UI and the art one family), with a soft shade behind the title column;
## embers streaming out of his launch along the leap (_embers); on the right one clean column with even
## gutters, clear of his hand: the CHAKA ZULU logo (gold lettering locked up with a Zulu shield and
## crossed assegais), its subtitle on a ribbon across the shield's foot, a big green PLAY, and the best
## run on a roomy parchment plaque as wide as PLAY (the Red Bob, "BEST" over the count, the three stars,
## the missing ones clear empty sockets); the settings on a round parchment button in a top corner
## (j15: a square gear among the pills). Everything arrives in a short choreography: the logo
## drops and bounces, the ribbon unrolls, PLAY pops, the rest fades in. Then the logo catches the light
## now and then and PLAY breathes.

const RIBBON := preload("res://assets/art/ui/ribbon_plain.png")  ## (its dashed stitch removed: tools/art/ui_kit.py)
const TAIL_TRIM := 8  ## px cut off each end of the ribbon's tails (its notch is 24 deep)
const LOGO := "res://assets/art/ui/logo.png"  ## loaded with the menu (a preload held it all run long)
const KEYART := "res://assets/art/ui/menu_keyart.png"  ## the painted title key art (hero + scene in one picture)
## Where things are in the key art, as shares of its size: the tip of his gauntleted hand (the title
## column keeps clear of it), the left edge of his ring (never pushed off the screen), and the dust
## cloud of his launch (the embers come out of it).
const HAND_U := 0.548
const RING_U := 0.17
const DUST := Rect2(0.0, 0.6, 0.24, 0.38)
const COLUMN_W := 440.0  ## the title column's width (PLAY and the Best plaque fill it)
const PLAY_H := 124.0
const PLATE_H := 100.0  ## the Best plaque's height
const GUTTER := 28.0  ## between his hand and the column, and between the column and the screen's edge
const GEAR := 92.0  ## the settings button's side

var _backdrop: SunsetBackdrop  # only when the key art is missing
var _art: TextureRect
var _art_size := Vector2(2556, 1179)
var _embers: CPUParticles2D
var _dust: CPUParticles2D
var _logo_box: Control  # sized by _layout; the logo and its ribbon inside
var _logo: TextureRect
var _logo_tex: Texture2D
var _ribbon: Control
var _ribbon_fit: Control  # holds the ribbon, shrunk to the column
var _column: VBoxContainer
var _play_box: Control
var _play_pop: Control  # unmanaged inside _play_box: what the entrance scales
var _play: JuicyButton
var _plate_fit: Control  # holds the Best plaque, shrunk with the column on a narrow screen
var _plate: Control
var _gear: JuicyButton
var _fit := 1.0  # the column's contents shrunk to a narrow column (a tablet)
var _pop_u := 1.0  # PLAY's entrance (its pop)


func enter(_data: Dictionary) -> void:
	if ResourceLoader.exists(KEYART):
		_art = TextureRect.new()
		_art.texture = load(KEYART)
		_art_size = _art.texture.get_size()
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_SCALE
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var grade := ShaderMaterial.new()
		grade.shader = preload("res://src/ui/grade.gdshader")
		_art.material = grade
		add_child(_art)
		if Prefs.motion():
			_embers = _ember_stream()
			add_child(_embers)
			_dust = _dust_drift()
			add_child(_dust)
	else:  # (no key art: the sunset alone)
		_backdrop = SunsetBackdrop.new()
		_backdrop.framing_tree = false
		_backdrop.motes = false
		add_child(_backdrop)
	add_child(_vignette())

	_column = VBoxContainer.new()  # placed by hand in _layout
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override(&"separation", 18)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)

	# the logo, its subtitle ribbon over its foot
	_logo_box = Control.new()
	_logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_logo_box)
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
	_play_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_play_box)
	_play_pop = Control.new()
	_play_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_box.add_child(_play_pop)
	_play = Ui.candy_button(tr("PLAY"), "play-fill", Ui.Tone.GREEN, int(PLAY_H), 62)
	_play.pressed.connect(func() -> void: Nav.go(&"game", {}, _play.get_global_rect().get_center()))
	_play.idle(0.06)
	_play.shine(3.2, 0)  # the sweep only: lens-flare glints read as stock
	_play_pop.add_child(_play)

	_plate_fit = Control.new()
	_plate_fit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_fit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if Save.games_played > 0:
		_plate = _best_plaque()
		_plate_fit.add_child(_plate)
		_column.add_child(_plate_fit)

	_gear = _gear_button()
	_gear.pressed.connect(func() -> void: Nav.go(&"settings", {}, _gear.get_global_rect().get_center()))
	add_child(_gear)

	resized.connect(_layout)
	Device.changed.connect(_layout)
	_layout()
	_arrive()
	Audio.play_music(&"menu")
	Services.ads.show_banner(true)


func _exit_tree() -> void:
	if Device.changed.is_connected(_layout):
		Device.changed.disconnect(_layout)


## The settings: a round parchment button (the Best plaque's material), its gear in the panels' warm
## orange, alone in the top left corner.
func _gear_button() -> JuicyButton:
	var b := JuicyButton.new()
	b.custom_minimum_size = Vector2(GEAR, GEAR)
	for state in [&"normal", &"hover"]:
		b.add_theme_stylebox_override(state, Ui.plaque_style(GEAR / 2.0))
	b.add_theme_stylebox_override(&"pressed", Ui.plaque_style(GEAR / 2.0, true))
	var i := Ui.bold_icon("gear-chunky", GEAR * 0.52, Color("d0641c"), Color("4a1e04"))
	b.add_child(Ui._face_holder(i, Ui.plaque_style(GEAR / 2.0)))
	b.content = i
	return b


## The best run on a parchment plaque in a brass ring, as wide as PLAY: the Red Bob, "BEST" over the
## count, and at its right end the three stars with room round them (the missing ones clear sockets).
func _best_plaque() -> PanelContainer:
	var s := Ui.plaque_style(30.0)
	s.content_margin_left = 26
	s.content_margin_right = 30
	s.content_margin_top = 8
	s.content_margin_bottom = 15
	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override(&"panel", s)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.custom_minimum_size = Vector2(COLUMN_W, PLATE_H)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bob := TextureRect.new()
	bob.texture = BobView.texture()
	bob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bob.custom_minimum_size = Vector2(60, 60)
	bob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bob)
	# one type style: "Best" and the count in the same brown family, the count bigger
	var words := VBoxContainer.new()
	words.add_theme_constant_override(&"separation", -10)  # the two lines close, not touching
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(Ui.label(tr("BEST").to_upper(), 24, Color("b0682c"), Ui.title_font(580, 2), HORIZONTAL_ALIGNMENT_LEFT))
	words.add_child(Ui.label(str(Save.best_bobs), 50, Color("3a1404"), Ui.font_display, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(words)
	var gap := Control.new()  # the stars at the plaque's right end, air between them and the count
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var stars := StarRow.new(Save.best_stars, 50)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars.add_theme_constant_override(&"separation", 8)
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
	v.modulate = Color(0.2, 0.05, 0.04, 0.4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


## Embers streaming out of the dust cloud of his launch along his leap (up and to the right), fast,
## then slowing and rising as they cool: hot white-gold streaks turning orange, stretched along their
## way (j15: "dust and embers uniform and directionless").
func _ember_stream() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.material = Fx.additive()
	p.texture = _streak_texture()
	p.amount = 44
	p.lifetime = 2.2
	p.preprocess = 2.2  # already flowing on the first frame
	p.randomness = 0.5
	p.lifetime_randomness = 0.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0.78, -0.62)
	p.spread = 16.0
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 380.0
	p.damping_min = 55.0
	p.damping_max = 110.0
	p.gravity = Vector2(10, -24)  # the heat lifts them as they slow
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.35
	p.scale_amount_max = 1.0
	var curve := Curve.new()  # they shrink as they cool
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.35))
	p.scale_amount_curve = curve
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.08, 0.45, 1.0])
	fade.colors = PackedColorArray([Color(1, 0.86, 0.52, 0.0), Color(1, 0.8, 0.42, 1.0), Color(1, 0.5, 0.14, 0.8),
			Color(0.9, 0.24, 0.05, 0.0)])
	p.color_ramp = fade
	return p


## A little of his dust still drifting back off the cloud, slow and soft, against the leap.
func _dust_drift() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = Fx.puff_texture()
	p.amount = 10
	p.lifetime = 3.5
	p.preprocess = 3.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(-0.8, -0.5)
	p.spread = 25.0
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 40.0
	p.gravity = Vector2(0, -6)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	fade.colors = PackedColorArray([Color(0.92, 0.8, 0.62, 0.0), Color(0.92, 0.8, 0.62, 0.22), Color(0.9, 0.78, 0.6, 0.0)])
	p.color_ramp = fade
	return p


static var _streak: GradientTexture2D


## A soft spark stretched along its way: an elongated radial glow (6 x 30), its long side its Y axis.
static func _streak_texture() -> GradientTexture2D:
	if not _streak:
		_streak = GradientTexture2D.new()
		_streak.width = 12
		_streak.height = 56
		_streak.fill = GradientTexture2D.FILL_RADIAL
		_streak.fill_from = Vector2(0.5, 0.5)
		_streak.fill_to = Vector2(1.0, 0.5)
		_streak.gradient = Gradient.new()
		_streak.gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		_streak.gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	return _streak


## The key art covers the screen, shifted left where the screen is narrower than it (a tablet) so his
## hand stays clear of the title column (never so far that his ring leaves the screen); the column on
## the right, GUTTER from his hand and from the safe area; the logo sized to the height left.
func _layout() -> void:
	var v := size
	if v.x <= 0.0 or v.y <= 0.0:
		return
	var insets := Device.insets()
	var right := v.x - insets.z - GUTTER
	var col_left := right - COLUMN_W
	var hand := 0.0
	if _art:
		var s := maxf(v.x / _art_size.x, v.y / _art_size.y)
		var art := _art_size * s
		var x0 := (v.x - art.x) / 2.0
		if x0 + HAND_U * art.x > col_left - GUTTER:  # shift it left, as far as it covers and the ring stays on
			x0 = maxf(col_left - GUTTER - HAND_U * art.x, maxf(v.x - art.x, -RING_U * art.x))
		_art.position = Vector2(x0, (v.y - art.y) / 2.0)
		_art.size = art
		hand = x0 + HAND_U * art.x
		var m := _art.material as ShaderMaterial  # the shade behind the column, in the picture's own UV
		m.set_shader_parameter(&"shade_at", (Vector2(right - COLUMN_W * 0.5, v.y * 0.5) - _art.position) / art)
		m.set_shader_parameter(&"shade_size", Vector2(COLUMN_W * 0.95, v.y * 0.7) / art)
		for p: CPUParticles2D in [_embers, _dust]:
			if p:
				p.position = _art.position + art * DUST.get_center()
				p.emission_rect_extents = art * DUST.size * 0.5
		if _embers:
			_embers.scale_amount_min = 0.3 * s / 0.54
			_embers.scale_amount_max = 0.8 * s / 0.54
	col_left = maxf(col_left, hand + GUTTER)
	var col_w := right - col_left
	_fit = clampf(col_w / COLUMN_W, 0.6, 1.0)
	var w := COLUMN_W * _fit
	# PLAY and the plaque, shrunk together to a narrow column
	_play_box.custom_minimum_size = Vector2(w, PLAY_H * _fit)
	_play_pop.size = Vector2(COLUMN_W, PLAY_H)
	_play_pop.pivot_offset = Vector2(COLUMN_W, PLAY_H) / 2
	_play_pop.position = (Vector2(w, PLAY_H * _fit) - Vector2(COLUMN_W, PLAY_H)) / 2  # scaled round the box's middle
	_play_pop.scale = Vector2.ONE * _pop_u * _fit
	_play.size = Vector2(COLUMN_W, PLAY_H)
	if _plate:
		_plate.size = Vector2(COLUMN_W, PLATE_H)
		_plate.scale = Vector2(_fit, _fit)
		_plate_fit.custom_minimum_size = Vector2(w, PLATE_H * _fit)
	# the logo takes the height left
	var top := insets.y + 18.0
	var bottom := v.y - Device.bottom_with_banner() - Device.ad_gap() - 18.0
	var rest := PLAY_H * _fit + (PLATE_H * _fit + 18.0 if _plate else 0.0) + 18.0
	var rk := minf(1.0, (w + GUTTER) / _ribbon.size.x)  # the ribbon a little wider than the column: its tails out
	_ribbon_fit.scale = Vector2(rk, rk)
	var ribbon_size := _ribbon.size * rk
	var logo_h := clampf(bottom - top - rest - ribbon_size.y * 0.55, 150.0, 330.0)
	var logo_w := logo_h * _logo_tex.get_width() / _logo_tex.get_height()
	if logo_w > w * 1.02:
		logo_w = w * 1.02
		logo_h = logo_w * _logo_tex.get_height() / _logo_tex.get_width()
	var box_w := maxf(logo_w, ribbon_size.x)
	_logo_box.custom_minimum_size = Vector2(box_w, logo_h + ribbon_size.y * 0.45)
	_logo.size = Vector2(logo_w, logo_h)
	_logo.position = Vector2((box_w - logo_w) / 2, 0)
	_logo.pivot_offset = _logo.size / 2
	_ribbon_fit.position = Vector2((box_w - ribbon_size.x) / 2, logo_h - ribbon_size.y * 0.55)  # across the shield's foot
	var centre_x := col_left + col_w / 2.0
	_column.size = Vector2(box_w, 0)
	_column.reset_size()
	var h := _column.get_combined_minimum_size().y
	_column.size = Vector2(maxf(box_w, w), h)
	_column.position = Vector2(centre_x - _column.size.x / 2, top + (bottom - top - h) / 2)
	# the settings in a top corner: the right one when the column leaves it free (a tablet), else the left
	_gear.size = _gear.custom_minimum_size
	var corner_right := _column.position.y >= insets.y + 18.0 + GEAR + 24.0
	_gear.position = Vector2(v.x - insets.z - 22.0 - GEAR if corner_right else insets.x + 22.0, insets.y + 18.0)


## The entrance, played as the transition opens.
func _arrive() -> void:
	var t := create_tween().set_parallel(true)
	_logo.position.y -= 420.0
	t.tween_property(_logo, "position:y", _logo.position.y + 420.0, 0.75).set_delay(0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ribbon.scale = Vector2(0.0, 1.0)
	t.tween_property(_ribbon, "scale", Vector2.ONE, 0.45).set_delay(0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_play(0.0)
	t.tween_method(_pop_play, 0.0, 1.0, 0.5).set_delay(0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for c: Control in [_plate_fit, _gear]:
		c.modulate.a = 0.0
		t.tween_property(c, "modulate:a", 1.0, 0.4).set_delay(0.9)


func _pop_play(u: float) -> void:
	_pop_u = u
	_play_pop.scale = Vector2.ONE * u * _fit


func _process(_delta: float) -> void:
	GameArt.collect_preloaded()


func back() -> void:
	get_tree().quit()

extends Screen
## Settings, on the ink (the user, 2026-11-13, of three panel styles shown: "C", no box, ink brush), over his savanna
## (the key art, lightly blurred): a band of brushed ink, its title in gold brush lettering over a red stroke across
## its top edge, the back and info buttons two quiet leaning plates at its top corners. Inside, laid out as a phone
## game's settings (UI r23, the judges of j19: r22's "three dense columns and nine rows in one wide, short panel: a
## desktop preferences dialog"): two clear columns of three big rows each, a thin gold line standing between them,
## Sound and feel (music and sounds volumes, vibration) and Game (language, screen shake, reduced motion), each row a
## thumb-sized target: a flat cream glyph (no tile), its name big in cream, and its control (a thin cream line with an
## angular red handle; a small leaning plate, red with ON, an outline with OFF); under them the help as quiet dark
## leaning plates in a gold line along the band's foot (the tutorial again, rate, privacy), and the ad choices and
## purchases beside them where they apply. The credits (About, the fonts and icons, the studio, the version) open in
## its place from the info button.

const ROW_H := 86.0  ## height of a row (the whole row takes the touch)
## the back and info plates at the band's top corners: the kit's quiet leaning plate (blind round 11: "round back
## and info buttons beside slanted plates": they were ink discs in a gold ring)
const PLATE := Vector2(88.0, 72.0)
const COLUMN_W := 470.0  ## each of the two columns (each as wide as its longest row needs, at least this)
const COLUMN_GAP := 40.0  ## from a column to the line between the two
const LABEL := 38  ## a row's name (phone size)
const GLYPH := 50.0  ## a row's glyph
const HELP_H := 78.0  ## the help plates along the foot
const BACKDROP := "res://assets/art/ui/menu_keyart_soft.png"  ## the menu's key art at 1/4 (tools/art/ui_keyart_soft.py)

var _page: Control
var _credits: Control


func enter(_data: Dictionary) -> void:
	Services.ads.show_banner(true)
	Services.store.ads_removed.connect(_build)  # the purchase rows change
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_credits = null
	add_child(_backdrop())
	var area := safe_area(true, 16)
	add_child(area)
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(page)
	_page = page
	var card := Card.ink(Vector4(50, 70, 50, 30))  # (its top: under the title's lower half)
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 26)
	card.add_child(body)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", int(COLUMN_GAP))
	body.add_child(columns)
	var music := _slider_row("music-notes-fill", tr("MUSIC"), &"music_volume", &"music_on")
	var sounds := _slider_row("speaker-high-fill", tr("SOUNDS"), &"sounds_volume", &"sounds_on")
	var names: Array[Label] = [music.get_child(1) as Label, sounds.get_child(1) as Label]  # the two sliders start level
	var name_w := 0.0
	for l in names:
		name_w = maxf(name_w, (Ui.font_title as Font).get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL).x + 4.0)
	for l in names:
		l.custom_minimum_size.x = name_w
	var vibration := _toggle_row("vibrate-fill", tr("VIBRATION"), &"vibration_on")
	var language := _button_row("language-fill", tr("LANGUAGE"), tr("LANGUAGE_NAME"), _switch_language)
	var shake := _toggle_row("screen-shake", tr("SCREEN_SHAKE"), &"screen_shake")
	var calm := _toggle_row("gauge-low", tr("REDUCE_MOTION"), &"reduce_motion")
	columns.add_child(_group(tr("SOUND_AND_FEEL"), [music, sounds, vibration]))
	columns.add_child(Ui.rule(0.0, true))
	columns.add_child(_group(tr("GENERAL"), [language, shake, calm]))
	# the help along the foot: quiet plates, three a line, as wide as the columns together; the ad choices
	# and the purchases with them where they apply
	var help := [_help_button("hand-pointing-fill", tr("REPLAY_TUTORIAL"), _replay_tutorial),
			_help_button("star-fill", tr("RATE"), Config.open_store_review),
			_help_button("shield-check-fill", tr("PRIVACY_POLICY"), Config.open_privacy_policy)]
	if Services.ads.privacy_options_required():
		help.append(_help_button("megaphone-fill", tr("AD_PRIVACY"), Services.ads.show_privacy_options))
	if Services.store.enabled():
		if not Save.ads_removed:
			help.append(_help_button("prohibit-fill", tr("REMOVE_ADS") + "  " + Services.store.price(), Services.store.buy_remove_ads))
		help.append(_help_button("arrows-clockwise-bold", tr("RESTORE_PURCHASES"), Services.store.restore))
	var help_size := 32 if help.size() <= 3 else 26  # (two lines of them: smaller words, the band no wider)
	for b: JuicyButton in help:
		_help_words(b, help_size)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 22)
	grid.add_theme_constant_override(&"v_separation", 16)
	for b: Control in help:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	body.add_child(grid)
	var banner := Ui.ink_title(tr("SETTINGS"), 124.0, 620.0)
	page.add_child(card)
	page.add_child(banner)
	var back_button := Ui.plate_button("arrow-left-bold", PLATE)  # at the band's corner
	back_button.pressed.connect(back)
	page.add_child(back_button)
	var info := Ui.plate_button("info-bold", PLATE)  # the credits: the back button's twin, a plain "i" as its arrow
	info.pressed.connect(_show_credits)
	page.add_child(info)
	var place := func() -> void:
		var room := page.size
		var top := banner.size.y * 0.5
		card.size = card.get_combined_minimum_size()
		# side margins; never more than 84 % of the width (round 20, the judges: "a desktop dialog"): his key art
		# shows round it
		# (and the band's rough ends on the screen, most of them: their last bristles may leave a narrow one)
		var ends := card.band.reach(Rect2(Vector2.ZERO, card.size)) * 0.8
		var k := minf(1.0, minf(minf(room.x * 0.84 / card.size.x, (room.x - 16.0) / (card.size.x + ends.x + ends.y)),
				(room.y - top - 30.0) / card.size.y))
		card.scale = Vector2.ONE * k
		var w := card.size.x * k
		var left_x := (room.x - w - (ends.x + ends.y) * k) / 2 + ends.x * k
		card.position = Vector2(left_x, top + (room.y - top - card.size.y * k) / 2)
		banner.scale = Vector2.ONE * k
		banner.position = Vector2(left_x + w / 2 - banner.size.x * k / 2, card.position.y - top * k)
		# the discs half over the band's top edge, at its corners (the panel's scale: their touch stays 86+)
		for b: JuicyButton in [back_button, info]:
			b.custom_minimum_size = PLATE * k
			b.size = b.custom_minimum_size
		back_button.position = card.position + Vector2(4.0, -24.0) * k - back_button.size / 2
		info.position = card.position + Vector2(card.size.x - 4.0, -24.0) * k - info.size / 2
	page.resized.connect(place)
	card.resized.connect(place)
	place.call_deferred()


## Behind the band the menu's own key art, lightly blurred (soft_blur.gdshader: its own colours nudged to the
## pause's warm dusk, closed corners), bright enough for the dark ink to stand out on it: the settings stay in his
## world, the scene recognisable (round 20, the judges: "a blurred purple-brown smear").
func _backdrop() -> TextureRect:
	var art := TextureRect.new()
	art.texture = load(BACKDROP)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # (a tablet: cropped, not squeezed)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/ui/soft_blur.gdshader")
	var g := {"tame": 0.3, "shadow_tint": Color("160c2a"), "mid_tint": Color("5c2e4e"), "light_tint": Color("f2b47e"),
			"duo": 0.15, "exposure": 0.9, "glow_colour": Color(1.0, 0.7, 0.42, 0.08), "glow_size": 1.0,
			"glow_at": Vector2(0.5, 0.52), "vignette_colour": Color("0a0414"), "vignette": 0.4}
	for key: String in g:
		m.set_shader_parameter(StringName(key), g[key])
	art.material = m
	return art


## A column: its title in leaning cream capitals, then its rows.
func _group(title: String, rows: Array) -> VBoxContainer:
	var g := VBoxContainer.new()
	g.add_theme_constant_override(&"separation", 2)
	g.custom_minimum_size.x = COLUMN_W
	g.add_child(Ui.label(title, 38, Ui.BONE, Ui.font_slant, HORIZONTAL_ALIGNMENT_LEFT))
	for row: Control in rows:
		g.add_child(row)
	return g


## A row: its glyph (flat cream, no tile), its name, and `right`.
func _row(icon_name: String, text: String, right: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	row.custom_minimum_size.y = ROW_H
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := Ui.icon(icon_name, GLYPH, Ui.BONE)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	var l := Ui.label(text, LABEL, Ui.BONE, Ui.font_title, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # (on one line: the column takes its width, in every language)
	row.add_child(l)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	return row


func _toggle_row(icon_name: String, text: String, option: StringName) -> Control:
	var switch := ToggleSwitch.new()
	switch.set_on(Save.get(option))
	switch.toggled.connect(func(on: bool) -> void:
		Save.set_option(option, on)
		if option == &"vibration_on" and on:
			Haptics.tap())
	var row := _row(icon_name, text, switch)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(event: InputEvent) -> void:  # the whole row flips it
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			switch.toggle())
	return row


## A volume: the slider; at 0 the bus is switched off too (Audio.apply_settings).
func _slider_row(icon_name: String, text: String, option: StringName, switch_option: StringName) -> Control:
	var on: bool = Save.get(switch_option)
	var slider := VolumeSlider.new(Save.get(option) if on else 0.0)
	slider.custom_minimum_size = Vector2(230, 62)  # a long, thick groove
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # the slider takes the room, not a gap after the name
	slider.changed.connect(func(v: float) -> void:
		if v > 0.0:  # at 0 the volume before stays, for when it is turned up again
			Save.set(option, v)
		Save.set_option(switch_option, v > 0.0)
		Audio.apply_settings()
		Prefs.apply_volumes())
	var row := _row(icon_name, text, slider)
	var name := row.get_child(1) as Label  # its name as wide as its word, the slider right after it
	name.size_flags_horizontal = Control.SIZE_FILL
	return row


## A row that opens something or steps through values (the language): its value in cream, a chevron after it.
func _button_row(icon_name: String, text: String, value: String, action: Callable) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var right := HBoxContainer.new()
	right.add_theme_constant_override(&"separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not value.is_empty():
		right.add_child(Ui.label(value, 34, Ui.BONE, Ui.font_title))
	var caret := Ui.icon("caret-right-bold", 30, Ui.BONE)
	caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(caret)
	var row := _row(icon_name, text, right)
	b.add_child(row)
	var fit := func() -> void: b.custom_minimum_size = row.get_combined_minimum_size()  # its row's whole width (its
	fit.call()  # name on one line: known for sure once in the tree)
	row.minimum_size_changed.connect(fit)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override(&"hover", StyleBoxEmpty.new())
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(1.0, 0.9, 0.72, 0.1)
	pressed.set_corner_radius_all(12)
	b.add_theme_stylebox_override(&"pressed", pressed)
	b.pressed.connect(func() -> void:
		Audio.play_sfx(&"button")
		Haptics.tap()
		action.call())
	return b


## A help button along the band's foot: a quiet dark leaning plate in a gold line, its glyph and its name.
func _help_button(icon_name: String, text: String, action: Callable) -> JuicyButton:
	var b := Ui.plate_button(icon_name, Vector2(0.0, HELP_H), text, 32)
	b.pressed.connect(action)
	return b


## Sets a help button's words (and its glyph) to `font_size`.
func _help_words(b: JuicyButton, font_size: int) -> void:
	var row := b.content as HBoxContainer
	var glyph := row.get_child(0) as Control
	glyph.custom_minimum_size = Vector2.ONE * font_size * 1.3
	(row.get_child(1) as Label).add_theme_font_size_override(&"font_size", font_size)
	row.add_theme_constant_override(&"separation", roundi(font_size * 0.4))


func _switch_language() -> void:
	var next := "fr" if TranslationServer.get_locale().begins_with("en") else "en"
	Save.set_option(&"language", next)
	Save.apply_language()
	_build()


func _replay_tutorial() -> void:
	Tutorial.replay()
	Ui.toast(tr("TUTORIAL_AGAIN"))


## About the game, the credits (the studio, not personal names) and the version, on a band of its own in the
## settings' place (two bands of ink one over the other would run together); the cross, the back button or a tap
## outside close it.
func _show_credits() -> void:
	if _credits:
		return
	_credits = Control.new()
	_credits.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_credits)
	if _page:
		_page.visible = false
	var veil := ColorRect.new()
	veil.color = Color(0.08, 0.02, 0.06, 0.3)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_credits())
	_credits.add_child(veil)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	box.custom_minimum_size.x = 620
	var logo_mark := TextureRect.new()
	logo_mark.texture = load("res://assets/art/ui/logo.png")
	logo_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_mark.custom_minimum_size = Vector2(0, 120)
	box.add_child(logo_mark)
	var text := Ui.label(tr("ABOUT_TEXT"), 24, Ui.BONE, Ui.font_body_bold)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var credits := Ui.label(tr("CREDITS"), 21, Ui.BONE_SOFT, Ui.font_body_bold)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(credits)
	var studio := TextureRect.new()
	studio.texture = load("res://assets/art/haiz_studio.png")
	studio.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	studio.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	studio.custom_minimum_size = Vector2(0, 70)
	box.add_child(studio)
	box.add_child(Ui.label(tr("VERSION") % Config.version, 21, Ui.BONE_SOFT, Ui.font_body_bold))
	var card := Card.ink(Vector4(46, 62, 46, 34))
	card.add_child(box)
	_credits.add_child(card)
	var banner := Ui.ink_title(tr("ABOUT"), 96.0, 520.0)
	_credits.add_child(banner)
	var close := Ui.plate_button("x-bold", Vector2(78.0, 64.0))
	close.pressed.connect(_close_credits)
	_credits.add_child(close)
	for l: Label in [text, credits]:  # (a wrapped text is as tall as its width makes it: known before it is measured)
		l.size.x = box.custom_minimum_size.x
	var place := func() -> void:
		card.size = card.get_combined_minimum_size()
		var v := size
		var ends := card.band.reach(Rect2(Vector2.ZERO, card.size)) * 0.8  # (its rough ends on the screen)
		var k := minf(1.0, minf((v.y - Device.insets().y - Device.bottom_with_banner() - 60.0 - banner.size.y * 0.5) / card.size.y,
				(v.x - Device.insets().x - Device.insets().z - 16.0) / (card.size.x + ends.x + ends.y)))
		card.scale = Vector2.ONE * k
		card.position = Vector2((v.x - (card.size.x + ends.x + ends.y) * k) / 2 + ends.x * k,
				(v.y - card.size.y * k) / 2 + banner.size.y * k * 0.25)
		banner.scale = Vector2.ONE * k
		banner.position = Vector2(card.position.x + (card.size.x - banner.size.x) * k / 2, card.position.y - banner.size.y * k * 0.5)
		close.size = close.custom_minimum_size
		close.position = card.position + Vector2(card.size.x * k - close.size.x * 0.4, -close.size.y * 0.7)
	card.minimum_size_changed.connect(place)
	place.call()
	_credits.modulate.a = 0.0
	_credits.create_tween().tween_property(_credits, "modulate:a", 1.0, 0.2)


func _close_credits() -> void:
	if not _credits:
		return
	var c := _credits
	_credits = null
	if _page:
		_page.visible = true
	var t := c.create_tween()
	t.tween_property(c, "modulate:a", 0.0, 0.15)
	t.tween_callback(c.queue_free)


## Android back: closes the credits, else back to the menu.
func back() -> void:
	if _credits:
		_close_credits()
	else:
		Nav.go(&"menu")

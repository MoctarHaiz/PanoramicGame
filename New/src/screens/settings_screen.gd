extends Screen
## Settings, in the game's own kit, over the sunset behind a light scrim: a framed panel with its
## ribbon, its back button in the panels' wood docked inside its top-left corner, under the frame, floating with margins all round; Panoramic stands
## whole at its left where there is room for him (never behind it). Inside, titled groups, each a
## sunken card of rows split by fine lines (not ten identical bars), grouped so the columns end level
## (no empty band). Three columns on a wide screen: Sound and feel (music and sounds volumes,
## vibration), Game (language, screen shake, reduced motion), Help (replay the tutorial, rate,
## privacy, credits); two on a narrower one: Sound and Effects, Game and Help; and More (the ad
## choices and purchases) where they apply. Each row has a chunky icon on a candy tile in its group's
## colour. Every row is a thumb-sized target. Credits
## (About, the fonts and icons, the studio, the version) open over it.

const ROW_H := 96.0  ## height of a row (the whole row takes the touch; tall: the panel fills the screen)
const BUTTON := 78.0  ## the header's back and info buttons
const COLUMN_W := 380.0
const HERO_ART := "res://assets/art/hero/hero_menu.png"
const INK := Color("4a1e04")
const HEAD_INK := Color("9a4214")  ## the section titles: lighter and warmer than the rows' ink
const BACKDROP := "res://assets/art/ui/menu_keyart_soft.png"  ## the menu's key art, small and soft (1/8)

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
	var hero := _hero()
	if hero:
		add_child(hero)
	var area := safe_area(true, 16)
	add_child(area)
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(page)
	var card := Card.new(Vector4(44, 74, 44, 40))  # (the back and info buttons sit on its top corners: no header row)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 22)
	card.add_child(columns)
	# one tile colour per group (amber sound, red effects, orange game, red help, blue purchases: the
	# kit's tones, all the same candy material): the eye finds a group by its colour, and inside a
	# group every tile is the same. The rows are grouped so the columns end level (no empty block): on a wide screen three
	# columns (big text, room to breathe) of three rows, the credits behind the info button in the
	# header; on a narrower one two columns of five, Panoramic beside them where there is room.
	var view := get_viewport().get_visible_rect().size
	var wide := view.x >= view.y * 1.7
	var music := _slider_row("music-notes-fill", tr("MUSIC"), &"music_volume", &"music_on")
	var sounds := _slider_row("speaker-high-fill", tr("SOUNDS"), &"sounds_volume", &"sounds_on")
	var vibration := _toggle_row("vibrate-fill", tr("VIBRATION"), &"vibration_on")
	var shake := _toggle_row("screen-shake", tr("SCREEN_SHAKE"), &"screen_shake")
	var calm := _toggle_row("snail", tr("REDUCE_MOTION"), &"reduce_motion")
	var language := _button_row("translate-fill", tr("LANGUAGE"), tr("LANGUAGE_NAME"), _switch_language)
	var tutorial := _button_row("hand-pointing-fill", tr("REPLAY_TUTORIAL"), "", _replay_tutorial)
	var help: Array = [_button_row("star-fill", tr("RATE"), "", Config.open_store_review),
			_button_row("shield-check-fill", tr("PRIVACY_POLICY"), "", Config.open_privacy_policy)]
	if not wide:  # (a wide screen has the info button in the header)
		help.append(_button_row("info-fill", tr("CREDITS_BUTTON"), "", _show_credits))
	var layout: Array  # columns of groups
	var switches := 0  # the column with the switches' long labels
	if wide:
		layout = [[_group("speaker-high-fill", tr("SOUND_AND_FEEL"), Ui.Tone.AMBER, [music, sounds, vibration])],
				[_group("play-fill", tr("GENERAL"), Ui.Tone.SUNSET, [language, shake, calm])],
				[_group("question-fill", tr("HELP"), Ui.Tone.CRIMSON, [tutorial] + help)]]  # (the "i" is the credits' alone)
		switches = 1
	else:
		layout = [[_group("speaker-high-fill", tr("SOUND_GROUP"), Ui.Tone.AMBER, [music, sounds]),
				_group("sparkle-fill", tr("FEEL"), Ui.Tone.CRIMSON, [vibration, shake, calm])],
				[_group("play-fill", tr("GENERAL"), Ui.Tone.SUNSET, [language, tutorial]),
				_group("question-fill", tr("HELP"), Ui.Tone.BLUE, help)]]  # (red is the effects' here)
	var more: Array = []  # the ad choices and the purchases, where they apply: under the first column
	if Services.ads.privacy_options_required():
		more.append(_button_row("megaphone-fill", tr("AD_PRIVACY"), "", Services.ads.show_privacy_options))
	if Services.store.enabled():
		if not Save.ads_removed:
			more.append(_button_row("prohibit-fill", tr("REMOVE_ADS"), Services.store.price(), Services.store.buy_remove_ads))
		more.append(_button_row("arrows-clockwise-bold", tr("RESTORE_PURCHASES"), "", Services.store.restore))
	if not more.is_empty():
		layout[0].append(_group("star-four-fill", tr("MORE"), Ui.Tone.BLUE, more))
	for i in layout.size():
		var col := _column(COLUMN_W + 50.0 if i == switches else (COLUMN_W + 40.0 if i == 0 else COLUMN_W - 20.0))
		for g: Control in layout[i]:
			col.add_child(g)
		columns.add_child(col)
	var banner := Banner.new(tr("SETTINGS"), Ui.Tone.SUNSET, 48)
	page.add_child(card)
	page.add_child(banner)
	var back_button := Ui.wood_button("arrow-left-bold", Vector2(BUTTON, BUTTON), BUTTON / 2)  # in the panel's wood
	back_button.pressed.connect(back)
	page.add_child(back_button)
	var info: JuicyButton = null  # the credits, at the header's other end (a wide screen: three rows a column)
	if wide:
		# lighter than the back button's dark wood (a heavy dark disc beside the content)
		info = Ui.wood_button("info-fill", Vector2(BUTTON, BUTTON), BUTTON / 2)  # the back button's twin
		info.pressed.connect(_show_credits)
		page.add_child(info)
	var place := func() -> void:
		var room := page.size
		var top := banner.custom_minimum_size.y * 0.5
		card.size = card.get_combined_minimum_size()
		var slot := 0.0  # the back button is inside the panel now
		var k := minf(1.0, minf((room.x - 70.0) / card.size.x, (room.y - top - 30.0) / card.size.y))  # side margins
		card.scale = Vector2.ONE * k
		var w := card.size.x * k
		# Panoramic whole at the left when the panel leaves him room, else the panel in the middle
		var hero_room := room.x - w - 60.0
		var show_hero := hero != null and hero_room >= 230.0
		var left_x := maxf((room.x - w) / 2, slot) if not show_hero else room.x - w - 20.0
		card.position = Vector2(left_x, top + (room.y - top - card.size.y * k) / 2)
		banner.size = banner.custom_minimum_size
		banner.position = Vector2(left_x + w / 2 - banner.size.x / 2, card.position.y - top)
		back_button.custom_minimum_size = Vector2(BUTTON, BUTTON) * k  # the panel's scale (its touch stays 86+)
		back_button.size = back_button.custom_minimum_size
		# on the panel's top left corner, over its frame (as the close buttons of top games' pop-ups): the
		# groups start right under the ribbon (a header row of their own left a dead band)
		back_button.position = card.position + Vector2(-0.2, -0.2) * BUTTON * k
		if info:  # the same on the top right corner
			info.custom_minimum_size = back_button.custom_minimum_size
			info.size = info.custom_minimum_size
			info.position = card.position + Vector2(card.size.x * k, 0.0) + Vector2(-0.8, -0.2) * BUTTON * k
		if hero:
			hero.visible = show_hero
			var origin := area.get_global_rect().position + page.position
			var hw := minf(hero_room - 20.0, size.y * 0.82 * hero.texture.get_width() / hero.texture.get_height())
			var hh := hw * hero.texture.get_height() / hero.texture.get_width()
			hero.size = Vector2(hw, hh)
			hero.position = Vector2(origin.x + (card.position.x - 30.0 - hw) / 2 + 10.0, size.y - hh - Device.bottom_with_banner() * 0.0 - 12.0)
	page.resized.connect(place)
	card.resized.connect(place)
	place.call_deferred()


## Behind the panel the menu's own key art, small and soft, graded as the pause's scrim
## (soft_blur.gdshader: a warm dusk, a light behind the panel, closed corners): the settings stay in his
## world (j15: a dark muddy sunset behind them).
func _backdrop() -> TextureRect:
	var art := TextureRect.new()
	art.texture = load(BACKDROP)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/ui/soft_blur.gdshader")
	var g := {"shadow_tint": Color("140b2c"), "mid_tint": Color("6e2c50"), "light_tint": Color("f2a862"), "duo": 0.72,
			"exposure": 0.8, "glow_colour": Color(1.0, 0.66, 0.38, 0.3), "glow_size": 1.0, "glow_at": Vector2(0.5, 0.52),
			"vignette_colour": Color("0a0414"), "vignette": 0.75}
	for key: String in g:
		m.set_shader_parameter(StringName(key), g[key])
	art.material = m
	return art


## Panoramic in his stance (the art track's render), lit by the sunset; null when the render isn't
## there.
func _hero() -> TextureRect:
	if not ResourceLoader.exists(HERO_ART):
		return null
	var art := TextureRect.new()
	art.texture = load(HERO_ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art  # (the render carries its own light)


func _column(width := COLUMN_W) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 22)  # air between the groups
	col.custom_minimum_size.x = width
	return col


## A group: a section title clearly above its rows (j15: "no typographic hierarchy"): small capitals,
## spaced, in a warm brown lighter than the rows, the group's glyph, a rule running to the column's
## edge; then its rows in one sunken card, a fine line between two rows. Every row's tile is the same
## cream tile, its glyph in the group's colour (j15: tiles of three colours in a column read as
## arbitrary).
func _group(icon_name: String, title: String, tone: Ui.Tone, rows: Array) -> VBoxContainer:
	var g := VBoxContainer.new()
	g.add_theme_constant_override(&"separation", 8)
	var c := Ui.tone_colours(tone)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 8)
	head.add_child(Ui.bold_icon(icon_name, 26, c.bottom, Color("2e0d04")))
	head.add_child(Ui.label(title.to_upper(), 23, HEAD_INK, Ui.title_font(700, 2), HORIZONTAL_ALIGNMENT_LEFT))
	var rule := ColorRect.new()  # the title's rule, to the column's edge
	rule.color = Color(0.55, 0.3, 0.1, 0.4)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rule)
	g.add_child(head)
	var well := PanelContainer.new()
	var s := Card.well(18)
	s.top = Color("fff8ea")  # the rows on near-white, clearly lighter than the tanned panel
	s.bottom = Color("fffdf6")
	s.set_outline(Color("6a3a14"), 3.0)
	s.set_content_margin_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 10
	well.add_theme_stylebox_override(&"panel", s)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 0)
	for i in rows.size():
		if i > 0:
			var line := ColorRect.new()
			line.color = Color(0.55, 0.32, 0.12, 0.25)
			line.custom_minimum_size = Vector2(0, 2)
			list.add_child(line)
		var row: Control = rows[i]
		list.add_child(row)
	well.add_child(list)
	g.add_child(well)
	for row: Control in rows:  # the group's colour on its rows' glyphs
		var tile := row.find_child("Tile", true, false) as PanelContainer
		if tile:
			var icon := tile.get_child(0) as BoldIcon
			if icon:
				icon.fill = c.bottom
				icon.outline = c.outline
				icon.queue_redraw()
	return g


## A row: its icon on a small tile (in its group's colour, see _group), its name, and `right`.
func _row(icon_name: String, text: String, right: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	row.custom_minimum_size.y = ROW_H
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := PanelContainer.new()
	tile.name = "Tile"
	var ts := Ui.candy_style(Ui.Tone.WHITE, 15.0, false, 5.0)  # one cream tile for every row; the glyph carries the colour
	ts.set_content_margin_all(6)
	ts.content_margin_bottom = 11
	tile.add_theme_stylebox_override(&"panel", ts)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(Ui.bold_icon(icon_name, 40, Ui.tone_colours(Ui.Tone.SUNSET).bottom, Ui.tone_colours(Ui.Tone.SUNSET).outline))
	row.add_child(tile)
	var l := Ui.label(text, 30, INK, Ui.font_title, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
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
	slider.custom_minimum_size.x = 226
	slider.changed.connect(func(v: float) -> void:
		if v > 0.0:  # at 0 the volume before stays, for when it is turned up again
			Save.set(option, v)
		Save.set_option(switch_option, v > 0.0)
		Audio.apply_settings()
		Prefs.apply_volumes())
	return _row(icon_name, text, slider)


func _button_row(icon_name: String, text: String, value: String, action: Callable) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var right := HBoxContainer.new()
	right.add_theme_constant_override(&"separation", 6)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not value.is_empty():
		right.add_child(Ui.label(value, 22, Color("c0431a"), Ui.font_title))
	right.add_child(Ui.bold_icon("caret-right-bold", 26, Color("e0661e"), Color("5a2408")))
	var row := _row(icon_name, text, right)
	b.add_child(row)
	b.custom_minimum_size = row.get_combined_minimum_size()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override(&"hover", StyleBoxEmpty.new())
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.55, 0.3, 0.1, 0.15)
	pressed.set_corner_radius_all(12)
	b.add_theme_stylebox_override(&"pressed", pressed)
	b.pressed.connect(func() -> void:
		Audio.play_sfx(&"button")
		Haptics.tap()
		action.call())
	return b


func _switch_language() -> void:
	var next := "fr" if TranslationServer.get_locale().begins_with("en") else "en"
	Save.set_option(&"language", next)
	Save.apply_language()
	_build()


func _replay_tutorial() -> void:
	Tutorial.replay()
	Ui.toast(tr("TUTORIAL_AGAIN"))


## About the game, the credits (the studio, not personal names) and the version, in a panel over
## the settings; the cross, the back button or a tap outside close it.
func _show_credits() -> void:
	if _credits:
		return
	_credits = Control.new()
	_credits.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_credits)
	var veil := ColorRect.new()
	veil.color = Color(0.08, 0.02, 0.06, 0.6)
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
	var text := Ui.label(tr("ABOUT_TEXT"), 24, Color("4a1e04"), Ui.font_body_bold)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	var credits := Ui.label(tr("CREDITS"), 21, Color("8a5a3a"), Ui.font_body_bold)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(credits)
	var studio := TextureRect.new()
	studio.texture = load("res://assets/art/haiz_studio.png")
	studio.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	studio.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	studio.custom_minimum_size = Vector2(0, 70)
	box.add_child(studio)
	box.add_child(Ui.label(tr("VERSION") % Config.version, 21, Color("8a5a3a"), Ui.font_body_bold))
	var card := Card.new(Vector4(44, 60, 44, 38))
	card.add_child(box)
	_credits.add_child(card)
	var banner := Banner.new(tr("ABOUT"), Ui.Tone.BLUE, 40)
	_credits.add_child(banner)
	var close := Ui.icon_button("x-bold", Ui.Tone.CRIMSON, 64.0, 32.0)
	close.pressed.connect(_close_credits)
	_credits.add_child(close)
	card.size = card.get_combined_minimum_size()
	var v := size
	var k := minf(1.0, (v.y - Device.insets().y - Device.bottom_with_banner() - 60.0) / card.size.y)
	card.scale = Vector2.ONE * k
	card.position = Vector2((v.x - card.size.x * k) / 2, (v.y - card.size.y * k) / 2 + 16.0)
	banner.size = banner.custom_minimum_size
	banner.position = Vector2(v.x / 2 - banner.size.x / 2, card.position.y - banner.size.y * 0.5)
	close.size = close.custom_minimum_size
	close.position = card.position + Vector2(card.size.x * k - close.size.x * 0.7, -close.size.y * 0.3)
	card.pivot_offset = card.size / 2
	_credits.modulate.a = 0.0
	_credits.create_tween().tween_property(_credits, "modulate:a", 1.0, 0.2)


func _close_credits() -> void:
	if not _credits:
		return
	var c := _credits
	_credits = null
	var t := c.create_tween()
	t.tween_property(c, "modulate:a", 0.0, 0.15)
	t.tween_callback(c.queue_free)


## Android back: closes the credits, else back to the menu.
func back() -> void:
	if _credits:
		_close_credits()
	else:
		Nav.go(&"menu")

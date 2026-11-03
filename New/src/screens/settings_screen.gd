extends Screen
## Settings, in the game's own kit, over the sunset dimmed behind a scrim: a framed panel with its
## ribbon, its back button nailed to its corner, floating with margins all round; Panoramic stands
## whole at its left where there is room for him (never behind it). Inside, four titled groups, each
## a sunken card of rows split by fine lines (not ten identical bars): Sound (music and sounds
## volumes), Feel (vibration, screen shake, reduced motion), Game (language, replay the tutorial)
## and Help (rate, privacy, credits, and the ad choices and purchases when they apply). Each row has
## a chunky icon on a candy tile tinted by its group. Every row is a thumb-sized target. Credits
## (About, the fonts and icons, the studio, the version) open over it.

const ROW_H := 70.0  ## height of a row (the whole row takes the touch: 86 with the lines around it)
const COLUMN_W := 390.0
const HERO_ART := "res://assets/art/hero/hero_menu.png"
const INK := Color("4a1e04")

var _credits: Control


func enter(_data: Dictionary) -> void:
	Services.ads.show_banner(true)
	Services.store.ads_removed.connect(_build)  # the purchase rows change
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_credits = null
	var backdrop := SunsetBackdrop.new()
	backdrop.framing_tree = false
	backdrop.motes = false
	backdrop.clouds = true
	backdrop.sun_at = Vector2(0.16, 0.6)
	add_child(backdrop)
	var shade := ColorRect.new()  # a scrim: the sunset steps back behind the panel
	shade.color = Color(0.06, 0.01, 0.06, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var vignette := TextureRect.new()
	vignette.texture = Fx.vignette_texture()
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.modulate = Color(0.02, 0.0, 0.02, 0.9)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	var hero := _hero()
	if hero:
		add_child(hero)
	var area := safe_area(true, 16)
	add_child(area)
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(page)
	var card := Card.new(Vector4(32, 78, 32, 30))  # room under the ribbon
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 28)
	card.add_child(columns)
	var left := _column()
	# the icon tiles are coloured by what they mean (sound gold, feel green, language and lessons
	# orange, rating gold, privacy blue, credits cream): nothing in alarm red
	left.add_child(_group("speaker-high-fill", tr("SOUND_GROUP"), Ui.Tone.GOLD, [
		_tinted(_slider_row("music-notes-fill", tr("MUSIC"), &"music_volume", &"music_on"), Ui.Tone.GOLD),
		_tinted(_slider_row("speaker-high-fill", tr("SOUNDS"), &"sounds_volume", &"sounds_on"), Ui.Tone.GOLD),
	]))
	left.add_child(_group("vibrate-fill", tr("FEEL"), Ui.Tone.GREEN, [
		_tinted(_toggle_row("vibrate-fill", tr("VIBRATION"), &"vibration_on"), Ui.Tone.GREEN),
		_tinted(_toggle_row("screen-shake", tr("SCREEN_SHAKE"), &"screen_shake"), Ui.Tone.GREEN),
		_tinted(_toggle_row("snail", tr("REDUCE_MOTION"), &"reduce_motion"), Ui.Tone.GREEN),
	]))
	columns.add_child(left)
	var right := _column()
	right.add_child(_group("play-fill", tr("GENERAL"), Ui.Tone.SUNSET, [
		_tinted(_button_row("translate-fill", tr("LANGUAGE"), tr("LANGUAGE_NAME"), _switch_language), Ui.Tone.SUNSET),
		_tinted(_button_row("hand-pointing-fill", tr("REPLAY_TUTORIAL"), "", _replay_tutorial), Ui.Tone.SUNSET),
	]))
	var help: Array = [
		_tinted(_button_row("star-fill", tr("RATE"), "", Config.open_store_review), Ui.Tone.GOLD),
		_tinted(_button_row("shield-check-fill", tr("PRIVACY_POLICY"), "", Config.open_privacy_policy), Ui.Tone.BLUE),
	]
	if Services.ads.privacy_options_required():
		help.append(_tinted(_button_row("megaphone-fill", tr("AD_PRIVACY"), "", Services.ads.show_privacy_options), Ui.Tone.BLUE))
	if Services.store.enabled():
		if not Save.ads_removed:
			help.append(_tinted(_button_row("prohibit-fill", tr("REMOVE_ADS"), Services.store.price(), Services.store.buy_remove_ads), Ui.Tone.SUNSET))
		help.append(_tinted(_button_row("arrows-clockwise-bold", tr("RESTORE_PURCHASES"), "", Services.store.restore), Ui.Tone.SUNSET))
	help.append(_tinted(_button_row("info-fill", tr("CREDITS_BUTTON"), "", _show_credits), Ui.Tone.WHITE))
	right.add_child(_group("info-fill", tr("HELP"), Ui.Tone.BLUE, help))
	columns.add_child(right)
	var banner := Banner.new(tr("SETTINGS"), Ui.Tone.SUNSET, 48)
	page.add_child(card)
	page.add_child(banner)
	var back_button := Ui.round_button("arrow-left-bold", 76)
	back_button.pressed.connect(back)
	page.add_child(back_button)
	var place := func() -> void:
		var room := page.size
		var top := banner.custom_minimum_size.y * 0.5
		card.size = card.get_combined_minimum_size()
		var slot := back_button.custom_minimum_size.x + 20.0  # the back button's own corner, left clear
		var k := minf(1.0, minf((room.x - slot - 30.0) / card.size.x, (room.y - top - 12.0) / card.size.y))
		card.scale = Vector2.ONE * k
		var w := card.size.x * k
		# Panoramic whole at the left when the panel leaves him room, else the panel in the middle
		var hero_room := room.x - w - 60.0
		var show_hero := hero != null and hero_room >= 230.0
		var left_x := maxf((room.x - w) / 2, slot) if not show_hero else room.x - w - 20.0
		card.position = Vector2(left_x, top + (room.y - top - card.size.y * k) / 2)
		banner.size = banner.custom_minimum_size
		banner.position = Vector2(left_x + w / 2 - banner.size.x / 2, card.position.y - top)
		back_button.size = back_button.custom_minimum_size
		back_button.position = Vector2.ZERO  # docked in the top-left corner of the safe area
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


## Marks `row` with the tone its icon tile takes (what it means).
func _tinted(row: Control, tone: Ui.Tone) -> Control:
	row.set_meta(&"tone", tone)
	return row


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


func _column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 16)
	col.custom_minimum_size.x = COLUMN_W
	return col


## A group: its title in the panel's own brown with its icon in the group's colour, then its rows
## in one sunken card, a fine line between two rows.
func _group(icon_name: String, title: String, tone: Ui.Tone, rows: Array) -> VBoxContainer:
	var g := VBoxContainer.new()
	g.add_theme_constant_override(&"separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 8)
	head.add_child(Ui.bold_icon(icon_name, 32, Ui.tone_colours(tone).bottom, Color("5a2408")))
	head.add_child(Ui.label(title, 30, INK, Ui.font_title, HORIZONTAL_ALIGNMENT_LEFT))
	g.add_child(head)
	var well := PanelContainer.new()
	var s := Card.well(18)
	s.set_content_margin_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	well.add_theme_stylebox_override(&"panel", s)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 0)
	for i in rows.size():
		if i > 0:
			var line := ColorRect.new()
			line.color = Color(0.55, 0.32, 0.12, 0.35)
			line.custom_minimum_size = Vector2(0, 2)
			list.add_child(line)
		var row: Control = rows[i]
		list.add_child(row)
	well.add_child(list)
	g.add_child(well)
	# the rows take the group's colour
	for row: Control in rows:
		var tile := row.find_child("Tile", true, false) as PanelContainer
		var row_tone: Ui.Tone = row.get_meta(&"tone", tone)
		if tile:
			var ts := Ui.candy_style(row_tone, 13.0, false, 4.0)
			ts.set_content_margin_all(5)
			ts.content_margin_bottom = 9
			tile.add_theme_stylebox_override(&"panel", ts)
			var icon := tile.get_child(0) as BoldIcon
			if icon:
				icon.outline = Ui.tone_colours(row_tone).outline
				if row_tone == Ui.Tone.WHITE:
					icon.fill = Ui.LABEL_DEEP
					icon.outline = Color(0, 0, 0, 0)
				icon.queue_redraw()
	return g


## A row: its icon on a small candy tile (tinted by its group), its name, and `right`.
func _row(icon_name: String, text: String, right: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	row.custom_minimum_size.y = ROW_H
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := PanelContainer.new()
	tile.name = "Tile"
	var ts := Ui.candy_style(Ui.Tone.SUNSET, 13.0, false, 4.0)
	ts.set_content_margin_all(5)
	ts.content_margin_bottom = 9
	tile.add_theme_stylebox_override(&"panel", ts)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(Ui.bold_icon(icon_name, 32, Ui.WHITE, Color("5a1a06")))
	row.add_child(tile)
	var l := Ui.label(text, 26, INK, Ui.font_title, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 140
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
	slider.custom_minimum_size.x = 190
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
	var card := Card.new(Vector4(40, 56, 40, 30))
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

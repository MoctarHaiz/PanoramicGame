extends Screen
## Settings, in the game's own kit: one framed panel with its ribbon over the sunset (dimmed a
## little), "Sound and feel" on the left (music and sounds volumes, vibration, screen shake,
## reduced motion), the rest on the right as candy buttons (language, replay the tutorial, rate,
## privacy, credits, and the ad choices and purchases when they apply). Every row is a thumb-sized
## target. Credits (About, the fonts and icons, the studio, the version) open over it.

const ROW_H := 74.0  ## height of a row (the whole row takes the touch: 86 with its gap)

var _credits: Control


func enter(_data: Dictionary) -> void:
	Services.ads.show_banner(true)
	Services.store.ads_removed.connect(_build)  # the purchase rows change
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_credits = null
	add_child(SunsetBackdrop.new())
	var shade := ColorRect.new()  # the sunset steps back behind the panel
	shade.color = Color(0.1, 0.02, 0.08, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var area := safe_area(true, 16)
	add_child(area)
	var page := Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(page)
	var card := Card.new(Vector4(34, 56, 34, 30))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 30)
	card.add_child(columns)
	columns.add_child(_column(tr("SOUND_AND_FEEL"), [
		_slider_row("music-notes-fill", tr("MUSIC"), &"music_volume", &"music_on"),
		_slider_row("speaker-high-fill", tr("SOUNDS"), &"sounds_volume", &"sounds_on"),
		_toggle_row("vibrate-fill", tr("VIBRATION"), &"vibration_on"),
		_toggle_row("screen-shake", tr("SCREEN_SHAKE"), &"screen_shake"),
		_toggle_row("sliders-horizontal-fill", tr("REDUCE_MOTION"), &"reduce_motion"),
	]))
	var more: Array = [
		_button_row("translate-fill", tr("LANGUAGE"), tr("LANGUAGE_NAME"), _switch_language),
		_button_row("hand-pointing-fill", tr("REPLAY_TUTORIAL"), "", _replay_tutorial),
		_button_row("star-fill", tr("RATE"), "", Config.open_store_review),
		_button_row("shield-check-fill", tr("PRIVACY_POLICY"), "", Config.open_privacy_policy),
	]
	if Services.ads.privacy_options_required():
		more.append(_button_row("megaphone-fill", tr("AD_PRIVACY"), "", Services.ads.show_privacy_options))
	if Services.store.enabled():
		if not Save.ads_removed:
			more.append(_button_row("prohibit-fill", tr("REMOVE_ADS"), Services.store.price(), Services.store.buy_remove_ads))
		more.append(_button_row("arrows-clockwise-bold", tr("RESTORE_PURCHASES"), "", Services.store.restore))
	more.append(_button_row("info-fill", tr("CREDITS_BUTTON"), "", _show_credits))
	columns.add_child(_column(tr("MORE"), more))
	var banner := Banner.new(tr("SETTINGS"), Ui.Tone.SUNSET, 44)
	page.add_child(card)
	page.add_child(banner)
	var back_button := Ui.round_button("arrow-left-bold", 76)
	back_button.pressed.connect(back)
	page.add_child(back_button)
	var place := func() -> void:
		var room := page.size
		var top := banner.custom_minimum_size.y * 0.5
		card.size = card.get_combined_minimum_size()
		var k := minf(1.0, minf(room.x / card.size.x, (room.y - top) / card.size.y))
		card.scale = Vector2.ONE * k
		card.position = Vector2((room.x - card.size.x * k) / 2, top + (room.y - top - card.size.y * k) / 2)
		banner.size = banner.custom_minimum_size
		banner.position = Vector2(room.x / 2 - banner.size.x / 2, card.position.y - top)
		back_button.size = back_button.custom_minimum_size
		back_button.position = Vector2(0, 0)
	page.resized.connect(place)
	card.resized.connect(place)
	place.call_deferred()


## A titled column of rows.
func _column(title: String, rows: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	col.custom_minimum_size.x = 470
	var head := Ui.label(title.to_upper(), 24, Color("a4561e"), Ui.font_title, HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(head)
	for r: Control in rows:
		col.add_child(r)
	return col


## A row on a sunken sand strip: its icon on a small candy tile, its name, and `right`.
func _row(icon_name: String, text: String, right: Control) -> PanelContainer:
	var strip := PanelContainer.new()
	var s := Card.well(18)
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.content_margin_left = 10
	s.content_margin_right = 14
	strip.add_theme_stylebox_override(&"panel", s)
	strip.custom_minimum_size.y = ROW_H
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := PanelContainer.new()
	var ts := Ui.candy_style(Ui.Tone.SUNSET, 14.0, false, 4.0)
	ts.set_content_margin_all(6)
	ts.content_margin_bottom = 10
	tile.add_theme_stylebox_override(&"panel", ts)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(Ui.bold_icon(icon_name, 30, Ui.WHITE, Color("5a1a06")))
	row.add_child(tile)
	var l := Ui.label(text, 27, Color("4a1e04"), Ui.font_title, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 150
	row.add_child(l)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	strip.add_child(row)
	return strip


func _toggle_row(icon_name: String, text: String, option: StringName) -> Control:
	var switch := ToggleSwitch.new()
	switch.set_on(Save.get(option))
	switch.toggled.connect(func(on: bool) -> void:
		Save.set_option(option, on)
		if option == &"vibration_on" and on:
			Haptics.tap())
	var strip := _row(icon_name, text, switch)
	strip.gui_input.connect(func(event: InputEvent) -> void:  # the whole row flips it
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			switch.toggle())
	return strip


## A volume: the slider; at 0 the bus is switched off too (Audio.apply_settings).
func _slider_row(icon_name: String, text: String, option: StringName, switch_option: StringName) -> Control:
	var on: bool = Save.get(switch_option)
	var slider := VolumeSlider.new(Save.get(option) if on else 0.0)
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
	right.add_child(Ui.bold_icon("caret-right-bold", 22, Color("c0431a"), Color(0, 0, 0, 0)))
	var strip := _row(icon_name, text, right)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(strip)
	b.custom_minimum_size = strip.get_combined_minimum_size()
	strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override(&"hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override(&"pressed", StyleBoxEmpty.new())
	b.button_down.connect(func() -> void: strip.modulate = Color(0.9, 0.85, 0.8))
	b.button_up.connect(func() -> void: strip.modulate = Color.WHITE)
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

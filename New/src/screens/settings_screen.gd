extends Screen
## Settings (music, sounds, vibration, language, links) on the left, About on the right.


func enter(_data: Dictionary) -> void:
	Services.ads.show_banner(true)
	Services.store.ads_removed.connect(_build)  # the purchase rows change
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	add_child(SunsetBackdrop.new())
	var area := safe_area(true, 18)
	add_child(area)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(col)
	col.add_child(header(tr("SETTINGS")))
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override(&"separation", 18)
	col.add_child(columns)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 12)
	scroll.add_child(list)
	list.add_child(_group([
		_toggle_row("music-notes-fill", tr("MUSIC"), Save.music_on, func(on: bool) -> void:
			Save.set_option(&"music_on", on)
			Audio.apply_settings()),
		_toggle_row("speaker-high-fill", tr("SOUNDS"), Save.sounds_on, func(on: bool) -> void:
			Save.set_option(&"sounds_on", on)
			Audio.apply_settings()),
		_toggle_row("vibrate-fill", tr("VIBRATION"), Save.vibration_on, func(on: bool) -> void:
			Save.set_option(&"vibration_on", on)
			Haptics.tap()),
		_value_row("translate-fill", tr("LANGUAGE"), tr("LANGUAGE_NAME"), _switch_language),
	]))
	var links: Array = [
		_value_row("star-fill", tr("RATE"), "", Config.open_store_review),
		_value_row("shield-check-fill", tr("PRIVACY_POLICY"), "", Config.open_privacy_policy),
	]
	if Services.ads.privacy_options_required():
		links.append(_value_row("megaphone-fill", tr("AD_PRIVACY"), "", Services.ads.show_privacy_options))
	if Services.store.enabled():
		if not Save.ads_removed:
			links.append(_value_row("prohibit-fill", tr("REMOVE_ADS"), Services.store.price(), Services.store.buy_remove_ads))
		links.append(_value_row("arrows-clockwise-bold", tr("RESTORE_PURCHASES"), "", Services.store.restore))
	list.add_child(_group(links))

	var about_scroll := ScrollContainer.new()
	about_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(about_scroll)
	about_scroll.add_child(_about())


func _switch_language() -> void:
	var next := "fr" if TranslationServer.get_locale().begins_with("en") else "en"
	Save.set_option(&"language", next)
	Save.apply_language()
	_build()


## Rows on a white card, with thin lines between them.
func _group(rows: Array) -> PanelContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	for i in rows.size():
		if i > 0:
			var line := ColorRect.new()
			line.color = Ui.BRAND_LIGHT
			line.custom_minimum_size = Vector2(0, 2)
			box.add_child(line)
		box.add_child(rows[i])
	var card := Ui.card(box, Ui.WHITE, 22)
	(card.get_theme_stylebox(&"panel") as StyleBoxFlat).set_content_margin_all(6)
	return card


func _row(icon_name: String, text: String, right: Control) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override(&"hover", StyleBoxEmpty.new())
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Ui.BRAND_MIST
	pressed.set_corner_radius_all(16)
	b.add_theme_stylebox_override(&"pressed", pressed)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override(&"separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Ui.BRAND_LIGHT
	s.set_corner_radius_all(16)
	badge.add_theme_stylebox_override(&"panel", s)
	badge.custom_minimum_size = Vector2(38, 38)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(Ui.icon(icon_name, 22, Ui.BRAND))
	row.add_child(badge)
	var l := Ui.label(text, 21, Ui.INK, Ui.font_body_bold, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(right)
	b.add_child(row)
	return b


func _toggle_row(icon_name: String, text: String, on: bool, changed: Callable) -> Button:
	var switch := ToggleSwitch.new()
	switch.set_on(on)
	switch.scale = Vector2.ONE * 0.6
	switch.toggled.connect(changed)
	var holder := Control.new()
	holder.custom_minimum_size = switch.custom_minimum_size * 0.6
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(switch)
	var b := _row(icon_name, text, holder)
	b.pressed.connect(switch.toggle)
	return b


func _value_row(icon_name: String, text: String, value: String, action: Callable) -> Button:
	var right := HBoxContainer.new()
	right.add_theme_constant_override(&"separation", 6)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not value.is_empty():
		right.add_child(Ui.label(value, 19, Ui.BRAND, Ui.font_strong))
	right.add_child(Ui.icon("caret-right-bold", 20, Ui.INK_SOFT))
	var b := _row(icon_name, text, right)
	b.pressed.connect(func() -> void:
		Audio.play_sfx(&"button")
		Haptics.tap()
		action.call())
	return b


## About the game, the credits (the studio, not personal names) and the version.
func _about() -> PanelContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var logo_mark := TextureRect.new()
	logo_mark.texture = load("res://assets/art/ui/logo.png")
	logo_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_mark.custom_minimum_size = Vector2(0, 104)
	box.add_child(logo_mark)
	box.add_child(Ui.label(tr("ABOUT"), 26, Ui.BRAND, Ui.font_title))
	var text := Ui.label(tr("ABOUT_TEXT"), 18, Ui.INK, Ui.font_body)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(300, 0)
	box.add_child(text)
	var credits := Ui.label(tr("CREDITS"), 16, Ui.INK_SOFT, Ui.font_body_bold)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(credits)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/art/haiz_studio.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 64)
	box.add_child(logo)
	box.add_child(Ui.label(tr("VERSION") % Config.version, 15, Ui.INK_SOFT, Ui.font_body))
	var card := Ui.card(box, Ui.WHITE, 22)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(card.get_theme_stylebox(&"panel") as StyleBoxFlat).set_content_margin_all(18)
	return card

class_name PausePanel
extends RefCounted
## The pause panel: a big RESUME, and under it one aligned row of four square candy tiles, each
## named under it: music, sounds and controls in gold, Home in red. Music and sounds show their state
## one way only, on the tile itself: off, the icon is dimmed and struck through (no lamp, no "On"
## text, no change of colour). Controls
## opens the five moves in the panel, each with its gesture played by a hand (the tutorial's
## pictures), so every control can be found again without crowding the pause.

const TILE := 136.0  ## side of a tile (big enough to read on a phone)
const GAP := 34.0  ## between two tiles


## Opens the pause panel over `host`. `resume` and `home` are the two ways out; `hide`: what to
## leave out of the picture behind (the HUD, the effects).
static func open(host: Control, resume: Callable, home: Callable, hide: Array = []) -> GamePanel:
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 20)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	var help := CenterContainer.new()  # where the moves open (Controls)
	help.visible = false
	body.add_child(help)
	var go := Ui.candy_button(tr_key("RESUME"), "play-fill", Ui.Tone.GREEN, 122, 54)
	go.custom_minimum_size.x = 4 * TILE + 3 * GAP  # as wide as the row of tiles under it (no dead margins)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(resume)
	go.idle(0.04)
	go.shine(3.2, 1, 0.3)  # one small glint: more would be noise
	body.add_child(go)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", GAP)
	row.add_child(SoundSwitch.new("music-notes-fill", "", &"music_on", tr_key("MUSIC")))
	row.add_child(SoundSwitch.new("speaker-high-fill", "speaker-x-fill", &"sounds_on", tr_key("SOUNDS")))
	var controls := _tile("gamepad", Ui.Tone.GOLD, tr_key("CONTROLS"))  # the moves: read at a glance
	(controls.get_child(0).get_child(0) as JuicyButton).pressed.connect(func() -> void:
		if help.get_child_count() == 0:
			help.add_child(controls_well())
		help.visible = not help.visible)
	row.add_child(controls)
	var home_tile := _tile("house-fill", Ui.Tone.CRIMSON, tr_key("HOME"))
	(home_tile.get_child(0).get_child(0) as JuicyButton).pressed.connect(home)
	row.add_child(home_tile)
	body.add_child(row)
	var panel := GamePanel.open(host, tr_key("PAUSED"), Ui.Tone.SUNSET, body, null, Color(0.05, 0.02, 0.06, 0.35),
			Color(0, 0, 0, 0), false, hide)
	panel.leave_out_of_picture(_moving_pieces(host))
	return panel


## The frozen scene's moving pieces: Panoramic, the bandits, the Red Bobs. Left out of the picture
## behind (lightly dimmed and blurred they read as a smear beside the panel, and as red stubs poking
## out under its ribbon); the still world stays.
static func _moving_pieces(host: Control) -> Array:
	var out := []
	var actors := host.find_child("Actors", true, false)
	if actors:
		out.append(actors)
	var level := host.find_child("Level", true, false)
	if level:
		for n in level.get_children():
			if n is BobView:
				out.append(n)
	return out


static func tr_key(key: String) -> String:
	return TranslationServer.translate(key)


## A square candy tile with its name under it (the pause's row).
static func _tile(icon_name: String, tone: Ui.Tone, caption: String) -> VBoxContainer:
	var item := VBoxContainer.new()
	item.add_theme_constant_override(&"separation", 10)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(TILE, TILE)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var b := Ui.icon_button(icon_name, tone, TILE, 30.0)
	b.size = holder.custom_minimum_size
	holder.add_child(b)
	item.add_child(holder)
	item.add_child(_caption(caption))
	return item


## The name of a tile, under it.
static func _caption(caption: String) -> Label:
	return Ui.label(caption, 34, Color("3a1404"), Ui.font_display)


## The five moves, each on a dark tile where a hand plays its gesture, its name under it.
static func controls_well() -> PanelContainer:
	var well := PanelContainer.new()
	well.add_theme_stylebox_override(&"panel", Card.well())
	var moves := HBoxContainer.new()
	moves.alignment = BoxContainer.ALIGNMENT_CENTER
	moves.add_theme_constant_override(&"separation", 16)
	for m: Array in moves_list():
		var item := VBoxContainer.new()
		item.add_theme_constant_override(&"separation", 4)
		var tile := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color(Ui.NIGHT, 0.82)
		s.set_corner_radius_all(18)
		s.border_color = Color("e0961e")
		s.set_border_width_all(2)
		s.set_content_margin_all(4)
		tile.add_theme_stylebox_override(&"panel", s)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var g := Gesture.new(m[0], 74.0, true)
		g.badge = false
		tile.add_child(g)
		item.add_child(tile)
		item.add_child(Ui.label(tr_key(m[1]), 22, Color("5a2408"), Ui.font_title))
		moves.add_child(item)
	well.add_child(moves)
	return well


## The moves, in the order they are met: [gesture, name key].
static func moves_list() -> Array:
	return [[Gesture.Kind.UP, "MOVE_JUMP"], [Gesture.Kind.TOP, "MOVE_HANG"], [Gesture.Kind.DOWN, "MOVE_LET_GO"],
			[Gesture.Kind.RIGHT, "MOVE_STEP"], [Gesture.Kind.TAP, "MOVE_THROW"]]


## Music or sounds on and off, read at a glance: a badge on the tile's top right corner (a green "ON", a red
## "OFF"), and the icon itself (notes, a speaker with its waves; off: a speaker with a cross, or the
## notes dimmed and struck through). A gold tile, its name under it.
class SoundSwitch extends VBoxContainer:
	var _option: StringName
	var _icon_name := ""
	var _off_icon := ""
	var _holder: Control

	func _init(icon_name: String, off_icon: String, option: StringName, caption: String) -> void:
		_option = option
		_icon_name = icon_name
		_off_icon = off_icon
		add_theme_constant_override(&"separation", 10)
		_holder = Control.new()
		_holder.custom_minimum_size = Vector2(TILE, TILE)
		_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(_holder)
		add_child(PausePanel._caption(caption))
		_fill()

	func _fill() -> void:
		for c in _holder.get_children():
			c.queue_free()
		var on: bool = Save.get(_option)
		var icon_name := _icon_name if on or _off_icon.is_empty() else _off_icon
		var b := Ui.icon_button(icon_name, Ui.Tone.GOLD, TILE, 30.0)
		b.size = _holder.custom_minimum_size
		b.pressed.connect(func() -> void:
			Save.set_option(_option, not Save.get(_option))
			Audio.apply_settings()
			_fill())
		_holder.add_child(b)
		b.add_child(_badge(on))
		if not on and _off_icon.is_empty():  # no off icon: dimmed and struck through, a dark-edged red bar
			b.content.self_modulate.a = 0.38
			var side: float = b.content.custom_minimum_size.x
			for line: Array in [[13.0, Color("3a0a04")], [7.0, Color("e8361c")]]:
				var slash := Line2D.new()
				slash.points = PackedVector2Array([Vector2(-0.12, -0.08) * side, Vector2(1.12, 1.08) * side])
				slash.width = line[0]
				slash.default_color = line[1]
				slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
				slash.end_cap_mode = Line2D.LINE_CAP_ROUND
				b.content.add_child(slash)

	## The state's badge inside the tile's top right corner (clear of the label under the tile):
	## a green pill "ON" or a red pill "OFF".
	static func _badge(on: bool) -> Control:
		var pill := PanelContainer.new()
		var st := StyleBoxFlat.new()  # a crisp tag (not a soft pill): square-ish, a fine edge, a drop shadow
		st.bg_color = Color("3fa21c") if on else Color("d8261a")
		st.border_color = Color("16300a") if on else Color("3a0603")
		st.set_border_width_all(3)
		st.set_corner_radius_all(9)
		st.content_margin_left = 10
		st.content_margin_right = 10
		st.content_margin_top = 1
		st.content_margin_bottom = 2
		st.shadow_color = Color(0.1, 0.02, 0.0, 0.5)
		st.shadow_size = 3
		st.shadow_offset = Vector2(0, 3)
		st.anti_aliasing = true
		pill.add_theme_stylebox_override(&"panel", st)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var word := TranslationServer.translate("SWITCH_ON" if on else "SWITCH_OFF").to_upper()
		pill.add_child(Ui.label(word, 24, Color.WHITE, Ui.font_display))
		pill.size = pill.get_combined_minimum_size()
		# pinned inside its own tile's top right corner (one hanging over the gap read as the next tile's)
		pill.position = Vector2(TILE - pill.size.x - 7.0, 7.0)
		return pill

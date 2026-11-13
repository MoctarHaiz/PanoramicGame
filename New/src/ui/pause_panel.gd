class_name PausePanel
extends RefCounted
## The pause panel, on the ink (the user, 2026-11-13, of three panel styles shown: "C", no box, ink brush), tight
## round what it holds (UI r22, the judges of j18: r21's "oversized panel with dead beige, a full-width web-banner
## Resume"), in two groups a thin gold line parts:
## - what is on: music and sounds, two wide leaning plates side by side, each its glyph and its name on the plate
##   itself: on, the gold plate, its glyph and name in ink; off, the dark plate, its line dim, the glyph dimmed and
##   struck through (a speaker with a cross, the notes with a red bar);
## - where to go: Home and Controls on quiet plates beside the red RESUME (the results' own row: Home, Play again,
##   Share). Controls (a gamepad: plainly "the controls") opens the five moves in the panel, each with its gesture
##   played by a hand (the tutorial's pictures), so every control can be found again without crowding the pause.
## (Blind round 12: "the CONTROLS plate is dark exactly like an off toggle beside two gold on toggles, so a
## navigation button looks like a disabled setting": it was the third plate of the switches' row, each named under it.)

const SWITCH_H := 92.0  ## a switch's plate
const SWITCH_GAP := 22.0  ## between the two
const GO_H := 100.0  ## RESUME's height with its shadow (the plates beside it are as tall as its face)
const SIDE_W := 112.0  ## the Home plate, and the Controls one
const OUT_GAP := 20.0  ## between two of that row
const WELL_W := 474.0  ## the five moves' row (controls_well)


## Opens the pause panel over `host`. `resume` and `home` are the two ways out; `hide`: what to
## leave out of the picture behind (the HUD, the effects).
static func open(host: Control, resume: Callable, home: Callable, hide: Array = []) -> GamePanel:
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 24)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	var help := CenterContainer.new()  # where the moves open (Controls)
	help.visible = false
	body.add_child(help)
	# the way out sets the panel's width: Home, Controls and the red RESUME; the two switches over it share it
	var go := Ui.cta_button(tr_key("RESUME"), GO_H, 46)
	var wide := 2.0 * (SIDE_W + OUT_GAP) + go.custom_minimum_size.x
	var plate := Vector2((wide - SWITCH_GAP) / 2.0, SWITCH_H)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", int(SWITCH_GAP))
	row.add_child(SoundSwitch.new("music-notes-fill", "", &"music_on", tr_key("MUSIC"), plate))
	row.add_child(SoundSwitch.new("speaker-high-fill", "speaker-x-fill", &"sounds_on", tr_key("SOUNDS"), plate))
	body.add_child(row)
	body.add_child(Ui.rule(wide + 30.0))
	var out := HBoxContainer.new()
	out.alignment = BoxContainer.ALIGNMENT_CENTER
	out.add_theme_constant_override(&"separation", int(OUT_GAP))
	var face_h := GO_H - roundf(GO_H * 0.09)  # RESUME's face, less its shadow
	var home_button := Ui.plate_button("house-fill", Vector2(SIDE_W, face_h))
	home_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	home_button.pressed.connect(home)
	out.add_child(home_button)
	var controls := Ui.plate_button("gamepad-fill", Vector2(SIDE_W, face_h))  # the moves
	controls.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	controls.pressed.connect(func() -> void:
		if help.get_child_count() == 0:
			help.add_child(controls_well())
		help.visible = not help.visible)
	out.add_child(controls)
	go.pressed.connect(resume)
	go.idle(0.04)
	out.add_child(go)
	body.add_child(out)
	var panel := GamePanel.open(host, tr_key("PAUSED"), body, null, Color(0.05, 0.02, 0.06, 0.35),
			Color(0, 0, 0, 0), false, hide)
	panel.leave_out_of_picture(moving_pieces(host))
	return panel


## The frozen scene's moving pieces: Panoramic, the bandits, the Red Bobs. Left out of the picture
## behind (lightly dimmed and blurred they read as a smear beside the panel, and as red stubs poking
## out under its ribbon); the still world stays.
static func moving_pieces(host: Control) -> Array:
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


## The five moves, each on a tile where a hand plays its gesture, its name under it; a thin gold line under them.
static func controls_well() -> Control:
	var well := VBoxContainer.new()
	well.add_theme_constant_override(&"separation", 18)
	var moves := HBoxContainer.new()
	moves.alignment = BoxContainer.ALIGNMENT_CENTER
	moves.add_theme_constant_override(&"separation", 16)
	for m: Array in moves_list():
		var item := VBoxContainer.new()
		item.add_theme_constant_override(&"separation", 4)
		var tile := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color(1.0, 0.9, 0.72, 0.07)
		s.set_corner_radius_all(5)
		s.border_color = Color(Ui.INK_GOLD, 0.75)
		s.set_border_width_all(2)
		s.set_content_margin_all(4)
		tile.add_theme_stylebox_override(&"panel", s)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var g := Gesture.new(m[0], 74.0, true)
		g.badge = false
		tile.add_child(g)
		item.add_child(tile)
		item.add_child(Ui.label(tr_key(m[1]), 22, Ui.BONE, Ui.font_title))
		moves.add_child(item)
	well.add_child(moves)
	well.add_child(Ui.rule(WELL_W + 40.0))
	return well


## The moves, in the order they are met: [gesture, name key].
static func moves_list() -> Array:
	return [[Gesture.Kind.UP, "MOVE_JUMP"], [Gesture.Kind.TOP, "MOVE_HANG"], [Gesture.Kind.DOWN, "MOVE_LET_GO"],
			[Gesture.Kind.RIGHT, "MOVE_STEP"], [Gesture.Kind.TAP, "MOVE_THROW"]]


## Music or sounds on and off, read at a glance on the plate itself (UI r23, the judges of j19: r22's lamps "tiny dark
## pills" under two tiles of three: show it on the button): a wide leaning plate, its glyph (notes, a speaker with its
## waves) and its name on it. On, the gold plate (Ui.on_style), glyph and name in ink (blind round 11: "no visible on
## state": it was a cream glyph in a brighter line); off, the dark plate, its line dim, glyph and name dimmed, the glyph
## struck through (a speaker with a cross, or the notes struck by a red bar). A tap flips it, the plate popping.
class SoundSwitch extends Control:
	var _option: StringName
	var _icon_name := ""
	var _off_icon := ""
	var _caption := ""

	func _init(icon_name: String, off_icon: String, option: StringName, caption: String, plate := Vector2(250.0, SWITCH_H)) -> void:
		_option = option
		_icon_name = icon_name
		_off_icon = off_icon
		_caption = caption
		custom_minimum_size = plate
		_fill(false)

	## Whether the plate is lit (the option on).
	func lit() -> bool:
		return Save.get(_option)

	## The plate for the option's state; `flipped`: it was just tapped (a little pop).
	func _fill(flipped: bool) -> void:
		for c in get_children():
			c.queue_free()
		var on := lit()
		var icon_name := _icon_name if on or _off_icon.is_empty() else _off_icon
		var plate := Vector2(maxf(size.x, custom_minimum_size.x), custom_minimum_size.y)
		var b := Ui.plate_button(icon_name, plate, _caption, 36)
		custom_minimum_size.x = maxf(custom_minimum_size.x, b.custom_minimum_size.x)  # (a longer name: a wider plate)
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.pressed.connect(func() -> void:
			Save.set_option(_option, not Save.get(_option))
			Audio.apply_settings()
			_fill(true))
		add_child(b)
		var glyph := b.content.get_child(0) as Control
		var word := b.content.get_child(1) as Label
		if on:  # the gold plate, its glyph and name in ink
			for state: StringName in [&"normal", &"hover", &"pressed"]:
				b.add_theme_stylebox_override(state, Ui.on_style(plate.y))
			glyph.self_modulate = Ui.ON_INK
			word.add_theme_color_override(&"font_color", Ui.ON_INK)
		else:
			for state: StringName in [&"normal", &"hover", &"pressed"]:
				(b.get_theme_stylebox(state) as SlantStyle).line.a = 0.4
			glyph.self_modulate = Color(Ui.BONE, 0.42)  # the glyph dimmed (its red bar not)
			word.add_theme_color_override(&"font_color", Color(Ui.BONE, 0.55))
			if _off_icon.is_empty():  # no off icon: struck through, a dark-edged red bar
				var slash := _Slash.new()
				slash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				glyph.add_child(slash)
		if flipped and Prefs.motion():
			b.pivot_offset = size / 2
			b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).from(Vector2.ONE * 0.9) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A red bar struck across the glyph it is in, inside the glyph's own square (in the middle of its control).
class _Slash extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var side := minf(size.x, size.y)
		var at := (size - Vector2(side, side)) / 2.0
		for line: Array in [[11.0, Color("140607")], [6.0, Color("e8361c")]]:
			draw_line(at + Vector2(0.1, 0.1) * side, at + Vector2(0.9, 0.9) * side, line[1], line[0], true)

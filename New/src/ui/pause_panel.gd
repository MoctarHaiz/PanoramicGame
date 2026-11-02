class_name PausePanel
extends RefCounted
## The pause panel's content: the five moves with their gestures (so every control can be found
## again), music and sounds as switches that show their state (a green tile with a tick, or a
## pale one with a red cross), Home and a big RESUME.


## Opens the pause panel over `host`. `resume` and `home` are the two ways out.
static func open(host: Control, resume: Callable, home: Callable) -> GamePanel:
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 22)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(controls_well())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 18)
	row.add_child(SoundSwitch.new("music-notes-fill", &"music_on", tr_key("MUSIC")))
	row.add_child(SoundSwitch.new("speaker-high-fill", &"sounds_on", tr_key("SOUNDS")))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(16, 0)
	row.add_child(gap)
	var home_button := Ui.icon_button("house-fill", Ui.Tone.SUNSET, 92.0, 30.0)
	home_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	home_button.pressed.connect(home)
	row.add_child(home_button)
	var go := Ui.candy_button(tr_key("RESUME"), "play-fill", Ui.Tone.GREEN, 92, 38)
	go.custom_minimum_size.x = 280
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(resume)
	go.idle(0.04)
	go.shine()
	row.add_child(go)
	body.add_child(row)
	return GamePanel.open(host, tr_key("PAUSED"), Ui.Tone.SUNSET, body)


static func tr_key(key: String) -> String:
	return TranslationServer.translate(key)


## The five moves in a sunken well: each its gesture on a gold badge, its name under it.
static func controls_well(badge := 64.0) -> PanelContainer:
	var well := PanelContainer.new()
	well.add_theme_stylebox_override(&"panel", Card.well())
	var moves := HBoxContainer.new()
	moves.alignment = BoxContainer.ALIGNMENT_CENTER
	moves.add_theme_constant_override(&"separation", 22)
	for m: Array in moves_list():
		var item := VBoxContainer.new()
		item.add_theme_constant_override(&"separation", 4)
		var g := Gesture.new(m[0], badge)
		g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		item.add_child(g)
		item.add_child(Ui.label(tr_key(m[1]), 24, Color("5a2408"), Ui.font_title))
		moves.add_child(item)
	well.add_child(moves)
	return well


## The moves, in the order they are met: [gesture, name key].
static func moves_list() -> Array:
	return [[Gesture.Kind.UP, "MOVE_JUMP"], [Gesture.Kind.TOP, "MOVE_HANG"], [Gesture.Kind.DOWN, "MOVE_LET_GO"],
			[Gesture.Kind.RIGHT, "MOVE_STEP"], [Gesture.Kind.TAP, "MOVE_THROW"]]


## Music or sounds on and off: a framed tile, green with a tick when on, pale with its icon
## crossed in red when off (the state reads without colour too), its name under it.
class SoundSwitch extends VBoxContainer:
	var _option: StringName
	var _icon_name := ""
	var _holder: Control

	func _init(icon_name: String, option: StringName, caption: String) -> void:
		_option = option
		_icon_name = icon_name
		add_theme_constant_override(&"separation", 4)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_holder = Control.new()
		_holder.custom_minimum_size = Vector2(84, 84)
		_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(_holder)
		add_child(Ui.label(caption, 23, Color("5a2408"), Ui.font_title))
		_fill()

	func _fill() -> void:
		for c in _holder.get_children():
			c.queue_free()
		var on: bool = Save.get(_option)
		var b := Ui.icon_button(_icon_name, Ui.Tone.GREEN if on else Ui.Tone.WHITE, 84.0, 26.0)
		if not on:
			b.modulate = Color(0.85, 0.82, 0.8)
		b.size = _holder.custom_minimum_size
		b.pressed.connect(func() -> void:
			Save.set_option(_option, not Save.get(_option))
			Audio.apply_settings()
			_fill())
		_holder.add_child(b)
		var mark := Ui.bold_icon("check-bold" if on else "x-bold", 26, Color("6ad43a") if on else Color("ff4a2a"), Color("2e0d04"))
		mark.position = Vector2(56, -8)
		_holder.add_child(mark)

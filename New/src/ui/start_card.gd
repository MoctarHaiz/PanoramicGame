class_name StartCard
extends Control
## Before the first touch the world waits (the 2017 "Ready"): a small prompt low on the screen, out
## of the scene's way: "Tap to start" breathing on a pill of dark glass, a hand tapping beside it.
## The first time, nothing else: the moves are taught when they are needed (Tutorial). Later runs
## show the five moves above it on a strip of dark glass, each with its own gesture, so every
## control stays easy to find.


func _init(first_run: bool) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 22)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	if not first_run:
		var strip := Card.new(Vector4(26, 16, 26, 14), true)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var moves := HBoxContainer.new()
		moves.add_theme_constant_override(&"separation", 26)
		moves.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for m: Array in PausePanel.moves_list():
			var item := VBoxContainer.new()
			item.add_theme_constant_override(&"separation", 4)
			item.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var g := Gesture.new(m[0], 60.0)
			g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			item.add_child(g)
			var name := Ui.display_text(tr(m[1]), 25, Ui.WHITE, Ui.NIGHT)
			name.depth = 2.0
			name.shadow = Color(0, 0, 0, 0)
			name.refresh()
			item.add_child(name)
			moves.add_child(item)
		strip.add_child(moves)
		box.add_child(strip)
	var go_row := HBoxContainer.new()
	go_row.alignment = BoxContainer.ALIGNMENT_CENTER
	go_row.add_theme_constant_override(&"separation", 6)
	go_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hand := Gesture.new(Gesture.Kind.TAP, 84.0, true)
	hand.badge = false
	go_row.add_child(hand)
	var go := Ui.display_text(tr("TAP_TO_START"), 44, Ui.WHITE, Ui.NIGHT, Color("ffd98a"))
	go.tracking = 3.0  # the outlines of "a" and "p" fused at this size
	go.depth = 4.0
	go.refresh()
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go_row.add_child(go)
	var plate := Card.new(Vector4(20, 6, 40, 8), true)  # on dark glass: it reads over any sky
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.add_child(go_row)
	box.add_child(plate)
	go.resized.connect(func() -> void: go.pivot_offset = go.size / 2)
	if Prefs.motion():
		var t := go.create_tween().set_loops()
		t.tween_property(go, "scale", Vector2.ONE * 1.07, 0.6).set_trans(Tween.TRANS_SINE)
		t.tween_property(go, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.3).set_delay(0.2)
	resized.connect(_fit.bind(box))
	box.minimum_size_changed.connect(_fit.bind(box))


## Centres it, shrunk to fit a narrow screen (a tablet, the longer French words) inside the safe
## area. (Placed by hand: a container would undo the scale.)
func _fit(box: Control) -> void:
	var insets := Device.insets()
	var room := size.x - insets.x - insets.z - 40.0
	var need := box.get_combined_minimum_size()
	var k := clampf(room / maxf(need.x, 1.0), 0.1, 1.0)
	box.size = need
	box.pivot_offset = need / 2
	# below the middle, its foot just above the row of Red Bobs at the start
	box.position = Vector2(insets.x + (size.x - insets.x - insets.z - need.x) / 2,
			size.y * 0.66 - need.y * (0.5 + 0.5 * k))
	box.scale = Vector2.ONE * k

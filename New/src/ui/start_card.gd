class_name StartCard
extends Control
## Before the first touch the world waits (the 2017 "Ready"): a compact prompt in the sky, above the
## platforms and the ground he runs on: "Tap to start" in gold on a pill of dark glass with a gold rim
## (it reads over yellow grass and blue sky alike), a hand tapping beside the words (never over them),
## the pill breathing gently.
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
	go_row.add_theme_constant_override(&"separation", 14)
	go_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hand := Gesture.new(Gesture.Kind.TAP, 56.0, true)
	hand.badge = false
	go_row.add_child(hand)
	var go := Ui.display_text(tr("TAP_TO_START"), 36, Color("fff2b8"), Color("2a0c04"), Color("ffc93c"))
	go.tracking = 2.0
	go.depth = 3.0
	go.shadow = Color(0, 0, 0, 0)
	go.refresh()
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go_row.add_child(go)
	var plate := PanelContainer.new()  # dark glass with a gold rim: reads over grass and sky
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.04, 0.03, 0.78)
	ps.set_corner_radius_all(40)
	ps.border_color = Color("f2b52a")
	ps.set_border_width_all(3)
	ps.shadow_color = Color(0, 0, 0, 0.3)
	ps.shadow_size = 8
	ps.shadow_offset = Vector2(0, 4)
	ps.anti_aliasing = true
	ps.content_margin_left = 16
	ps.content_margin_right = 30
	ps.content_margin_top = 4
	ps.content_margin_bottom = 6
	plate.add_theme_stylebox_override(&"panel", ps)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.add_child(go_row)
	box.add_child(plate)
	if Prefs.motion():
		plate.resized.connect(func() -> void: plate.pivot_offset = plate.size / 2)
		var t := plate.create_tween().set_loops()
		t.tween_property(plate, "scale", Vector2.ONE * 1.04, 0.7).set_trans(Tween.TRANS_SINE)
		t.tween_property(plate, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.3).set_delay(0.2)
	resized.connect(_fit.bind(box))
	box.minimum_size_changed.connect(_fit.bind(box))


## Centres it, shrunk to fit a narrow screen (a tablet, the longer French words) inside the safe
## area. (Placed by hand: a container would undo the scale.)
func _fit(box: Control) -> void:
	var insets := Device.insets()
	var room := minf(size.x - insets.x - insets.z - 40.0, size.x * 0.55)  # compact: never most of a tablet's width
	var need := box.get_combined_minimum_size()
	var k := clampf(room / maxf(need.x, 1.0), 0.1, 1.0)
	box.size = need
	box.pivot_offset = need / 2
	# in the sky: centred at 38 % of the height, under the HUD band, above the platforms and the
	# ground he runs on (the play area)
	var y := clampf(size.y * 0.38 - need.y / 2, insets.y + 90.0 - need.y * (1.0 - k) / 2, size.y)
	box.position = Vector2(insets.x + (size.x - insets.x - insets.z - need.x) / 2, y)
	box.scale = Vector2.ONE * k

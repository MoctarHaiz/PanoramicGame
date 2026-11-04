class_name StartCard
extends Control
## Before the first touch the world waits (the 2017 "Ready"): the screen's call to action in the sky,
## above the platforms and the ground he runs on: "Tap to start" in big bold display letters (cream to
## gold, a heavy ink outline and depth) on a soft dark glow that keeps them readable over sky and
## grass, a big hand tapping beside them with its ripples (never over the words), the whole beating
## like the Play button, a warm light pulsing behind.
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
	# the call to action: big bold display letters (cream to gold, a heavy ink outline, depth, a soft
	# shadow) on a soft dark glow that keeps them readable over sky and grass, a big hand tapping
	# beside them with its ripples; the whole beats like the Play button
	var halo := Control.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var shade := TextureRect.new()  # the soft dark glow behind the words (no pill: not a tooltip)
	shade.texture = Fx.glow_texture()
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.modulate = Color(0.08, 0.02, 0.0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.add_child(shade)
	var glow := TextureRect.new()  # and a warm light pulsing in it
	glow.texture = Fx.glow_texture()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.material = Fx.additive()
	glow.modulate = Color(1, 0.72, 0.3, 0.35)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.add_child(glow)
	var go_row := HBoxContainer.new()
	go_row.alignment = BoxContainer.ALIGNMENT_CENTER
	go_row.add_theme_constant_override(&"separation", 4)
	go_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var go := Ui.display_text(tr("TAP_TO_START"), 70, Color("fffbe6"), Color("2a0c04"), Color("ffc33a"))
	go.outline_width = 8.0
	go.depth = 7.0
	go.arch = 8.0
	go.shadow = Color(0.05, 0.0, 0.0, 0.45)
	go.refresh()
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go_row.add_child(go)
	var hand := Gesture.new(Gesture.Kind.TAP, 118.0, true)  # big: a finger tapping, its ripples
	hand.badge = false
	hand.size_flags_vertical = Control.SIZE_SHRINK_END
	go_row.add_child(hand)
	halo.add_child(go_row)
	box.add_child(halo)
	var hold := func() -> void:
		var need := go_row.get_combined_minimum_size()
		halo.custom_minimum_size = need
		go_row.size = need
		shade.size = need * Vector2(1.25, 2.1)
		shade.position = need / 2 - shade.size / 2
		glow.size = need * Vector2(1.1, 1.8)
		glow.position = need / 2 - glow.size / 2
		halo.pivot_offset = need / 2
	go_row.minimum_size_changed.connect(hold)
	hold.call_deferred()
	if Prefs.motion():  # a heartbeat: two quick swells, then a rest
		var t := halo.create_tween().set_loops()
		t.tween_property(halo, "scale", Vector2.ONE * 1.07, 0.14).set_trans(Tween.TRANS_SINE)
		t.tween_property(halo, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)
		t.tween_property(halo, "scale", Vector2.ONE * 1.05, 0.14).set_trans(Tween.TRANS_SINE)
		t.tween_property(halo, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)
		t.tween_interval(0.66)
		var g := glow.create_tween().set_loops()
		g.tween_property(glow, "modulate:a", 0.6, 0.65).set_trans(Tween.TRANS_SINE)
		g.tween_property(glow, "modulate:a", 0.25, 0.65).set_trans(Tween.TRANS_SINE)
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.3).set_delay(0.2)
	resized.connect(_fit.bind(box))
	box.minimum_size_changed.connect(_fit.bind(box))


## Centres it, shrunk to fit a narrow screen (a tablet, the longer French words) inside the safe
## area. (Placed by hand: a container would undo the scale.)
func _fit(box: Control) -> void:
	var insets := Device.insets()
	var room := minf(size.x - insets.x - insets.z - 40.0, size.x * 0.7)  # big, but never the whole width
	var need := box.get_combined_minimum_size()
	var k := clampf(room / maxf(need.x, 1.0), 0.1, 1.0)
	box.size = need
	box.pivot_offset = need / 2
	# in the sky: centred at 38 % of the height, under the HUD band, above the platforms and the
	# ground he runs on (the play area)
	var y := clampf(size.y * 0.38 - need.y / 2, insets.y + 90.0 - need.y * (1.0 - k) / 2, size.y)
	box.position = Vector2(insets.x + (size.x - insets.x - insets.z - need.x) / 2, y)
	box.scale = Vector2.ONE * k

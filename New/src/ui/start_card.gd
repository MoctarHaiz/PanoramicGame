class_name StartCard
extends Control
## Before the first touch the world waits (the 2017 "Ready"): a small bright prompt at the foot of
## the screen, over the soil, out of the scene's way: "Tap to start" on a glossy gold pill that
## breathes in a pulsing glow, a hand tapping beside it.
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
	var go := Ui.display_text(tr("TAP_TO_START"), 44, Ui.WHITE, Color("6a3205"), Color("fff3d6"))
	go.tracking = 3.0  # the outlines of "a" and "p" fused at this size
	go.depth = 4.0
	go.refresh()
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go_row.add_child(go)
	var plate := PanelContainer.new()  # a glossy gold pill: bright over any ground
	var ps := Ui.candy_style(Ui.Tone.GOLD, 40.0, false, 7.0)
	ps.content_margin_left = 18
	ps.content_margin_right = 36
	ps.content_margin_top = 4
	ps.content_margin_bottom = 12
	plate.add_theme_stylebox_override(&"panel", ps)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(go_row)
	var halo := Control.new()  # the pill and the glow pulsing behind it
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var glow := TextureRect.new()
	glow.texture = Fx.glow_texture()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.material = Fx.additive()
	glow.modulate = Color(1, 0.8, 0.35, 0.55)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.add_child(glow)
	halo.add_child(plate)
	box.add_child(halo)
	plate.minimum_size_changed.connect(func() -> void: _hold(halo, plate, glow))
	_hold.call_deferred(halo, plate, glow)
	if Prefs.motion():
		halo.resized.connect(func() -> void: halo.pivot_offset = halo.size / 2)
		var t := halo.create_tween().set_loops()
		t.tween_property(halo, "scale", Vector2.ONE * 1.06, 0.6).set_trans(Tween.TRANS_SINE)
		t.tween_property(halo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
		var g := glow.create_tween().set_loops()
		g.tween_property(glow, "modulate:a", 0.85, 0.6).set_trans(Tween.TRANS_SINE)
		g.tween_property(glow, "modulate:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.3).set_delay(0.2)
	resized.connect(_fit.bind(box))
	box.minimum_size_changed.connect(_fit.bind(box))


## Sizes the pill's holder to the pill, the glow wider than it behind.
static func _hold(halo: Control, plate: Control, glow: Control) -> void:
	var need := plate.get_combined_minimum_size()
	halo.custom_minimum_size = need
	plate.size = need
	glow.size = need * Vector2(1.5, 2.6)
	glow.position = need / 2 - glow.size / 2


## Centres it, shrunk to fit a narrow screen (a tablet, the longer French words) inside the safe
## area. (Placed by hand: a container would undo the scale.)
func _fit(box: Control) -> void:
	var insets := Device.insets()
	var room := size.x - insets.x - insets.z - 40.0
	var need := box.get_combined_minimum_size()
	var k := clampf(room / maxf(need.x, 1.0), 0.1, 1.0)
	box.size = need
	box.pivot_offset = need / 2
	# at the foot of the screen, over the soil band, clear of the platforms and the Red Bobs
	box.position = Vector2(insets.x + (size.x - insets.x - insets.z - need.x) / 2,
			size.y - Device.bottom_with_banner() - 14.0 - need.y * (0.5 + 0.5 * k))
	box.scale = Vector2.ONE * k

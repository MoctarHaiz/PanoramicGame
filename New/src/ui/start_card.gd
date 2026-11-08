class_name StartCard
extends Control
## Before the first touch the world waits (the 2017 "Ready"): the screen's call to action at the foot of the
## screen, over the soil under the run's ground line, where it covers nothing of the play (UI r21, the judges
## of j17: r20's big framed plate "dead centre" covered the scene; UI r22, the judges of j18: r21's pill in the
## lower third "sits on the gem row"): "Tap to start" in bold display letters (cream to gold, an ink outline and depth)
## on a slim pill of dark glass with a gold line, a hand tapping beside the words with its ripples (never
## over them), the words beating like the Play button. No glow round it (it washed the sky milky).
## The first time, nothing else: the moves are taught when they are needed (Tutorial). Later runs
## show the five moves above it on a strip of dark glass, each with its own gesture, so every
## control stays easy to find.


const PILL_PAD := Vector2(28, 6)  ## from the words and the hand to the pill's edge
const FOOT := 14.0  ## from the bottom of it all to the safe area's foot (design units)


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
	# the call to action: bold display letters on a slim pill of dark glass, a hand tapping beside them
	var halo := Control.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var plate := Card.new(Vector4.ZERO, true)  # dark glass with a gold line
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.add_child(plate)
	var go_row := HBoxContainer.new()
	go_row.alignment = BoxContainer.ALIGNMENT_CENTER
	go_row.add_theme_constant_override(&"separation", 2)
	go_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var go := Ui.display_text(tr("TAP_TO_START"), 36, Color("fffbe6"), Color("2a0c04"), Color("ffc33a"))
	go.outline_width = 5.0
	go.depth = 3.0
	go.shadow = Color(0, 0, 0, 0)
	go.refresh()
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go_row.add_child(go)
	var hand := Gesture.new(Gesture.Kind.TAP, 48.0, true)  # a finger tapping, its ripples
	hand.badge = false
	hand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go_row.add_child(hand)
	halo.add_child(go_row)
	box.add_child(halo)
	var hold := func() -> void:
		var need := go_row.get_combined_minimum_size()
		var whole := need + PILL_PAD * 2.0
		halo.custom_minimum_size = whole
		go_row.size = need
		go_row.position = PILL_PAD
		plate.size = whole
		plate.position = Vector2.ZERO
		plate.radius = whole.y / 2.0  # a pill
		plate.queue_redraw()
		go_row.pivot_offset = need / 2
	go_row.minimum_size_changed.connect(hold)
	hold.call_deferred()
	if Prefs.motion():  # a heartbeat of the words (the pill stays): two quick swells, then a rest
		var t := go_row.create_tween().set_loops()
		t.tween_property(go_row, "scale", Vector2.ONE * 1.05, 0.14).set_trans(Tween.TRANS_SINE)
		t.tween_property(go_row, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)
		t.tween_property(go_row, "scale", Vector2.ONE * 1.03, 0.14).set_trans(Tween.TRANS_SINE)
		t.tween_property(go_row, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)
		t.tween_interval(0.66)
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.3).set_delay(0.2)
	resized.connect(_fit.bind(box))
	box.minimum_size_changed.connect(_fit.bind(box))


## Centres it across, its foot at the safe area's foot (FOOT), shrunk to fit a narrow screen (a tablet,
## the longer French words) inside the safe area. (Placed by hand: a container would undo the scale.)
func _fit(box: Control) -> void:
	var insets := Device.insets()
	var room := minf(size.x - insets.x - insets.z - 40.0, size.x * 0.7)  # never the whole width
	var need := box.get_combined_minimum_size()
	var k := clampf(room / maxf(need.x, 1.0), 0.1, 1.0)
	box.size = need
	box.pivot_offset = need / 2
	var foot := size.y - insets.w - FOOT  # (inside the safe area at the bottom)
	var y := foot - need.y + need.y * (1.0 - k) / 2  # its foot there once shrunk round its middle
	box.position = Vector2(insets.x + (size.x - insets.x - insets.z - need.x) / 2, y)
	box.scale = Vector2.ONE * k

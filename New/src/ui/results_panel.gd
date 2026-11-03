class_name ResultsPanel
extends RefCounted
## The end of a run, over the game (GamePanel), told in order so the eye can follow it:
## - Home: a gold ribbon; the three stars slam into their carved sockets one after the other, each
##   with a burst and its note (the third shakes the card), coins and confetti rain in front of
##   everything; then the Red Bobs roll up with ticks; a NEW BEST stamp slams in last (in its own row
##   under the count, so it covers nothing and stays on the card). Panoramic
##   stands at the left with his arms up, in a pool of gold light, a big burst of rays turning
##   behind the card.
## - A lost run: a crimson GAME OVER ribbon and what happened under it; the Red Bobs roll up, then
##   the bar of the way home fills to where he got (the house at its end in a gold disc: the goal);
##   the buttons are there at once. Panoramic down on one knee in a cold, dim light.
## Home, PLAY AGAIN (the big one) and Share sit in one warm row, there from the start.

const HERO_WIN := "res://assets/art/hero/hero_win.png"  ## the art track's render (arms up), when there
const HERO_LOSE := "res://assets/art/hero/hero_defeat.png"  # the art track's defeat pose
const HERO_STAND := preload("res://assets/art/ui/hero_stand.png")
const HERO_DOWN := preload("res://assets/art/ui/hero_down.png")
const STAR_STEP := 0.32  ## seconds between two stars
const COUNT_TIME := 0.7  ## seconds the Red Bobs take to roll up


## Opens the results over `game` (the game screen). `news`: what Save.record_run found new.
static func open(game: Control, world: World, news: Dictionary, home: Callable, again: Callable,
		share: Callable, hide: Array = []) -> GamePanel:
	var won := world.state == World.State.WON
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 14)
	var stars: Array[Control] = []
	if won:
		body.add_child(_stars_stage(stars))
	else:
		var why := Ui.display_text(TranslationServer.translate("FELL" if world.death_reason == &"fall" else "CAUGHT"),
				36, Color("e8361c"), Color("4a0804"), Color("b8180a"))  # heavy: what happened, in red
		why.depth = 3.0
		why.shadow = Color(0, 0, 0, 0)
		why.refresh()
		body.add_child(why)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override(&"panel", Card.well())
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 10)
	well.add_child(lines)
	var big := HBoxContainer.new()  # the Red Bobs: the run's big number
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	big.add_theme_constant_override(&"separation", 16)
	var bob := TextureRect.new()
	bob.texture = BobView.texture()
	bob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bob.custom_minimum_size = Vector2(78, 78)
	bob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	big.add_child(bob)
	# out of the Red Bobs the stars count (the ones he can reach), so the count and the stars agree
	var total := " / %d" % mini(World.BOBS_REACHABLE, world.level.bobs_total)
	var bobs := Ui.display_text("0" + total, 68, Ui.WHITE, Card.INK, Color("ffd36b"))
	bobs.depth = 6.0
	bobs.refresh()
	bobs.custom_minimum_size.x = maxf(bobs.custom_minimum_size.x, 300.0)
	big.add_child(bobs)
	lines.add_child(big)
	var bar: WayBar = null
	if not won:
		bar = WayBar.new(world.progress())
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var way := HBoxContainer.new()  # what the bar measures, said beside it (not a second score)
		way.alignment = BoxContainer.ALIGNMENT_CENTER
		way.add_theme_constant_override(&"separation", 12)
		way.add_child(Ui.label(TranslationServer.translate("WAY_HOME"), 24, Color("6a3010"), Ui.font_title))
		way.add_child(bar)
		lines.add_child(way)
	body.add_child(well)
	var slot := Control.new()  # a new best's stamp lands here, in its own room: it covers nothing
	slot.custom_minimum_size = Vector2(0, 64)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.visible = news.get("best_bobs", false)
	body.add_child(slot)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 22)
	var home_button := Ui.icon_button("house-fill", Ui.Tone.SUNSET, 96.0, 30.0)
	home_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	home_button.pressed.connect(home)
	buttons.add_child(home_button)
	var go := Ui.candy_button(TranslationServer.translate("PLAY_AGAIN"), "arrow-counter-clockwise-bold", Ui.Tone.GREEN, 100, 42)
	go.custom_minimum_size.x = 340
	go.pressed.connect(again)
	go.shine()
	buttons.add_child(go)
	var share_button := Ui.icon_button("share-network-fill", Ui.Tone.GOLD, 96.0, 30.0)
	share_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	share_button.pressed.connect(share)
	buttons.add_child(share_button)
	var foot := MarginContainer.new()  # the same air under the buttons as above the stats
	foot.add_theme_constant_override(&"margin_top", 6)
	foot.add_child(buttons)
	body.add_child(foot)
	var title := TranslationServer.translate("HOME_REACHED" if won else "GAME_OVER")
	var panel: GamePanel
	if won:  # warm and radiant
		panel = GamePanel.open(game, title, Ui.Tone.GOLD, body, _hero(true), Color(0.22, 0.08, 0.02, 0.28),
				Color(1, 0.78, 0.4, 0.75), false, hide)
	else:  # cold and dim
		panel = GamePanel.open(game, title, Ui.Tone.CRIMSON, body, _hero(false), Color(0.03, 0.04, 0.12, 0.42),
				Color(0.5, 0.6, 1.0, 0.25), false, hide)
	_reveal(game, panel, world, stars, bobs, total, bar, slot, news.get("best_bobs", false), buttons, go)
	return panel


## The three stars, placed by hand: the middle one bigger and higher, over a turning sunburst.
static func _stars_stage(stars: Array[Control]) -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 168)
	var burst := Rays.new(860, Color(1, 0.86, 0.48, 0.62), 18)  # the one sunburst of the win
	burst.material = Fx.additive()
	stage.add_child(burst)
	var glow := TextureRect.new()
	glow.texture = Fx.glow_texture()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.material = Fx.additive()
	glow.modulate = Color(1, 0.8, 0.4, 0.7)
	glow.size = Vector2(560, 280)
	stage.add_child(glow)
	if Prefs.motion():
		var spin := burst.create_tween().set_loops()
		spin.tween_property(burst, "rotation", TAU, 30.0).from(0.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 4)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(row)
	for i in 3:
		var side := 170.0 if i == 1 else 148.0
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(side, side)
		slot.size_flags_vertical = Control.SIZE_SHRINK_END if i != 1 else Control.SIZE_SHRINK_BEGIN
		slot.add_child(StarBadge.new(side, false))
		var star := StarBadge.new(side, true)
		star.visible = false
		star.set_meta(&"tilt", [-0.24, 0.0, 0.24][i])  # the outer two lean out
		slot.add_child(star)
		var socket := slot.get_child(0) as Control
		socket.rotation = star.get_meta(&"tilt")
		row.add_child(slot)
		stars.append(star)
	stage.resized.connect(func() -> void:
		burst.position = stage.size / 2 - burst.size / 2
		glow.position = stage.size / 2 - glow.size / 2)
	return stage


## Panoramic beside the card: arms up in the gold light after a win, down on one knee after a loss
## (hero.gdshader, colder and darker then). The art track's renders when they are there.
static func _hero(won: bool) -> TextureRect:
	var art := TextureRect.new()
	var path := HERO_WIN if won else HERO_LOSE
	var rendered := ResourceLoader.exists(path)  # the art track's renders carry their own light
	art.texture = load(path) if rendered else (HERO_STAND if won else HERO_DOWN)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	if won:
		art.set_meta(&"tall", 1.06)  # arms up: he stands a head above the card
		art.set_meta(&"overlap", 0.0)  # beside it: his raised hand clear of the ribbon
	else:
		art.set_meta(&"tall", 0.62)  # sitting dazed on the ground, upright, against the card's edge
		art.set_meta(&"overlap", -0.05)  # beside the card with a little air: his boot clear of the frame
	if not rendered:  # the crops from the user's studio renders: lit by the screen here
		var lit := ShaderMaterial.new()
		lit.shader = preload("res://src/ui/hero.gdshader")
		if not won:
			art.set_meta(&"tall", 0.86)
			lit.set_shader_parameter(&"grade", Vector3(0.78, 0.82, 0.98))
			lit.set_shader_parameter(&"rim_colour", Color(0.7, 0.8, 1.0))
			lit.set_shader_parameter(&"sky_colour", Color(0.5, 0.5, 0.9))
			lit.set_shader_parameter(&"shade", 0.55)
		art.material = lit
	return art


## The choreography, one beat after the other (each step is skipped if the panel is gone).
static func _reveal(game: Control, panel: GamePanel, world: World, stars: Array[Control], bobs: DisplayText,
		total: String, bar: WayBar, slot: Control, best: bool, _buttons: Control, go: JuicyButton) -> void:
	var tree := game.get_tree()
	var won := world.state == World.State.WON
	if not won:
		Audio.stinger(&"game_over")
	else:
		Audio.set_mood(&"results")
	go.idle(0.05)
	var t := 0.35  # the panel has landed
	if won:
		for i in world.stars():
			_slam_star(tree, stars[i], i, t + i * STAR_STEP, panel)
		t += maxi(world.stars(), 1) * STAR_STEP + 0.05
		var party := panel.create_tween()  # owned by the panel: it never outlives it
		party.tween_interval(t - 0.1)
		party.tween_callback(func() -> void:
			var back := Node2D.new()  # behind the card: it flies out from under its top
			back.scale = Vector2.ONE * 0.5
			panel.add_child(back)
			panel.move_child(back, panel.card.get_parent().get_index())
			Fx.confetti_burst(back, stars[1].get_global_rect().get_center() * 2.0)
			var rain := Node2D.new()  # coins and confetti around the card (over the words they read as stains)
			panel.add_child(rain)
			panel.move_child(rain, panel.card.get_parent().get_index())
			Fx.coin_shower(rain, panel.size.x, panel.size.y)
			var view := panel.size * 2.0  # New (audio): fireworks in the sky behind him and the card
			Fx.fireworks(back, Vector2(view.x * 0.04, view.y * 1.02), 1.0)
			Fx.fireworks(back, Vector2(view.x * 0.96, view.y * 1.02), -1.0))
	_count_up(tree, bobs, world.bobs, total, t, panel)
	t += COUNT_TIME + 0.1
	if bar:
		bar.fill_from(t - 0.1)
		t += 0.6
	if best:
		_stamp(tree, panel, slot, t + 0.1)


## A star slams into its socket: from big and turned to a little small, then its size, a burst of
## light and sparks as it lands, a note a third higher each; the third shakes the card. Then it
## catches the light now and then.
static func _slam_star(tree: SceneTree, star: Control, i: int, delay: float, panel: GamePanel) -> void:
	await tree.create_timer(delay).timeout
	if not is_instance_valid(panel):
		return
	star.visible = true
	star.scale = Vector2.ONE * 1.8
	star.modulate.a = 0.0
	star.rotation = -0.5
	var t := star.create_tween()
	t.set_parallel(true)
	t.tween_property(star, "modulate:a", 1.0, 0.06)
	var tilt: float = star.get_meta(&"tilt", 0.0)
	t.tween_property(star, "rotation", tilt, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(star, "scale", Vector2.ONE * 0.9, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_property(star, "scale", Vector2.ONE * 1.12, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(star, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tree.create_timer(0.14).timeout
	if not is_instance_valid(panel):
		return
	Audio.play_tuned(&"star", i)  # A, C#, E: the chord of the key, a step per star
	Haptics.star()
	var fx := Node2D.new()
	fx.scale = Vector2.ONE * 0.5
	panel.add_child(fx)
	var at := star.get_global_rect().get_center() * 2.0
	Fx.counter_pop(fx, at)
	Fx.badge_burst(fx, at)
	if i == 2:
		_shake(panel.card, 3.0)
	var flare := TextureRect.new()  # a glow that blooms behind it as it lands, then breathes
	flare.texture = Fx.glow_texture()
	flare.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flare.material = Fx.additive()
	flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flare.size = star.size * 2.4
	flare.position = star.size / 2 - flare.size / 2
	flare.pivot_offset = flare.size / 2
	flare.modulate = Color(1, 0.85, 0.4, 0.9)
	flare.show_behind_parent = true
	star.add_child(flare)
	var bloom := flare.create_tween()
	bloom.tween_property(flare, "modulate:a", 0.35, 0.5).from(0.9)
	if Prefs.motion():
		bloom.tween_property(flare, "modulate:a", 0.55, 1.0).set_trans(Tween.TRANS_SINE)
		bloom.tween_property(flare, "modulate:a", 0.35, 1.0).set_trans(Tween.TRANS_SINE)
		bloom.set_loops()
		var shine := star.create_tween().set_loops()
		shine.tween_interval(1.4 + i * 0.35)
		shine.tween_property(star, "scale", Vector2.ONE * 1.08, 0.12).set_trans(Tween.TRANS_SINE)
		shine.tween_property(star, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)


## The Red Bobs roll up from 0 to `target` in COUNT_TIME, ticking, then punch.
static func _count_up(tree: SceneTree, value: DisplayText, target: int, suffix: String, delay: float,
		panel: Control) -> void:
	await tree.create_timer(delay).timeout
	var steps := mini(target, 20)
	for k in range(1, steps + 1):
		if not is_instance_valid(panel):
			return
		value.text = str(roundi(float(target) * k / steps)) + suffix
		if k % 2 == 0:
			Audio.play_sfx(&"tick", 1.0 + 0.3 * k / steps, 0.6)
		await tree.create_timer(COUNT_TIME / maxi(steps, 1)).timeout
	if not is_instance_valid(panel):
		return
	value.text = str(target) + suffix
	value.pivot_offset = value.size / 2
	var bump := value.create_tween()
	bump.tween_property(value, "scale", Vector2.ONE * 1.22, 0.06)
	bump.tween_property(value, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## NEW BEST!: a red stamp with a crown slams into its row under the count, a little tilted, the card
## shakes, light and sparkles burst under it.
static func _stamp(tree: SceneTree, panel: GamePanel, slot: Control, delay: float) -> void:
	await tree.create_timer(delay).timeout
	if not is_instance_valid(panel):
		return
	var chip := Ui.chip(TranslationServer.translate("NEW_BEST"), Ui.Tone.CRIMSON, 36, "crown-fill")
	var stamp := Control.new()
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.size = chip.get_combined_minimum_size()
	stamp.add_child(chip)
	slot.add_child(stamp)  # in its own row of the card, between the count and the buttons
	stamp.position = (slot.size - stamp.size) / 2
	stamp.pivot_offset = stamp.size / 2
	stamp.rotation = -0.06
	stamp.scale = Vector2.ONE * 1.6
	stamp.modulate.a = 0.0
	var t := stamp.create_tween().set_parallel(true)
	t.tween_property(stamp, "modulate:a", 1.0, 0.06)
	t.tween_property(stamp, "scale", Vector2.ONE * 0.94, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_property(stamp, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tree.create_timer(0.14).timeout
	if not is_instance_valid(panel):
		return
	_shake(panel.card, 4.0)
	var fx := Node2D.new()
	fx.scale = Vector2.ONE * 0.5
	panel.add_child(fx)
	Fx.badge_burst(fx, stamp.get_global_rect().get_center() * 2.0)
	Audio.play_sfx(&"new_best")
	Haptics.success()


## A short shake of `c` (a few px, a quarter of a second).
static func _shake(c: Control, px: float) -> void:
	if not Prefs.motion():
		return
	var at := c.position
	var t := c.create_tween()
	for k in 5:
		t.tween_property(c, "position", at + Vector2(px * (1.0 if k % 2 == 0 else -1.0), px * 0.4 * (1.0 if k % 3 == 0 else -1.0)) * (1.0 - k * 0.18), 0.04)
	t.tween_property(c, "position", at, 0.05)


## The way home on a lost run's card: a sunken groove, a thick gold fill to where he got (it fills
## up when the count is done), the percentage on it, and at its end the goal: the house on a gold
## disc, drawn as part of the bar (not a button).
class WayBar extends Control:
	var progress := 0.0
	var _shown := 0.0
	var _label: DisplayText

	func _init(p: float) -> void:
		progress = clampf(p, 0.0, 1.0)
		custom_minimum_size = Vector2(290, 54)
		var french := TranslationServer.get_locale().begins_with("fr")  # "21 %" in French, "21%" in English
		_label = Ui.display_text(("%d %%" if french else "%d%%") % roundi(progress * 100.0), 30, Ui.WHITE, Card.INK)
		_label.depth = 2.0
		_label.shadow = Color(0, 0, 0, 0)
		_label.refresh()
		add_child(_label)
		resized.connect(func() -> void:
			_label.size = Vector2(size.x - 50.0, size.y)
			_label.position = Vector2.ZERO)

	## The gold fills up to where he got, after `delay` seconds.
	func fill_from(delay: float) -> void:
		var t := create_tween()
		t.tween_interval(maxf(delay, 0.0))
		t.tween_method(func(v: float) -> void:
			_shown = v
			queue_redraw(), 0.0, progress, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var ci := get_canvas_item()
		var r := Rect2(Vector2(0, 10), Vector2(size.x - 40.0, size.y - 20))
		var rad := r.size.y / 2
		GlossStyle.fill_rounded(ci, r.grow(3.0), rad + 3.0, Card.INK, Card.INK)
		GlossStyle.fill_rounded(ci, r, rad, Color("6a3a1c"), Color("8a5a30"))
		var w := maxf(r.size.x * _shown, r.size.y)
		var f := Rect2(r.position, Vector2(w, r.size.y))
		GlossStyle.fill_rounded(ci, f, rad, Color("ffd34a"), Color("e8860e"))
		GlossStyle.fill_rounded(ci, Rect2(f.position + Vector2(6, 3), Vector2(maxf(w - 12, 0), 5)), 2.5,
				Color(1, 1, 0.9, 0.7), Color(1, 1, 0.9, 0.4))
		# milestones every quarter: gold studs once passed, pale ones still ahead
		for q in range(1, 4):
			var m := Vector2(r.position.x + r.size.x * q / 4.0, r.get_center().y)
			var passed := q / 4.0 <= _shown
			draw_circle(m, 7.5, Card.INK, true, -1, true)
			draw_circle(m, 5.5, Color("fff0b0") if passed else Color("c8a27a"), true, -1, true)
			draw_circle(m - Vector2(1.5, 1.5), 2.0, Color(1, 1, 1, 0.9 if passed else 0.4), true, -1, true)
		# the goal: the house on a gold disc, part of the bar
		var hc := Vector2(size.x - 24.0, size.y / 2)
		draw_circle(hc, 25.0, Card.INK, true, -1, true)
		draw_circle(hc, 22.0, Color("e08a10"), true, -1, true)
		draw_circle(hc + Vector2(0, -2), 19.5, Color("ffc93c"), true, -1, true)
		var house := Ui.icon_texture("house-fill")
		draw_texture_rect(house, Rect2(hc - Vector2(13, 14), Vector2(26, 26)), false, Color("6a2408"))

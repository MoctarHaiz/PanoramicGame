class_name ResultsPanel
extends RefCounted
## The end of a run, over the game (GamePanel).
## - Home: a gold ribbon, three big glossy stars landing in carved sockets over a turning sunburst,
##   the Red Bobs as the big number, the bandits knocked out and the lives kept beside it, confetti
##   bursting from both lower corners and from behind the stars; Panoramic stands at the left,
##   full length in a pool of gold light.
## - A lost run: a crimson GAME OVER ribbon, what happened under it, the Red Bobs, the bandits and
##   how close home was (a bar to the house: "so close"); Panoramic down on one knee, in a cold
##   dim light.
## Then a NEW BEST chip if there is one, and PLAY AGAIN big between Home and Share.

const HERO_STAND := preload("res://assets/art/ui/hero_stand.png")
const HERO_DOWN := preload("res://assets/art/ui/hero_down.png")
const INK := Color("5a2408")  ## words on the cream card


## Opens the results over `game` (the game screen). `news`: what Save.record_run found new.
static func open(game: Control, world: World, news: Dictionary, home: Callable, again: Callable,
		share: Callable) -> GamePanel:
	var won := world.state == World.State.WON
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 12)
	var stars: Array[Control] = []
	var counters: Array = []
	if won:
		body.add_child(_stars_stage(stars))
	else:
		var why := Ui.label(TranslationServer.translate("FELL" if world.death_reason == &"fall" else "CAUGHT"), 30,
				Color("8a1a0a"), Ui.font_title)
		body.add_child(why)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override(&"panel", Card.well())
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 8)
	well.add_child(lines)
	var big := HBoxContainer.new()  # the Red Bobs: the run's big number
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	big.add_theme_constant_override(&"separation", 14)
	var bob := TextureRect.new()
	bob.texture = BobView.texture()
	bob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bob.custom_minimum_size = Vector2(72, 72)
	bob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	big.add_child(bob)
	var total := " / %d" % world.level.bobs_total
	var bobs := Ui.display_text("0" + total, 62, Ui.WHITE, Card.INK, Color("ffd36b"))
	bobs.depth = 5.0
	bobs.refresh()
	bobs.custom_minimum_size.x = maxf(bobs.custom_minimum_size.x, 270.0)
	big.add_child(bobs)
	lines.add_child(big)
	counters.append([bobs, world.bobs, total])
	var small := HBoxContainer.new()
	small.alignment = BoxContainer.ALIGNMENT_CENTER
	small.add_theme_constant_override(&"separation", 40)
	var ko := _stat(BanditFace.new(58.0), "×0")
	small.add_child(ko[0])
	counters.append([ko[1], world.knocked_out, "", "×"])
	if won:
		small.add_child(_lives(world.lives))
	else:
		small.add_child(_way_home(world.progress()))
	lines.add_child(small)
	body.add_child(well)
	var best := Control.new()  # the NEW BEST chip's place (it pops in at the end)
	best.custom_minimum_size = Vector2(0, 54)
	body.add_child(best)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 20)
	var home_button := Ui.icon_button("house-fill", Ui.Tone.SUNSET, 92.0, 30.0)
	home_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	home_button.pressed.connect(home)
	buttons.add_child(home_button)
	var go := Ui.candy_button(TranslationServer.translate("PLAY_AGAIN"), "arrow-counter-clockwise-bold", Ui.Tone.GREEN, 96, 40)
	go.custom_minimum_size.x = 330
	go.pressed.connect(again)
	go.shine()
	buttons.add_child(go)
	var share_button := Ui.icon_button("share-network-fill", Ui.Tone.BLUE, 92.0, 30.0)
	share_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	share_button.pressed.connect(share)
	buttons.add_child(share_button)
	body.add_child(buttons)
	var title := TranslationServer.translate("HOME_REACHED" if won else "GAME_OVER")
	var panel: GamePanel
	if won:  # warm and radiant
		panel = GamePanel.open(game, title, Ui.Tone.GOLD, body, _hero(true), Color(0.3, 0.12, 0.04, 0.42),
				Color(1, 0.78, 0.4, 0.7), true)
	else:  # cold and dim
		panel = GamePanel.open(game, title, Ui.Tone.CRIMSON, body, _hero(false), Color(0.04, 0.05, 0.14, 0.64),
				Color(0.5, 0.6, 1.0, 0.25))
	_reveal(game, panel, world, stars, counters, best if news.get("best_bobs", false) else null, buttons, go)
	return panel


## The three stars, placed by hand: the middle one bigger and higher, over a turning sunburst.
static func _stars_stage(stars: Array[Control]) -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 150)
	var burst := Rays.new(640, Color(1, 0.85, 0.45, 0.42), 18)
	burst.material = Fx.additive()
	stage.add_child(burst)
	var glow := TextureRect.new()
	glow.texture = Fx.glow_texture()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.material = Fx.additive()
	glow.modulate = Color(1, 0.8, 0.4, 0.6)
	glow.size = Vector2(520, 260)
	stage.add_child(glow)
	if Prefs.motion():
		var spin := burst.create_tween().set_loops()
		spin.tween_property(burst, "rotation", TAU, 30.0).from(0.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 2)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(row)
	for i in 3:
		var side := 148.0 if i == 1 else 116.0
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(side, side)
		slot.size_flags_vertical = Control.SIZE_SHRINK_END if i != 1 else Control.SIZE_SHRINK_BEGIN
		slot.add_child(StarBadge.new(side, false))
		var star := StarBadge.new(side, true)
		star.visible = false
		slot.add_child(star)
		row.add_child(slot)
		stars.append(star)
	stage.resized.connect(func() -> void:
		burst.position = stage.size / 2 - burst.size / 2
		glow.position = stage.size / 2 - glow.size / 2)
	return stage


## An icon and a count beside it. Returns [the row, the count's DisplayText].
static func _stat(icon: Control, text: String) -> Array:
	var item := HBoxContainer.new()
	item.add_theme_constant_override(&"separation", 8)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(icon)
	var value := Ui.display_text(text, 44, Ui.GOLD, Card.INK, Color("ffab24"))
	value.align = HORIZONTAL_ALIGNMENT_LEFT
	value.depth = 3.0
	value.shadow = Color(0, 0, 0, 0)
	value.refresh()
	value.custom_minimum_size.x = maxf(value.custom_minimum_size.x, 96.0)
	item.add_child(value)
	return [item, value]


## The lives he kept: full hearts, lost ones as empty sockets.
static func _lives(lives: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 2)
	for i in World.LIVES:
		if i < lives:
			row.add_child(Ui.bold_icon("heart-fill", 44, Color("ff3d24"), Card.INK))
		else:
			row.add_child(Ui.bold_icon("heart-fill", 44, Color(0.45, 0.22, 0.1, 0.45), Color(Card.INK, 0.5)))
	return row


## How close home was: a bar to the house, filled to `progress`, the percentage on it.
static func _way_home(progress: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	var bar := WayBar.new(progress)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var house := Ui.bold_icon("house-fill", 40, Ui.WHITE, Card.INK)
	house.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(house)
	return row


## Panoramic beside the card: standing in the gold light after a win, down on one knee after a
## loss (hero.gdshader, colder and darker then).
static func _hero(won: bool) -> TextureRect:
	var art := TextureRect.new()
	art.texture = HERO_STAND if won else HERO_DOWN
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	var lit := ShaderMaterial.new()
	lit.shader = preload("res://src/ui/hero.gdshader")
	if not won:
		art.set_meta(&"tall", 0.72)  # on one knee: about three quarters of his standing height
		art.set_meta(&"overlap", 0.04)  # his boots reach right: clear of the Home button
		lit.set_shader_parameter(&"grade", Vector3(0.82, 0.84, 0.98))
		lit.set_shader_parameter(&"rim_colour", Color(0.7, 0.78, 1.0))
		lit.set_shader_parameter(&"sky_colour", Color(0.55, 0.5, 0.9))
		lit.set_shader_parameter(&"shade", 0.5)
	art.material = lit
	return art


## The choreography: the stars land one after the other while the counts tick up; the buttons are
## there from the start of it; confetti after a win; a new best ends it (each step is skipped if
## the panel is gone).
static func _reveal(game: Control, panel: GamePanel, world: World, stars: Array[Control], counters: Array,
		best: Control, buttons: Control, go: JuicyButton) -> void:
	var tree := game.get_tree()
	if world.state != World.State.WON:
		Audio.stinger(&"game_over")
	else:
		Audio.set_mood(&"results")
	buttons.modulate.a = 0.0
	buttons.create_tween().tween_property(buttons, "modulate:a", 1.0, 0.25).set_delay(0.45)
	go.idle(0.05)
	for i in world.stars():
		_drop_star(tree, stars[i], i, 0.35 + i * 0.22, panel)
	for i in counters.size():
		var c: Array = counters[i]
		_count_up(tree, c[0], c[1], c[2], c[3] if c.size() > 3 else "", 0.35 + i * 0.12, i == 0, panel)
	if world.state == World.State.WON:
		tree.create_timer(0.45 + world.stars() * 0.22).timeout.connect(func() -> void:
			if not is_instance_valid(panel):
				return
			var back := Node2D.new()  # behind the card: it flies out from under its top
			back.scale = Vector2.ONE * 0.5
			panel.add_child(back)
			panel.move_child(back, 2)
			Fx.confetti_burst(back, stars[1].get_global_rect().get_center() * 2.0)
			var rain := Node2D.new()  # behind the card too: its words stay clear
			panel.add_child(rain)
			panel.move_child(rain, 1)
			Fx.coin_shower(rain, panel.size.x, panel.size.y)
			var front := Node2D.new()  # and from both lower corners, over everything
			front.scale = Vector2.ONE * 0.5
			panel.add_child(front)
			var view := panel.size * 2.0
			Fx.confetti_burst(front, Vector2(view.x * 0.04, view.y * 1.02))
			Fx.confetti_burst(front, Vector2(view.x * 0.96, view.y * 1.02)))
	if not best:
		return
	await tree.create_timer(1.2).timeout
	if not is_instance_valid(panel):
		return
	var chip := Ui.chip(TranslationServer.translate("NEW_BEST"), Ui.Tone.CRIMSON, 30, "crown-fill")
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	best.add_child(holder)
	var pop := Control.new()
	pop.custom_minimum_size = chip.get_combined_minimum_size()
	holder.add_child(pop)
	pop.add_child(chip)
	pop.pivot_offset = pop.custom_minimum_size / 2
	pop.scale = Vector2.ZERO
	pop.rotation = -0.15
	var t := pop.create_tween().set_parallel(true)
	t.tween_property(pop, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(pop, "rotation", -0.04, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_sfx(&"new_best")
	Haptics.success()


## A star thumps into its socket: from big and turned to its place, a chime a third higher each,
## a flash and sparkles as it lands; then it catches the light now and then.
static func _drop_star(tree: SceneTree, star: Control, i: int, delay: float, panel: Control) -> void:
	await tree.create_timer(delay).timeout
	if not is_instance_valid(panel):
		return
	star.visible = true
	star.scale = Vector2.ONE * 2.6
	star.modulate.a = 0.0
	star.rotation = -0.6
	var t := star.create_tween().set_parallel(true)
	t.tween_property(star, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(star, "modulate:a", 1.0, 0.1)
	t.tween_property(star, "rotation", 0.0, 0.28)
	await tree.create_timer(0.17).timeout
	if not is_instance_valid(panel):
		return
	Audio.play_tuned(&"star", i)  # A, C#, E: the chord of the key, a step per star
	Haptics.star()
	var fx := Node2D.new()
	fx.scale = Vector2.ONE * 0.5
	panel.add_child(fx)
	Fx.counter_pop(fx, star.get_global_rect().get_center() * 2.0)
	if Prefs.motion():
		var shine := star.create_tween().set_loops()
		shine.tween_interval(1.4 + i * 0.35)
		shine.tween_property(star, "scale", Vector2.ONE * 1.08, 0.12).set_trans(Tween.TRANS_SINE)
		shine.tween_property(star, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)


## A number ticks up from 0 to `target` in half a second, then bumps.
static func _count_up(tree: SceneTree, value: DisplayText, target: int, suffix: String, prefix: String,
		delay: float, ticks: bool, panel: Control) -> void:
	await tree.create_timer(delay).timeout
	var steps := mini(target, 16)
	for k in range(1, steps + 1):
		if not is_instance_valid(panel):
			return
		value.text = prefix + str(roundi(float(target) * k / steps)) + suffix
		if ticks and k % 2 == 0:
			Audio.play_sfx(&"tick", 1.0 + 0.3 * k / steps, 0.6)
		await tree.create_timer(0.5 / steps).timeout
	if not is_instance_valid(panel):
		return
	value.text = prefix + str(target) + suffix
	value.pivot_offset = value.size / 2
	var bump := value.create_tween()
	bump.tween_property(value, "scale", Vector2.ONE * 1.2, 0.06)
	bump.tween_property(value, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The way home on a lost run's card: a sunken groove, a thick gold fill to where he got, the
## percentage on it.
class WayBar extends Control:
	var progress := 0.0
	var _label: DisplayText

	func _init(p: float) -> void:
		progress = clampf(p, 0.0, 1.0)
		custom_minimum_size = Vector2(230, 44)
		var french := TranslationServer.get_locale().begins_with("fr")  # "21 %" in French, "21%" in English
		_label = Ui.display_text(("%d\u00a0%%" if french else "%d%%") % roundi(progress * 100.0), 30, Ui.WHITE, Card.INK)
		_label.depth = 2.0
		_label.shadow = Color(0, 0, 0, 0)
		_label.refresh()
		add_child(_label)
		resized.connect(func() -> void:
			_label.size = size
			_label.position = Vector2.ZERO)

	func _draw() -> void:
		var r := Rect2(Vector2(0, 6), Vector2(size.x, size.y - 12))
		var rad := r.size.y / 2
		GlossStyle.fill_rounded(get_canvas_item(), r.grow(3.0), rad + 3.0, Card.INK, Card.INK)
		GlossStyle.fill_rounded(get_canvas_item(), r, rad, Color("6a3a1c"), Color("8a5a30"))
		var w := maxf(r.size.x * progress, r.size.y)
		var f := Rect2(r.position, Vector2(w, r.size.y))
		GlossStyle.fill_rounded(get_canvas_item(), f, rad, Color("ffd34a"), Color("e8860e"))
		GlossStyle.fill_rounded(get_canvas_item(), Rect2(f.position + Vector2(6, 3), Vector2(maxf(w - 12, 0), 5)), 2.5,
				Color(1, 1, 0.9, 0.7), Color(1, 1, 0.9, 0.4))


## A bandit knocked out, as a badge (the count of bandits knocked out): his violet hood with its
## pointed ears, the gold mask band across his eyes, crosses for eyes, an ink outline.
class BanditFace extends Control:
	const HOOD := Color("6a46a0")
	const HOOD_LIGHT := Color("9474c8")
	const HOOD_DARK := Color("3e2466")

	func _init(side: float) -> void:
		custom_minimum_size = Vector2(side, side)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size / 2 + Vector2(0, s * 0.06)
		var r := s * 0.36
		var line := maxf(s * 0.05, 2.0)
		var ears := [PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.2), c + Vector2(-r * 0.75, -r * 1.35), c + Vector2(-r * 0.15, -r * 0.8)]),
				PackedVector2Array([c + Vector2(r * 0.95, -r * 0.2), c + Vector2(r * 0.75, -r * 1.35), c + Vector2(r * 0.15, -r * 0.8)])]
		for e: PackedVector2Array in ears:
			for poly in Geometry2D.offset_polygon(e, line, Geometry2D.JOIN_ROUND):
				draw_colored_polygon(poly, Card.INK)
		draw_circle(c + Vector2(0, line * 0.6), r + line, Card.INK, true, -1, true)
		for e: PackedVector2Array in ears:
			draw_colored_polygon(e, HOOD)
		draw_circle(c, r, HOOD_DARK, true, -1, true)
		draw_circle(c - Vector2(r * 0.06, r * 0.08), r * 0.92, HOOD, true, -1, true)
		draw_circle(c - Vector2(r * 0.35, r * 0.4), r * 0.3, Color(HOOD_LIGHT, 0.8), true, -1, true)
		# the mask band and the dazed eyes
		var band := Rect2(c + Vector2(-r * 0.98, -r * 0.28), Vector2(r * 1.96, r * 0.5))
		GlossStyle.fill_rounded(get_canvas_item(), band.grow(line * 0.6), r * 0.2, Card.INK, Card.INK)
		GlossStyle.fill_rounded(get_canvas_item(), band, r * 0.18, Color("ffd060"), Color("d88a14"))
		for side: float in [-1.0, 1.0]:
			var e := c + Vector2(side * r * 0.42, -r * 0.03)
			var k := r * 0.13
			draw_line(e - Vector2(k, k), e + Vector2(k, k), Card.INK, line * 0.9, true)
			draw_line(e + Vector2(-k, k), e + Vector2(k, -k), Card.INK, line * 0.9, true)

class_name ResultsPanel
extends RefCounted
## The end of a run, over the game (GamePanel), told in order so the eye can follow it:
## - Home: a red ribbon on the gilded card; the three stars (the middle one bigger, raised) slam into
##   their sockets one
##   after the other, each with a burst and its note (the third shakes the card), coins and confetti
##   rain in front of everything; then the Red Bobs roll up with ticks in a groove cut into the
##   parchment; a NEW BEST burst badge slams in last beside the count (its place kept in the count's
##   row from the start: nothing moves, nothing is covered, no empty band). Panoramic stands at the
##   left with his arms up, in a pool of gold light, a big burst of rays turning behind the card.
## - A lost run, in another mood: the world behind drained grey, the card in smoked wood, old bronze
##   and dusty hide, a red GAME OVER ribbon and what happened under it; the Red Bobs roll up, then the
##   bar of the way home fills to where he got (the house at its end in a gold disc: the goal); the
##   buttons are there at once. Panoramic dazed on the ground in a cold, dim light.
## PLAY AGAIN (the big green one) between Home and Share, two gold ones (apart from the red ribbon
## and the brown wood: orange was too close to them, bone read as disabled, blue fought the green).

const HERO_WIN := "res://assets/art/hero/hero_win.png"  ## the art track's render (arms up), when there
const HERO_LOSE := "res://assets/art/hero/hero_defeat.png"  # the art track's defeat pose
const HERO_STAND := "res://assets/art/ui/hero_stand.png"  ## fallbacks, loaded only when used (a preload
const HERO_DOWN := "res://assets/art/ui/hero_down.png"  ## kept them in texture memory all the time)
const KO_HEAD := Vector2(0.57, 0.04)  ## (round 19) over the knock-out still's head (hero_defeat.png): its stars circle there
const STAR_STEP := 0.32  ## seconds between two stars
const COUNT_TIME := 0.7  ## seconds the Red Bobs take to roll up
const BADGE := 62.0  ## the NEW BEST badge's radius (its spikes)


## Opens the results over `game` (the game screen). `news`: what Save.record_run found new.
static func open(game: Control, world: World, news: Dictionary, home: Callable, again: Callable,
		share: Callable, hide: Array = []) -> GamePanel:
	var won := world.state == World.State.WON
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 8)
	var stars: Array[Control] = []
	if won:
		body.add_child(_stars_stage(stars))
	else:
		# what happened: cream display letters in a thick deep-red stroke with its depth, as the ribbon's
		# title (j15: red letters on the beige hide had a middling contrast)
		var why := Ui.display_text(TranslationServer.translate("FELL" if world.death_reason == &"fall" else "CAUGHT"),
				38, Color("fffaf0"), Color("6e1006"), Color("ffe0c0"))
		why.outline_width = 6.0
		why.depth = 3.0
		why.tracking = 2.0
		why.shadow = Color(0.2, 0.03, 0.0, 0.3)
		why.refresh()
		var air := MarginContainer.new()  # air round it (not edge to edge), room for a crown under it
		air.add_theme_constant_override(&"margin_bottom", 14)
		air.add_theme_constant_override(&"margin_left", 34)
		air.add_theme_constant_override(&"margin_right", 34)
		air.add_child(why)
		body.add_child(air)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override(&"panel", _dark_well(won))
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
	# the count: white to gold after a win, all gold on a loss's deep cool well
	var bobs := Ui.display_text("0" + total, 68, Ui.WHITE if won else Color("fff0a0"), Card.INK, Color("ffd36b") if won else Color("ffb21e"))
	bobs.depth = 6.0
	bobs.refresh()
	bobs.custom_minimum_size.x = maxf(bobs.custom_minimum_size.x, 300.0)
	big.add_child(bobs)
	var slot := Control.new()  # a new best's badge lands here, beside the count: its place is kept,
	# with air between it and the count, and as tall as it (it stays inside the groove)
	slot.custom_minimum_size = Vector2(BADGE * 2.0 + 44.0, BADGE * 2.0 + 6.0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.visible = news.get("best_bobs", false)
	big.add_child(slot)
	lines.add_child(big)
	var bar: WayBar = null
	if not won:
		bar = WayBar.new(world.progress())
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var way := HBoxContainer.new()  # what the bar measures, said beside it (not a second score)
		way.alignment = BoxContainer.ALIGNMENT_CENTER
		way.add_theme_constant_override(&"separation", 12)
		way.add_child(Ui.label(TranslationServer.translate("WAY_HOME"), 28, Color("fbe4c0"), Ui.font_title))
		way.add_child(bar)
		lines.add_child(way)
	body.add_child(well)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 34)  # air between them: the main button, two gold ones
	var home_button := Ui.icon_button("house-fill", Ui.Tone.GOLD, 92.0, 28.0)
	home_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	home_button.pressed.connect(home)
	buttons.add_child(home_button)
	var go := Ui.candy_button(TranslationServer.translate("PLAY_AGAIN"), "arrow-counter-clockwise-bold", Ui.Tone.GREEN,
			108 if won else 100, 44 if won else 42)
	go.custom_minimum_size.x = 360 if won else 340
	go.pressed.connect(again)
	if won:  # the reward screen's call: bigger, a warm light breathing behind it, its glints
		_glow_behind(go)
		go.shine(2.6, 2, 0.42)
	else:
		go.shine(3.2, 1, 0.3)  # one small glint
	buttons.add_child(go)
	var share_button := Ui.icon_button("share-network-fill", Ui.Tone.GOLD, 92.0, 28.0)
	share_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	share_button.pressed.connect(share)
	buttons.add_child(share_button)
	var foot := MarginContainer.new()  # air before the buttons: the result above reads as one group
	foot.add_theme_constant_override(&"margin_top", 22)
	foot.add_child(buttons)
	body.add_child(foot)
	var title := TranslationServer.translate("HOME_REACHED" if won else "GAME_OVER")
	var panel: GamePanel
	if won:  # warm and radiant: a red ribbon on the gold (gold on gold was lost)
		panel = GamePanel.open(game, title, Ui.Tone.CRIMSON, body, _hero(true), Color(0.2, 0.07, 0.02, 0.38),
				Color(1, 0.78, 0.4, 0.75), true, hide, &"win")
	else:  # drained and dim: a grey world, old bronze, a red ribbon, him on a dim warm patch of ground
		panel = GamePanel.open(game, title, Ui.Tone.CRIMSON, body, _hero(false), Color(0.06, 0.04, 0.06, 0.45),
				Color(1.0, 0.72, 0.45, 0.32), false, hide, &"loss")
	_reveal(game, panel, world, stars, bobs, total, bar, slot, news.get("best_bobs", false), buttons, go)
	return panel


## The groove under the run's count: cut into the parchment (InsetStyle: shade under its upper
## edge, the lit lip of the parchment under it), dark, so the cream numbers stand out on it: the kit's
## own leather (j15: a navy inset on parchment and wood read as a second UI kit), warm after a win,
## smoked and quieter after a loss: smooth gradients and a soft inner shadow.
static func _dark_well(won: bool) -> InsetStyle:
	var s := InsetStyle.new(22.0)
	s.top = Color("6a2e10") if won else Color("2a1810")  # a win's warmer (dark chocolate dulled the gold)
	s.bottom = Color("9c5420") if won else Color("5c3e2c")  # a loss's smoked leather
	s.outline = Card.INK
	s.content_margin_top = 12
	s.content_margin_bottom = 14
	return s


## A warm light breathing behind `b` (the win's Play again: something special about the call).
static func _glow_behind(b: Control) -> void:
	var halo := TextureRect.new()
	halo.texture = Fx.glow_texture()
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.material = Fx.additive()
	halo.modulate = Color(1, 0.82, 0.32, 0.55)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.show_behind_parent = true
	b.add_child(halo)
	b.resized.connect(func() -> void:
		halo.size = b.size * Vector2(1.35, 2.1)
		halo.position = b.size / 2 - halo.size / 2)
	if Prefs.motion():
		var t := halo.create_tween().set_loops()
		t.tween_property(halo, "modulate:a", 0.8, 0.9).set_trans(Tween.TRANS_SINE)
		t.tween_property(halo, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)


## The three stars, placed by hand: the middle one bigger and higher, over a turning sunburst.
static func _stars_stage(stars: Array[Control]) -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 214)
	# the one sunburst of the win: a deep warm orange, soft, so the gold stars stand out on it (a white
	# glow behind them washed them out)
	var burst := Rays.new(820, Color(1, 0.46, 0.06, 0.32), 18)
	stage.add_child(burst)
	if Prefs.motion():
		var spin := burst.create_tween().set_loops()
		spin.tween_property(burst, "rotation", TAU, 30.0).from(0.0)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 4)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(row)
	for i in 3:
		var side := 214.0 if i == 1 else 172.0  # the middle one the biggest, raised; the sides big too
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
		burst.position = stage.size / 2 - burst.size / 2)
	return stage


## Panoramic beside the card: his victory pose in the gold light after a win, knocked out (dizzy) after a loss
## (hero.gdshader, colder and darker then, for the fallback crops). The art track's stills when they are there.
static func _hero(won: bool) -> TextureRect:
	var art := TextureRect.new()
	var path := HERO_WIN if won else HERO_LOSE
	var rendered := ResourceLoader.exists(path)  # the art track's renders carry their own light
	art.texture = load(path) if rendered else load(HERO_STAND if won else HERO_DOWN)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	if rendered:  # the stills stand on their own contact shadow (hero_atlas_ai.py stills()): the panel adds none
		art.set_meta(&"ground", 0.935)  # (round 19) where his feet are, a share of the picture's height
	if won:
		# (round 19, the judges: "the hero small on the win screen") the victory still, a fist punched to the sky: he
		# stands taller than the card
		art.set_meta(&"tall", 1.16)
		art.set_meta(&"overlap", -0.06)  # beside it, with air: his raised fist clear of the ribbon
	else:
		var tex_size := art.texture.get_size()
		# whatever his shape he stays clear of the card's frame and band (a little air between)
		if tex_size.x > tex_size.y * 1.75:  # lying on the ground (very wide; round 17: the KO sit is 1.59)
			art.set_meta(&"tall", 0.5)
			art.set_meta(&"overlap", -0.03)
		elif tex_size.x > tex_size.y * 1.15:  # (round 19) knocked out, slumped where he sat down: big enough to read
			art.set_meta(&"tall", 0.82)
			art.set_meta(&"overlap", -0.03)
			if rendered:
				art.add_child(_dizzy(KO_HEAD))
		elif tex_size.x > tex_size.y * 0.8:  # seated (wide): on the ground beside the card, big enough
			art.set_meta(&"tall", 0.66)  # not to float small in the dark
			art.set_meta(&"overlap", -0.03)
		else:  # an upright one: beside the card with a little air, a boot clear of the frame
			art.set_meta(&"tall", 0.62)
			art.set_meta(&"overlap", -0.05)
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


## (round 19, the judges: "the game over reads lounging, sunbathing, not knocked out") Dazed stars circling over his
## head on the knock-out still (its spiral eyes): BanditView's stars, on a ring tilted in depth (those behind him
## fainter). `head`: where they circle, a share of the picture's size.
static func _dizzy(head: Vector2) -> Control:
	var stars := Control.new()
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var turn := [0.0]
	stars.draw.connect(func() -> void:
		var c := stars.size * head
		var r := stars.size.x * 0.085
		for i in 3:
			var a: float = turn[0] + i * TAU / 3.0
			var depth := sin(a)
			BanditView._star(stars, c + Vector2(cos(a) * r, depth * r * 0.28), r * (0.2 + 0.05 * depth), a * 0.6,
					Color(1, 0.86, 0.3, 0.8 + 0.2 * depth)))
	if Prefs.motion():  # (reduced motion: they stay still)
		var spin := stars.create_tween().set_loops()
		spin.tween_method(func(t: float) -> void:
			turn[0] = t
			stars.queue_redraw(), 0.0, TAU, 1.4)
	return stars


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
			var rain := Node2D.new()  # coins around the card (over the words they read as stains)
			panel.add_child(rain)
			panel.move_child(rain, panel.card.get_parent().get_index())
			Fx.coin_shower(rain, panel.size.x, panel.size.y)
			rain = Node2D.new()  # the cannons' near paper: in front of everything (it keeps off him and the card)
			rain.scale = Vector2.ONE * 0.5
			panel.add_child(rain)
			var view := panel.size * 2.0  # New (audio): fireworks in the sky behind him and the card
			Fx.fireworks(back, Vector2(view.x * 0.96, view.y * 1.02), -1.0)  # shells on the right only (left: him)
			Fx.card_bursts(back, panel.card)  # New (audio): crisp bursts left of him and right of the card
			_fire_cannons(panel, back, rain))
		party.tween_interval(1.7)  # a second volley while the first still flutters down
		party.tween_callback(func() -> void:
			var back := Node2D.new()
			back.scale = Vector2.ONE * 0.5
			panel.add_child(back)
			panel.move_child(back, panel.card.get_parent().get_index())
			var front := Node2D.new()
			front.scale = Vector2.ONE * 0.5
			panel.add_child(front)
			_fire_cannons(panel, back, front))
	_count_up(tree, bobs, world.bobs, total, t, panel)
	t += COUNT_TIME + 0.1
	if bar:
		bar.fill_from(t - 0.1)
		t += 0.6
	if best:
		_stamp(tree, panel, slot, t + 0.1, not won)


## The party cannons from the screen's bottom corners (Fx.cannons): far paper on `back` (behind him and
## the card), near paper on `front` (in front, effects units: both scaled 0.5).
static func _fire_cannons(panel: GamePanel, back: Node2D, front: Node2D) -> void:
	var to_local := back.get_global_transform().affine_inverse()
	var card: Rect2 = to_local * panel.card.get_global_rect()
	var hero := Rect2()
	if panel.art and panel.art.visible:
		hero = to_local * panel.art.get_global_rect()
	Fx.cannons(back, front, panel.size * 2.0, card, hero)


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
	flare.modulate = Color(1, 0.8, 0.34, 0.75)
	flare.show_behind_parent = true
	star.add_child(flare)
	var bloom := flare.create_tween()
	bloom.tween_property(flare, "modulate:a", 0.3, 0.5).from(0.75)
	if Prefs.motion():
		bloom.tween_property(flare, "modulate:a", 0.42, 1.0).set_trans(Tween.TRANS_SINE)
		bloom.tween_property(flare, "modulate:a", 0.3, 1.0).set_trans(Tween.TRANS_SINE)
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


## NEW BEST!: a burst badge (a gold starburst, a glossy red medallion, a crown: a seal, not a
## button) slams into its place beside the count, spinning in a little askew, the card shakes,
## light and sparkles burst under it. After a defeat (`calm`) the same news without the fanfare
## (j15: a shouting seal on a loss sent mixed emotions): a quiet gold medal settles into its place.
static func _stamp(tree: SceneTree, panel: GamePanel, slot: Control, delay: float, calm := false) -> void:
	await tree.create_timer(delay).timeout
	if not is_instance_valid(panel):
		return
	var stamp := BurstBadge.new(TranslationServer.translate("NEW_BEST"), BADGE, calm)
	slot.add_child(stamp)  # in the count's row, its place kept from the start
	stamp.position = (slot.size - stamp.size) / 2
	if calm:
		stamp.modulate.a = 0.0
		stamp.scale = Vector2.ONE * 0.85
		var q := stamp.create_tween().set_parallel(true)
		q.tween_property(stamp, "modulate:a", 1.0, 0.35)
		q.tween_property(stamp, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		Audio.play_sfx(&"tick", 1.4, 0.7)
		return
	stamp.scale = Vector2.ONE * 1.8
	stamp.modulate.a = 0.0
	var t := stamp.create_tween().set_parallel(true)
	t.tween_property(stamp, "modulate:a", 1.0, 0.06)
	t.tween_property(stamp, "rotation", -0.06, 0.28).from(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(stamp, "scale", Vector2.ONE * 0.92, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_property(stamp, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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


## The way home on a lost run's card: a sunken track (a pale rim, the way to go dark), the gold
## filling it from its left end to where he got (when the count is done), cut square at the tip,
## the percentage riding the tip, and at its end the goal: the house on a gold disc, drawn as part
## of the bar (not a button).
class WayBar extends Control:
	var progress := 0.0
	var _shown := 0.0
	var _label: DisplayText

	func _init(p: float) -> void:
		progress = clampf(p, 0.0, 1.0)
		custom_minimum_size = Vector2(340, 64)  # a thick bar
		var french := TranslationServer.get_locale().begins_with("fr")  # "21 %" in French, "21%" in English
		_label = Ui.display_text(("%d %%" if french else "%d%%") % roundi(progress * 100.0), 32, Ui.WHITE, Card.INK)
		_label.depth = 2.0
		_label.shadow = Color(0, 0, 0, 0)
		_label.refresh()
		add_child(_label)
		resized.connect(_place_label)

	## The percentage rides the fill: inside its tip when the gold is long enough, else just past it
	## (never floating over the empty groove's middle).
	func _place_label() -> void:
		var need := _label.get_combined_minimum_size()
		_label.size = need
		var r := Rect2(Vector2(0, 8), Vector2(size.x - 44.0, size.y - 16))
		var tip := r.position.x + r.size.x * _shown
		var x := tip - need.x - 8.0 if tip - r.position.x >= need.x + 16.0 else tip + 6.0
		_label.position = Vector2(x, (size.y - need.y) / 2)

	## The gold fills up to where he got, after `delay` seconds.
	func fill_from(delay: float) -> void:
		var t := create_tween()
		t.tween_interval(maxf(delay, 0.0))
		t.tween_method(func(v: float) -> void:
			_shown = v
			_place_label()
			queue_redraw(), 0.0, progress, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var ci := get_canvas_item()
		var r := Rect2(Vector2(0, 8), Vector2(size.x - 44.0, size.y - 16))
		var rad := r.size.y / 2
		# the track, plainly a track: a pale rim round it, an ink line, the way still to go much darker
		# than the well (a groove the colour of the well let the gold read as a pill sitting on it)
		GlossStyle.fill_rounded(ci, r.grow(6.0), rad + 6.0, Color(0.95, 0.84, 0.6, 0.7), Color(0.85, 0.7, 0.45, 0.7))
		GlossStyle.fill_rounded(ci, r.grow(3.0), rad + 3.0, Card.INK, Card.INK)
		GlossStyle.fill_rounded(ci, r, rad, Color("140a06"), Color("2a1810"))
		GlossStyle.fill_clipped(ci, r, rad, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)),
				Color(0, 0, 0, 0.5), Color(0, 0, 0, 0))
		# the way done: the track's own fill, from its left end, its full inner height, cut square at the
		# tip with a bright edge there, a light inside its top
		var tip := r.position.x + r.size.x * _shown
		GlossStyle.fill_bar(ci, r, rad, tip, Color("ffd84e"), Color("e07a0a"), 0.95, 0.0)
		if _shown > 0.0 and tip < r.end.x - rad * 0.5:
			draw_line(Vector2(tip - 1.0, r.position.y + 3.0), Vector2(tip - 1.0, r.end.y - 3.0), Color(1, 1, 0.85, 0.85), 2.0, true)
		# the goal: the house on a gold disc, part of the bar
		var hc := Vector2(size.x - 28.0, size.y / 2)
		draw_circle(hc, 29.0, Card.INK, true, -1, true)
		draw_circle(hc, 26.0, Color("e08a10"), true, -1, true)
		draw_circle(hc + Vector2(0, -2), 23.0, Color("ffc93c"), true, -1, true)
		var house := Ui.icon_texture("house-fill")
		draw_texture_rect(house, Rect2(hc - Vector2(15, 16), Vector2(30, 30)), false, Color("6a2408"))

class_name ResultsPanel
extends RefCounted
## The end of a run, over the game (GamePanel), told in order so the eye can follow it:
## - Home: a red ribbon on the gilded card; the three stars (the middle one bigger, raised) slam into
##   their places one after the other, each with a burst and its note (the third shakes the card); a
##   star not earned stays its dark gold-edged socket (StarBadge); the party (UI r23, the judges of j19: r22's
##   "sparse flat rectangles at the edges, plus one thin firework"): ONE dense burst of lit, tumbling confetti
##   thrown high from behind the stars over the whole scene; then the Red Bobs roll up with ticks in a
##   groove cut into the parchment; a NEW BEST burst badge slams in last beside the count (its place
##   kept in the count's row from the start: nothing moves, nothing is covered, no empty band).
##   Panoramic stands at the left with his fist up on a drawn patch of lit ground, his contact shade under
##   each boot, close to the card, the scene behind flooded with warm light, soft rays turning behind
##   him and the card.
## - A lost run, in another mood: the world behind cool and soft but still coloured and lit, a deep vignette,
##   the card in smoked wood, old bronze and dusty hide, a red GAME OVER ribbon and what happened under it in
##   one punchy word; the Red Bobs roll up, then the bar of the way home fills to where he got (the house at
##   its end in a gold disc: the goal); the buttons are there at once; a new best is the same seal as a
##   win's, quieter (BurstBadge.calm). Panoramic dazed on the floor in a cool light, sitting on it (the shade
##   of his hips, hand and heels, the chakram lying on it in its own shade).
## PLAY AGAIN (the big green one) between Home and Share, two gold ones (apart from the red ribbon
## and the brown wood: orange was too close to them, bone read as disabled, blue fought the green).

const HERO_WIN := "res://assets/art/hero/hero_win.png"  ## the art track's render (arms up), when there
const HERO_LOSE := "res://assets/art/hero/hero_defeat.png"  # the art track's defeat pose
const HERO_STAND := "res://assets/art/ui/hero_stand.png"  ## fallbacks, loaded only when used (a preload
const HERO_DOWN := "res://assets/art/ui/hero_down.png"  ## kept them in texture memory all the time)
const KO_HEAD := Vector2(0.57, 0.04)  ## (round 19) over the knock-out still's head (hero_defeat.png): its stars circle there
## (UI r23) where the knock-out still meets the floor (hero_defeat.png, shares of its size): x, y, width (a share of its
## width), darkness: his hips, the hand planted behind him, the heel on the ground, the boot he holds up (fainter)
const KO_CONTACTS: Array[Vector4] = [Vector4(0.655, 0.79, 0.26, 0.85), Vector4(0.905, 0.763, 0.14, 0.85),
		Vector4(0.33, 0.918, 0.11, 0.9), Vector4(0.11, 0.9, 0.17, 0.4)]
const KO_SQUASH := 0.34  ## the floor's depth over its width there (the chakram lying on it is as flat)
const KO_RING := Vector4(0.849, 0.852, 0.32, 0.115)  ## the chakram's shade ring on the floor: middle, width, height
const WIN_GROUND := Color(1.0, 0.72, 0.55, 0.3)  ## the pool of light a fallback crop stands in (additive)
## his shadow on the ground, under the victory still (hero_win.png, shares of its size): a soft occlusion under his
## stride and each boot's contact where it stands (the back boot higher up the picture: further back on the ground)
const WIN_POOL := Vector3(0.46, 0.935, 0.9)  ## its middle (x, y) and width
const WIN_BOOTS: Array[Vector3] = [Vector3(0.13, 0.936, 0.2), Vector3(0.735, 0.907, 0.22)]  ## each boot's: x, y, width
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
		# what happened, in one punchy word (UI r23, the judges of j19: r22's "The bandits caught Panoramic!", red
		# letters in a cream stroke on the cream hide, "fussy and low contrast"): big heavy letters in one solid deep
		# red, a hairline of the same red darker round them, no stroke, no depth
		var why := Ui.display_text(TranslationServer.translate("FELL" if world.death_reason == &"fall" else "CAUGHT"),
				60, Color("9e1608"), Color("6a0c04"))
		why.outline_width = 1.5
		why.depth = 0.0
		why.tracking = 1.0
		why.shadow = Color(0, 0, 0, 0)
		why.refresh()
		var air := MarginContainer.new()  # air round it (not edge to edge), room for a crown under it
		air.add_theme_constant_override(&"margin_bottom", 10)
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
	if won:  # the reward screen's call: bigger, a warm light breathing behind it, a sweep of light
		_glow_behind(go)
		go.shine(2.6, 0)  # (UI r21, the judges of j17: the ring's sparkle glints read as stock)
	else:
		go.shine(3.6, 0)
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
	# (round 20, the judges: "a yellow bloom smudge at his feet") his stills stand on their own dark contact
	# shadow: only a faint light on the ground round them
	if won:  # radiant: a red ribbon on the gold (gold on gold was lost), the home at a cool dusk behind
		panel = GamePanel.open(game, title, Ui.Tone.CRIMSON, body, _hero(true), Color(0.04, 0.03, 0.1, 0.3),
				WIN_GROUND, true, hide, &"win")
	else:  # drained and dim: where he fell, cool and dark, old bronze, a red ribbon
		panel = GamePanel.open(game, title, Ui.Tone.CRIMSON, body, _hero(false), Color(0.06, 0.04, 0.06, 0.45),
				Color(0.75, 0.8, 1.0, 0.1), false, hide, &"loss")
	panel.leave_out_of_picture(PausePanel.moving_pieces(game))  # his still stands for him: not him twice
	if won:  # (UI r22, the judges of j18: "a blurred HOME sign right behind his head") the signpost's letters
		# framed his head in the picture behind: left out of it (the home stays: its huts, fence and fire)
		panel.leave_out_of_picture(_home_sign(game))
	_reveal(game, panel, world, stars, bobs, total, bar, slot, news.get("best_bobs", false), buttons, go)
	return panel


## The home's carved HOME signpost in the scene (HomeView's back layer), or nothing.
static func _home_sign(game: Control) -> Array:
	var back := game.find_child("HomeBack", true, false)
	if not back:
		return []
	var out := []
	for n in back.get_children():
		if n is Sprite2D and (n as Sprite2D).texture and (n as Sprite2D).texture.resource_path.ends_with("home_sign.png"):
			out.append(n)
	return out


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
		# (UI r21) the ground under him (GamePanel._Dais; UI r23: a drawn patch of lit earth seen a little from above):
		# its middle and half width, shares of the picture's width, and its middle's height, a share of its height
		# (standing, under his stride; knocked out, under where he sits, the hand behind him and the chakram lying on it)
		art.set_meta(&"dais", Vector2(0.47, 0.55) if won else Vector2(0.6, 0.5))
		art.set_meta(&"dais_y", 0.925 if won else 0.86)
		# (UI r23, the judges of j19: he must sit on the ground, not float on it) his contact occlusion, behind the still:
		# under each boot after a win; under his hips, his hand, his heels and round the chakram after a defeat
		var ground := Control.new()
		ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ground.show_behind_parent = true
		ground.draw.connect((_draw_win_ground if won else _draw_ko_ground).bind(ground))
		ground.resized.connect(ground.queue_redraw)
		art.add_child(ground)
		if won:  # (UI r23) its own shadow band ran to the picture's edges: a hard cut on the drawn ground, softened
			var edges := ShaderMaterial.new()
			edges.shader = preload("res://src/ui/still_mask.gdshader")
			edges.set_shader_parameter(&"edge_fade", 0.05)
			edges.set_shader_parameter(&"edge_from", 0.85)
			edges.set_shader_parameter(&"edge_fade_low", 0.16)
			edges.set_shader_parameter(&"edge_low_from", 0.94)
			art.material = edges
	# (UI r23) in a clean, neutral light (the still's own): no night tint, no warm spill on him
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
				var mask := ShaderMaterial.new()  # (UI r23) its own side-view shadow under the chakram: gone (_draw_ko_ground)
				mask.shader = preload("res://src/ui/still_mask.gdshader")
				mask.set_shader_parameter(&"cut", Vector4(0.69, 0.907, 1.1, 1.1))
				art.material = mask
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


## (round 21) The victory still's shadow on the ground (WIN_POOL, WIN_BOOTS): the stride's soft occlusion, each boot's
## contact under it, a near-black core where its sole meets the ground. (UI r23) Drawn with the panel's own soft
## shades (_soft: no mipmapped edge, so no seam where a squashed blob's rect ends; r22's tufts hid one).
static func _draw_win_ground(ground: Control) -> void:
	var s := ground.size
	var pool := Vector2(WIN_POOL.z, WIN_POOL.z * 0.2) * s.x * 0.5
	ground.draw_texture_rect(_soft(), Rect2(Vector2(WIN_POOL.x, WIN_POOL.y) * s - pool, pool * 2.0), false, Color(0.12, 0.05, 0.02, 0.45))
	for boot in WIN_BOOTS:
		var r := Vector2(boot.z, boot.z * 0.24) * s.x * 0.5
		var at := Vector2(boot.x, boot.y) * s
		ground.draw_texture_rect(_soft(), Rect2(at - r, r * 2.0), false, Color(0.08, 0.03, 0.01, 0.7))
		ground.draw_texture_rect(_soft(), Rect2(at - r * Vector2(0.62, 0.5), r * Vector2(1.24, 1.0)), false, Color(0.03, 0.01, 0.0, 0.8))


## (UI r23, the judges of j19: "give him contact occlusion where he sits: hips, hand and heels"; "the chakram on the
## floor is a flat ellipse, a decal") The knocked-out still's occlusion on the floor it sits on (the floor seen a little
## from above, as the chakram lies on it): a soft dark pool under his hips, under the hand behind him, under the heel
## on the ground and, fainter and wider, under the boot he holds up; round the chakram a soft ring of shade where its
## rim meets the floor (its hole stays lit), so it lies on the ground. KO_CONTACTS: shares of the picture.
static func _draw_ko_ground(ground: Control) -> void:
	var s := ground.size
	for c in KO_CONTACTS:
		var r := Vector2(c.z, c.z * KO_SQUASH) * s.x * 0.5
		ground.draw_texture_rect(_soft(), Rect2(Vector2(c.x, c.y) * s - r, r * 2.0), false, Color(0.02, 0.01, 0.04, c.w))
	var ring := Vector2(KO_RING.z, KO_RING.w) * s.x * 0.5
	var at := Vector2(KO_RING.x, KO_RING.y) * s
	ground.draw_texture_rect(_soft(), Rect2(at + Vector2(0, ring.y * 0.25) - ring * 1.08, ring * 2.16), false, Color(0.02, 0.01, 0.04, 0.3))  # its shade on the floor
	ground.draw_texture_rect(_ring(), Rect2(at - ring, ring * 2.0), false, Color(0.02, 0.01, 0.04, 0.95))  # where its rim meets it


static var _soft_tex: GradientTexture2D
static var _ring_tex: GradientTexture2D


## A soft round shade: full in its middle, easing out to nothing at its edge.
static func _soft() -> GradientTexture2D:
	if not _soft_tex:
		_soft_tex = _radial(PackedFloat32Array([0.0, 0.3, 0.65, 1.0]), PackedFloat32Array([1.0, 0.85, 0.35, 0.0]))
	return _soft_tex


## A soft ring of shade (a ring lying on the floor): clear in its middle, darkest just inside its edge.
static func _ring() -> GradientTexture2D:
	if not _ring_tex:
		_ring_tex = _radial(PackedFloat32Array([0.0, 0.5, 0.72, 0.86, 1.0]), PackedFloat32Array([0.0, 0.0, 0.9, 0.7, 0.0]))
	return _ring_tex


static func _radial(offsets: PackedFloat32Array, alphas: PackedFloat32Array) -> GradientTexture2D:
	var t := GradientTexture2D.new()
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.gradient = Gradient.new()
	t.gradient.offsets = offsets
	var cols := PackedColorArray()
	for a in alphas:
		cols.append(Color(1, 1, 1, a))
	t.gradient.colors = cols
	return t


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
			var back := Node2D.new()  # behind him and the card
			back.scale = Vector2.ONE * 0.5
			panel.add_child(back)
			panel.move_child(back, panel.card.get_parent().get_index())
			var group := panel.card.get_parent()
			var over := Node2D.new()  # over the card, under him and the title's ribbon
			over.scale = Vector2.ONE * 0.5
			group.add_child(over)
			group.move_child(over, panel.card.get_index() + 1)
			var star := stars[1].get_global_rect().get_center()
			_party(back, back.get_global_transform().affine_inverse() * star, over, over.get_global_transform().affine_inverse() * star))
	_count_up(tree, bobs, world.bobs, total, t, panel)
	t += COUNT_TIME + 0.1
	if bar:
		bar.fill_from(t - 0.1)
		t += 0.6
	if best:
		_stamp(tree, panel, slot, t + 0.1, not won)


## The win's party (UI r23, the judges of j19: r22's "sparse flat rectangles at the edges, plus one thin firework":
## make "one dense, lit, tumbling burst"): one burst from behind the card's stars, a flash of warm light at its
## heart, its paper thrown high and wide over the scene and floating down for seconds, every piece turning and
## flipping, shaded by how it faces the light and glinting when it faces it (Confetti), in three depths: far,
## small, slow and hazy with the warm air, behind everything (`back`, at `back_at`); the bulk crisp and two-tone
## with gold streamers and sparks, and a few big soft pieces near the eye, over the card but under him and the
## title's ribbon (`over`, at `over_at`), so his face and the title stay clean.
static func _party(back: Node2D, back_at: Vector2, over: Node2D, over_at: Vector2) -> void:
	Fx.glow(back, back_at, Color(1, 0.88, 0.6, 0.95), 0.4, 2.6, 0.5)
	var far := Confetti.make(back, back_at)
	far.depth = 0.9
	far.haze = Color(1.0, 0.9, 0.74)
	far.gravity = 300.0
	far.drag = 1.7
	far.flutter = 380.0
	far.spray(100, Fx.WIN_SHAPES, Fx.PAPER_COLOURS, Vector2(800, 1800), Vector2.UP, 88.0, 1.2, Vector2(4.0, 5.2), 40.0)
	var mid := Confetti.make(over, over_at)
	mid.gravity = 320.0
	mid.drag = 1.6
	mid.flutter = 420.0
	mid.spray(120, Fx.WIN_SHAPES, Fx.PAPER_COLOURS, Vector2(700, 1800), Vector2.UP, 86.0, 2.0, Vector2(4.0, 5.0), 36.0)
	mid.spray(14, Fx.STREAMERS, Fx.STREAMER_COLOURS, Vector2(700, 1600), Vector2.UP, 70.0, 1.6, Vector2(3.6, 4.6), 28.0)
	mid.sparkle(36, Fx.GOLD, Vector2(500, 1500), 1.1, Vector2(1.6, 2.6))
	var near := Confetti.make(over, over_at)  # out of focus, closest to the eye
	near.gravity = 260.0
	near.drag = 1.3
	near.flutter = 180.0
	near.glints = false
	var colours: Array[Color] = []
	for c in Fx.PAPER_COLOURS:
		colours.append(Color(c, 0.8))
	near.spray(7, [Confetti.Shape.BOKEH], colours, Vector2(900, 1900), Vector2.UP, 80.0, 3.4, Vector2(3.4, 4.4), 30.0)
	Audio.play_sfx(&"firework", 1.4, 0.5)


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

class_name ResultsPanel
extends RefCounted
## The end of a run, over the game (GamePanel), on the ink (the user, 2026-11-13, of three panel styles shown: "C", no
## box, ink brush), told in order so the eye can follow it:
## - Home: the title in gold brush lettering; the three stars, flat gold in an ink line, slam into their places one
##   after the other, each with a burst and its note (the third shakes the band); a star not earned stays a thin gold
##   outline (StarBadge); the party (UI r23, the judges of j19: r22's "sparse flat rectangles at the edges, plus one thin
##   firework"): ONE dense burst of lit, tumbling confetti thrown high from behind the stars over the whole scene; then
##   the Red Bobs roll up with ticks, cream numbers beside the Red Bob, no plate under them; a red NEW BEST! stamp slams
##   in last beside the count (its place kept in the count's row from the start: nothing moves, nothing is covered).
##   Panoramic stands at the left with his fist up on a drawn patch of lit ground, his contact shade under each boot,
##   close to the band, the scene behind flooded with warm light, soft rays turning behind him.
## - A lost run, in another mood: the world behind cool and soft but still coloured and lit, a deep vignette; GAME OVER
##   and what happened under it in one punchy word, cream; the Red Bobs roll up, then the bar of the way home fills to
##   where he got (a leaning track in a cream line, gold as far as he got, the house at its end: the goal); the buttons
##   are there at once; a new best is the same stamp as a win's, quieter (BurstBadge.calm). Panoramic dazed on the floor
##   in a cool light, sitting on it (the shade of his hips, hand and heels, the chakram lying on it in its own shade).
## Under a thin gold line, PLAY AGAIN (the red leaning plate, the menu's PLAY) between Home and Share, two quiet dark
## plates in a gold line.

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
const BADGE := 66.0  ## the NEW BEST! stamp's radius
const BADGE_CALM := 56.0  ## ... after a defeat (blind round 12: "the loudest object on a game-over screen: it outweighs the title")
const STAR := 132.0  ## a star of the three
const GO_H := 100.0  ## PLAY AGAIN's height with its shadow


## Opens the results over `game` (the game screen). `news`: what Save.record_run found new.
static func open(game: Control, world: World, news: Dictionary, home: Callable, again: Callable,
		share: Callable, hide: Array = []) -> GamePanel:
	var won := world.state == World.State.WON
	var body := VBoxContainer.new()
	body.add_theme_constant_override(&"separation", 16)
	var stars: Array[Control] = []
	if won:
		body.add_child(_stars_stage(stars))
	else:
		# what happened, in one punchy word (UI r23, the judges of j19: r22's "The bandits caught Panoramic!" was "fussy
		# and low contrast"): heavy leaning cream letters in an ink line
		body.add_child(_ink_text(TranslationServer.translate("FELL" if world.death_reason == &"fall" else "CAUGHT"), 56))
	var big := HBoxContainer.new()  # the Red Bobs: the run's big number, on the ink (no plate under it)
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	big.add_theme_constant_override(&"separation", 18)
	var bob := TextureRect.new()
	bob.texture = BobView.texture()
	bob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bob.custom_minimum_size = Vector2(82, 82)
	bob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	big.add_child(bob)
	# out of the Red Bobs the stars count (the ones he can reach), so the count and the stars agree
	var total := " / %d" % mini(World.BOBS_REACHABLE, world.level.bobs_total)
	var bobs := _ink_text("0" + total, 68)
	bobs.custom_minimum_size.x = maxf(bobs.custom_minimum_size.x, 300.0)
	bobs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	big.add_child(bobs)
	var slot := Control.new()  # a new best's stamp lands here, beside the count: its place is kept,
	# with air between it and the count, and as tall as it
	var badge := BADGE if won else BADGE_CALM
	slot.custom_minimum_size = Vector2(badge * 2.0 + 44.0, badge * 2.0 + 6.0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.visible = news.get("best_bobs", false)
	big.add_child(slot)
	body.add_child(big)
	var bar: WayBar = null
	if not won:
		bar = WayBar.new(world.progress())
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var way := HBoxContainer.new()  # what the bar measures, said beside it (not a second score)
		way.alignment = BoxContainer.ALIGNMENT_CENTER
		way.add_theme_constant_override(&"separation", 14)
		way.add_child(Ui.label(TranslationServer.translate("WAY_HOME"), 36, Ui.BONE, Ui.font_title))
		way.add_child(bar)
		body.add_child(way)
	body.add_child(Ui.rule())
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 20)
	var face_h := GO_H - roundf(GO_H * 0.09)  # PLAY AGAIN's face, less its shadow: the quiet plates are as tall
	var home_button := Ui.plate_button("house-fill", Vector2(118.0, face_h))
	home_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	home_button.pressed.connect(home)
	buttons.add_child(home_button)
	var go := Ui.cta_button(TranslationServer.translate("PLAY_AGAIN"), GO_H, 44, "arrow-counter-clockwise-bold")
	go.custom_minimum_size.x = maxf(go.custom_minimum_size.x, 360.0)
	go.pressed.connect(again)
	buttons.add_child(go)
	var share_button := Ui.plate_button("share-network-fill", Vector2(118.0, face_h))
	share_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	share_button.pressed.connect(share)
	buttons.add_child(share_button)
	body.add_child(buttons)
	var title := TranslationServer.translate("HOME_REACHED" if won else "GAME_OVER")
	var panel: GamePanel
	# (round 20, the judges: "a yellow bloom smudge at his feet") his stills stand on their own dark contact
	# shadow: only a faint light on the ground round them
	if won:  # radiant: the home at a cool dusk behind
		panel = GamePanel.open(game, title, body, _hero(true), Color(0.04, 0.03, 0.1, 0.3),
				WIN_GROUND, true, hide, &"win")
	else:  # drained and dim: where he fell, cool and dark
		panel = GamePanel.open(game, title, body, _hero(false), Color(0.06, 0.04, 0.06, 0.45),
				Color(0.75, 0.8, 1.0, 0.1), false, hide, &"loss")
	panel.leave_out_of_picture(PausePanel.moving_pieces(game))  # his still stands for him: not him twice
	if won:  # (UI r22, the judges of j18: "a blurred HOME sign right behind his head") the signpost's letters
		# framed his head in the picture behind: left out of it (the home stays: its huts, fence and fire)
		panel.leave_out_of_picture(_home_sign(game))
	_reveal(game, panel, world, stars, bobs, total, bar, slot, news.get("best_bobs", false), buttons, go)
	return panel


## Heavy leaning cream letters in an ink line, on the ink (the count, what happened).
static func _ink_text(text: String, font_size: int) -> DisplayText:
	var t := Ui.display_text(text, font_size, Ui.BONE, Ui.INK_BLACK)
	t.font = Ui.font_slant
	t.outline_width = maxf(font_size * 0.05, 2.0)
	t.depth = 0.0
	t.shadow = Color(0, 0, 0, 0)
	t.refresh()
	return t


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


## The three stars in a row on the ink: flat gold in an ink line; a star not earned stays a thin gold outline (StarBadge).
static func _stars_stage(stars: Array[Control]) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 26)
	for i in 3:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(STAR, STAR)
		slot.add_child(StarBadge.new(STAR, false))
		var star := StarBadge.new(STAR, true)
		star.visible = false
		slot.add_child(star)
		row.add_child(slot)
		stars.append(star)
	return row


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
			var star := stars[1].get_global_rect().get_center()
			_party(back, back.get_global_transform().affine_inverse() * star))
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
## small, slow and hazy with the warm air; the bulk crisp and two-tone with gold streamers and sparks; and a few
## big soft pieces near the eye. All of it behind the ink band and him (`back`, at `back_at`): no paper crosses
## the title, the stars or the count (blind round 11: "confetti lands on the title and the score": the bulk was
## over the band).
static func _party(back: Node2D, back_at: Vector2) -> void:
	Fx.glow(back, back_at, Color(1, 0.88, 0.6, 0.95), 0.4, 2.6, 0.5)
	var far := Confetti.make(back, back_at)
	far.depth = 0.9
	far.haze = Color(1.0, 0.9, 0.74)
	far.gravity = 300.0
	far.drag = 1.7
	far.flutter = 380.0
	far.spray(100, Fx.WIN_SHAPES, Fx.PAPER_COLOURS, Vector2(800, 1800), Vector2.UP, 88.0, 1.2, Vector2(4.0, 5.2), 40.0)
	var mid := Confetti.make(back, back_at)
	mid.gravity = 320.0
	mid.drag = 1.6
	mid.flutter = 420.0
	mid.spray(120, Fx.WIN_SHAPES, Fx.PAPER_COLOURS, Vector2(700, 1800), Vector2.UP, 86.0, 2.0, Vector2(4.0, 5.0), 36.0)
	mid.spray(14, Fx.STREAMERS, Fx.STREAMER_COLOURS, Vector2(700, 1600), Vector2.UP, 70.0, 1.6, Vector2(3.6, 4.6), 28.0)
	mid.sparkle(36, Fx.GOLD, Vector2(500, 1500), 1.1, Vector2(1.6, 2.6))
	var near := Confetti.make(back, back_at)  # out of focus, closest to the eye
	near.gravity = 260.0
	near.drag = 1.3
	near.flutter = 180.0
	near.glints = false
	var colours: Array[Color] = []
	for c in Fx.PAPER_COLOURS:
		colours.append(Color(c, 0.8))
	near.spray(7, [Confetti.Shape.BOKEH], colours, Vector2(900, 1900), Vector2.UP, 80.0, 3.4, Vector2(3.4, 4.4), 30.0)
	Audio.play_sfx(&"firework", 1.4, 0.5)


## A star slams into its place: from big and turned to a little small, then its size, a burst of
## light and sparks as it lands, a note a third higher each; the third shakes the band. Then it
## swells a little now and then.
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
	var flare := TextureRect.new()  # a flash of light behind it as it lands, gone at once (no glow stays on the ink)
	flare.texture = Fx.glow_texture()
	flare.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flare.material = Fx.additive()
	flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flare.size = star.size * 2.4
	flare.position = star.size / 2 - flare.size / 2
	flare.modulate = Color(1, 0.8, 0.34, 0.75)
	flare.show_behind_parent = true
	star.add_child(flare)
	var bloom := flare.create_tween()
	bloom.tween_property(flare, "modulate:a", 0.0, 0.45).from(0.75)
	bloom.tween_callback(flare.queue_free)
	if Prefs.motion():
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


## NEW BEST!: a round red stamp (BurstBadge) slams into its place beside the count, spinning in a little askew, the
## band shakes, light and sparkles burst under it. After a defeat (`calm`) the same news without the fanfare
## (j15: a shouting seal on a loss sent mixed emotions): a darker stamp settles into its place.
static func _stamp(tree: SceneTree, panel: GamePanel, slot: Control, delay: float, calm := false) -> void:
	await tree.create_timer(delay).timeout
	if not is_instance_valid(panel):
		return
	var stamp := BurstBadge.new(TranslationServer.translate("NEW_BEST"), BADGE_CALM if calm else BADGE, calm)
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


## The way home on a lost run's panel: a dark leaning track in a thin cream line, the gold filling it from its left
## end to where he got (when the count is done), cut at the tip as the track leans, the percentage riding the tip, and
## past its end the goal: a cream house.
class WayBar extends Control:
	const SLANT := 0.3  ## its top leans this far right of its foot, a share of its height (the red plate's)
	const HOUSE := 54.0  ## the house past its end
	var progress := 0.0
	var _shown := 0.0
	var _label: DisplayText

	func _init(p: float) -> void:
		progress = clampf(p, 0.0, 1.0)
		custom_minimum_size = Vector2(450, 76)  # (blind round 12: "small and thin": it was 400 by 64)
		var french := TranslationServer.get_locale().begins_with("fr")  # "21 %" in French, "21%" in English
		_label = Ui.display_text(("%d %%" if french else "%d%%") % roundi(progress * 100.0), 38, Ui.WHITE, Color("140607"))
		_label.font = Ui.font_slant
		_label.outline_width = 2.5
		_label.depth = 0.0
		_label.shadow = Color(0, 0, 0, 0)
		_label.refresh()
		add_child(_label)
		resized.connect(_place_label)

	## The track: the bar less the house past its end.
	func _track() -> Rect2:
		return Rect2(Vector2(4.0, 10.0), Vector2(size.x - HOUSE - 18.0, size.y - 20.0))

	## The leaning piece of the track from `x0` to `x1` along its foot.
	func _piece(x0: float, x1: float) -> PackedVector2Array:
		var r := _track()
		var lean := r.size.y * SLANT
		return PackedVector2Array([Vector2(x0 + lean, r.position.y), Vector2(x1 + lean, r.position.y),
				Vector2(x1, r.end.y), Vector2(x0, r.end.y)])

	## Where the fill ends, along the track's foot.
	func _tip() -> float:
		var r := _track()
		return r.position.x + (r.size.x - r.size.y * SLANT) * _shown

	## The percentage rides the fill: inside its tip when the gold is long enough, else past it, clear of its leaning
	## edge (blind round 12: "the percentage straddling the fill's edge"; never floating over the empty track's middle).
	func _place_label() -> void:
		var need := _label.get_combined_minimum_size()
		_label.size = need
		var r := _track()
		var tip := _tip() + r.size.y * SLANT * 0.5
		var x := tip - need.x - 14.0 if tip - r.position.x >= need.x + 30.0 else tip + r.size.y * SLANT * 0.5 + 14.0
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
		var r := _track()
		var whole := _piece(r.position.x, r.end.x - r.size.y * SLANT)
		draw_colored_polygon(whole, Color("1c1310"))
		if _shown > 0.0:
			var done := _piece(r.position.x, _tip())
			draw_colored_polygon(done, Color("ffc928"))
			# one cel step along its foot
			var low := Geometry2D.intersect_polygons(done, PackedVector2Array([Vector2(-10.0, r.position.y + r.size.y * 0.6),
					Vector2(size.x + 10.0, r.position.y + r.size.y * 0.6), Vector2(size.x + 10.0, size.y + 10.0), Vector2(-10.0, size.y + 10.0)]))
			for part: PackedVector2Array in low:
				draw_colored_polygon(part, Color("f0940e"))
		var edge := whole.duplicate()
		edge.append(whole[0])
		draw_polyline(edge, Color("140607"), 6.0, true)
		draw_polyline(edge, Color(Ui.BONE, 0.95), 2.5, true)
		# the goal: the house past its end
		draw_texture_rect(Ui.icon_texture("house-fill"), Rect2(Vector2(size.x - HOUSE, (size.y - HOUSE) / 2.0), Vector2(HOUSE, HOUSE)), false, Ui.BONE)

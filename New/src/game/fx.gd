class_name Fx
## One-shot effects (from the Super Gassamanh kit): the "+1" pop, flashes and confetti, blows,
## leaves, trails, and the confetti of a win. What should look solid (confetti, leaves,
## stone chips) is Confetti: shaded pieces that tumble; what is light (flashes, rays, glints, rings)
## is added onto the scene.

# Chaka Zulu: sunset orange, gold, the Red Bob red, the ring blue, savanna green, white.
const CONFETTI: Array[Color] = [Color("f2662e"), Color("ffd36b"), Color("e82808"), Color("3a8fd8"), Color("a8c808"), Color("ffffff")]
## Party colours, the scene's palette: gold, the warm reds of the sunset and the Red Bobs, the deep
## indigo of his beads, cream.
const PARTY: Array[Color] = [Color("ffd36b"), Color("e8a317"), Color("e85a3a"), Color("c8341f"), Color("f2662e"),
		Color("4a43a8"), Color("2f2b7a"), Color("fff1d0")]
## Blue sparks of a ring hitting a bandit.
const RING_SPARKS: Array[Color] = [Color("ffffff"), Color("8fd0ff"), Color("3fa2ff")]
## Red Bob bits.
const BOB_BITS: Array[Color] = [Color("e82808"), Color("ff6a4a"), Color("ffd36b"), Color("ffffff")]
const SPARKS: Array[Color] = [Color("ffffff"), Color("ffd36b"), Color("fff0c2")]
const STONE_DUST: Array[Color] = [Color("c69c6d"), Color("f1d0ad"), Color("a57b4f")]
const STONE_CHIPS: Array[Color] = [Color("a57b4f"), Color("8a6440"), Color("c69c6d"), Color("6e4c2e")]
const LEAVES: Array[Color] = [Color("99ce40"), Color("8abd31"), Color("76a22a"), Color("aedb5a")]
const CHALK: Array[Color] = [Color(1, 1, 1)]
## The streamers of a burst: glossy satin streamers and a few petals that tumble (their size varies;
## short wavy ribbons read as letters at a distance, so they are left out).
const STREAMERS := [Confetti.Shape.STREAMER, Confetti.Shape.STREAMER, Confetti.Shape.STREAMER, Confetti.Shape.PETAL]
## Their colours, curated: gold, the sunset's red and coral, cream, his indigo.
const STREAMER_COLOURS: Array[Color] = [Color("ffcf3a"), Color("f5b81c"), Color("e8452e"), Color("ff7a52"),
		Color("fff1d0"), Color("4a43a8")]
## Paper confetti, two-tone (Confetti.TWO_TONE gives each its lighter back): bright gold, cream and
## coral, a warm red for accent (warm and bright: deeper shades read as dead leaves; no pastel blues).
const PAPER_COLOURS: Array[Color] = [Color("ffd23a"), Color("ffd23a"), Color("ffe680"), Color("fff4dc"),
		Color("fff4dc"), Color("ff7a5a"), Color("ff7a5a"), Color("ff4d3d")]
## The paper of a celebration: mostly squares, some strips, a few round sequins.
const PAPER_SHAPES := [Confetti.Shape.PAPER, Confetti.Shape.PAPER, Confetti.Shape.PAPER, Confetti.Shape.STRIP,
		Confetti.Shape.SEQUIN]
## The win's mix, shapes of several kinds (not "flat uniform rectangles"): squares, long strips, round
## sequins, a few stars (curled streamers read as squiggles at this size).
const WIN_SHAPES := [Confetti.Shape.PAPER, Confetti.Shape.PAPER, Confetti.Shape.STRIP, Confetti.Shape.STRIP,
		Confetti.Shape.SEQUIN, Confetti.Shape.SEQUIN, Confetti.Shape.STAR]
## A firework's sparks: white-hot to gold to the sunset's orange and red.
const FIREWORK: Array[Color] = [Color("fff6d8"), Color("ffd36b"), Color("ffab3a"), Color("ff6a3a")]
## A burst's colour, the sunset's: gold, red-orange, amber, white-gold, peach (no cool purples or teals:
## they fought the warm card; no pink).
const FIREWORK_HUES: Array[Color] = [Color("ffc93a"), Color("ff5a32"), Color("ff9a2a"), Color("fff1cc"), Color("ffb27a")]
const PLUS_SIZE := 118  ## font size of the "+1" and the "×N" (design px): one size, scaled per use
const PLUS_SCALE := 0.85  ## the "+1" a little under its glyphs' size: a small clean pop that reads at phone size
## The "+1"'s clock (s): it pops in, settles, holds, then shrinks away and fades; its burst keeps the
## same clock, so the number is never seen without it.
const PLUS_POP := 0.06
const PLUS_SETTLE := 0.1
const PLUS_HOLD := 0.55
const PLUS_OUT := 0.16
## The badges' outlines (px): the dark stroke and the warm rim. The "+1" and the "×N" share them and
## the font size, so their glyphs are rasterised once (each size and outline is megabytes of pages).
const BADGE_OUTLINES: Array[int] = [34, 16]
## The ring's light: white-hot core, its blue, a deeper blue at the edge.
const RING_LIGHT: Array[Color] = [Color("ffffff"), Color("bfe6ff"), Color("6cc4ff"), Color("2f8bff")]
## A Red Bob's streak: hot gold to its red.
const BOB_LIGHT: Array[Color] = [Color("fff1c4"), Color("ffc65a"), Color("ff7a3a"), Color("e82808")]
const EMBERS: Array[Color] = [Color("ffe2a0"), Color("ffb347"), Color("ff7a2a")]
const GOLD: Array[Color] = [Color("ffcf3a"), Color("f5b81c"), Color("ffe27a"), Color("e8a317")]
## The shared impacts, from a ring's tap to the last blow (the game screen applies them: _impact).
## stop: hit-stop (s: 3, 4, 5 frames); shake: camera shake (design units: about 4-8 px on a phone,
## gone in 8-12 frames); shards: sparks thrown away from the contact; knock: how far the one hit is
## knocked (design units; it springs back, the rules don't move); scale: the size of the burst.
const IMPACTS := {
	&"small": {"stop": 0.05, "shake": 3.0, "shards": 5, "knock": 16.0, "scale": 0.7},
	&"medium": {"stop": 0.067, "shake": 4.5, "shards": 8, "knock": 30.0, "scale": 1.0},
	&"fatal": {"stop": 0.083, "shake": 6.5, "shards": 12, "knock": 46.0, "scale": 1.35},
}
const FLASH_TIME := 0.035  ## the white of a blow: 2 frames, then the one hit shows (the views use it)
const MAX_FLIERS := 6  ## Red Bobs flying to the counter at once (more just pop on it)
const STREAK_SIZE_K := 0.8  ## the "×N" shows at this share of PLUS_SIZE (its node's scale)
## The streak badge's colour per tier (2-3, 4-5, 6-7, 8+ in a row).
const STREAK_TIERS: Array[Color] = [Color("ffffff"), Color("ffd84a"), Color("ff9a2a"), Color("ff4a3a")]

static var _knocks := {}  # key (&"hero", a World.Bandit) -> [start (knock clock), push, seconds]
static var _knock_clock := 0.0
static var _fliers := 0
static var _streak_badge: Node2D

static var _confetti_tex: Texture2D
static var _bubble_tex: Texture2D
static var _glow_tex: Texture2D
static var _puff_tex: Texture2D
static var _vignette_tex: Texture2D
static var _edge_tex: Texture2D
static var _additive: CanvasItemMaterial
static var _badge: ShaderMaterial
static var _plus_font: Font


## True when the player asked for reduced motion (Settings, Save.reduce_motion: Prefs): no screen
## shake or camera kicks then, and the red flash of a blow is halved. Particles and light stay.
static func calm() -> bool:
	return not Prefs.motion()


## Knocks `key` (&"hero", or a World.Bandit) by `push` (design units): out fast (ease-out, the
## first 30 % of `seconds`), then back to where the rules have it. The views add knock_offset().
static func knock(key: Variant, push: Vector2, seconds := 0.4) -> void:
	_knocks[key] = [_knock_clock, push, seconds]


## Where `key` is drawn from its place now (design units).
static func knock_offset(key: Variant) -> Vector2:
	var k: Array = _knocks.get(key, [])
	if k.is_empty():
		return Vector2.ZERO
	var u: float = (_knock_clock - k[0]) / k[2]
	if u >= 1.0:
		_knocks.erase(key)
		return Vector2.ZERO
	var amount := 1.0 - pow(1.0 - u / 0.3, 3.0) if u < 0.3 else 1.0 - smoothstep(0.35, 1.0, u)
	return k[1] * amount


## The knocks' clock: advanced by the game while the world runs (a hit-stop holds the knock too).
static func advance_knocks(delta: float) -> void:
	_knock_clock += delta


## The light of a blow at `at` (effects units), sized by an IMPACTS preset: a white-hot core for
## two frames, then only a thin ring spreading (the one hit is never hidden), sharp shards thrown
## `away` from the contact, a few sparks. `tint`: the colour of the light (the ring's blue, red
## for a blow on Panoramic).
static func impact_burst(parent: Node, at: Vector2, away: Vector2, size: StringName, tint: Color) -> void:
	var k: float = IMPACTS[size].scale
	# all added light, so the order doesn't show: the lines first (ring, shards), then the soft light
	# (core, sparks), so each kind batches into one draw call
	ring(parent, at, 14.0 * k, 110.0 * k, 0.22, Color(tint.lerp(Color.WHITE, 0.4), 0.85), 5.0 * k)
	shards(parent, at, away, IMPACTS[size].shards, k, tint)
	glow(parent, at, Color(1, 1, 1, 0.9), 0.12 * k, 0.4 * k, FLASH_TIME * 1.5)
	Confetti.make(parent, at).sparkle(int(4 * k), [Color.WHITE, tint.lightened(0.4)], Vector2(160, 420), 0.7 * k,
			Vector2(0.2, 0.4))


## The "+1" of a knock-out, popping out of a soft burst of light where the ring struck (pop_light): a
## bold number filled white at its top, gold through its middle and amber at its foot (badge_text.gdshader,
## which works with the MSDF title font), a cream rim inside a thick dark stroke and a drop shadow: it
## reads on the sky and on brown earth. It pops in (0 to 1.5 to 1), rises 26 units easing out (still in
## its light), holds and shrinks away with it (PLUS_POP .. PLUS_OUT: 0.87 s). (Drawn at PLUS_SIZE with
## BADGE_OUTLINES like the streak's "×N": one set of glyphs for both.)
static func plus_one(parent: Node, at: Vector2) -> void:
	pop_light(parent, at + Vector2(0.0, -14.0), PLUS_SIZE * 0.8)
	var node := Node2D.new()
	node.position = at
	node.material = badge_material()
	var font := plus_font()
	var w := font.get_string_size("+1", HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE).x
	var base := Vector2(-w / 2, PLUS_SIZE * 0.36)  # the baseline that centres the figures on the node
	node.draw.connect(func() -> void:
		node.draw_string_outline(font, base + Vector2(4, 12), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, BADGE_OUTLINES[0], Color(0.05, 0.02, 0.0, 0.6))
		node.draw_string_outline(font, base, "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, BADGE_OUTLINES[0], Color("1c0b02"))
		node.draw_string_outline(font, base, "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, BADGE_OUTLINES[1], Color("fff0c0"))
		node.draw_string(font, base, "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, Color.WHITE))  # white: filled gold to amber
	parent.add_child(node)
	var big := PLUS_SCALE
	node.scale = Vector2.ZERO
	node.rotation = -0.2
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2.ONE * 1.5 * big, PLUS_POP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE * big, PLUS_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(PLUS_HOLD)
	t.tween_property(node, "scale", Vector2.ONE * 0.7 * big, PLUS_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(node, "modulate:a", 0.0, PLUS_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(node.queue_free)
	var turn := node.create_tween()  # its own clock: the wobble never stretches the number's life
	turn.tween_property(node, "rotation", 0.06, PLUS_POP)
	turn.tween_property(node, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	node.create_tween().tween_property(node, "position:y", at.y - 26.0, 0.5) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## The light a "+1" pops out of (`radius`: its longest rays, effects units), staying where the hit was:
## a soft warm glow round a hotter middle, ten soft rays of light tapering out (long and short in turn)
## and a few small glints: light added onto the scene, no outline, no hard edge. It flashes open (0 to
## 1.25 to 1 with the number's pop), turns a little and settles to a softer glow while the number
## holds, and shrinks away and fades with it (the "+1"'s clock: PLUS_POP .. PLUS_OUT). Drawn once (its
## tweens move it) from the Confetti atlas: one batch.
static func pop_light(parent: Node, at: Vector2, radius: float) -> void:
	var node := Node2D.new()
	node.position = at
	node.rotation = randf() * TAU
	node.material = additive()
	var tilt := []
	for i in 10:
		tilt.append(randf_range(-0.08, 0.08))
	node.draw.connect(func() -> void:
		var tex := Confetti.atlas()
		var glow := Confetti.region(&"glow")
		var streak := Confetti.region(&"streak")
		var flare := Confetti.region(&"flare")
		node.draw_texture_rect_region(tex, Rect2(-Vector2.ONE * radius, Vector2.ONE * radius * 2.0), glow, Color(1, 0.86, 0.55, 0.6))
		for i in 10:  # a ray: the streak's wide end at the middle, its tip out (it points along -x)
			var length := radius * (1.05 if i % 2 == 0 else 0.7)
			var w := radius * (0.1 if i % 2 == 0 else 0.075)
			node.draw_set_transform(Vector2.ZERO, i * TAU / 10.0 + tilt[i] + PI)
			node.draw_texture_rect_region(tex, Rect2(-length, -w, length, w * 2.0), streak, Color(1, 0.9, 0.6, 0.7))
		node.draw_set_transform(Vector2.ZERO)
		node.draw_texture_rect_region(tex, Rect2(-Vector2.ONE * radius * 0.45, Vector2.ONE * radius * 0.9), glow,
				Color(1, 0.97, 0.88, 0.8))
		for i in 3:  # small glints round it
			var p := Vector2.from_angle(i * TAU / 3.0 + 0.5) * radius * 0.72
			node.draw_texture_rect_region(tex, Rect2(p - Vector2.ONE * 12.0, Vector2.ONE * 24.0), flare, Color(1, 0.98, 0.9, 0.9)))
	parent.add_child(node)
	node.scale = Vector2.ZERO
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2.ONE * 1.25, PLUS_POP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, PLUS_SETTLE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 0.7, PLUS_HOLD).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)  # the flash settles
	t.tween_property(node, "scale", Vector2.ONE * 0.5, PLUS_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(node, "modulate:a", 0.0, PLUS_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(node.queue_free)
	node.create_tween().tween_property(node, "rotation", node.rotation + 0.4, PLUS_POP + PLUS_SETTLE + PLUS_HOLD + PLUS_OUT) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## A big reward: a warm flash, a burst of rays and speed lines, two rings of light,
## twinkling stars and a fountain of shaded two-tone paper that tumbles and catches the light.
static func rescue_burst(parent: Node, at: Vector2) -> void:
	glow(parent, at, Color(1, 0.85, 0.6, 0.6), 0.4, 1.5, 0.28)
	rays(parent, at, Color(1, 0.92, 0.66, 0.7), 12, 250.0, 0.5)
	lines(parent, at, Color(1, 1, 1, 0.85), 9, 70.0, 230.0, 0.24)
	ring(parent, at, 30.0, 150.0, 0.4, Color(1, 1, 1, 0.95), 16.0)
	ring(parent, at, 18.0, 100.0, 0.5, Color(1, 0.84, 0.4, 0.8), 9.0)
	var c := Confetti.make(parent, at)
	c.gravity = 1150.0
	c.drag = 2.1
	c.flutter = 420.0
	_behind_hero(c, parent)
	c.spray(16, PAPER_SHAPES, PAPER_COLOURS, Vector2(420, 900), Vector2.UP, 105.0, 1.5, Vector2(0.9, 1.3))
	c.sparkle(14, GOLD, Vector2(140, 420))


## The light behind a badge popping in (NEW BEST): a glow and a ring, smaller and softer
## than rescue_burst; drawn under the badge, so its words and those around it stay legible.
static func badge_burst(parent: Node, at: Vector2) -> void:
	glow(parent, at, Color(1, 0.85, 0.55, 0.5), 0.3, 0.9, 0.3)
	ring(parent, at, 24.0, 110.0, 0.35, Color(1, 0.95, 0.8, 0.7), 8.0)
	Confetti.make(parent, at).sparkle(10, SPARKS, Vector2(160, 420))


## A celebration bursting from one point (the doorway at home, behind the stars of a win):
## two-tone paper in the sunset's golds and red thrown up and out in a fan, in two depths, blurred
## by its speed, then fluttering down; a flash and sparkles at the origin.
static func confetti_burst(parent: Node, at: Vector2) -> void:
	glow(parent, at, Color(1, 0.9, 0.65, 0.8), 0.3, 1.6, 0.35)
	var c := Confetti.make(parent, at)
	c.gravity = 900.0
	c.drag = 1.6
	c.flutter = 520.0
	_behind_hero(c, parent)
	# paper squares, strips and sequins (their backs a lighter tint: they flash between two bright
	# colours as they tumble, and glint): far ones small and a little paler, mid ones crisp and shaded
	var far: Array[Color] = []
	for col in PAPER_COLOURS:
		far.append(col.lerp(Color("fff6e0"), 0.2))  # a little paler with the air, never duller
	c.spray(12, PAPER_SHAPES, far, Vector2(600, 1400), Vector2.UP, 60.0, 1.2, Vector2(2.6, 3.4), 30.0)
	c.spray(24, PAPER_SHAPES, PAPER_COLOURS, Vector2(750, 1700), Vector2.UP, 65.0, 2.1, Vector2(2.4, 3.2), 30.0)
	c.sparkle(24, GOLD, Vector2(200, 650), 1.0, Vector2(0.6, 1.2))


## In the level (`parent` the world view's effects layer), what flies out of the doorway behind him
## passes behind Panoramic: `c` keeps clear of his body (WorldView.hero_screen_rect), so no piece
## lands on his face.
static func _behind_hero(c: Confetti, parent: Node) -> void:
	var view := parent.get_parent()
	if view and view.has_method(&"hero_screen_rect"):
		c.avoid = c.get_global_transform().affine_inverse() * (view.call(&"hero_screen_rect") as Rect2)


## Fireworks from `from` (a lower corner of the screen, effects units): three shells rise steeply,
## leaning a little towards the middle (`inward`: +1 from the left, -1 from the right), bursting at
## their tops, each a different kind (FireworkShow.Kind) and colour. Best behind the people and
## panels: they are light in the sky.
static func fireworks(parent: Node, from: Vector2, inward: float) -> void:
	var show := FireworkShow.new()
	show.material = additive()
	show.radius = 300.0
	parent.add_child(show)
	var screen: Variant = parent.get_parent()  # the results panel, if that is where they are
	var card: Variant = screen.get(&"card") if screen else null
	if card is Control and is_instance_valid(card):
		_keep_off(show, card as Control)
	var shells := [[FireworkShow.Kind.PEONY, 1, 0.8], [FireworkShow.Kind.CHRYSANTHEMUM, 0, 1.0],
			[FireworkShow.Kind.RING, 2, 0.7]]  # kind, colour (FIREWORK_HUES), size
	for i in shells.size():
		show.launch(from, Vector2(inward * randf_range(0.06, 0.16), -1.0).normalized() * randf_range(1150.0, 1300.0),
				i * 0.6, shells[i][1], shells[i][0], shells[i][2])


## Fireworks round the results card (`card`, a Control; `parent` is behind it, effects units): eight
## bursts, one every 0.6 s, taking turns in the sky left of the hero (high) and right of the card
## (higher, then lower: never mirrored), each sized to stay off the card and off him (_keep_off); each
## a different kind, warm colour and size from the one before, so any moment of the reveal shows a
## fresh one and an older one unlike it.
static func card_bursts(parent: Node2D, card: Control) -> void:
	var to_local := parent.get_global_transform().affine_inverse()
	var box: Rect2 = to_local * card.get_global_rect()
	var screen: Variant = parent.get_parent()  # the panel, over the whole screen
	var view: Rect2 = to_local * ((screen as Control).get_global_rect() if screen is Control else card.get_viewport_rect())
	var hero := _hero_rect(card, to_local)
	var left := minf(box.position.x, hero.position.x) if hero.has_area() else box.position.x  # the sky left of him
	var right := Vector2(box.end.x, view.end.x)  # the sky right of the card
	var show := FireworkShow.new()
	show.material = additive()
	show.radius = clampf(minf(left - view.position.x, right.y - right.x) * 0.42, 150.0, 300.0)
	parent.add_child(show)
	_keep_off(show, card)
	var spots := [Vector2((view.position.x + left) * 0.45, view.position.y + view.size.y * 0.3),
			Vector2((right.x + right.y) / 2.0 + show.radius * 0.15, view.position.y + view.size.y * 0.15),
			Vector2((right.x + right.y) / 2.0 - show.radius * 0.1, view.position.y + view.size.y * 0.5)]
	var inside := Vector2(view.position.x + show.radius * 0.55, view.end.x - show.radius * 0.55)  # (narrow margins: a tablet)
	var plan := [[FireworkShow.Kind.CHRYSANTHEMUM, 0, 1.0], [FireworkShow.Kind.RING, 1, 0.75],
			[FireworkShow.Kind.WILLOW, 0, 1.1], [FireworkShow.Kind.PEONY, 2, 0.8],
			[FireworkShow.Kind.CHRYSANTHEMUM, 4, 0.9], [FireworkShow.Kind.PEONY, 1, 0.7],
			[FireworkShow.Kind.WILLOW, 0, 1.0], [FireworkShow.Kind.RING, 4, 0.85]]  # kind, colour, size
	for i in plan.size():
		var at: Vector2 = spots[i % 3] + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		show.burst(Vector2(clampf(at.x, inside.x, inside.y), at.y), i * 0.6, plan[i][1], plan[i][0], plan[i][2])


## What `show`'s bursts keep off (in its units): the results card and Panoramic beside it, with a
## little air; a burst too close to them shrinks to fit, or doesn't go off at all.
static func _keep_off(show: FireworkShow, card: Control) -> void:
	var to_local := show.get_global_transform().affine_inverse()
	show.keep_off.append((to_local * card.get_global_rect()).grow(24.0))
	var hero := _hero_rect(card, to_local)
	if hero.has_area():
		show.keep_off.append(hero.grow(16.0))


## Fireworks, all one node and one batch (light added onto the scene, the Confetti atlas): shells
## that rise and burst at their top, and bursts set off at a point, each of a Kind, sized to stay off
## keep_off. A burst is a white flash for a few frames, a warm bloom that lights the sky round it, and
## sparks flung out over a sphere (seen from the side: dense at its rim), each a tapered streak with a
## bright white-hot core behind a glowing head that cools to its warm colour, the streaks shortening as
## they slow, droop and dim.
class FireworkShow extends Node2D:
	## A chrysanthemum: long soft streaks, its slow middle in white-gold, glittering out; a peony:
	## fat glowing stars on short stubs, a gold middle; a willow: gold glitter drooping into long
	## falling trails that hang on; a ring: every spark on the rim, a crisp circle.
	enum Kind { CHRYSANTHEMUM, PEONY, WILLOW, RING }
	## Per kind: sparks, life (s), drag (per s: out fast, then hanging), fall (px/s²), its streak as a
	## share of its path (fresh, dying), the streak's width and its head's radius (px).
	const KINDS := {
		Kind.CHRYSANTHEMUM: {"sparks": 48, "life": 1.5, "drag": 3.0, "fall": 260.0, "trail": Vector2(0.55, 0.12),
				"width": 13.0, "head": 6.5},
		Kind.PEONY: {"sparks": 40, "life": 1.3, "drag": 3.4, "fall": 200.0, "trail": Vector2(0.2, 0.06),
				"width": 12.0, "head": 10.0},
		Kind.WILLOW: {"sparks": 36, "life": 2.4, "drag": 2.4, "fall": 380.0, "trail": Vector2(0.7, 0.55),
				"width": 9.0, "head": 5.0},
		Kind.RING: {"sparks": 36, "life": 1.3, "drag": 3.2, "fall": 140.0, "trail": Vector2(0.35, 0.1),
				"width": 11.0, "head": 7.0},
	}
	const GRAVITY := 900.0  ## pulls a rising shell (px/s²)
	const BLOOM := 0.9  ## seconds the bloom of its colour lights the sky
	var radius := 300.0  ## how far a burst of size 1 flings its sparks (px)
	var keep_off: Array[Rect2] = []  ## what the bursts stay clear of (the results card, him): they shrink to fit
	const SMALLEST := 0.35  ## a burst that would have to shrink below this share of its size doesn't go off
	var _shells: Array[Vector4] = []  # x, y, delay (s), colour index
	var _shell_vel: Array[Vector2] = []
	var _shell_from: Array[Vector2] = []
	var _shell_kind: Array[Vector2] = []  # kind, size
	var _bursts: Array[Vector4] = []  # x, y, age (s; below 0: waiting), colour index
	var _burst_kind: Array[Vector2] = []  # kind, size
	var _sparks: Array[Vector4] = []  # x, y, age, life (s)
	var _spark_vel: Array[Vector2] = []
	var _spark_from: Array[Vector2] = []
	var _spark_col: Array[Color] = []
	var _spark_kind: Array[int] = []

	func launch(at: Vector2, vel: Vector2, delay: float, hue: int, kind := Kind.CHRYSANTHEMUM, size := 1.0) -> void:
		_shells.append(Vector4(at.x, at.y, delay, hue))
		_shell_vel.append(vel)
		_shell_from.append(at)
		_shell_kind.append(Vector2(kind, size))

	func burst(at: Vector2, delay: float, hue: int, kind := Kind.CHRYSANTHEMUM, size := 1.0) -> void:
		_bursts.append(Vector4(at.x, at.y, -maxf(delay, 0.001), hue))  # (it goes off as its age passes 0)
		_burst_kind.append(Vector2(kind, size))

	func _process(delta: float) -> void:
		for i in range(_shells.size() - 1, -1, -1):
			if _shells[i].z > 0.0:
				_shells[i].z -= delta
				continue
			_shell_vel[i].y += GRAVITY * delta
			_shells[i].x += _shell_vel[i].x * delta
			_shells[i].y += _shell_vel[i].y * delta
			if randf() < delta * 40.0:  # the rising shell sheds embers
				var at := Vector2(_shells[i].x, _shells[i].y)
				_add_spark(at, at, Vector2(randf_range(-40, 40), randf_range(20, 80)), randf_range(0.25, 0.4), Fx.FIREWORK[1],
						Kind.PEONY)
			if _shell_vel[i].y > -120.0:  # near its top: it bursts
				var size := _explode(Vector2(_shells[i].x, _shells[i].y), int(_shells[i].w), int(_shell_kind[i].x), _shell_kind[i].y)
				if size > 0.0:
					_bursts.append(Vector4(_shells[i].x, _shells[i].y, 0.0, _shells[i].w))
					_burst_kind.append(Vector2(_shell_kind[i].x, size))
				_shells.remove_at(i)
				_shell_vel.remove_at(i)
				_shell_from.remove_at(i)
				_shell_kind.remove_at(i)
		for i in range(_bursts.size() - 1, -1, -1):
			var was := _bursts[i].z
			_bursts[i].z += delta
			if was < 0.0 and _bursts[i].z >= 0.0:
				_burst_kind[i].y = _explode(Vector2(_bursts[i].x, _bursts[i].y), int(_bursts[i].w), int(_burst_kind[i].x),
						_burst_kind[i].y)
			if _bursts[i].z > BLOOM or _burst_kind[i].y <= 0.0:
				_bursts.remove_at(i)
				_burst_kind.remove_at(i)
		for i in range(_sparks.size() - 1, -1, -1):
			var kind: Dictionary = KINDS[_spark_kind[i]]
			_sparks[i].z += delta
			_spark_vel[i] -= _spark_vel[i] * minf(kind.drag * delta, 0.5)
			_spark_vel[i].y += kind.fall * delta
			_sparks[i].x += _spark_vel[i].x * delta
			_sparks[i].y += _spark_vel[i].y * delta
			if _sparks[i].z > _sparks[i].w:
				_sparks.remove_at(i)
				_spark_vel.remove_at(i)
				_spark_from.remove_at(i)
				_spark_col.remove_at(i)
				_spark_kind.remove_at(i)
		if _shells.is_empty() and _bursts.is_empty() and _sparks.is_empty():
			queue_free()
		queue_redraw()

	## A burst at `at`: its sound and its sparks, evenly round (a little jitter), their speed the
	## sphere's seen from the side (a ring: its rim only); the slow middle in a second colour. Its size
	## shrinks so its sparks stay clear of keep_off; returns the size it went off at (0: it didn't).
	func _explode(at: Vector2, hue: int, kind: int, size: float) -> float:
		for r in keep_off:
			var gap := Vector2(maxf(maxf(r.position.x - at.x, at.x - r.end.x), 0.0),
					maxf(maxf(r.position.y - at.y, at.y - r.end.y), 0.0)).length()
			size = minf(size, gap / radius)
		if size < SMALLEST:
			return 0.0
		Audio.play_sfx(&"firework")
		var k: Dictionary = KINDS[kind]
		var outer: Color = Fx.FIREWORK_HUES[hue]
		var inner := Fx.FIREWORK[0] if kind == Kind.CHRYSANTHEMUM else Fx.FIREWORK[1]
		if kind == Kind.WILLOW:  # gold glitter, whatever its colour: amber at its heart
			inner = Fx.FIREWORK[2]
		for i in k.sparks:
			var z := randf_range(-0.15, 0.15) if kind == Kind.RING else randf_range(-1.0, 1.0)
			var out := sqrt(1.0 - z * z)
			var dir := Vector2.from_angle((i + randf_range(-0.3, 0.3)) * TAU / k.sparks)
			_add_spark(at, at, dir * out * radius * size * k.drag, k.life * randf_range(0.85, 1.15),
					outer if out > 0.6 else inner, kind)
		return size

	func _add_spark(at: Vector2, from: Vector2, vel: Vector2, life: float, colour: Color, kind: int) -> void:
		_sparks.append(Vector4(at.x, at.y, 0.0, life))
		_spark_vel.append(vel)
		_spark_from.append(from)
		_spark_col.append(colour)
		_spark_kind.append(kind)

	func _draw() -> void:
		var tex := Confetti.atlas()
		var glow := Confetti.region(&"glow")
		var streak := Confetti.region(&"streak")
		var dot := Confetti.region(&"dot")
		var flare := Confetti.region(&"flare")
		for i in _bursts.size():  # the heart: a white flash, then a warm bloom that lights the sky round it
			var b := _bursts[i]
			if b.z < 0.0:
				continue
			var at := Vector2(b.x, b.y)
			var k := b.z / BLOOM
			var r := radius * _burst_kind[i].y
			var warm: Color = Fx.FIREWORK_HUES[int(b.w)].lerp(Color.WHITE, 0.25)
			_light(tex, glow, at, Vector2.ONE * r * (0.8 + 0.35 * k), 0.0, Color(warm, 0.42 * (1.0 - k) * (1.0 - k)))
			_light(tex, glow, at, Vector2.ONE * r * 0.4, 0.0, Color(warm, 0.5 * (1.0 - k) * (1.0 - k) * (1.0 - k)))
			if b.z < 0.12:  # a hot point, not a white smudge
				_light(tex, glow, at, Vector2.ONE * 70.0 * (1.0 + b.z * 6.0), 0.0, Color(1, 0.97, 0.9, 1.0 - b.z / 0.12))
		for i in _shells.size():  # a rising shell: a short gold streak and its hot head
			var s := _shells[i]
			if s.z > 0.0:
				continue
			var head := Vector2(s.x, s.y)
			var length := minf(head.distance_to(_shell_from[i]), 70.0)
			_streak(tex, streak, head, _shell_vel[i].angle(), length, 7.0, Fx.FIREWORK[1], 0.9)
			_light(tex, dot, head, Vector2(8, 8), 0.0, Fx.FIREWORK[0])
		for i in _sparks.size():
			var s := _sparks[i]
			var kind: Dictionary = KINDS[_spark_kind[i]]
			var willow := _spark_kind[i] == Kind.WILLOW
			var k := s.z / s.w
			var fade := 1.0 - k * k
			var hue := _spark_col[i]
			var hot := Color(1, 0.98, 0.92).lerp(hue, minf(k * 1.8, 1.0))  # white-hot, cooling to its colour
			var head := Vector2(s.x, s.y)
			var length := minf(head.distance_to(_spark_from[i]) * lerpf(kind.trail.x, kind.trail.y, k), radius * 0.7)
			draw_set_transform(head, _spark_vel[i].angle())  # its head at 0, its path along -x
			if length > 3.0:
				var w: float = kind.width * 0.5 * (1.0 - 0.35 * k)
				draw_texture_rect_region(tex, Rect2(-length, -w, length, w * 2.0), streak, Color(hue, fade))
				draw_texture_rect_region(tex, Rect2(-length * 0.7, -w * 0.35, length * 0.7, w * 0.7), streak, Color(hot, fade))  # a bright core
			var glitter := 0.3 if willow else 0.6  # from when it glitters (a willow almost at once)
			if k < glitter or fmod(s.z * 22.0 + i * 0.37, 1.0) < 0.55:
				var r: float = kind.head * 1.2 * (1.0 - 0.35 * k)
				draw_texture_rect_region(tex, Rect2(-r, -r, r * 2.0, r * 2.0).grow(r * 1.4), glow, Color(hue, 0.35 * fade))  # its glow
				draw_texture_rect_region(tex, Rect2(-r, -r, r * 2.0, r * 2.0), dot, Color(hot, fade))
				if k > 0.65 and i % 3 == 0:
					draw_texture_rect_region(tex, Rect2(-13, -13, 26, 26), flare, Color(hot, fade))
		draw_set_transform(Vector2.ZERO)

	## A streak ending at `head` (its tail back along `angle`), `width` thick.
	func _streak(tex: Texture2D, src: Rect2, head: Vector2, angle: float, length: float, width: float, colour: Color,
			alpha: float) -> void:
		draw_set_transform(head, angle)
		draw_texture_rect_region(tex, Rect2(-length, -width / 2.0, length, width), src, Color(colour, colour.a * alpha))

	## A light `half` the size each way round `at`, turned by `angle`.
	func _light(tex: Texture2D, src: Rect2, at: Vector2, half: Vector2, angle: float, colour: Color) -> void:
		draw_set_transform(at, angle)
		draw_texture_rect_region(tex, Rect2(-half, half * 2.0), src, colour)


## A reward landing in a counter: a small flash, a ring and a few stars.
static func counter_pop(parent: Node, at: Vector2) -> void:
	glow(parent, at, Color(1, 0.92, 0.7, 0.9), 0.3, 1.3, 0.24)
	ring(parent, at, 26.0, 90.0, 0.32, Color(1, 0.95, 0.75, 0.9), 10.0)
	Confetti.make(parent, at).sparkle(7, SPARKS, Vector2(160, 380), 0.85, Vector2(0.35, 0.6))


## Panoramic takes a blow: the medium impact in red (shards thrown the way he is knocked, `push`),
## a few stars knocked loose.
static func impact(parent: Node, at: Vector2, push: float) -> void:
	impact_burst(parent, at, Vector2(push, -0.4).normalized(), &"medium", Color(1.0, 0.45, 0.3))
	var stars := Confetti.make(parent, at)
	stars.gravity = 1500.0
	stars.drag = 1.2
	stars.flutter = 0.0
	stars.spray(5, [Confetti.Shape.STAR], [Color("ffd36b"), Color("ffffff")], Vector2(300, 620),
			Vector2(push, -1.3).normalized(), 55.0, 0.9, Vector2(0.5, 0.75))


## A ring strikes a bandit: the small impact in the ring's blue, shards thrown the way it flew.
static func ring_hit(parent: Node, at: Vector2) -> void:
	impact_burst(parent, at, Vector2.RIGHT, &"small", RING_LIGHT[2])


## A bandit knocked out: the medium impact in the ring's blue (shards flung up and away), stars
## flying off and a puff of dust where he stood.
static func knock_out(parent: Node, at: Vector2, feet: Vector2) -> void:
	impact_burst(parent, at, Vector2(1, -0.4).normalized(), &"medium", RING_LIGHT[2])
	var stars := Confetti.make(parent, at)
	stars.gravity = 1400.0
	stars.drag = 1.4
	stars.flutter = 0.0
	stars.spray(8, [Confetti.Shape.STAR], [Color("ffd36b"), Color("ffe9a8"), Color("ffffff")], Vector2(320, 720),
			Vector2(0.6, -1).normalized(), 70.0, 1.0, Vector2(0.55, 0.85))
	stars.sparkle(6, RING_SPARKS, Vector2(160, 420), 1.0, Vector2(0.3, 0.55))
	dust(parent, feet, 10, 260.0, 0.0, 1.3)


## A metal glint: a four-point star of thin light that flicks open and shrinks away in `time`.
static func glint(parent: Node, at: Vector2, size: float, time: float) -> void:
	var node := Node2D.new()
	node.position = at
	node.rotation = randf_range(-0.3, 0.3)
	node.material = additive()
	parent.add_child(node)
	var state := [0.0]
	node.draw.connect(func() -> void:
		var k: float = state[0]
		var r := size * (0.6 + 0.4 * sin(minf(k * 2.0, 1.0) * PI * 0.5)) * (1.0 - k)
		var c := Color(1, 1, 1, 1.0 - k * k)
		node.draw_line(Vector2(-r, 0), Vector2(r, 0), c, 3.0 * (1.0 - k) + 1.0, true)
		node.draw_line(Vector2(0, -r * 0.7), Vector2(0, r * 0.7), c, 3.0 * (1.0 - k) + 1.0, true))
	var t := node.create_tween()
	t.tween_method(func(k: float) -> void:
		state[0] = k
		node.queue_redraw(), 0.0, 1.0, time)
	t.tween_callback(node.queue_free)


## Streaks of light flung out from a hit (`towards`: the way the blow went), each a tapered line
## that flies, slows and fades: the shrapnel of the ring's light.
static func shards(parent: Node, at: Vector2, towards: Vector2, count: int, power: float,
		tint := Color("6cc4ff")) -> void:
	var node := Node2D.new()
	node.position = at
	node.material = additive()
	parent.add_child(node)
	var bits: Array[Vector4] = []  # angle, speed, length, width
	for i in count:
		var a := towards.angle() + randf_range(-1.1, 1.1) if i % 3 != 0 else randf() * TAU
		bits.append(Vector4(a, randf_range(380.0, 820.0) * power, randf_range(26.0, 60.0) * power, randf_range(3.0, 6.0)))
	var state := [0.0]
	node.draw.connect(func() -> void:
		var k: float = state[0]
		var travel := 1.0 - pow(1.0 - k, 2.5)  # fast out, slowing
		for b in bits:
			var dir := Vector2.from_angle(b.x)
			var head := dir * b.y * 0.3 * travel
			var tail := head - dir * b.z * (1.0 - k)
			var c := tint.lightened(0.45).lerp(tint.darkened(0.2), k)
			node.draw_line(tail, head, Color(c, 0.9 * (1.0 - k)), b.w * (1.0 - 0.6 * k), true)
			node.draw_line(tail.lerp(head, 0.5), head, Color(1, 1, 1, 0.8 * (1.0 - k)), b.w * 0.4, true))
	var t := node.create_tween()
	t.tween_method(func(k: float) -> void:
		state[0] = k
		node.queue_redraw(), 0.0, 1.0, 0.32)
	t.tween_callback(node.queue_free)


## Draws a tapered ribbon along `path` (x, y, age; the newest first) on `canvas`, `width` wide at its
## head, fading out by `life` seconds of age, coloured from `head` to `tail`, with a thin bright core:
## one polygon and one line, whatever the length (the trails run every frame).
static func ribbon(canvas: CanvasItem, path: Array[Vector3], life: float, width: float, head: Color, tail: Color,
		core: Color) -> void:
	if path.size() < 2:
		return
	var with_core := core.a > 0.0
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var cols := PackedColorArray()
	var line := PackedVector2Array()
	var line_cols := PackedColorArray()
	for i in path.size():
		var p := Vector2(path[i].x, path[i].y)
		var q := Vector2(path[mini(i + 1, path.size() - 1)].x, path[mini(i + 1, path.size() - 1)].y)
		if i == path.size() - 1:
			q = p + (p - Vector2(path[i - 1].x, path[i - 1].y))
		var d := (q - p)
		var n := d.normalized().orthogonal() if d.length_squared() > 0.01 else Vector2.UP
		var k := clampf(1.0 - path[i].z / life, 0.0, 1.0)
		left.append(p + n * width * 0.5 * k)
		right.append(p - n * width * 0.5 * k)
		cols.append(Color(head.lerp(tail, 1.0 - k), head.a * k))
		line.append(p)
		line_cols.append(Color(core, core.a * k * k))
	right.reverse()
	var rc := cols.duplicate()
	rc.reverse()
	left.append_array(right)
	cols.append_array(rc)
	if Geometry2D.triangulate_polygon(left).size() > 0:
		canvas.draw_polygon(left, cols)
	if with_core:
		canvas.draw_polyline_colors(line, line_cols, 3.0, true)


## The ring leaving his hand: a flash of blue light, a small ring and sparks thrown forward.
static func ring_launch(parent: Node, at: Vector2) -> void:
	glow(parent, at, Color(0.5, 0.8, 1.0, 0.8), 0.2, 1.0, 0.16)
	ring(parent, at, 10.0, 54.0, 0.18, Color(0.75, 0.9, 1.0, 0.85), 6.0)
	var c := Confetti.make(parent, at)
	c.sparkle(5, RING_SPARKS, Vector2(220, 520), 0.7, Vector2(0.18, 0.32))


## The light of a ring in flight, over its picture (RingView): a bloom breathing round it, a long
## tapered ribbon of blue light with a white-hot core behind it, sparks shed along its path that
## drift and fade. It follows the rules' ring (`world`, `r`: play units, drawn at twice the size
## here, like everything in the effects layer) and, once the ring is gone, lets its light die away.
static func ring_flight(parent: Node, world: World, r: World.Ring) -> void:
	var f := RingFlight.new()
	f.world = world
	f.ring = r
	f.material = additive()
	parent.add_child(f)


class RingFlight extends Node2D:
	const TRAIL_TIME := 0.05  ## seconds of path the streak keeps: 3 frames, a motion smear, not a beam
	const WIDTH := 34.0  ## the streak's width at the ring (effects px)
	var world: World
	var ring: World.Ring
	var _path: Array[Vector3] = []  # x, y, age
	var _sparks: Array[Vector4] = []  # x, y, age, life
	var _drift: Array[Vector2] = []
	var _clock := 0.0
	var _flying := true
	var _at := Vector2.ZERO

	## The ring's picture (WorldView's RingView for it), where its light goes: RingView launches it
	## from his hand, so the light follows the picture, not the rules.
	func _ring_view() -> Node2D:
		var rings: Variant = get_parent().get_parent().get(&"_rings") if get_parent() and get_parent().get_parent() else null
		var v: Variant = (rings as Dictionary).get(ring.id) if rings is Dictionary else null
		return v if is_instance_valid(v) else null

	func _process(delta: float) -> void:
		_clock += delta
		if _flying:
			_flying = world.rings.has(ring) and world.state == World.State.RUNNING
		if _flying:
			var drawn: Node2D = _ring_view()
			_at = (drawn.position if drawn else Vector2(lerpf(ring.prev_x, ring.x, world.alpha) + 12.0, ring.y + 14.0)) * 2.0
			_path.push_front(Vector3(_at.x, _at.y, 0.0))
			if randf() < delta * 20.0:
				_sparks.append(Vector4(_at.x + randf_range(-14, 14), _at.y + randf_range(-18, 18), 0.0, randf_range(0.2, 0.4)))
				_drift.append(Vector2(randf_range(-160, -40), randf_range(-60, 60)))
		for i in _path.size():
			_path[i].z += delta
		while not _path.is_empty() and _path[_path.size() - 1].z > TRAIL_TIME:
			_path.pop_back()
		for i in range(_sparks.size() - 1, -1, -1):
			_sparks[i].z += delta
			_sparks[i].x += _drift[i].x * delta
			_sparks[i].y += _drift[i].y * delta
			if _sparks[i].z > _sparks[i].w:
				_sparks.remove_at(i)
				_drift.remove_at(i)
		if not _flying and _path.is_empty() and _sparks.is_empty():
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var tex := Fx.glow_texture()
		Fx.ribbon(self, _path, TRAIL_TIME, WIDTH, Color(Fx.RING_LIGHT[1], 0.5), Fx.RING_LIGHT[3], Color(1, 1, 1, 0.0))
		for sp in _sparks:
			var k := 1.0 - sp.z / sp.w
			var r := 7.0 + 6.0 * k
			draw_texture_rect(tex, Rect2(Vector2(sp.x, sp.y) - Vector2(r, r), Vector2(r, r) * 2), false, Color(Fx.RING_LIGHT[1], k))
		if _flying:
			var r := 40.0 * (1.0 + 0.1 * sin(_clock * 30.0))  # (RingView has its own halo)
			draw_texture_rect(tex, Rect2(_at - Vector2(r, r), Vector2(r, r) * 2), false, Color(0.35, 0.65, 1.0, 0.22))


## A Red Bob flying to the counter (screen units): it pops, rises a little (an overshoot up),
## then curves in, slow at first and accelerating into the counter, shrinking; a tapered streak
## of warm light behind it, sparks shed on the way; `arrived` runs when it lands. At most
## MAX_FLIERS fly at once: more just land at once (the counter already counts them).
static func bob_flight(parent: Node, from: Vector2, to: Vector2, start_size: float, end_size: float,
		arrived: Callable) -> void:
	if _fliers >= MAX_FLIERS:
		arrived.call()
		return
	_fliers += 1
	var s := Sprite2D.new()
	s.texture = BobView.texture()  # the row's face for its first frames, then joy as it flies
	var k0 := BobView.scale_for(start_size)
	var k1 := BobView.scale_for(end_size) * 0.8
	s.position = from
	s.scale = Vector2.ONE * k0
	var light := BobStreak.new()  # normal blending: over the sky an added orange would wash out to white
	parent.add_child(light)
	parent.add_child(s)
	light.ball = s
	light.width = start_size * 0.8
	var c1 := from + Vector2(-30.0, -minf(110.0, 50.0 + from.distance_to(to) * 0.12))  # up first
	var c2 := to + Vector2(-minf(220.0, from.distance_to(to) * 0.35), 70.0)  # comes in from below-left
	var t := s.create_tween()
	t.tween_property(s, "scale", Vector2.ONE * k0 * 1.2, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void: s.texture = BobView.texture(BobView.Face.JOY))
	t.tween_method(func(u: float) -> void:
		var e := pow(u, 1.7)  # slow for the first third, then fast into the counter
		s.position = from.bezier_interpolate(c1, c2, to, e)
		light.follow(s.position)  # the streak's head moves with the ball, in the same step
		s.rotation = -0.6 * u
		s.scale = Vector2.ONE * lerpf(k0 * 1.15, k1, e), 0.0, 1.0, 0.5)
	t.tween_callback(func() -> void:
		s.set_meta(&"landed", true)
		arrived.call()
		light.ball = null
		s.queue_free())
	s.tree_exiting.connect(_flier_gone.bind(s))  # landed, or the screen left with it in the air


static func _flier_gone(ball: Node) -> void:
	_fliers = maxi(_fliers - 1, 0)


## "×N" for a streak of Red Bobs, popping at the pickup (effects units) beside him: big, rising
## and fading in half a second, white, then yellow, orange and red as the streak grows.
static func streak_pop(parent: Node, at: Vector2, n: int) -> void:
	if is_instance_valid(_streak_badge):  # the new count takes the place of the last
		_streak_badge.queue_free()
	var node := Node2D.new()
	_streak_badge = node
	node.z_index = 2  # (in view.fx, z 10) over the Red Bobs flying to the counter (z 11), under the panels (20)
	node.position = at + Vector2(30, -40)
	var font := plus_font()
	var text := "×%d" % n
	# one font size and outline for every step, the "+1"'s (each new size would cache its own glyph
	# pages: megabytes of texture per step); the badge grows with the node's scale instead
	var grow := (0.62 + 0.05 * mini(n, 8)) * STREAK_SIZE_K / 0.8
	var colour := STREAK_TIERS[clampi((n - 2) / 2, 0, STREAK_TIERS.size() - 1)]
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE).x
	var base := Vector2(-w / 2, PLUS_SIZE * 0.36)
	node.draw.connect(func() -> void:
		node.draw_string_outline(font, base + Vector2(4, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, BADGE_OUTLINES[0], Color(0.08, 0.03, 0.0, 0.5))
		node.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, BADGE_OUTLINES[0], Color("2a1204"))
		node.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, BADGE_OUTLINES[1], colour.darkened(0.35))
		node.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, colour))
	parent.add_child(node)
	node.scale = Vector2.ONE * 0.4 * grow
	node.rotation = -0.15
	var t := node.create_tween().set_parallel(true)
	t.tween_property(node, "scale", Vector2.ONE * 1.25 * grow, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "rotation", 0.0, 0.2)
	t.tween_property(node, "position:y", node.position.y - 80.0, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE * grow, 0.15).set_delay(0.1)
	t.tween_property(node, "modulate:a", 0.0, 0.2).set_delay(0.3)
	t.chain().tween_callback(node.queue_free)


class BobStreak extends Node2D:
	const TRAIL_TIME := 0.08  ## seconds of path the streak keeps (it retracts fast once the ball lands)
	var ball: Node2D
	var width := 24.0
	var _path: Array[Vector3] = []  # x, y, age: the newest first, pushed by the flight (follow)
	var _sparks: Array[Vector4] = []

	func follow(at: Vector2) -> void:
		_path.push_front(Vector3(at.x, at.y, 0.0))
		queue_redraw()

	func _process(delta: float) -> void:
		var flying := is_instance_valid(ball)
		if flying and not _path.is_empty() and randf() < delta * 40.0:
			_sparks.append(Vector4(_path[0].x + randf_range(-5, 5), _path[0].y + randf_range(-5, 5), 0.0, randf_range(0.18, 0.32)))
		for i in _path.size():
			_path[i].z += delta * (1.0 if flying else 3.0)
		while _path.size() > 1 and _path[_path.size() - 1].z > TRAIL_TIME:
			_path.pop_back()
		if not flying and not _path.is_empty() and _path[0].z > TRAIL_TIME:
			_path.clear()
		for i in range(_sparks.size() - 1, -1, -1):
			_sparks[i].z += delta
			_sparks[i].y += 40.0 * delta
			if _sparks[i].z > _sparks[i].w:
				_sparks.remove_at(i)
		if not flying and _path.is_empty() and _sparks.is_empty():
			queue_free()
		queue_redraw()

	func _draw() -> void:
		Fx.ribbon(self, _path, TRAIL_TIME, width, Color(Fx.BOB_LIGHT[2], 0.6), Fx.BOB_LIGHT[3], Color(Fx.BOB_LIGHT[1], 0.85))
		var tex := Fx.glow_texture()
		for sp in _sparks:
			var k := 1.0 - sp.z / sp.w
			var r := 4.0 + 4.0 * k
			draw_texture_rect(tex, Rect2(Vector2(sp.x, sp.y) - Vector2(r, r), Vector2(r, r) * 2), false, Color(Fx.BOB_LIGHT[1], k))


## A Red Bob taken in a streak (`combo` 0 for the first), on top of the pickup's own light
## (WorldView): from the second in a row a ring that grows with the streak, turning from warm red to
## gold, with a glow; every 5th a burst of rays. Light: a fast run of Bobs stays cheap to draw.
static func bob_pop(parent: Node, at: Vector2, combo: int) -> void:
	if combo < 1:
		return
	var k := minf(combo / 6.0, 1.0)
	var c := Color("ff8a4a").lerp(Color("ffd36b"), k)
	# added light, so the order doesn't show: the shapes first (ring, rays), then the soft light (glow,
	# sparks), so each kind batches into one draw call
	ring(parent, at, 12.0, 70.0 + 50.0 * k, 0.26, Color(c, 0.9), 6.0 + 4.0 * k)
	if combo % 5 == 4:
		rays(parent, at, Color(c, 0.45), 8, 150.0, 0.3)
	glow(parent, at, Color(c, 0.5 + 0.3 * k), 0.3, 1.0 + 0.8 * k, 0.22)
	if combo % 5 == 4:
		Confetti.make(parent, at).sparkle(8, SPARKS, Vector2(160, 520), 0.9, Vector2(0.3, 0.55))


## Home: the doorway's warm light (`at`: the middle of the doorway, effects units) as soft light
## that keeps him readable: a long flat pool of it on the ground at the threshold, breathing, and
## long rays fanning from the top of the doorway (over his head, not through him); embers rising from
## the hearth. (The doorway's own firelight is the hut's; nothing is added over his body.)
static func home_glow(parent: Node, at: Vector2) -> void:
	var g := Sprite2D.new()
	g.texture = glow_texture()
	g.material = additive()
	g.position = at + Vector2(0.0, 130.0)  # the threshold: the doorway's foot
	g.modulate = Color(1, 0.78, 0.48, 0.0)
	g.scale = Vector2(10.0, 1.5) * 0.6
	parent.add_child(g)
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.2, 0.6).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(g, "scale", Vector2(10.0, 1.5), 1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	for i in 3:
		t.tween_property(g, "modulate:a", 0.15, 0.5).set_trans(Tween.TRANS_SINE)
		t.tween_property(g, "modulate:a", 0.2, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(g, "modulate:a", 0.0, 0.8)
	t.tween_callback(g.queue_free)
	# (env, round 10: no rays from the doorway: "flat orange stripe rays: a cheap starburst"; the
	# hut's light spills out on the ground instead, HomeView)
	var p := CPUParticles2D.new()
	p.position = at + Vector2(0, 40)
	p.material = additive()
	p.texture = glow_texture()
	p.amount = 46
	p.lifetime = 1.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(70, 30)
	p.direction = Vector2.UP
	p.spread = 35.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 190.0
	p.gravity = Vector2(25, -90)
	p.damping_min = 10.0
	p.damping_max = 40.0
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.16
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(EMBERS[0], 0.0), Color(EMBERS[0], 1.0), Color(EMBERS[1], 0.8), Color(EMBERS[2], 0.0)])
	p.color_ramp = fade
	parent.add_child(p)
	p.emitting = true
	var stop := p.create_tween()  # owned by the embers: it goes with them if the screen is left
	stop.tween_interval(2.6)
	stop.tween_property(p, "emitting", false, 0.0)
	stop.tween_interval(p.lifetime + 0.1)
	stop.tween_callback(p.queue_free)


## The win's shower over the results (`width` x `height`, screen units; `parent` is behind him and
## the card): shaded two-tone paper in the sunset's golds and red fluttering down beside the card for
## the whole reveal, blurred by its motion, most of it behind him and the card (they hide what passes
## behind them: depth), and in front of everything only where nothing is behind it (left of him,
## right of the card; fading if it drifts over the card or him): gold coins tumbling and glinting as
## they turn, some paper, gold motes twinkling; the coins' tinkle.
static func coin_shower(parent: Node, width: float, height: float) -> void:
	var front: Node = parent.get_parent() if parent.get_parent() else parent  # the panel: over everything
	var holder := Node2D.new()
	front.add_child(holder)
	var to_local := holder.get_global_transform().affine_inverse()
	var card := Rect2(width * 0.3, 0.0, width * 0.4, height)  # the card and him, if the panel says where
	var hero := Rect2()
	var c: Variant = front.get(&"card")
	if c is Control and is_instance_valid(c):
		card = to_local * (c as Control).get_global_rect()
		hero = _hero_rect(c, to_local)
	card = card.grow(12.0)
	var sides := [Vector2(0.0, maxf(card.position.x, 0.0)), Vector2(card.end.x, maxf(width - card.end.x, 0.0))]
	for side: Vector2 in sides:  # behind: the paper of both margins
		if side.y < 20.0:
			continue
		var paper := Confetti.make(parent, Vector2(side.x, 0.0))  # slow paper: in the air all the reveal
		paper.gravity = 520.0
		paper.drag = 2.2
		paper.flutter = 420.0
		paper.rain(int(44 * side.y / width) + 6, side.y, WIN_SHAPES, PAPER_COLOURS, 1.15, Vector2(3.4, 4.2), 2.2)
	var left := (hero.position.x if hero.has_area() else card.position.x) - 8.0  # the sky left of him
	var clear := [Vector3(0.0, left, 0.0), Vector3(card.end.x, width - card.end.x, 1.0)]
	for strip: Vector3 in clear:  # in front: x, width, 1 right of the card
		if strip.y < 40.0:
			continue
		var share := strip.y / width
		var avoid := card if strip.z > 0.0 else (hero if hero.has_area() else card)
		var coins := Confetti.make(holder, Vector2(strip.x, 0.0))
		coins.gravity = 1100.0
		coins.drag = 0.8
		coins.flutter = 40.0
		coins.avoid = Rect2(avoid.position - coins.position, avoid.size)
		coins.rain(int(30 * share) + 3, strip.y, [Confetti.Shape.COIN], GOLD, 1.6, Vector2(1.8, 2.4), 2.0)
		var paper := Confetti.make(holder, Vector2(strip.x, 0.0))
		paper.gravity = 560.0
		paper.drag = 2.1
		paper.flutter = 420.0
		paper.avoid = coins.avoid
		paper.rain(int(26 * share) + 3, strip.y, WIN_SHAPES, PAPER_COLOURS, 1.3, Vector2(3.2, 4.0), 2.2)
		var motes := Confetti.make(holder, Vector2(strip.x + strip.y / 2.0, height * 0.35))
		motes.avoid = Rect2(avoid.position - motes.position, avoid.size)
		motes.sparkle(8, GOLD, Vector2(120, 420), 0.8, Vector2(0.6, 1.1), strip.y * 0.4)
	Audio.play_sfx(&"coins")


## Panoramic's picture beside the results card (the panel's art: it carries a "tall" meta), in the
## coordinates `to_local` takes the screen to, or an empty rectangle.
static func _hero_rect(card: Control, to_local: Transform2D) -> Rect2:
	for n: Node in card.get_parent().get_children():
		if n is Control and n.has_meta(&"tall") and (n as Control).visible:
			return to_local * (n as Control).get_global_rect()
	return Rect2()


## A body falling into a pool (or leaping out): a column of water thrown up and falling back, drops
## of several sizes, two ripple rings spreading flat on the surface, a ring of foam.
static func splash(parent: Node, at: Vector2, size := 1.0) -> void:
	var column := Sprite2D.new()  # the column: a soft white plume that rises and collapses
	column.texture = puff_texture()
	column.position = at
	column.modulate = Color(0.9, 0.98, 1.0, 0.85)
	column.offset = Vector2(0, -column.texture.get_height() / 2.0)
	column.scale = Vector2(0.9, 0.3) * size
	parent.add_child(column)
	var t := column.create_tween()
	t.tween_property(column, "scale", Vector2(0.6, 2.6) * size, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(column, "scale", Vector2(1.2, 0.4) * size, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(column, "modulate:a", 0.0, 0.3)
	t.tween_callback(column.queue_free)
	for spec: Array in [[22, Vector2(380, 900), 0.6], [10, Vector2(250, 650), 1.1]]:  # small and big drops
		var drops := burst(parent, at, [Color(1, 1, 1, 0.95), Color("c9f1fb"), Color("86d9ee")] as Array[Color],
				int(spec[0] * size), spec[1] * size, 2200.0, 0.85, spec[2] * size)
		drops.texture = puff_texture()
		drops.direction = Vector2.UP
		drops.spread = 32.0
		drops.angular_velocity_min = 0.0
		drops.angular_velocity_max = 0.0
		drops.damping_min = 10.0
		drops.damping_max = 40.0
	for k in 2:  # the ripples, seen from the side: flat rings, the second a little later
		var ring_node := Node2D.new()
		ring_node.position = at
		ring_node.scale = Vector2(1.0, 0.2)
		parent.add_child(ring_node)
		var later := ring_node.create_tween()  # owned by the ripple: it goes with it if the screen is left
		later.tween_interval(k * 0.18)
		later.tween_callback(Fx.ring.bind(ring_node, Vector2.ZERO, 20.0, (130.0 + k * 60.0) * size, 0.7,
				Color(1, 1, 1, 0.85 - k * 0.3), 9.0 - k * 3.0))
		later.tween_interval(0.8)
		later.tween_callback(ring_node.queue_free)
	dust(parent, at, int(8 * size), 260.0 * size, 0.0, 1.1 * size)  # foam spreading on the surface


## Savanna dust kicked up at the feet: soft pale puffs that swell and fade, spreading along the
## ground (`spread` px/s), rising a little, and carried by the ground (`drift` px/s, the scroll).
static func dust(parent: Node, at: Vector2, amount: int, spread: float, drift: float, size := 1.0) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.5
	p.texture = puff_texture()
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(14, 3)
	p.direction = Vector2(-0.25, -1)
	p.spread = 80.0
	p.initial_velocity_min = spread * 0.35
	p.initial_velocity_max = spread
	p.gravity = Vector2(0, -60)
	p.damping_min = spread * 1.2
	p.damping_max = spread * 2.0
	p.scale_amount_min = 0.3 * size
	p.scale_amount_max = 0.6 * size
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(0.4, 1.0))
	grow.add_point(Vector2(1, 1.3))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([Color(0.96, 0.88, 0.74, 0.0), Color(0.96, 0.88, 0.74, 0.55), Color(0.92, 0.82, 0.66, 0)])
	p.color_ramp = fade
	parent.add_child(p)
	p.emitting = true
	# carried along with the ground as it scrolls
	if drift != 0.0:
		p.create_tween().tween_property(p, "position:x", at.x + drift * p.lifetime * 1.2, p.lifetime * 1.2)
	p.finished.connect(p.queue_free)


## The hero falling into the bushes: leaves torn off and fluttering down.
static func leaves(parent: Node, at: Vector2) -> void:
	var c := Confetti.make(parent, at)
	c.gravity = 700.0
	c.drag = 2.4
	c.flutter = 900.0
	c.glints = false
	c.spray(26, [Confetti.Shape.LEAF], LEAVES, Vector2(320, 780), Vector2.UP, 60.0, 1.2, Vector2(1.0, 1.5), 50.0)


## A puff of dust off the ledge where his hands catch it.
static func chalk(parent: Node, at: Vector2) -> void:
	var p := burst(parent, at, CHALK, 6, Vector2(50, 140), -40.0, 0.38, 0.32)
	p.texture = puff_texture()
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.angular_velocity_min = 0.0
	p.angular_velocity_max = 0.0
	p.angle_max = 0.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	p.color_ramp = fade


## The confetti of a new best score, falling from above a strip `width` wide.
static func confetti_rain(parent: Node, width: float) -> Confetti:
	var c := Confetti.make(parent, Vector2.ZERO)
	c.gravity = 800.0
	c.drag = 1.6
	c.flutter = 560.0
	c.rain(90, width, PAPER_SHAPES, PAPER_COLOURS, 1.8, Vector2(2.6, 3.4), 0.8)
	return c


## A flash of soft light that swells and fades.
static func glow(parent: Node, at: Vector2, colour: Color, from_scale: float, to_scale: float, time: float) -> void:
	var g := Sprite2D.new()
	g.texture = glow_texture()
	g.material = additive()
	g.position = at
	g.scale = Vector2.ONE * from_scale
	g.modulate = colour
	parent.add_child(g)
	var t := g.create_tween().set_parallel(true)
	t.tween_property(g, "scale", Vector2.ONE * to_scale, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(g, "modulate:a", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(g.queue_free)


## A burst of light rays that open, turn a little and fade.
static func rays(parent: Node, at: Vector2, colour: Color, count: int, length: float, time: float) -> void:
	var node := Node2D.new()
	node.position = at
	node.rotation = randf() * TAU
	node.material = additive()
	parent.add_child(node)
	var state := [0.0]
	node.draw.connect(func() -> void:
		var k: float = state[0]
		var r := length * (0.45 + 0.55 * (1.0 - pow(1.0 - k, 3.0)))
		var c := Color(colour, colour.a * (1.0 - k * k))
		for i in count:
			var a := i * TAU / count
			var w := TAU / count * (0.2 if i % 2 == 0 else 0.11)
			var reach := r * (1.0 if i % 2 == 0 else 0.72)
			node.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - w) * reach, Vector2.from_angle(a + w) * reach]),
					PackedColorArray([c, Color(c, 0), Color(c, 0)])))
	var t := node.create_tween().set_parallel(true)
	t.tween_method(func(k: float) -> void:
		state[0] = k
		node.queue_redraw(), 0.0, 1.0, time)
	t.tween_property(node, "rotation", node.rotation + 0.5, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(node.queue_free)


## Speed lines shooting out from a point.
static func lines(parent: Node, at: Vector2, colour: Color, count: int, from_radius: float, to_radius: float, time: float) -> void:
	var node := Node2D.new()
	node.position = at
	node.material = additive()
	parent.add_child(node)
	var angles: Array[float] = []
	for i in count:
		angles.append((i + randf_range(-0.3, 0.3)) * TAU / count)
	var state := [0.0]
	node.draw.connect(func() -> void:
		var k: float = state[0]
		var head := lerpf(from_radius, to_radius, 1.0 - pow(1.0 - k, 2.0))
		var tail := lerpf(from_radius * 0.6, to_radius, 1.0 - pow(1.0 - k, 1.2))
		for a in angles:
			node.draw_line(Vector2.from_angle(a) * tail, Vector2.from_angle(a) * head, Color(colour, colour.a * (1.0 - k)),
					lerpf(7.0, 2.0, k)))
	var t := node.create_tween()
	t.tween_method(func(k: float) -> void:
		state[0] = k
		node.queue_redraw(), 0.0, 1.0, time)
	t.tween_callback(node.queue_free)


## An expanding ring of light.
static func ring(parent: Node, at: Vector2, from_radius: float, to_radius: float, time: float, colour: Color,
		width := 10.0) -> void:
	var node := Node2D.new()
	node.position = at
	node.material = additive()
	parent.add_child(node)
	var state := [0.0]
	node.draw.connect(func() -> void:
		var k: float = state[0]
		var r := lerpf(from_radius, to_radius, 1.0 - pow(1.0 - k, 3.0))
		var c := Color(colour, colour.a * (1.0 - k) * (1.0 - k))
		node.draw_arc(Vector2.ZERO, r, 0, TAU, 56, c, lerpf(width, 2.0, k), true)
		node.draw_arc(Vector2.ZERO, r - lerpf(width, 2.0, k) * 0.9, 0, TAU, 56, Color(c, c.a * 0.35), lerpf(width, 2.0, k) * 1.6, true))
	var t := node.create_tween()
	t.tween_method(func(k: float) -> void:
		state[0] = k
		node.queue_redraw(), 0.0, 1.0, time)
	t.tween_callback(node.queue_free)


## A ribbon that fades behind a moving node (`seconds` long), added onto the scene if `light`.
static func trail(parent: Node, target: Node2D, colour: Color, width: float, seconds: float, light := false) -> Trail:
	var t := Trail.new()
	t.target = target
	t.colour = colour
	t.width = width
	t.seconds = seconds
	if light:
		t.material = additive()
	parent.add_child(t)
	return t


class Trail extends Node2D:
	var target: Node2D
	var colour := Color.WHITE
	var width := 20.0
	var seconds := 0.15
	var _points: Array[Vector3] = []  # x, y, time
	var _clock := 0.0

	func _process(delta: float) -> void:
		_clock += delta
		var following := is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree()
		if following:
			var p := to_local(target.global_position)
			_points.append(Vector3(p.x, p.y, _clock))
		while not _points.is_empty() and _clock - _points[0].z > seconds:
			_points.pop_front()
		if _points.is_empty() and not following:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for i in range(1, _points.size()):
			var a := Vector2(_points[i - 1].x, _points[i - 1].y)
			var b := Vector2(_points[i].x, _points[i].y)
			if a.distance_squared_to(b) < 0.01:
				continue
			var n := (b - a).normalized().orthogonal()
			var ka := clampf(1.0 - (_clock - _points[i - 1].z) / seconds, 0.0, 1.0)
			var kb := clampf(1.0 - (_clock - _points[i].z) / seconds, 0.0, 1.0)
			var ca := Color(colour, colour.a * ka * ka)
			var cb := Color(colour, colour.a * kb * kb)
			draw_primitive(PackedVector2Array([a + n * width * 0.5 * ka, b + n * width * 0.5 * kb, b - n * width * 0.5 * kb,
					a - n * width * 0.5 * ka]), PackedColorArray([ca, cb, cb, ca]), PackedVector2Array())


static func additive() -> CanvasItemMaterial:
	if not _additive:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


## The material of the "+1": its white letters filled white to gold to amber (badge_text.gdshader).
static func badge_material() -> ShaderMaterial:
	if not _badge:
		_badge = ShaderMaterial.new()
		_badge.shader = preload("res://src/game/badge_text.gdshader")
		_badge.set_shader_parameter(&"top_colour", Color("ffffff"))  # a white top that reads on sky and earth,
		_badge.set_shader_parameter(&"mid_colour", Color("ffe98a"))  # gold through its middle, amber at its
		_badge.set_shader_parameter(&"bottom_colour", Color("ffb12a"))  # foot (inside a cream rim, a dark stroke)
		_badge.set_shader_parameter(&"top_y", -PLUS_SIZE * 0.42)
		_badge.set_shader_parameter(&"bottom_y", PLUS_SIZE * 0.38)
	return _badge


static func plus_font() -> Font:
	if not _plus_font:
		_plus_font = Ui.title_font(700)
	return _plus_font


## A soft round light (white centre fading out), 128 px.
static func glow_texture() -> Texture2D:
	if not _glow_tex:
		var g := GradientTexture2D.new()
		g.width = 128
		g.height = 128
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.gradient = Gradient.new()
		g.gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		g.gradient.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 0.96, 0.85, 0.55), Color(1, 1, 1, 0)])
		_glow_tex = g
	return _glow_tex


## A ball of dust lit from the upper left: lighter there, shaded down-right, soft at the edge.
static func puff_texture() -> Texture2D:
	if not _puff_tex:
		var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var u := Vector2(x + 0.5, y + 0.5) / 32.0 - Vector2.ONE
				var r := u.length()
				var light := clampf(0.5 + 0.5 * u.dot(Vector2(-0.6, -0.8)) / maxf(r, 0.001) * minf(r * 2.0, 1.0), 0.0, 1.0)
				var l := 0.74 + 0.26 * light
				img.set_pixel(x, y, Color(l, l, l, pow(clampf(1.0 - r, 0.0, 1.0), 1.4)))
		img.generate_mipmaps()
		_puff_tex = ImageTexture.create_from_image(img)
	return _puff_tex


## The edges of the screen only (white: tinted by its user), for the red of a blow: clear over
## most of the picture, so the blow itself stays readable.
static func edge_texture() -> Texture2D:
	if not _edge_tex:
		var g := GradientTexture2D.new()  # 128 px: a smooth ramp, stretched over the screen
		g.width = 128
		g.height = 128
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.05, 0.5)
		g.gradient = Gradient.new()
		g.gradient.offsets = PackedFloat32Array([0.0, 0.62, 0.82, 1.0])
		g.gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 1)])
		_edge_tex = g
	return _edge_tex


static func vignette_texture() -> Texture2D:
	if not _vignette_tex:
		var g := GradientTexture2D.new()
		g.width = 256
		g.height = 256
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.15, 0.5)
		g.gradient = Gradient.new()
		g.gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.05), Color(1, 1, 1, 1)])
		_vignette_tex = g
	return _vignette_tex


static func burst(parent: Node, at: Vector2, colours: Array[Color], amount: int, speed: Vector2,
		gravity: float, lifetime: float, size: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = lifetime
	p.texture = confetti_texture()
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector2(0, gravity)
	p.damping_min = 60.0
	p.damping_max = 160.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.55 * size
	p.scale_amount_max = 1.0 * size
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(0.7, 0.9))
	shrink.add_point(Vector2(1, 0))
	p.scale_amount_curve = shrink
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array(range(colours.size()).map(func(i: int) -> float: return float(i) / colours.size()))
	g.colors = PackedColorArray(colours)
	p.color_initial_ramp = g
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Draws each of the game's shaders once, almost invisible, so that they are compiled while the
## logo shows and the first pickup, hit or game over doesn't stutter; starts baking the confetti.
## Nothing here reads the screen (a shader that does, or a CanvasGroup, makes Godot keep a back buffer
## the size of the window for good: 15 MB on an iPhone, 29 MB on an iPad).
static func warm_up(parent: Control) -> void:
	var holder := Control.new()
	holder.modulate.a = 0.01
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for shader: Shader in [preload("res://src/game/light_grade.gdshader"),
			preload("res://src/game/flash.gdshader"), preload("res://src/game/water.gdshader"),
			preload("res://src/game/sway.gdshader"), preload("res://src/game/actor.gdshader"),
			preload("res://src/ui/shine.gdshader"), preload("res://src/game/water_front.gdshader"),
			preload("res://src/ui/portrait.gdshader")]:
		var rect := ColorRect.new()  # the light grade, a flash, the water, the swaying grass
		rect.size = Vector2(4, 4)
		rect.material = ShaderMaterial.new()
		rect.material.shader = shader
		holder.add_child(rect)
	var glow_dot := Sprite2D.new()
	glow_dot.texture = glow_texture()
	glow_dot.material = additive()
	glow_dot.scale = Vector2(0.05, 0.05)
	holder.add_child(glow_dot)
	var text := Node2D.new()
	text.material = badge_material()  # the "+1"'s shader compiled now, not at the first knock-out
	text.draw.connect(_draw_badge_glyphs.bind(text))
	holder.add_child(text)
	Confetti.bake_soon()  # the confetti's atlas, on a thread: not in this frame, nor at the first pickup
	parent.add_child(holder)
	var t := holder.create_tween()
	t.tween_interval(0.3)
	t.tween_callback(holder.queue_free)


## The "+1" and the streak's "×N" glyphs, rasterised once (at the sizes and outlines they use) by an
## invisible node under `parent` that then goes: the level calls it as it loads, so no knock-out or
## streak in play allocates them (each size and outline is megabytes of glyph pages).
static func warm_glyphs(parent: Node) -> void:
	var text := Node2D.new()
	text.modulate.a = 0.01
	text.material = badge_material()
	text.draw.connect(_draw_badge_glyphs.bind(text))
	parent.add_child(text)
	var t := text.create_tween()
	t.tween_interval(0.1)
	t.tween_callback(text.queue_free)


static func _draw_badge_glyphs(text: Node2D) -> void:
	var f := plus_font()
	for o: int in BADGE_OUTLINES:
		text.draw_string_outline(f, Vector2(0, 10), "+×0123456789", HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, o)
	text.draw_string(f, Vector2(0, 10), "+×0123456789", HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE)


static func confetti_texture() -> Texture2D:
	if not _confetti_tex:
		var img := Image.create_empty(28, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(27, 0), Vector2i(0, 15), Vector2i(27, 15)]:
			img.set_pixelv(corner, Color(1, 1, 1, 0))
		_confetti_tex = ImageTexture.create_from_image(img)
	return _confetti_tex


static func bubble_texture() -> Texture2D:
	if not _bubble_tex:
		var g := GradientTexture2D.new()
		g.width = 48
		g.height = 48
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.gradient = Gradient.new()
		g.gradient.offsets = PackedFloat32Array([0.0, 0.62, 0.8, 1.0])
		g.gradient.colors = PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.75), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_bubble_tex = g
	return _bubble_tex

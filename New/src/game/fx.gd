class_name Fx
## One-shot effects (from the Super Gassamanh kit): the "+1" pop, flashes and confetti, blows,
## leaves, trails, and the confetti of a win. What should look solid (confetti, leaves,
## stone chips) is Confetti: shaded pieces that tumble; what is light (flashes, rays, glints, rings)
## is added onto the scene.

# Chaka Zulu: sunset orange, gold, the Red Bob red, the ring blue, savanna green, white.
const CONFETTI: Array[Color] = [Color("f2662e"), Color("ffd36b"), Color("e82808"), Color("3a8fd8"), Color("a8c808"), Color("ffffff")]
## Party colours: the brand sunset with the reward colours (gold, red, blue) and white.
const PARTY: Array[Color] = [Color("f2662e"), Color("ff9a5a"), Color("e82808"), Color("ffd36b"), Color("3a8fd8"), Color("a8c808"), Color("ffffff")]
## Blue sparks of a ring hitting a bandit.
const RING_SPARKS: Array[Color] = [Color("ffffff"), Color("8fd0ff"), Color("3fa2ff")]
## Red Bob bits.
const BOB_BITS: Array[Color] = [Color("e82808"), Color("ff6a4a"), Color("ffd36b"), Color("ffffff")]
const SPARKS: Array[Color] = [Color("ffffff"), Color("ffd36b"), Color("fff0c2")]
const STONE_DUST: Array[Color] = [Color("c69c6d"), Color("f1d0ad"), Color("a57b4f")]
const STONE_CHIPS: Array[Color] = [Color("a57b4f"), Color("8a6440"), Color("c69c6d"), Color("6e4c2e")]
const LEAVES: Array[Color] = [Color("99ce40"), Color("8abd31"), Color("76a22a"), Color("aedb5a")]
const CHALK: Array[Color] = [Color(1, 1, 1)]
## The mix of confetti pieces: mostly paper, some ribbons, sequins and stars.
const PARTY_SHAPES := [Confetti.Shape.PAPER, Confetti.Shape.PAPER, Confetti.Shape.PAPER, Confetti.Shape.RIBBON,
		Confetti.Shape.SEQUIN, Confetti.Shape.STAR]
const PLUS_SIZE := 118  ## font size of the "+1" (design px)

static var _confetti_tex: Texture2D
static var _bubble_tex: Texture2D
static var _glow_tex: Texture2D
static var _impact_tex: Texture2D
static var _puff_tex: Texture2D
static var _vignette_tex: Texture2D
static var _additive: CanvasItemMaterial
static var _shine: ShaderMaterial
static var _plus_font: Font


## The "+1" of a rescue: a chunky gold number with a deep crimson outline (the 2018 "+1" red on its
## rim) that punches in, overshoots, floats up and shrinks away.
static func plus_one(parent: Node, at: Vector2) -> void:
	var node := Node2D.new()
	node.position = at
	node.material = shine_material()
	var font := plus_font()
	var w := font.get_string_size("+1", HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE).x
	var base := Vector2(-w / 2, PLUS_SIZE * 0.36)  # the baseline that centres the figures on the node
	node.draw.connect(func() -> void:
		node.draw_string_outline(font, base + Vector2(0, 10), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, 34, Color(0.24, 0.02, 0.12, 0.4))
		node.draw_string_outline(font, base, "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, 34, Color("5c0828"))
		node.draw_string_outline(font, base, "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, 16, Color("dd2a5f"))
		node.draw_string(font, base, "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, PLUS_SIZE, Color.WHITE))
	parent.add_child(node)
	node.scale = Vector2(0.3, 0.3)
	node.rotation = -0.3
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2(1.18, 1.18), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(node, "rotation", 0.1, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2(0.94, 0.94), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(node, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.12)
	t.tween_property(node, "scale", Vector2(0.55, 0.55), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(node, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(node.queue_free)
	node.create_tween().tween_property(node, "position:y", at.y - 125.0, 0.9) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## A big reward: a warm flash, a burst of rays and speed lines, two rings of light,
## twinkling stars and a fountain of shaded, tumbling confetti that catches the light.
static func rescue_burst(parent: Node, at: Vector2) -> void:
	glow(parent, at, Color(1, 0.93, 0.74, 0.95), 0.45, 2.1, 0.3)
	rays(parent, at, Color(1, 0.92, 0.66, 0.7), 12, 250.0, 0.5)
	lines(parent, at, Color(1, 1, 1, 0.85), 9, 70.0, 230.0, 0.24)
	ring(parent, at, 30.0, 150.0, 0.4, Color(1, 1, 1, 0.95), 16.0)
	ring(parent, at, 18.0, 100.0, 0.5, Color(1, 0.84, 0.4, 0.8), 9.0)
	var c := Confetti.make(parent, at)
	c.gravity = 1150.0
	c.drag = 2.1
	c.flutter = 420.0
	c.spray(26, PARTY_SHAPES, PARTY, Vector2(420, 900), Vector2.UP, 105.0, 1.0, Vector2(0.8, 1.15))
	c.sparkle(10, SPARKS, Vector2(140, 420))


## The light behind a badge popping in (NEW BEST): a glow and a ring, smaller and softer
## than rescue_burst; drawn under the badge, so its words and those around it stay legible.
static func badge_burst(parent: Node, at: Vector2) -> void:
	glow(parent, at, Color(1, 0.85, 0.55, 0.5), 0.3, 0.9, 0.3)
	ring(parent, at, 24.0, 110.0, 0.35, Color(1, 0.95, 0.8, 0.7), 8.0)
	Confetti.make(parent, at).sparkle(10, SPARKS, Vector2(160, 420))


## A celebration bursting from one point (the doorway at home, behind the stars of a win):
## confetti and ribbons thrown up and out in a fan, in three sizes (near ones bigger and fewer),
## smearing while they fly fast, then fluttering down; a flash and sparkles at the origin.
static func confetti_burst(parent: Node, at: Vector2) -> void:
	glow(parent, at, Color(1, 0.9, 0.65, 0.8), 0.3, 1.6, 0.35)
	var c := Confetti.make(parent, at)
	c.gravity = 950.0
	c.drag = 1.5
	c.flutter = 520.0
	c.spray(46, PARTY_SHAPES, PARTY, Vector2(700, 1700), Vector2.UP, 70.0, 1.1, Vector2(2.2, 3.0), 30.0)
	c.spray(22, PARTY_SHAPES, PARTY, Vector2(800, 1800), Vector2.UP, 60.0, 1.9, Vector2(2.2, 3.0), 30.0)
	c.spray(9, PARTY_SHAPES, PARTY, Vector2(900, 1900), Vector2.UP, 50.0, 2.8, Vector2(2.2, 3.0), 30.0)
	c.sparkle(14, SPARKS, Vector2(200, 600), 1.2)


## A reward landing in a counter: a small flash, a ring and a few stars.
static func counter_pop(parent: Node, at: Vector2) -> void:
	glow(parent, at, Color(1, 0.92, 0.7, 0.9), 0.3, 1.3, 0.24)
	ring(parent, at, 26.0, 90.0, 0.32, Color(1, 0.95, 0.75, 0.9), 10.0)
	Confetti.make(parent, at).sparkle(7, SPARKS, Vector2(160, 380), 0.85, Vector2(0.35, 0.6))


## Panoramic takes a blow: a jagged white-hot spark, a red shock ring, a few stars knocked loose.
## (`push`: the side he is knocked to.)
static func impact(parent: Node, at: Vector2, push: float) -> void:
	hit_spark(parent, at, Color(1, 0.9, 0.8), 100.0, 0.14)
	glow(parent, at, Color(1, 0.45, 0.35, 0.7), 0.3, 1.3, 0.22)
	ring(parent, at, 18.0, 110.0, 0.28, Color(1, 0.55, 0.45, 0.85), 11.0)
	var stars := Confetti.make(parent, at)
	stars.gravity = 1500.0
	stars.drag = 1.2
	stars.flutter = 0.0
	stars.spray(5, [Confetti.Shape.STAR], [Color("ffd36b"), Color("ffffff")], Vector2(300, 620),
			Vector2(push, -1.3).normalized(), 55.0, 0.9, Vector2(0.5, 0.75))


## A ring strikes a bandit: a blue-white spark, a ring of light, blue sparks.
static func ring_hit(parent: Node, at: Vector2) -> void:
	hit_spark(parent, at, Color(0.75, 0.9, 1.0), 70.0, 0.11)
	ring(parent, at, 12.0, 84.0, 0.24, Color(0.6, 0.86, 1.0, 0.9), 9.0)
	Confetti.make(parent, at).sparkle(7, RING_SPARKS, Vector2(160, 420), 0.85, Vector2(0.3, 0.5))


## A bandit knocked out: a bigger spark, a burst of the ring's blue light, short rays, stars
## flying off and a puff of dust where he stood.
static func knock_out(parent: Node, at: Vector2, feet: Vector2) -> void:
	hit_spark(parent, at, Color(0.8, 0.92, 1.0), 95.0, 0.14)
	glow(parent, at, Color(0.45, 0.75, 1.0, 0.7), 0.3, 1.25, 0.26)
	rays(parent, at, Color(0.7, 0.88, 1.0, 0.5), 8, 130.0, 0.26)
	ring(parent, at, 20.0, 125.0, 0.32, Color(0.75, 0.9, 1.0, 0.85), 11.0)
	var stars := Confetti.make(parent, at)
	stars.gravity = 1400.0
	stars.drag = 1.4
	stars.flutter = 0.0
	stars.spray(8, [Confetti.Shape.STAR], [Color("ffd36b"), Color("ffe9a8"), Color("ffffff")], Vector2(320, 720),
			Vector2(0.6, -1).normalized(), 70.0, 1.0, Vector2(0.55, 0.85))
	stars.sparkle(6, RING_SPARKS, Vector2(160, 420), 1.0, Vector2(0.3, 0.55))
	dust(parent, feet, 10, 260.0, 0.0, 1.3)


## A hit, painted to sit with the art: a soft burst of light with ragged, tapering rays (no hard
## vector edge) that punches out and fades, over a warm glow (additive), and a few short streaks of
## light flying out. `colour` tints its rays; the core is white-hot.
static func hit_spark(parent: Node, at: Vector2, colour: Color, radius: float, time: float) -> void:
	var node := Sprite2D.new()
	node.texture = impact_texture()
	node.position = at
	node.rotation = randf() * TAU
	node.material = additive()
	node.modulate = colour.lerp(Color.WHITE, 0.35)
	parent.add_child(node)
	var base := radius * 2.4 / 128.0
	node.scale = Vector2.ONE * base * 0.45
	var t := node.create_tween().set_parallel(true)
	t.tween_property(node, "scale", Vector2.ONE * base, time * 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "rotation", node.rotation + 0.25, time * 1.6)
	t.tween_property(node, "modulate:a", 0.0, time * 1.2).set_delay(time * 0.4)
	t.chain().tween_callback(node.queue_free)
	lines(parent, at, Color(colour, 0.8), 7, radius * 0.5, radius * 1.5, time * 1.4)


## The soft burst of a hit (128 px, made once): a white-hot core, rays of uneven length with soft,
## tapering edges and a faint glow between them.
static func impact_texture() -> Texture2D:
	if not _impact_tex:
		var n := 128
		var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
		var rays: Array[float] = []
		for i in 11:
			rays.append(randf_range(0.5, 1.0))
		for y in n:
			for x in n:
				var u := Vector2(x + 0.5, y + 0.5) / (n / 2.0) - Vector2.ONE
				var r := u.length()
				var a := fposmod(u.angle() / TAU * 11.0, 11.0)
				var i := int(a)
				var f := a - i
				var reach := lerpf(rays[i], rays[(i + 1) % 11], smoothstep(0.0, 1.0, f))
				var spike := pow(absf(sin(f * PI)), 3.0)  # thin between rays, full on them
				var ray := clampf(1.0 - r / (reach * (0.35 + 0.65 * spike)), 0.0, 1.0)
				var core := exp(-r * r * 14.0)
				var glow := exp(-r * r * 4.0) * 0.35
				var v := clampf(ray * ray * 0.9 + core + glow, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, v))
		img.generate_mipmaps()
		_impact_tex = ImageTexture.create_from_image(img)
	return _impact_tex


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
		var delay := k * 0.18
		ring_node.get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(ring_node):
				ring(ring_node, Vector2.ZERO, 20.0, (130.0 + k * 60.0) * size, 0.7, Color(1, 1, 1, 0.85 - k * 0.3), 9.0 - k * 3.0))
		ring_node.get_tree().create_timer(delay + 0.8).timeout.connect(ring_node.queue_free)
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
	c.rain(120, width, PARTY_SHAPES, PARTY, 1.4, Vector2(2.6, 3.4), 0.8)
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


## The material of the "+1": a gold fill (shine_text.gdshader).
static func shine_material() -> ShaderMaterial:
	if not _shine:
		_shine = ShaderMaterial.new()
		_shine.shader = preload("res://src/game/shine_text.gdshader")
		_shine.set_shader_parameter(&"top_y", -PLUS_SIZE * 0.4)
		_shine.set_shader_parameter(&"bottom_y", PLUS_SIZE * 0.38)
	return _shine


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


## Edges fading to a clear middle (white: tinted by its user), for the pulse of a blow.
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
## logo shows and the first pickup, hit or game over doesn't stutter. Bakes the confetti too.
static func warm_up(parent: Control) -> void:
	var holder := Control.new()
	holder.modulate.a = 0.01
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil := Ui.frosted_veil()
	veil.set_anchors_preset(Control.PRESET_TOP_LEFT)
	veil.size = Vector2(4, 4)
	holder.add_child(veil)
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
	var shadow := SoftShadow.new()
	var dot := ColorRect.new()
	dot.size = Vector2(4, 4)
	shadow.add_child(dot)
	holder.add_child(shadow)
	var hit := Sprite2D.new()  # the hit burst: its picture is made here, not at the first hit
	hit.texture = impact_texture()
	hit.material = additive()
	hit.scale = Vector2(0.05, 0.05)
	holder.add_child(hit)
	var glow_dot := Sprite2D.new()
	glow_dot.texture = glow_texture()
	glow_dot.material = additive()
	glow_dot.scale = Vector2(0.05, 0.05)
	holder.add_child(glow_dot)
	var text := Node2D.new()  # the "+1"
	text.material = shine_material()
	text.draw.connect(func() -> void: text.draw_string(plus_font(), Vector2(0, 10), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 8))
	holder.add_child(text)
	var bits := Confetti.make(holder, Vector2.ZERO)
	bits.spray(2, [Confetti.Shape.PAPER], PARTY, Vector2(1, 2))
	bits.sparkle(1, SPARKS, Vector2(1, 2))
	parent.add_child(holder)
	await parent.get_tree().create_timer(0.3).timeout
	holder.queue_free()


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

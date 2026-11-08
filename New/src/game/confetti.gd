class_name Confetti
extends Node2D
## Shaded bits tumbling through the air: confetti, leaves, stone chips, and twinkling sparkles.
## Each piece turns in the plane and flips in depth, so it narrows to its edge and shows its darker
## back; it is shaded by how squarely it faces the light and glints when it faces it full on
## (a small additive flare); air slows it, and flat pieces flutter sideways as they flip; fast
## pieces smear along their path. Every picture is a region of one atlas, so a node's pieces draw
## in one batch and its light in another; then the node frees itself. Made by Fx (rescue, game
## over, the bushes, the stone).

enum Shape { PAPER, RIBBON, SEQUIN, STAR, LEAF, CHIP, COIN, PETAL, BEAD, STREAMER, STRIP }

## Size of each shape in design px at size 1.
const SIZES := {
	Shape.PAPER: Vector2(19, 12), Shape.RIBBON: Vector2(30, 10), Shape.SEQUIN: Vector2(13, 13),
	Shape.STAR: Vector2(19, 19), Shape.LEAF: Vector2(27, 14), Shape.CHIP: Vector2(15, 13), Shape.COIN: Vector2(22, 22),
	Shape.PETAL: Vector2(18, 11), Shape.BEAD: Vector2(10, 10), Shape.STREAMER: Vector2(54, 15),
	Shape.STRIP: Vector2(22, 8),
}
const STREAK_SPEED := 420.0  ## faster than this (px/s), a piece leaves a smear
const SHUTTER := 0.03  ## s of its path a moving piece is stretched over (a camera's motion blur)
## The pieces the motion blur stretches: the paper, the coins and the party's bits (not the knocked-out
## stars, leaves or stone: they keep their shapes).
const BLURRED := [Shape.PAPER, Shape.STRIP, Shape.COIN, Shape.PETAL, Shape.RIBBON, Shape.STREAMER,
		Shape.SEQUIN, Shape.BEAD]
## Two-tone paper (PAPER, STRIP): the colour of a piece's back for each front colour (others: a paler
## version of their own): a lighter warm tint, so a tumbling piece flashes between two bright colours, never into
## a muddy dark (deeper backs read as "maroon, olive and brown: dead leaves").
const TWO_TONE := {"ffd23a": Color("fff0b0"), "ffe680": Color("ffc840"), "fff4dc": Color("ffd88a"),
		"ff7a5a": Color("ffb59a"), "ff4d3d": Color("ff8a6a"), "ffb07a": Color("ffe0c4")}
## The party's paper, bits and coins: lit brightly whichever way they face (shading by at most 18 %,
## and warmer, not greyer: shaded gold turns amber, never olive), so they stay bright as they tumble.
const BRIGHT := [Shape.PAPER, Shape.STRIP, Shape.STREAMER, Shape.SEQUIN, Shape.COIN, Shape.STAR]
const ATLAS_WIDTH := 256  ## px: every picture of the confetti and of its light, side by side
const PAD := 4  ## px of clear between two pictures of the atlas (its mipmaps don't bleed)

static var _atlas: ImageTexture
static var _regions := {}  # Shape or light name (&"flare", &"glow", &"streak", &"dot") -> Rect2 in the atlas
static var _additive: CanvasItemMaterial
static var _sheet: Image  # the atlas's picture once baked, until atlas() makes it a texture
static var _baking := -1  # the WorkerThreadPool task baking it (-1: none)

## Pulls the pieces down (px/s²), slows them (per second: terminal speed = gravity / drag), and
## pushes flat pieces sideways as they flip (px/s²).
var gravity := 900.0
var drag := 2.5
var flutter := 500.0
## Pieces flash when they face the light (paper, sequins); matte ones (leaves, stone) don't.
var glints := true
## Pieces inside this rectangle (local units) aren't drawn: they pass behind it (a card's words,
## him); they fade out as they reach it (_clear).
var avoid := Rect2()
## Depth (0: none): the pieces of a spray are spread over that much depth, each its own: the far
## ones smaller, slower (parallax), paler with the air (towards `haze`) and fainter, drawn first; the
## near ones bigger and crisp (j15: "flat same-size rectangles").
var depth := 0.0
var haze := Color(1.0, 0.92, 0.82)

var _pieces: Array[Piece] = []
var _sparkles: Array[Sparkle] = []
var _lights: Node2D


class Piece:
	var pos: Vector2
	var vel: Vector2
	var turn: float
	var turn_speed: float
	var flip: float
	var flip_speed: float
	var glint_phase: float
	var size: Vector2
	var colour: Color
	var back: Color  # the colour of its other side (two-tone paper)
	var shape: Shape
	var age: float
	var life: float
	var z := 1.0  # its depth: 0 far, 1 near (Confetti.depth)


class Sparkle:
	var pos: Vector2
	var vel: Vector2
	var turn: float
	var size: float
	var colour: Color
	var twinkle: float
	var age: float
	var life: float


static func make(parent: Node, at: Vector2) -> Confetti:
	var c := Confetti.new()
	c.position = at
	parent.add_child(c)
	return c


## Starts baking the atlas's picture on a worker thread (Fx.warm_up, at boot): about 0.1 s of GDScript
## on a desktop, several times that on a phone, kept out of the boot's frames.
static func bake_soon() -> void:
	if not _atlas and _baking < 0:
		_baking = WorkerThreadPool.add_task(_bake_sheet)


## The atlas of every piece and light: the thread's picture made a texture (waiting for the thread if
## it isn't done), or baked here if no thread was started.
static func atlas() -> Texture2D:
	if not _atlas:
		if _baking >= 0:
			WorkerThreadPool.wait_for_task_completion(_baking)
			_baking = -1
		else:
			_bake_sheet()
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_atlas = ImageTexture.create_from_image(_sheet)
		_sheet = null
	return _atlas


## Where `key` (a Shape, or &"flare", &"glow", &"streak", &"dot") lies in the atlas (px).
static func region(key: Variant) -> Rect2:
	atlas()
	return _regions[key]


func _init() -> void:
	atlas()
	_lights = Node2D.new()
	_lights.material = _additive
	_lights.draw.connect(_draw_lights)
	add_child(_lights)


## Throws `count` pieces from around the origin: in `direction` give or take `spread` degrees, at a
## speed between `speed.x` and `speed.y`, each living `life.x` to `life.y` seconds.
func spray(count: int, shapes: Array, colours: Array, speed: Vector2, direction := Vector2.UP,
		spread := 180.0, size := 1.0, life := Vector2(0.8, 1.1), radius := 8.0) -> void:
	for i in count:
		var p := Piece.new()
		var a := direction.angle() + deg_to_rad(randf_range(-spread, spread))
		p.pos = Vector2.from_angle(randf() * TAU) * randf() * radius
		p.vel = Vector2.from_angle(a) * randf_range(speed.x, speed.y)
		_setup(p, shapes, colours, size, life)
		_pieces.append(p)
	_sort_by_depth()


## The far pieces first (drawn under the near ones).
func _sort_by_depth() -> void:
	if depth > 0.0:
		_pieces.sort_custom(func(a: Piece, b: Piece) -> bool: return a.z < b.z)


## Lets `count` pieces fall from a strip `width` wide above the origin, over `stagger` seconds.
func rain(count: int, width: float, shapes: Array, colours: Array, size := 1.0,
		life := Vector2(2.4, 3.2), stagger := 0.7) -> void:
	for i in count:
		var p := Piece.new()
		p.pos = Vector2(randf() * width, randf_range(-90.0, -20.0))
		p.vel = Vector2(randf_range(-120.0, 120.0), randf_range(120.0, 420.0))
		_setup(p, shapes, colours, size, life)
		p.age = -randf() * stagger
		_pieces.append(p)
	_sort_by_depth()


## Twinkling four-point stars that drift out and fade.
func sparkle(count: int, colours: Array, speed: Vector2, size := 1.0, life := Vector2(0.45, 0.8),
		radius := 10.0) -> void:
	for i in count:
		var s := Sparkle.new()
		s.pos = Vector2.from_angle(randf() * TAU) * randf() * radius
		s.vel = Vector2.from_angle(randf() * TAU) * randf_range(speed.x, speed.y) + Vector2(0, -60)
		s.turn = randf() * TAU
		s.size = randf_range(16.0, 30.0) * size
		s.colour = colours[randi() % colours.size()]
		s.twinkle = randf() * TAU
		s.life = randf_range(life.x, life.y)
		_sparkles.append(s)


func _setup(p: Piece, shapes: Array, colours: Array, size: float, life: Vector2) -> void:
	p.shape = shapes[randi() % shapes.size()]
	p.colour = colours[randi() % colours.size()]
	p.back = TWO_TONE.get(p.colour.to_html(false), p.colour.lerp(Color(1, 0.97, 0.9), 0.4))  # (else a lighter tint too)
	p.size = SIZES[p.shape] * size * randf_range(0.75, 1.25)
	p.turn = randf() * TAU
	p.turn_speed = randf_range(-9.0, 9.0)
	p.flip = randf() * TAU
	p.flip_speed = randf_range(6.0, 15.0) * (1.0 if randf() < 0.5 else -1.0)
	p.glint_phase = randf() * TAU
	p.life = randf_range(life.x, life.y)
	if depth > 0.0:  # spread in depth: far pieces small, slow and hazy, near ones big
		p.z = 1.0 - depth * pow(randf(), 0.8)
		p.size *= lerpf(0.5, 1.25, p.z)
		p.vel *= lerpf(0.72, 1.05, p.z)
		var air := (1.0 - p.z) * 0.35
		p.colour = p.colour.lerp(haze, air)
		p.back = p.back.lerp(haze, air)


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	var alive := false
	for p in _pieces:
		p.age += dt
		if p.age < 0.0 or p.age >= p.life:
			alive = alive or p.age < p.life
			continue
		alive = true
		p.vel.y += gravity * dt
		p.vel -= p.vel * minf(drag * dt, 0.5)
		p.vel.x += sin(p.flip) * flutter * dt
		p.pos += p.vel * dt
		p.turn += p.turn_speed * dt
		p.flip += p.flip_speed * dt
	for s in _sparkles:
		s.age += dt
		if s.age >= s.life:
			continue
		alive = true
		s.vel -= s.vel * minf(3.5 * dt, 0.5)
		s.vel.y += 160.0 * dt
		s.pos += s.vel * dt
		s.turn += 1.5 * dt
	if not alive:
		queue_free()
		return
	queue_redraw()
	_lights.queue_redraw()


func _draw() -> void:
	# Motion blur first, under the pieces: a fast piece leaves a faint copy of itself stretched back
	# along its path (its own shape and colour: a blur, never a thin stick). One atlas: one batch.
	for p in _pieces:
		if p.age < 0.0 or p.age >= p.life or p.shape == Shape.COIN:  # a coin is solid metal: no blur
			continue
		var speed := p.vel.length()
		var clear := _clear(p)
		if speed <= STREAK_SPEED or clear <= 0.0:
			continue
		var k := minf((speed - STREAK_SPEED) / 600.0, 1.0)
		var c := _shade(p)
		c.a *= clear
		var src: Rect2 = _regions[p.shape]
		if p.shape in [Shape.STREAMER, Shape.RIBBON]:  # two fading afterimages of itself
			for back in [0.022, 0.044]:
				draw_set_transform(p.pos - p.vel * back, p.turn, Vector2(1.0, maxf(absf(cos(p.flip)), 0.55)))
				draw_texture_rect_region(_atlas, Rect2(-p.size / 2, p.size), src, Color(c, c.a * 0.3 * k * (1.0 - back * 12.0)))
			continue
		c.a *= 0.35 * k
		draw_set_transform(p.pos - p.vel * 0.018, p.vel.angle(), Vector2(1.0 + 1.6 * k, 0.75))
		draw_texture_rect_region(_atlas, Rect2(-p.size / 2, p.size), src, c)
	for p in _pieces:
		if p.age < 0.0 or p.age >= p.life:
			continue
		var clear := _clear(p)
		if clear <= 0.0:
			continue
		var face := cos(p.flip)
		var w := 1.0 if p.shape == Shape.BEAD else maxf(absf(face), 0.14)  # a bead is round from every side
		var grow := minf(p.age / 0.06, 1.0)  # pieces open out of the burst
		# a long ribbon twists across its width (keeping its length), a paper strip about its length;
		# a big paper piece tumbles but never thins to a sliver (it reads as paper in any frame); a
		# flat piece turns edge-on
		var twist := Vector2(w, 1.0)
		if p.shape == Shape.STREAMER or p.shape == Shape.RIBBON:
			twist = Vector2(1.0, maxf(w, 0.55))
		elif p.shape == Shape.STRIP:
			twist = Vector2(1.0, maxf(w, 0.3))
		elif p.shape == Shape.PAPER:
			twist = Vector2(maxf(w, 0.3), 1.0)
		var smear := _smear(p)  # motion blur: stretched along its path, a touch fainter
		var c := _shade(p)
		c.a *= clear / pow(smear, 0.2)
		draw_set_transform_matrix(_placed(p, twist * grow, smear))
		draw_texture_rect_region(_atlas, Rect2(-p.size / 2, p.size), _regions[p.shape], c)
	draw_set_transform(Vector2.ZERO)


## Where and how a piece is drawn: at its place, turned, squashed by its tumble (`scale`), then
## stretched by `smear` along the way it moves.
func _placed(p: Piece, scale: Vector2, smear: float) -> Transform2D:
	var x := Vector2(cos(p.turn), sin(p.turn)) * scale.x
	var y := Vector2(-sin(p.turn), cos(p.turn)) * scale.y
	if smear > 1.0:
		var v := p.vel.normalized()
		x += v * x.dot(v) * (smear - 1.0)
		y += v * y.dot(v) * (smear - 1.0)
	return Transform2D(x, y, p.pos)


## How far a piece stretches along its path (1: not at all): the way it goes in SHUTTER seconds,
## against its size (a coin, solid metal, a little; none for the shapes not BLURRED).
func _smear(p: Piece) -> float:
	if p.shape not in BLURRED:
		return 1.0
	return clampf(1.0 + p.vel.length() * SHUTTER / maxf(p.size.x, p.size.y), 1.0, 1.35 if p.shape == Shape.COIN else 2.4)


## The pieces' glints and the sparkles, added onto the scene (one atlas: one batch).
func _draw_lights() -> void:
	var flare: Rect2 = _regions[&"flare"]
	if glints:
		for p in _pieces:
			if p.age < 0.0 or p.age >= p.life:
				continue
			var g := _glint(p)
			if g < 0.08 or avoid.has_point(p.pos):
				continue
			var r := minf((p.size.x + p.size.y) * 0.75, 22.0) * g  # a glint, never a lens-flare star
			_lights.draw_set_transform(p.pos, p.turn * 0.3, Vector2.ONE)
			_lights.draw_texture_rect_region(_atlas, Rect2(-Vector2(r, r), Vector2(r, r) * 2), flare,
					Color(1, 0.97, 0.88, 0.85 * g * _fade(p.age, p.life)))
	var glow: Rect2 = _regions[&"glow"]
	for s in _sparkles:  # each a soft halo and a four-point star
		if s.age >= s.life or avoid.has_point(s.pos):
			continue
		var k := s.age / s.life
		var pop := minf(k / 0.15, 1.0)
		var tw := 0.75 + 0.25 * sin(s.twinkle + s.age * 22.0)
		var r := s.size * pop * tw * (1.0 - 0.5 * k)
		var c := Color(s.colour, (1.0 - k * k))
		_lights.draw_set_transform(s.pos, s.turn, Vector2.ONE)
		_lights.draw_texture_rect_region(_atlas, Rect2(-Vector2(r, r) * 1.1, Vector2(r, r) * 2.2), glow, Color(c, c.a * 0.45))
		_lights.draw_texture_rect_region(_atlas, Rect2(-Vector2(r, r), Vector2(r, r) * 2), flare, c)
	_lights.draw_set_transform(Vector2.ZERO)


## How much of a piece shows by the rectangle it avoids (the card): none inside, fading in over half
## its size outside, so a big piece slides behind the card's edge instead of vanishing.
func _clear(p: Piece) -> float:
	if not avoid.has_area():
		return 1.0
	var out := Vector2(maxf(maxf(avoid.position.x - p.pos.x, p.pos.x - avoid.end.x), 0.0),
			maxf(maxf(avoid.position.y - p.pos.y, p.pos.y - avoid.end.y), 0.0))
	return clampf(out.length() / (maxf(p.size.x, p.size.y) * 0.5), 0.0, 1.0)


## Colour of a piece: its own colour lit by how squarely it faces the light, its back darker.
func _shade(p: Piece) -> Color:
	var face := cos(p.flip)
	var lit := (0.82 + 0.18 * absf(face)) if p.shape in BRIGHT else (0.6 + 0.4 * absf(face))
	var base := p.colour
	if face < 0.0:
		if p.shape in [Shape.STRIP, Shape.PAPER]:  # two-tone paper: its other side shows as it turns over
			base = p.back
		else:
			lit *= 0.9 if p.shape in BRIGHT else 0.8
	var c := Color(base.r * lit, base.g * lit, base.b * lit, _fade(p.age, p.life) * lerpf(0.7, 1.0, p.z))
	if p.shape in BRIGHT:  # its shade warmer, not greyer: red holds, green and blue go
		c = Color(base.r * (0.9 + 0.1 * lit), base.g * lit, base.b * lit * lit, c.a)
	if glints:
		c = c.lerp(Color(1, 1, 1, c.a), 0.55 * _glint(p))
	return c


## How much a piece catches the light (0 to 1): for a moment as it turns full face (paper a little
## longer: its glints are part of the party).
func _glint(p: Piece) -> float:
	if p.shape in [Shape.LEAF, Shape.CHIP, Shape.PETAL, Shape.STREAMER, Shape.RIBBON]:  # satin and leaves: no flash
		return 0.0
	var sharp := 10.0 if p.shape in BRIGHT else 24.0
	return pow(maxf(cos(p.flip + p.glint_phase), 0.0), sharp) * maxf(cos(p.flip), 0.0)


func _fade(age: float, life: float) -> float:
	return clampf((life - age) / (life * 0.25), 0.0, 1.0)


# ---------------------------------------------------------------- textures

## The shapes, white and shaded as if lit from the upper left (the colour comes from the piece), and
## the light (a glint, a soft glow, a spark's streak and its hot head), packed into one picture: only
## images, no texture or other server object, so it runs on a worker thread (bake_soon).
static func _bake_sheet() -> void:
	var images := {}
	# A paper square: a rounded rectangle with a slight curl (a lit band across it, the far end
	# turning into shade) and a crisp lit top edge: it reads as paper even at its size on a phone.
	images[Shape.PAPER] = _bake(Vector2i(56, 36), func(u: Vector2) -> Vector2:
		var d := _box(u, Vector2(0.94, 0.9), 0.18) * 1.4
		var band := 0.1 * exp(-pow((u.x + 0.35) * 2.2, 2.0))
		var edge := 0.06 * (1.0 - smoothstep(-0.9, -0.7, u.y))
		return Vector2(0.9 + band + edge - 0.12 * smoothstep(0.1, 1.0, u.x) - 0.03 * u.y, d))
	images[Shape.RIBBON] = _bake(Vector2i(60, 20), func(u: Vector2) -> Vector2:
		var wave := sin(u.x * PI * 1.5) * 0.45
		var d := 1.0 - absf(u.y - wave) / 0.42
		return Vector2(0.78 + 0.22 * cos(u.x * PI * 1.5 + 0.6), minf(d * 6.0, 1.0 - absf(u.x) * 0.2)))
	images[Shape.SEQUIN] = _bake(Vector2i(26, 26), func(u: Vector2) -> Vector2:
		var r := u.length()
		var light := clampf(u.dot(Vector2(-0.6, -0.8)) * 0.5 + 0.5, 0.0, 1.0)
		var shine := 1.0 - smoothstep(0.0, 0.35, (u - Vector2(-0.35, -0.35)).length())
		return Vector2(0.8 + 0.16 * light + 0.08 * shine - 0.1 * smoothstep(0.75, 0.95, r), (0.95 - r) * 12.0))
	images[Shape.STAR] = _bake(Vector2i(32, 32), func(u: Vector2) -> Vector2:
		var a := atan2(u.y, u.x) + PI / 2
		var arm := absf(fposmod(a, TAU / 5) - TAU / 10) / (TAU / 10)  # 0 on an arm, 1 between
		var edge := lerpf(0.95, 0.42, arm)
		var light := clampf(0.5 - 0.5 * u.normalized().dot(Vector2(0.6, 0.8)), 0.0, 1.0) if u.length() > 0.01 else 1.0
		return Vector2(0.7 + 0.3 * light, (edge - u.length()) * 14.0))
	images[Shape.LEAF] = _bake(Vector2i(42, 22), func(u: Vector2) -> Vector2:
		var half := 0.9 * pow(maxf(1.0 - u.x * u.x, 0.0), 0.75)
		var d := (half - absf(u.y)) * 10.0
		var rib := 0.16 * (1.0 - smoothstep(0.0, 0.12, absf(u.y)))
		return Vector2((1.0 if u.y < 0.0 else 0.8) - rib - 0.1 * (u.x + 1.0) / 2.0, d))
	images[Shape.CHIP] = _bake(Vector2i(22, 20), func(u: Vector2) -> Vector2:
		var a := atan2(u.y, u.x)
		var edge := 0.82 + 0.13 * sin(a * 3.0 + 0.7) + 0.06 * sin(a * 5.0)
		var facet := 1.0 if a < -PI * 0.25 and a > -PI * 0.95 else (0.62 if a > PI * 0.15 else 0.8)
		return Vector2(facet, (edge - u.length()) * 9.0))
	# A coin: a raised rim catching the light, a sunken field, an embossed star in the middle.
	images[Shape.COIN] = _bake(Vector2i(44, 44), func(u: Vector2) -> Vector2:
		var r := u.length()
		var light := clampf(u.dot(Vector2(-0.6, -0.8)) * 0.5 + 0.5, 0.0, 1.0)
		var a := atan2(u.y, u.x) + PI / 2
		var arm := absf(fposmod(a, TAU / 5) - TAU / 10) / (TAU / 10)
		var star := 1.0 - smoothstep(lerpf(0.5, 0.24, arm) - 0.05, lerpf(0.5, 0.24, arm) + 0.03, r)
		var rim := smoothstep(0.72, 0.8, r)
		var b := lerpf(0.68 + 0.18 * light, 0.86 + 0.14 * light, rim)
		b = lerpf(b, 0.95 + 0.05 * light, star)
		return Vector2(b - 0.12 * smoothstep(0.86, 0.95, r) * (1.0 - light), (0.97 - r) * 14.0))
	# A petal: a soft teardrop, darker at its base, a crease down the middle, lit from the upper left.
	images[Shape.PETAL] = _bake(Vector2i(36, 22), func(u: Vector2) -> Vector2:
		var x := (u.x + 1.0) / 2.0  # 0 at the base, 1 at the tip
		var half := 0.9 * pow(sin(clampf(x, 0.0, 1.0) * PI), 0.7) * (0.55 + 0.45 * x)
		var crease := 0.12 * (1.0 - smoothstep(0.0, 0.15, absf(u.y)))
		var light := clampf(0.6 - 0.4 * u.y + 0.2 * x, 0.0, 1.0)
		return Vector2(0.62 + 0.38 * light - crease, (half - absf(u.y)) * 10.0))
	# A glass bead: a sphere with a hard specular point and a coloured rim light.
	images[Shape.BEAD] = _bake(Vector2i(20, 20), func(u: Vector2) -> Vector2:
		var r := u.length()
		var light := clampf(u.dot(Vector2(-0.6, -0.8)) * 0.5 + 0.5, 0.0, 1.0)
		var spec := pow(maxf(1.0 - (u - Vector2(-0.35, -0.4)).length() / 0.3, 0.0), 2.0)
		var rim := smoothstep(0.7, 0.95, r) * (1.0 - light) * 0.3
		return Vector2(0.45 + 0.45 * light + 0.6 * spec + rim, (0.96 - r) * 12.0))
	# A paper strip: a small rectangle, a slight curl lit along its length (brighter at one end).
	images[Shape.STRIP] = _bake(Vector2i(44, 16), func(u: Vector2) -> Vector2:
		var d := _box(u, Vector2(0.95, 0.85), 0.2)
		return Vector2(0.88 + 0.1 * (1.0 - absf(u.x + 0.3)) - 0.04 * u.y, d))
	# A streamer: a wide satin ribbon in a gentle double curl, shaded across its width (lit edge on
	# top, a glossy band, its underside darker) and darker where the curl turns away from the light.
	images[Shape.STREAMER] = _bake(Vector2i(96, 30), func(u: Vector2) -> Vector2:
		var wave := sin(u.x * PI * 2.0) * 0.32
		var across := (u.y - wave) / 0.6  # -1 at its top edge, 1 at its bottom edge
		var slope := cos(u.x * PI * 2.0)
		var shade := 0.82 - 0.22 * across + 0.12 * slope
		var gloss := 0.35 * exp(-pow((across + 0.35) * 4.0, 2.0))
		return Vector2(shade + gloss, minf((1.0 - absf(across)) * 8.0, (1.0 - pow(absf(u.x), 8.0)) * 6.0)))
	# A glint: a hot core, four thin spikes and a soft halo.
	images[&"flare"] = _bake(Vector2i(64, 64), func(u: Vector2) -> Vector2:
		var r := u.length()
		var spikes := maxf(exp(-absf(u.y) * 30.0) * pow(maxf(1.0 - absf(u.x), 0.0), 2.0),
				exp(-absf(u.x) * 30.0) * pow(maxf(1.0 - absf(u.y), 0.0), 2.0))
		return Vector2(1.0, exp(-r * r * 30.0) + 0.9 * spikes + 0.3 * exp(-r * 5.0) * (1.0 - r)))
	# A soft round light (as Fx.glow_texture: 0.95 at its middle, 0.55 a quarter out, clear at the edge).
	images[&"glow"] = _bake(Vector2i(64, 64), func(u: Vector2) -> Vector2:
		var r := u.length()
		return Vector2(1.0, lerpf(0.95, 0.55, r / 0.25) if r < 0.25 else lerpf(0.55, 0.0, minf((r - 0.25) / 0.75, 1.0))))
	# A spark's streak (its head at the right): a crisp line tapering to nothing behind, dimming
	# along its length, with a faint skirt of light round it.
	images[&"streak"] = _bake(Vector2i(96, 16), func(u: Vector2) -> Vector2:
		var x := (u.x + 1.0) / 2.0  # 0 at its tail, 1 at its head
		var y := absf(u.y) * 8.0  # px from its middle
		var half := 6.0 * pow(x, 0.85)
		var line := clampf(half - y + 0.5, 0.0, 1.0)
		var skirt := 0.3 * clampf(1.0 - y / (half + 3.0), 0.0, 1.0)
		return Vector2(1.0, (line + skirt) * (0.2 + 0.8 * pow(x, 1.3))))
	# A spark's head: a hard white-hot disc with a small halo.
	images[&"dot"] = _bake(Vector2i(24, 24), func(u: Vector2) -> Vector2:
		var r := u.length()
		return Vector2(1.0, clampf((0.5 - r) * 10.0, 0.0, 1.0) + 0.45 * exp(-r * r * 7.0) * (1.0 - r)))
	_pack(images)


## Lays the pictures out in rows in one picture, tallest first, PAD apart, and keeps where each is.
static func _pack(images: Dictionary) -> void:
	var keys := images.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return images[a].get_height() > images[b].get_height())
	var at := Vector2i(PAD, PAD)
	var row := 0
	for key: Variant in keys:
		var img: Image = images[key]
		if at.x + img.get_width() + PAD > ATLAS_WIDTH:
			at = Vector2i(PAD, at.y + row + PAD)
			row = 0
		_regions[key] = Rect2(at, img.get_size())
		at.x += img.get_width() + PAD
		row = maxi(row, img.get_height())
	var sheet := Image.create_empty(ATLAS_WIDTH, at.y + row + PAD, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(1, 1, 1, 0))
	for key: Variant in keys:
		var img: Image = images[key]
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(_regions[key].position))
	sheet.generate_mipmaps()
	_sheet = sheet


## A picture whose every pixel comes from `shape` at u in -1..1: (brightness, coverage), coverage
## clamped to 0..1, averaged over 3x3 samples so the edges are smooth.
static func _bake(px: Vector2i, shape: Callable) -> Image:
	var img := Image.create_empty(px.x, px.y, false, Image.FORMAT_RGBA8)
	for y in px.y:
		for x in px.x:
			var light := 0.0
			var cover := 0.0
			for j in 3:
				for i in 3:
					var u := Vector2((x + (i + 0.5) / 3.0) / px.x * 2.0 - 1.0, (y + (j + 0.5) / 3.0) / px.y * 2.0 - 1.0)
					var s: Vector2 = shape.call(u)
					var c := clampf(s.y, 0.0, 1.0)
					light += s.x * c
					cover += c
			var l := light / cover if cover > 0.0 else 1.0
			img.set_pixel(x, y, Color(l, l, l, cover / 9.0))
	return img


## Coverage of a rounded box of half-size `half` and corner `r` (in u units), soft over a pixel.
static func _box(u: Vector2, half: Vector2, r: float) -> float:
	var q := u.abs() - half + Vector2(r, r)
	var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
	return -d * 12.0

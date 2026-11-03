class_name Confetti
extends Node2D
## Shaded bits tumbling through the air: confetti, leaves, stone chips, and twinkling sparkles.
## Each piece turns in the plane and flips in depth, so it narrows to its edge and shows its darker
## back; it is shaded by how squarely it faces the light and glints when it faces it full on
## (a small additive flare); air slows it, and flat pieces flutter sideways as they flip; fast
## pieces smear along their path. Everything is drawn in a few batched calls, then the node frees
## itself. Made by Fx (rescue, game over, the bushes, the stone).

enum Shape { PAPER, RIBBON, SEQUIN, STAR, LEAF, CHIP, COIN, PETAL, BEAD, STREAMER }

## Size of each shape in design px at size 1.
const SIZES := {
	Shape.PAPER: Vector2(19, 12), Shape.RIBBON: Vector2(30, 10), Shape.SEQUIN: Vector2(13, 13),
	Shape.STAR: Vector2(19, 19), Shape.LEAF: Vector2(27, 14), Shape.CHIP: Vector2(15, 13), Shape.COIN: Vector2(22, 22),
	Shape.PETAL: Vector2(18, 11), Shape.BEAD: Vector2(10, 10), Shape.STREAMER: Vector2(54, 9),
}
const STREAK_SPEED := 420.0  ## faster than this (px/s), a piece leaves a smear

static var _textures := {}
static var _flare: Texture2D
static var _additive: CanvasItemMaterial

## Pulls the pieces down (px/s²), slows them (per second: terminal speed = gravity / drag), and
## pushes flat pieces sideways as they flip (px/s²).
var gravity := 900.0
var drag := 2.5
var flutter := 500.0
## Pieces flash when they face the light (paper, sequins); matte ones (leaves, stone) don't.
var glints := true

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
	var shape: Shape
	var age: float
	var life: float


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


func _init() -> void:
	if _textures.is_empty():
		_bake_textures()
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
	p.size = SIZES[p.shape] * size * randf_range(0.8, 1.2)
	p.turn = randf() * TAU
	p.turn_speed = randf_range(-9.0, 9.0)
	p.flip = randf() * TAU
	p.flip_speed = randf_range(6.0, 15.0) * (1.0 if randf() < 0.5 else -1.0)
	p.glint_phase = randf() * TAU
	p.life = randf_range(life.x, life.y)


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
	# along its path (its own shape and colour: a blur, never a thin stick).
	for p in _pieces:
		if p.age < 0.0 or p.age >= p.life or p.shape == Shape.COIN:  # a coin is solid metal: no blur
			continue
		var speed := p.vel.length()
		if speed > STREAK_SPEED:
			var k := minf((speed - STREAK_SPEED) / 600.0, 1.0)
			var c := _shade(p)
			c.a *= 0.35 * k
			var stretch := 1.0 + 1.6 * k
			draw_set_transform(p.pos - p.vel * 0.018, p.vel.angle(), Vector2(stretch, 0.75))
			draw_texture_rect(_textures[p.shape], Rect2(-p.size / 2, p.size), false, c)
	draw_set_transform(Vector2.ZERO)
	for shape: int in Shape.values():
		var tex: Texture2D = _textures[shape]
		for p in _pieces:
			if p.shape != shape or p.age < 0.0 or p.age >= p.life:
				continue
			var face := cos(p.flip)
			var w := 1.0 if p.shape == Shape.BEAD else maxf(absf(face), 0.14)  # a bead is round from every side
			var grow := minf(p.age / 0.06, 1.0)  # pieces open out of the burst
			# a long ribbon twists across its width (keeping its length); a flat piece turns edge-on
			var twist := Vector2(1.0, maxf(w, 0.3)) if p.shape == Shape.STREAMER or p.shape == Shape.RIBBON else Vector2(w, 1.0)
			draw_set_transform(p.pos, p.turn, twist * grow)
			draw_texture_rect(tex, Rect2(-p.size / 2, p.size), false, _shade(p))
	draw_set_transform(Vector2.ZERO)


## The pieces' glints and the sparkles, added onto the scene.
func _draw_lights() -> void:
	if glints:
		for p in _pieces:
			if p.age < 0.0 or p.age >= p.life:
				continue
			var g := _glint(p)
			if g < 0.08:
				continue
			var r := (p.size.x + p.size.y) * 0.75 * g
			_lights.draw_set_transform(p.pos, p.turn * 0.3, Vector2.ONE)
			_lights.draw_texture_rect(_flare, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false,
					Color(1, 0.97, 0.88, 0.85 * g * _fade(p.age, p.life)))
	for s in _sparkles:
		if s.age >= s.life:
			continue
		var k := s.age / s.life
		var pop := minf(k / 0.15, 1.0)
		var tw := 0.75 + 0.25 * sin(s.twinkle + s.age * 22.0)
		var r := s.size * pop * tw * (1.0 - 0.5 * k)
		var c := Color(s.colour, (1.0 - k * k))
		_lights.draw_set_transform(s.pos, s.turn, Vector2.ONE)
		_lights.draw_texture_rect(Fx.glow_texture(), Rect2(-Vector2(r, r) * 1.1, Vector2(r, r) * 2.2), false, Color(c, c.a * 0.45))
		_lights.draw_texture_rect(_flare, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, c)
	_lights.draw_set_transform(Vector2.ZERO)


## Colour of a piece: its own colour lit by how squarely it faces the light, its back darker.
func _shade(p: Piece) -> Color:
	var face := cos(p.flip)
	var lit := 0.6 + 0.4 * absf(face)
	if face < 0.0:
		lit *= 0.8
	var c := Color(p.colour.r * lit, p.colour.g * lit, p.colour.b * lit, _fade(p.age, p.life))
	if glints:
		c = c.lerp(Color(1, 1, 1, c.a), 0.55 * _glint(p))
	return c


## How much a piece catches the light (0 to 1): for an instant as it turns full face.
func _glint(p: Piece) -> float:
	if p.shape == Shape.LEAF or p.shape == Shape.CHIP or p.shape == Shape.PETAL:
		return 0.0
	return pow(maxf(cos(p.flip + p.glint_phase), 0.0), 24.0) * maxf(cos(p.flip), 0.0)


func _fade(age: float, life: float) -> float:
	return clampf((life - age) / (life * 0.25), 0.0, 1.0)


# ---------------------------------------------------------------- textures

## The shapes, white and shaded as if lit from the upper left (the colour comes from the piece).
static func _bake_textures() -> void:
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_textures[Shape.PAPER] = _bake(Vector2i(38, 24), func(u: Vector2) -> Vector2:
		var d := _box(u, Vector2(0.92, 0.88), 0.25)
		return Vector2(lerpf(1.0, 0.78, (u.y + 1.0) / 2.0) - (0.12 if u.x > 0.8 else 0.0), d))
	_textures[Shape.RIBBON] = _bake(Vector2i(60, 20), func(u: Vector2) -> Vector2:
		var wave := sin(u.x * PI * 1.5) * 0.45
		var d := 1.0 - absf(u.y - wave) / 0.42
		return Vector2(0.78 + 0.22 * cos(u.x * PI * 1.5 + 0.6), minf(d * 6.0, 1.0 - absf(u.x) * 0.2)))
	_textures[Shape.SEQUIN] = _bake(Vector2i(26, 26), func(u: Vector2) -> Vector2:
		var r := u.length()
		var light := clampf(u.dot(Vector2(-0.6, -0.8)) * 0.5 + 0.5, 0.0, 1.0)
		var shine := 1.0 - smoothstep(0.0, 0.35, (u - Vector2(-0.35, -0.35)).length())
		return Vector2(0.62 + 0.3 * light + 0.08 * shine - 0.15 * smoothstep(0.75, 0.95, r), (0.95 - r) * 12.0))
	_textures[Shape.STAR] = _bake(Vector2i(32, 32), func(u: Vector2) -> Vector2:
		var a := atan2(u.y, u.x) + PI / 2
		var arm := absf(fposmod(a, TAU / 5) - TAU / 10) / (TAU / 10)  # 0 on an arm, 1 between
		var edge := lerpf(0.95, 0.42, arm)
		var light := clampf(0.5 - 0.5 * u.normalized().dot(Vector2(0.6, 0.8)), 0.0, 1.0) if u.length() > 0.01 else 1.0
		return Vector2(0.7 + 0.3 * light, (edge - u.length()) * 14.0))
	_textures[Shape.LEAF] = _bake(Vector2i(42, 22), func(u: Vector2) -> Vector2:
		var half := 0.9 * pow(maxf(1.0 - u.x * u.x, 0.0), 0.75)
		var d := (half - absf(u.y)) * 10.0
		var rib := 0.16 * (1.0 - smoothstep(0.0, 0.12, absf(u.y)))
		return Vector2((1.0 if u.y < 0.0 else 0.8) - rib - 0.1 * (u.x + 1.0) / 2.0, d))
	_textures[Shape.CHIP] = _bake(Vector2i(22, 20), func(u: Vector2) -> Vector2:
		var a := atan2(u.y, u.x)
		var edge := 0.82 + 0.13 * sin(a * 3.0 + 0.7) + 0.06 * sin(a * 5.0)
		var facet := 1.0 if a < -PI * 0.25 and a > -PI * 0.95 else (0.62 if a > PI * 0.15 else 0.8)
		return Vector2(facet, (edge - u.length()) * 9.0))
	# A coin: a raised rim catching the light, a sunken field, an embossed star in the middle.
	_textures[Shape.COIN] = _bake(Vector2i(44, 44), func(u: Vector2) -> Vector2:
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
	_textures[Shape.PETAL] = _bake(Vector2i(36, 22), func(u: Vector2) -> Vector2:
		var x := (u.x + 1.0) / 2.0  # 0 at the base, 1 at the tip
		var half := 0.9 * pow(sin(clampf(x, 0.0, 1.0) * PI), 0.7) * (0.55 + 0.45 * x)
		var crease := 0.12 * (1.0 - smoothstep(0.0, 0.15, absf(u.y)))
		var light := clampf(0.6 - 0.4 * u.y + 0.2 * x, 0.0, 1.0)
		return Vector2(0.62 + 0.38 * light - crease, (half - absf(u.y)) * 10.0))
	# A glass bead: a sphere with a hard specular point and a coloured rim light.
	_textures[Shape.BEAD] = _bake(Vector2i(20, 20), func(u: Vector2) -> Vector2:
		var r := u.length()
		var light := clampf(u.dot(Vector2(-0.6, -0.8)) * 0.5 + 0.5, 0.0, 1.0)
		var spec := pow(maxf(1.0 - (u - Vector2(-0.35, -0.4)).length() / 0.3, 0.0), 2.0)
		var rim := smoothstep(0.7, 0.95, r) * (1.0 - light) * 0.3
		return Vector2(0.45 + 0.45 * light + 0.6 * spec + rim, (0.96 - r) * 12.0))
	# A streamer: a long satin ribbon in a double curl, a glossy band of light along its crest.
	_textures[Shape.STREAMER] = _bake(Vector2i(96, 18), func(u: Vector2) -> Vector2:
		var wave := sin(u.x * PI * 2.0) * 0.5
		var d := 1.0 - absf(u.y - wave) / 0.36
		var slope := cos(u.x * PI * 2.0)
		var gloss := pow(maxf(0.0, 1.0 - absf(u.y - wave + 0.12)) , 6.0) * 0.35
		return Vector2(0.7 + 0.22 * slope + gloss, minf(d * 6.0, 1.0 - pow(absf(u.x), 6.0))))
	# A glint: a hot core, four thin spikes and a soft halo.
	_flare = _bake(Vector2i(64, 64), func(u: Vector2) -> Vector2:
		var r := u.length()
		var spikes := maxf(exp(-absf(u.y) * 30.0) * pow(maxf(1.0 - absf(u.x), 0.0), 2.0),
				exp(-absf(u.x) * 30.0) * pow(maxf(1.0 - absf(u.y), 0.0), 2.0))
		return Vector2(1.0, exp(-r * r * 30.0) + 0.9 * spikes + 0.3 * exp(-r * 5.0) * (1.0 - r)))


## A texture whose every pixel comes from `shape` at u in -1..1: (brightness, coverage), coverage
## clamped to 0..1, averaged over 3x3 samples so the edges are smooth.
static func _bake(px: Vector2i, shape: Callable) -> ImageTexture:
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
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Coverage of a rounded box of half-size `half` and corner `r` (in u units), soft over a pixel.
static func _box(u: Vector2, half: Vector2, r: float) -> float:
	var q := u.abs() - half + Vector2(r, r)
	var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
	return -d * 12.0

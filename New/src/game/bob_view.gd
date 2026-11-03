class_name BobView
extends Node2D
## A Red Bob in the level (assets/art/bob/: the ball rendered in 3D in Panoramic's light by
## tools/art/blender/bob_render.py, its faces drawn by tools/art/bob_sheet.py): a glossy red ball with a face that
## floats up and down (each at its own phase and pace, so a row never moves as one), sways, squashes
## at the bottom of its float, blinks now and then, catches a glint of light, carries a hot specular
## point on its gloss, and glows warm (an additive rim breathing round it) so a row reads as treasure.
## When Panoramic takes it, the game screen flies a copy to the counter (BobView.flier()).

const DIR := "res://assets/art/bob/"
const SIZE := 28.0  ## drawn width in units (a 32-unit tile: neighbours apart, never overlapping as they bob)
enum Face { SMILE, BLINK, JOY, WINK }

static var _sheet: Texture2D
static var _frame_px := 128
static var _radius_px := 57.0
static var _faces := {}  # Face -> AtlasTexture
static var _glint: Texture2D
static var _halo_tex: Texture2D
static var _additive: CanvasItemMaterial

var _sprite: Sprite2D
var _halo: Sprite2D  # the warm glow behind the ball
var _spec: Sprite2D  # the hot specular point on its gloss (additive)
var _pace := 3.4  # radians per second of its float
var _shine: Node2D  # the glint, added onto the ball
var _clock := 0.0
var _phase := 0.0
var _blink_at := 0.0
var _glint_at := 0.0
var _glint_k := 0.0
var _scale := 1.0
var _tilt := 0.0  # its own lean (radians): no two alike
var _face := Face.SMILE  # its own face (round 7: a row was "identical tomatoes"): happy, laughing, winking
var _star := false  # every other one wears a star glint on its gloss all the time


static func load_art() -> void:
	if _sheet:
		return
	_sheet = load(DIR + "bob.png")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "bob.json"))
	_frame_px = int(data.frame)
	_radius_px = float(data.radius)
	for f: Face in [Face.SMILE, Face.BLINK, Face.JOY, Face.WINK]:
		var a := AtlasTexture.new()
		a.atlas = _sheet
		a.region = Rect2(f * _frame_px, 0, _frame_px, _frame_px)
		_faces[f] = a
	_glint = _make_glint()
	_halo_tex = _make_halo()
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


## The Red Bob picture (HUD, results, share card): one face of the sheet.
static func texture(face := Face.SMILE) -> Texture2D:
	load_art()
	return _faces[face]


## Scale that draws the ball `width` units wide.
static func scale_for(width: float) -> float:
	load_art()
	return width / (_radius_px * 2.0)


## A 4-pointed star of light (additive): the glint on the gloss.
static func _make_glint() -> Texture2D:
	var n := 48
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := Vector2(x + 0.5, y + 0.5) / (n / 2.0) - Vector2.ONE
			var cross := maxf(exp(-absf(u.x) * 14.0) * (1.0 - absf(u.y)), exp(-absf(u.y) * 14.0) * (1.0 - absf(u.x)))
			var core := exp(-u.length_squared() * 18.0)
			var a := clampf(cross * 0.9 + core, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A soft round glow (additive), brightest in the middle.
static func _make_halo() -> Texture2D:
	var n := 64
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := (Vector2(x + 0.5, y + 0.5) / (n / 2.0) - Vector2.ONE).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(exp(-r * r * 4.0) * (1.0 - r), 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _init(column := 0, row := 0) -> void:
	load_art()
	_scale = scale_for(SIZE)
	_halo = Sprite2D.new()
	_halo.texture = _halo_tex
	_halo.material = _additive
	_halo.scale = Vector2.ONE * SIZE * 1.75 / 64.0
	add_child(_halo)
	_sprite = Sprite2D.new()
	_sprite.texture = _faces[Face.SMILE]
	_sprite.scale = Vector2.ONE * _scale
	add_child(_sprite)
	_spec = Sprite2D.new()
	_spec.texture = _halo_tex
	_spec.material = _additive
	_spec.scale = Vector2.ONE * 15.0 / 64.0  # (round 8: the shine is what reads at phone size)
	_spec.modulate = Color(1, 0.98, 0.92, 1.0)
	add_child(_spec)
	_shine = Node2D.new()
	_shine.material = _additive
	_shine.draw.connect(_draw_glint)
	add_child(_shine)
	# a wave along a row (neighbours a quarter beat apart) with a golden-angle jitter: a row reads as a
	# ripple, not a copy-pasted line
	_phase = fposmod(column * 1.2 + row * 1.618 + fposmod(column * 2.399, 1.2), TAU)
	# round 6 ("stamped tomatoes"): each a little bigger or smaller and leaning its own way
	var h := fposmod(sin(column * 12.9898 + row * 78.233) * 43758.5453, 1.0)
	_scale *= 0.88 + 0.22 * h
	_tilt = (fposmod(h * 7.31, 1.0) - 0.5) * 0.7
	_face = [Face.SMILE, Face.JOY, Face.SMILE, Face.WINK, Face.JOY][int(h * 97.0) % 5]
	_star = int(h * 53.0) % 2 == 0  # (round 8: every other one)
	_pace = 3.0 + fposmod(column * 0.37 + row * 0.53, 0.8)
	_clock = 0.0
	_blink_at = 1.0 + fposmod(column * 1.37 + row * 0.71, 4.0)
	_glint_at = 0.2 + fposmod(column * 0.41 + row * 1.9, 3.0)


func _process(delta: float) -> void:
	_clock += delta
	# float: up and down, squashed a little at the bottom, stretched going up
	var s := sin(_clock * _pace - _phase)
	_sprite.position.y = -6.0 * s  # (a deep float, staggered along a row by _phase: a ripple even in a still)
	var squash := 0.05 * -s
	var pulse := 1.0 + 0.045 * maxf(sin(_clock * 3.1 - _phase * 1.3), 0.0)  # a slight beat of size
	_sprite.scale = Vector2(_scale * (1.0 + squash), _scale * (1.0 - squash)) * pulse
	_sprite.rotation = _tilt + 0.09 * sin(_clock * 2.1 - _phase * 0.7)
	_halo.position = _sprite.position
	_halo.modulate = Color(1.0, 0.48, 0.22, 0.7 + 0.2 * sin(_clock * 2.6 - _phase))  # a soft warm glow
	_halo.scale = Vector2.ONE * SIZE * 2.2 / 64.0 * pulse
	_spec.modulate.a = 0.7 + 0.3 * sin(_clock * 5.3 + _phase)  # the hotspot twinkles
	_spec.position = _sprite.position + Vector2(-6.0, -7.0).rotated(_sprite.rotation)
	# blink every few seconds; once in a while a wink
	var face := _face  # (one in four wears a star glint; see _star)
	if _clock >= _blink_at:
		face = Face.WINK if int(_blink_at * 7.0) % 9 == 0 else Face.BLINK
		if _clock >= _blink_at + 0.13:
			_blink_at = _clock + randf_range(2.2, 5.5)
	_sprite.texture = _faces[face]
	# the glint: a star of light that flares on the gloss and fades
	if _clock >= _glint_at:
		_glint_k = 1.0
		_glint_at = _clock + randf_range(1.2, 3.0)  # (often: a moving sparkle along a row)
	if _glint_k > 0.0 or _star:
		_glint_k = maxf(_glint_k - delta * 1.8, 0.0)
		_shine.queue_redraw()


func _draw_glint() -> void:
	if _star:  # a small four-point star sitting on the gloss, twinkling (seen in a still)
		var tw := 0.75 + 0.25 * sin(_clock * 4.3 + _phase)
		_shine.draw_set_transform(_sprite.position + Vector2(-7.0, -8.0).rotated(_sprite.rotation), 0.4, Vector2.ONE * 0.22 * tw)
		_shine.draw_texture(_glint, -Vector2(24, 24), Color(1, 1, 1, 0.95))
		_shine.draw_set_transform(Vector2.ZERO)
	if _glint_k <= 0.0:
		return
	var k := sin(_glint_k * PI)  # flares up then down
	var at := _sprite.position + Vector2(-6.5, -7.0)
	_shine.draw_set_transform(at, _glint_k * 1.4, Vector2.ONE * (0.12 + 0.22 * k))
	_shine.draw_texture(_glint, -Vector2(24, 24), Color(1, 1, 1, k))
	_shine.draw_set_transform(Vector2.ZERO)


## A copy that pops with joy where the Bob was and flies to the counter (`to`, both in the
## coordinates of `parent`), shrinking to `end_size` units; calls `arrived` when it lands.
static func flier(parent: Node, from: Vector2, to: Vector2, start_size: float, end_size: float, arrived: Callable) -> void:
	load_art()
	var s := Sprite2D.new()
	s.texture = _faces[Face.JOY]
	s.position = from
	var k0 := start_size / (_radius_px * 2.0)
	var k1 := end_size / (_radius_px * 2.0)
	s.scale = Vector2.ONE * k0
	parent.add_child(s)
	# the pop: a quick swell with a squash, then away on a curve (up first, then to the counter)
	var lift := from + Vector2(-from.distance_to(to) * 0.08, -minf(110.0, from.distance_to(to) * 0.35))
	# (it leaves at once and shrinks as it goes, a short tapered streak of warm light behind it: a
	# quick run of pickups reads as treasure flying home; New: no more faded copies of the ball,
	# which read as a drawing bug)
	var streak := Line2D.new()
	streak.width = start_size * 0.55
	streak.width_curve = Curve.new()
	streak.width_curve.add_point(Vector2(0, 1))
	streak.width_curve.add_point(Vector2(1, 0))
	streak.gradient = Gradient.new()
	streak.gradient.set_color(0, Color(1.0, 0.72, 0.42, 0.55))
	streak.gradient.set_color(1, Color(1.0, 0.45, 0.2, 0.0))
	streak.joint_mode = Line2D.LINE_JOINT_ROUND
	streak.begin_cap_mode = Line2D.LINE_CAP_ROUND
	streak.material = _additive
	parent.add_child(streak)
	parent.move_child(streak, s.get_index())
	var history: Array[Vector2] = []
	var t := s.create_tween()
	t.tween_method(func(u: float) -> void:
		var e := u * (1.0 - u) * 0.9 + u * u  # leaves briskly, arrives fast
		var a := from.lerp(lift, e)
		var b := lift.lerp(to, e)
		s.position = a.lerp(b, e)
		s.rotation = -0.6 * u
		s.scale = Vector2.ONE * lerpf(k0 * 0.8, k1 * 0.8, sqrt(u))
		history.push_front(s.position)
		if history.size() > 6:
			history.pop_back()
		streak.points = PackedVector2Array(history)
		streak.width = s.scale.x * _radius_px * 1.1, 0.0, 1.0, 0.42)
	t.tween_callback(func() -> void:
		arrived.call()
		streak.queue_free()
		s.queue_free())

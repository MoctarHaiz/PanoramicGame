class_name JuicyButton
extends Button
## A tactile button: its face sinks into its edge when pressed, then springs back with a click
## and a light buzz. The main button of a screen can also breathe (idle()) and shine (shine()): a
## sweep of light now and then, glints twinkling on its ring between two sweeps.

const PRESS_DEPTH := 6.0

## Inner content (text, icon) that sinks with the face. Set by the Ui builders.
var content: Control
var click_sound := true
## Smallest side of the area that takes touches (design units): a small button still takes a
## thumb-sized touch around it.
var touch_size := Ui.MIN_TOUCH

var _tween: Tween
var _squash := 1.0  # pressed size (animated)
var _breath := 0.0  # idle pulse strength (0: none)
var _clock := 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	button_down.connect(_press.bind(true))
	button_up.connect(_press.bind(false))
	pressed.connect(_on_pressed)
	resized.connect(func() -> void: pivot_offset = size / 2)
	pivot_offset = size / 2
	set_process(_breath > 0)


## The area that takes touches, in the button's own coordinates: its rect, grown to touch_size.
func hit_rect() -> Rect2:
	var grow := ((Vector2(touch_size, touch_size) - size) / 2).max(Vector2.ZERO)
	return Rect2(-grow, size + grow * 2)


func _has_point(point: Vector2) -> bool:
	return hit_rect().has_point(point)


## The touch area on screen (for screens that route touches themselves).
func global_hit_rect() -> Rect2:
	var r := hit_rect()
	return Rect2(get_global_transform() * r.position, r.size * get_global_transform().get_scale())


## A slow, springy pulse that says "tap me" (the screen's main action). Not with reduced motion.
func idle(strength := 0.035) -> void:
	if not Prefs.motion():
		return
	_breath = strength
	set_process(is_inside_tree())


## A band of light sweeps across the face every `every` seconds (the face's shape clips it).
func shine(every := 3.2) -> void:
	if not Prefs.motion():
		return
	var band := _Shine.new()
	band.every = every
	band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(band)
	move_child(band, 0)  # under the label


func _process(delta: float) -> void:
	_clock += delta
	_apply_scale()


func _apply_scale() -> void:
	var k := _squash
	if _breath > 0:
		# A heartbeat: two quick swells, then a rest.
		var t := fposmod(_clock, 1.6)
		var beat := maxf(0.0, sin(t / 0.45 * PI)) if t < 0.45 else 0.0
		k *= 1.0 + _breath * beat
		scale = Vector2(k * (1.0 + _breath * 0.3 * beat), k)
	else:
		scale = Vector2(k, k)


func _set_squash(v: float) -> void:
	_squash = v
	_apply_scale()


func _press(down: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if down:
		_tween.tween_method(_set_squash, _squash, 0.95, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if content:
			_tween.tween_property(content, "position:y", PRESS_DEPTH, 0.06)
	else:
		_tween.tween_method(_set_squash, _squash, 1.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if content:
			_tween.tween_property(content, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_pressed() -> void:
	if click_sound:
		Audio.play_sfx(&"button")
	Haptics.tap()


## The sweep of light: a soft slanted sheen clipped to the face of the button's GlossStyle, its light
## a smooth gradient (vertex colours: clear at both edges, brightest in the middle, no hard edge).
class _Shine extends Control:
	const PEAK := 0.3  ## the light in the middle of the band
	var every := 3.2
	var _t := -1.8  # the first sweep once the screen has settled (not while it pops in)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var button := get_parent() as Button
		var style := button.get_theme_stylebox(&"pressed" if button.button_pressed else &"normal") as GlossStyle
		if not style:
			return
		var rect := Rect2(Vector2.ZERO, size)
		_glints(style, rect)
		var k := fposmod(_t, every) / 0.7  # the sweep takes 0.7 s
		if _t < 0.0 or k >= 1.0:
			return
		var face := style.face_rect(rect)
		var w := face.size.y * 1.1
		var x := lerpf(face.position.x - w * 2, face.end.x + w, k)
		var slant := face.size.y * 0.5
		var clip := GlossStyle.rounded_points(face, style.face_radius(rect))
		# slices only so the vertex colours can follow the sine; each slice is shaded smoothly
		var slices := 6
		for i in slices:
			var a := x + w * i / slices
			var b := x + w * (i + 1) / slices
			var band := PackedVector2Array([Vector2(a + slant, face.position.y), Vector2(b + slant, face.position.y),
					Vector2(b, face.end.y), Vector2(a, face.end.y)])
			for poly in Geometry2D.intersect_polygons(clip, band):
				var colours := PackedColorArray()
				for p in poly:  # across the band: where this point lies once the slant is taken out
					var u := (p.x - x - slant * (face.end.y - p.y) / face.size.y) / w
					colours.append(Color(1, 1, 1, sin(clampf(u, 0.0, 1.0) * PI) * PEAK))
				draw_polygon(poly, colours)

	## Two glints on the brass ring (its top left and bottom right corners) twinkling out of step: the
	## sparkle of top games' main buttons, there between two sweeps.
	func _glints(style: GlossStyle, rect: Rect2) -> void:
		var ring := style.top_rect(rect)
		var rr := minf(style.radius - style.outline_width, minf(ring.size.x, ring.size.y) / 2)
		var arm := ring.size.y * 0.5  # big enough to read on a phone (round 9's read as a faint cross)
		for g: Array in [[Vector2(-1, -1), 0.0, 1.0], [Vector2(1, 1), 2.1, 0.75]]:
			var dir: Vector2 = g[0]
			var corner := ring.get_center() + Vector2(ring.size.x / 2 - rr, ring.size.y / 2 - rr) * dir
			var at := corner + dir.normalized() * (rr - style.frame_width * 0.5)
			var beat := 0.5 + 0.5 * sin(_t * 2.4 + float(g[1]))
			_star(at, arm * float(g[2]) * (0.65 + 0.35 * beat), 0.5 + 0.5 * beat)

	## A glint: a soft halo, four long bright arms and four short diagonal ones fading to their tips,
	## a white core.
	func _star(at: Vector2, arm: float, alpha: float) -> void:
		draw_circle(at, arm * 0.42, Color(1, 0.95, 0.7, 0.16 * alpha), true, -1, true)
		draw_circle(at, arm * 0.24, Color(1, 0.97, 0.8, 0.3 * alpha), true, -1, true)
		for k: Array in [[arm, -PI / 2, 0.2], [arm * 0.45, -PI / 4, 0.3]]:
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			for i in 8:
				var r: float = k[0] if i % 2 == 0 else k[0] * k[2]
				pts.append(at + Vector2.from_angle(i * PI / 4 + float(k[1])) * r)
				cols.append(Color(1, 1, 0.92, 0.0 if i % 2 == 0 else alpha))
			draw_polygon(pts, cols)
		draw_circle(at, arm * 0.12, Color(1, 1, 0.97, alpha), true, -1, true)

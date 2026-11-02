class_name Hud
extends Control
## The game's heads-up display, inside the safe area. Every piece sits on the same plate (dark
## glazed wood, outlined, bevelled, lit along its top: the candy kit of the buttons), one family:
## - lives on the left: three hearts; a lost one flies off and leaves an empty socket; the last one
##   beats like a heart when it is all that is left;
## - the way home in the middle: a thick gold track that fills as the level scrolls, Panoramic's
##   framed face running along it to the house on a gold disc at its end;
## - the Red Bobs on the right (each one counts when it lands on the counter, BobView.flier) and
##   the pause button on its own plate.

signal pause_pressed

const ROW_HEIGHT := 60.0
const BOB_ICON := 46.0  ## size of the Red Bob on the counter
const TRACK_W := 300.0
const HEART := 34.0
const PLATE_TOP := Color(0.44, 0.21, 0.11, 0.94)
const PLATE_BOTTOM := Color(0.25, 0.08, 0.03, 0.94)
const PLATE_EDGE := Color(0.13, 0.04, 0.02, 0.96)
const PLATE_LINE := Color(0.09, 0.02, 0.01, 0.96)

var world: World
var _hearts: Array[Control] = []
var _count_box: Control
var _number: DisplayText
var _bob_icon: TextureRect
var _track: _Track
var _pause: JuicyButton
var _shown_bobs := -1
var _shown_lives := -1
var _in_flight := 0  # Red Bobs on their way to the counter (counted when they land)
var _fx: Node2D  # effects (the Fx kit is sized for a 1280-tall design: drawn at half size)
var _clock := 0.0
var _lives_glass: Control
var _track_glass: Control
var _hero_rect := Rect2()  # where Panoramic is on screen (game_screen sets it every frame)


## The HUD's plate: a candy shape in glazed dark wood (see GlossStyle).
static func plate(radius: float, pressed := false) -> GlossStyle:
	var s := GlossStyle.new(PLATE_TOP, PLATE_BOTTOM, PLATE_EDGE, radius, 5.0, pressed)
	s.set_outline(PLATE_LINE, 3.0)
	s.rim = 0.2
	s.gloss = 0.08
	s.shadow.shadow_color = Color(0, 0, 0, 0.28)
	s.shadow.shadow_size = 8
	s.shadow.shadow_offset = Vector2(0, 4)
	return s


func setup(w: World) -> void:
	world = w
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var area := SafeArea.new(false, 12.0)
	add_child(area)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override(&"separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(row)

	# lives
	var hearts := HBoxContainer.new()
	hearts.add_theme_constant_override(&"separation", 4)
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in World.LIVES:
		var slot := Control.new()  # an empty socket under each heart
		slot.custom_minimum_size = Vector2(HEART, HEART) + Vector2(6, 8)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var socket := Ui.bold_icon("heart-fill", HEART, Color(0, 0, 0, 0.4), Color(PLATE_LINE, 0.6))
		slot.add_child(socket)
		var h := Ui.bold_icon("heart-fill", HEART, Color("ff3d24"), PLATE_LINE)
		h.pivot_offset = slot.custom_minimum_size / 2
		slot.add_child(h)
		hearts.add_child(slot)
		_hearts.append(h)
	_lives_glass = _glass(hearts, 14.0)
	row.add_child(_lives_glass)

	var middle := CenterContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(middle)
	_track = _Track.new()
	_track_glass = _glass(_track, 10.0)
	middle.add_child(_track_glass)

	_count_box = _counter()
	_count_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_count_box)
	var gap := Control.new()  # the counter never crowds the pause button
	gap.custom_minimum_size = Vector2(6, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	_pause = _pause_button(ROW_HEIGHT)
	_pause.pressed.connect(pause_pressed.emit)
	row.add_child(_pause)
	_fx = Node2D.new()
	_fx.scale = Vector2.ONE * 0.5
	add_child(_fx)
	refresh()


## A plate around a row of things.
func _glass(content: Control, side_margin: float) -> PanelContainer:
	var s := plate(ROW_HEIGHT / 2.0)
	s.content_margin_left = side_margin
	s.content_margin_right = side_margin
	s.content_margin_top = 5.0
	s.content_margin_bottom = 5.0 + 5.0
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(content)
	return p


## The Red Bob counter: the count on a plate, the Bob overlapping its left end.
func _counter() -> Control:
	_bob_icon = TextureRect.new()
	_bob_icon.texture = BobView.texture()
	_bob_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bob_icon.custom_minimum_size = Vector2(BOB_ICON, BOB_ICON) * 1.2
	_bob_icon.size = _bob_icon.custom_minimum_size
	_bob_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number = Ui.display_text("000", 32, Ui.WHITE, PLATE_LINE, Color("ffe2a8"))
	_number.outline_width = 5.0
	_number.depth = 3.0
	_number.shadow = Color(0, 0, 0, 0)
	_number.align = HORIZONTAL_ALIGNMENT_LEFT
	_number.refresh()
	var s := plate(ROW_HEIGHT / 2.0)
	s.content_margin_left = _bob_icon.size.x * 0.62
	s.content_margin_right = 16.0
	s.content_margin_bottom = 5.0
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override(&"panel", s)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(_number.get_combined_minimum_size().x + 6.0, ROW_HEIGHT - 8.0)
	holder.add_child(_number)
	pill.add_child(holder)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pill)
	box.add_child(_bob_icon)
	pill.position = Vector2(_bob_icon.size.x * 0.4, 0)
	pill.size = Vector2(pill.get_combined_minimum_size().x, ROW_HEIGHT)
	_bob_icon.position = Vector2(0, (ROW_HEIGHT - 5.0 - _bob_icon.size.y) / 2)
	box.custom_minimum_size = Vector2(pill.position.x + pill.size.x, ROW_HEIGHT)
	return box


## The pause button: a round plate with a white pause sign, sinking when pressed.
func _pause_button(side: float) -> JuicyButton:
	var b := JuicyButton.new()
	b.custom_minimum_size = Vector2(side, side)
	for state in [&"normal", &"hover"]:
		b.add_theme_stylebox_override(state, plate(side / 2.0))
	b.add_theme_stylebox_override(&"pressed", plate(side / 2.0, true))
	var icon := Ui.bold_icon("pause-fill", side * 0.42, Ui.WHITE, PLATE_LINE)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_top = 3.0
	holder.offset_bottom = -8.0
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(icon)
	b.add_child(holder)
	b.content = icon
	return b


func _process(delta: float) -> void:
	_clock += delta
	# the lives and the track fade while he is under them (hanging under the vine, a high jump)
	for item: Control in [_lives_glass, _track_glass]:
		if item:
			var over := item.get_global_rect().grow(6.0).intersects(_hero_rect)
			item.modulate.a = move_toward(item.modulate.a, 0.28 if over else 1.0, delta * 5.0)
	# the last heart beats
	if world and world.lives == 1 and _hearts.size() > 0:
		var t := fposmod(_clock, 0.9)
		var beat := maxf(sin(t / 0.16 * PI), 0.0) if t < 0.16 else (maxf(sin((t - 0.2) / 0.14 * PI), 0.0) * 0.6 if t < 0.34 else 0.0)
		_hearts[0].scale = Vector2.ONE * (1.0 + 0.16 * beat)


## Where Panoramic is on screen, so the pieces over him can fade.
func hero_at(r: Rect2) -> void:
	_hero_rect = r


func refresh() -> void:
	var bobs := maxi(world.bobs - _in_flight, 0)
	if bobs != _shown_bobs:
		var bumped := _shown_bobs >= 0 and bobs > _shown_bobs
		_shown_bobs = bobs
		_number.text = str(bobs)
		if bumped:
			_bump(_bob_icon, 1.35)
			_bump(_number, 1.2)
	if world.lives != _shown_lives:
		if _shown_lives > world.lives:
			for i in range(maxi(world.lives, 0), mini(_shown_lives, _hearts.size())):
				_lose_heart(_hearts[i])
		elif _shown_lives < 0:
			for i in _hearts.size():
				_hearts[i].visible = i < world.lives
		_shown_lives = world.lives
	_track.progress = world.progress()


## A heart lost: it swells, flashes white, and flies off spinning while it fades.
func _lose_heart(h: Control) -> void:
	var start := h.position
	var t := h.create_tween()
	t.tween_property(h, "scale", Vector2.ONE * 1.6, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(h, "modulate", Color(3, 3, 3), 0.08)
	t.tween_property(h, "modulate", Color(1, 1, 1, 0), 0.45)
	t.parallel().tween_property(h, "position", start + Vector2(10, -50), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(h, "rotation", 0.8, 0.45)
	t.parallel().tween_property(h, "scale", Vector2.ONE * 0.6, 0.45)
	t.tween_callback(func() -> void:
		h.visible = false
		h.position = start
		h.rotation = 0.0
		h.scale = Vector2.ONE
		h.modulate = Color.WHITE)


func _bump(c: Control, amount: float) -> void:
	c.pivot_offset = c.size / 2
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE * amount, 0.06)
	t.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A Red Bob is flying to the counter: it counts when it lands.
func bob_launched() -> void:
	_in_flight += 1


func bob_arrived() -> void:
	_in_flight = maxi(_in_flight - 1, 0)
	Fx.counter_pop(_fx, bob_target() * 2.0)


## The Red Bob counter's rect on screen (the combo badge pins itself to its corner).
func counter_rect() -> Rect2:
	return _count_box.get_global_rect()


## Where the Red Bob counter's icon is, in screen units (for pickups that fly to it).
func bob_target() -> Vector2:
	return _bob_icon.get_global_rect().get_center()


## True when a touch at `pos` belongs to a HUD button, not to the game.
func blocks(pos: Vector2) -> bool:
	return _pause.get_global_rect().grow(10).has_point(pos)


## The way home: a sunken groove, a thick gold fill with a moving sheen, quarter marks, Panoramic's
## face in a gold ring at its tip and the house on a gold disc at the end.
class _Track extends Control:
	const HEAD := preload("res://assets/art/ui/head.png")
	const GROOVE := 22.0
	var progress := 0.0:
		set(value):
			if not is_equal_approx(value, progress):
				progress = value
				queue_redraw()
	var _clock := 0.0
	var _house: BoldIcon
	var _styles := {}  # (colour, radius, border) -> StyleBoxFlat, made once

	func _init() -> void:
		custom_minimum_size = Vector2(Hud.TRACK_W + 44, Hud.ROW_HEIGHT - 10.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_house = Ui.bold_icon("house-fill", 22, Ui.WHITE, Hud.PLATE_LINE)
		add_child(_house)

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		var y := size.y / 2
		var x0 := 22.0
		var w := Hud.TRACK_W - 22.0
		var groove := Rect2(x0, y - GROOVE / 2, w, GROOVE)
		_rounded(groove, Color(0.06, 0.01, 0.0, 0.8), GROOVE / 2)
		# the way still to go: a pale dusty path in the groove
		_rounded(groove.grow(-3.0), Color(0.86, 0.66, 0.42, 0.42), GROOVE / 2 - 3.0)
		_rounded(Rect2(groove.position + Vector2(5, GROOVE * 0.5), Vector2(w - 10, 3)), Color(0.35, 0.18, 0.08, 0.35), 1.5)
		var fill_w := maxf(w * progress, 0.0)
		if fill_w > 6.0:
			var fill := Rect2(x0 + 3, y - GROOVE / 2 + 3, fill_w - 3, GROOVE - 6)
			_rounded(fill, Color("e08a10"), fill.size.y / 2)
			_rounded(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.62)), Color("ffc93c"), fill.size.y * 0.31)
			_rounded(Rect2(fill.position + Vector2(4, 2), Vector2(maxf(fill.size.x - 8, 0), 3)), Color(1, 1, 0.9, 0.7), 1.5)
			# a sheen running along the fill
			var sx := fposmod(_clock * 140.0, fill_w + 80.0) - 40.0
			if sx > 0 and sx < fill_w - 8:
				draw_rect(Rect2(fill.position.x + sx, fill.position.y + 1, 8, fill.size.y - 2), Color(1, 1, 1, 0.5))
		# quarter marks: gold pips, dim ahead of him, lit once passed
		for i in range(1, 4):
			var mx := x0 + w * i / 4.0
			var passed := mx <= x0 + fill_w
			draw_circle(Vector2(mx, y), 6.0, Hud.PLATE_LINE)
			draw_circle(Vector2(mx, y), 4.2, Color("ffe08a") if passed else Color(0.72, 0.52, 0.3))
			draw_circle(Vector2(mx - 1.2, y - 1.4), 1.6, Color(1, 1, 1, 0.8 if passed else 0.35))
		# the house at the end, on a gold disc
		var hc := Vector2(x0 + w + 6, y)
		draw_circle(hc, 21.0, Hud.PLATE_LINE)
		draw_circle(hc, 18.0, Color("e08a10"))
		draw_circle(hc + Vector2(0, -2), 15.5, Color("ffc93c"))
		_house.position = hc - _house.size / 2 + Vector2(0, 1)
		# the face in its gold ring, bobbing a little as it runs
		var hx := x0 + 3 + fill_w
		var bob := absf(sin(_clock * 8.0)) * 2.0
		var c := Vector2(hx, y - bob)
		draw_circle(c, 24.0, Hud.PLATE_LINE)
		draw_circle(c, 21.5, Color("ffc93c"))
		draw_texture_rect(HEAD, Rect2(c - Vector2(19, 19), Vector2(38, 38)), false)

	func _rounded(r: Rect2, colour: Color, radius: float, border := Color(0, 0, 0, 0), border_w := 0.0) -> void:
		var key := [colour, int(minf(radius, r.size.y / 2)), border, border_w]
		var s: StyleBoxFlat = _styles.get(key)
		if not s:
			s = StyleBoxFlat.new()
			s.bg_color = colour
			s.set_corner_radius_all(key[1])
			s.anti_aliasing = true
			if border_w > 0:
				s.border_color = border
				s.set_border_width_all(int(border_w))
				s.draw_center = colour.a > 0
			_styles[key] = s
		draw_style_box(s, r)

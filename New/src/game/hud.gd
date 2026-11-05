class_name Hud
extends Control
## The game's heads-up display, inside the safe area, over a soft shade along the top that sets it
## apart from the vine. Every piece sits on the same slim plate (dark smoked glass in a thin bright
## brass rim, a fine ink line, a soft shadow: the kit of the buttons, without their heavy bevel), one
## family:
## - lives on the left: three glossy hearts; a lost one flashes, cracks in two and its halves fall
##   while the plate flashes red, leaving a dark socket; the last one beats when it is all that is
##   left;
## - the way home in the middle: a dark trail cut into the plate, his footprints faint on it leading
##   to the house, filling with gold as the level scrolls, Panoramic's face, big in its gold ring over
##   the plate's edges, running along it to the house on a gold disc;
## - the Red Bobs on the right (counted the moment one is taken, the counter punching and
##   flashing) and the pause button, a round gold button of the kit in a bright brass ring.
## The plates stay solid (a HUD held half see-through, or gone for seconds, reads as broken).

signal pause_pressed

const ROW_HEIGHT := 60.0
const BOB_ICON := 46.0  ## size of the Red Bob on the counter
const GEM_ICON := "res://assets/art/bob/icon.png"  ## art's ruby icon for the counter, when it is there
const TRACK_W := 300.0
const HEART := 39.0
const PLATE_TOP := Color(0.24, 0.1, 0.07, 0.88)
const PLATE_BOTTOM := Color(0.12, 0.04, 0.03, 0.9)
const PLATE_EDGE := Color(0.08, 0.02, 0.01, 0.92)
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


## The HUD's plate: dark smoked glass in a thin bright brass rim (see GlossStyle), a shallow edge.
static func plate(radius: float, pressed := false) -> GlossStyle:
	var s := GlossStyle.new(PLATE_TOP, PLATE_BOTTOM, PLATE_EDGE, radius, 3.0, pressed)
	s.set_outline(PLATE_LINE, 2.0)
	s.set_frame(3.5, Ui.BRASS[0], Ui.BRASS[1], Color(PLATE_LINE, 0.8))  # the kit's brass ring, bright
	s.rim = 0.22
	s.gloss = 0.22  # a little light inside the top of each pill
	s.shadow.shadow_color = Color(0.05, 0.0, 0.0, 0.42)  # it stands off the vine and the sky behind it
	s.shadow.shadow_size = 12
	s.shadow.shadow_offset = Vector2(0, 6)
	return s


func setup(w: World) -> void:
	world = w
	name = "Hud"  # (perf.tscn --hide=Hud measures what it costs)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shelf := TextureRect.new()  # a soft shade along the top: the HUD's band reads apart from the vine
	var g := GradientTexture2D.new()
	g.fill_from = Vector2(0.5, 0.0)
	g.fill_to = Vector2(0.5, 1.0)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(0.05, 0.0, 0.03, 0.42))
	g.gradient.set_color(1, Color(0.05, 0.0, 0.03, 0.0))
	shelf.texture = g
	shelf.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shelf.stretch_mode = TextureRect.STRETCH_SCALE
	shelf.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shelf.custom_minimum_size.y = ROW_HEIGHT + 34.0
	shelf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shelf.name = "HudShelf"
	add_child(shelf)
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
		slot.add_child(_Heart.new(HEART, false))  # the empty socket under it
		var h := _Heart.new(HEART, true)
		h.pivot_offset = h.size / 2
		slot.add_child(h)
		hearts.add_child(slot)
		_hearts.append(h)
	_lives_glass = _glass(hearts, 14.0)
	_lives_glass.name = "HudLives"
	row.add_child(_lives_glass)

	var middle := CenterContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(middle)
	_track = _Track.new()
	_track_glass = _glass(_track, 10.0)
	_track_glass.name = "HudTrack"
	middle.add_child(_track_glass)

	_count_box = _counter()
	_count_box.name = "HudCount"
	_count_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_count_box)
	var gap := Control.new()  # the counter never crowds the pause button
	gap.custom_minimum_size = Vector2(26, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	_pause = _pause_button(ROW_HEIGHT + 4.0)
	_pause.name = "HudPause"
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
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0 + 3.0
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(content)
	return p


## The Red Bob counter: the count on a plate, the Bob overlapping its left end.
func _counter() -> Control:
	_bob_icon = TextureRect.new()
	# art's ruby icon when there is one, else the Red Bob's own picture (the faceted ruby)
	_bob_icon.texture = load(GEM_ICON) if ResourceLoader.exists(GEM_ICON) else BobView.texture()
	_bob_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bob_icon.custom_minimum_size = Vector2(BOB_ICON, BOB_ICON) * 1.2
	_bob_icon.size = _bob_icon.custom_minimum_size
	_bob_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number = Ui.display_text("000", 38, Ui.WHITE, PLATE_LINE, Color("ffe2a8"))
	_number.outline_width = 5.0
	_number.depth = 3.0
	_number.shadow = Color(0, 0, 0, 0)
	_number.align = HORIZONTAL_ALIGNMENT_LEFT
	_number.refresh()
	var s := plate(ROW_HEIGHT / 2.0)
	s.content_margin_left = _bob_icon.size.x * 0.62
	s.content_margin_right = 16.0
	s.content_margin_bottom = 3.0
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
	var back := Panel.new()  # an ink disc behind the gem: it holds its shape over the sky
	var bs := StyleBoxFlat.new()
	bs.bg_color = PLATE_LINE
	bs.set_corner_radius_all(int(_bob_icon.size.x / 2 + 3))
	bs.anti_aliasing = true
	back.add_theme_stylebox_override(&"panel", bs)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.size = _bob_icon.size * 0.86 + Vector2(6, 6)
	box.add_child(back)
	box.add_child(_bob_icon)
	pill.position = Vector2(_bob_icon.size.x * 0.4, 0)
	pill.size = Vector2(pill.get_combined_minimum_size().x, ROW_HEIGHT)
	_bob_icon.position = Vector2(0, (ROW_HEIGHT - 5.0 - _bob_icon.size.y) / 2)
	back.position = _bob_icon.position + _bob_icon.size / 2 - back.size / 2
	box.custom_minimum_size = Vector2(pill.position.x + pill.size.x, ROW_HEIGHT)
	return box


## The pause button: a round gold button of the kit (the pause's own tiles), a white pause sign,
## sinking when pressed.
func _pause_button(side: float) -> JuicyButton:
	var b := Ui.icon_button("pause-fill", Ui.Tone.GOLD, side, side / 2.0, Ui.BRASS)  # bright, as the house's disc
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


func _process(delta: float) -> void:
	_clock += delta
	# the last heart beats
	if world and world.lives == 1 and _hearts.size() > 0:
		var t := fposmod(_clock, 0.9)
		var beat := maxf(sin(t / 0.16 * PI), 0.0) if t < 0.16 else (maxf(sin((t - 0.2) / 0.14 * PI), 0.0) * 0.6 if t < 0.34 else 0.0)
		_hearts[0].scale = Vector2.ONE * (1.0 + 0.16 * beat)


## The run is over: the HUD leaves in a blink (it slides up out of the screen as it fades), never
## held half see-through.
func leave() -> void:
	set_process(false)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position:y", -110.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.14).set_delay(0.06)
	t.chain().tween_callback(hide)  # gone, not waiting above the screen (nor catching a tap)


## Where Panoramic is on screen (game_screen sets it every frame).
func hero_at(r: Rect2) -> void:
	_hero_rect = r


func refresh() -> void:
	var bobs := world.bobs  # New: counted the moment it is taken (the flier is decoration)
	if bobs != _shown_bobs:
		var bumped := _shown_bobs >= 0 and bobs > _shown_bobs
		_shown_bobs = bobs
		_number.text = str(bobs)
		if bumped:
			_bump(_bob_icon, 1.4)
			_bump(_number, 1.3)
			_glow_at(_count_box.get_global_rect(), Color(1, 0.85, 0.45, 0.6), 1.3, true)  # behind: the gem stays crisp
	if world.lives != _shown_lives:
		if _shown_lives > world.lives:
			for i in range(maxi(world.lives, 0), mini(_shown_lives, _hearts.size())):
				_lose_heart(_hearts[i])
		elif _shown_lives < 0:
			for i in _hearts.size():
				_hearts[i].visible = i < world.lives
		_shown_lives = world.lives
	_track.progress = world.progress()


## A heart lost: it swells in a flash of white light, cracks in two, and the halves fall away
## spinning while the plate flashes red; its socket stays, dark (added light, so it shows on phones).
func _lose_heart(h: Control) -> void:
	var slot := h.get_parent() as Control
	_glow_at(h.get_global_rect(), Color(1, 0.95, 0.85, 0.95), 1.6)
	_glow_at(_lives_glass.get_global_rect(), Color(1, 0.15, 0.1, 0.7), 1.0)
	var t := h.create_tween()
	t.tween_property(h, "scale", Vector2.ONE * 1.4, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		h.visible = false
		h.scale = Vector2.ONE
		for side: float in [-1.0, 1.0]:  # the two halves
			var half := Control.new()
			half.clip_contents = true
			half.mouse_filter = Control.MOUSE_FILTER_IGNORE
			half.size = Vector2(h.size.x / 2, h.size.y)
			half.position = h.position + Vector2(0.0 if side < 0 else h.size.x / 2, 0)
			half.pivot_offset = Vector2(h.size.x / 2 if side < 0 else 0.0, h.size.y)
			var copy := _Heart.new(HEART, true)
			copy.position = Vector2(0.0 if side < 0 else -h.size.x / 2, 0)
			half.add_child(copy)
			slot.add_child(half)
			var f := half.create_tween().set_parallel(true)
			f.tween_property(half, "rotation", side * 0.9, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			f.tween_property(half, "position", half.position + Vector2(side * 14.0, 46.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			f.tween_property(half, "modulate", Color(0.4, 0.1, 0.1, 0.0), 0.5)
			f.chain().tween_callback(half.queue_free))


## A burst of added light over `r` (screen units): a flash on the counter, a lost heart; `behind`: under
## the plates.
func _glow_at(r: Rect2, colour: Color, grow: float, behind := false) -> void:
	var g := TextureRect.new()
	g.texture = Fx.glow_texture()
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.material = Fx.additive()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side := maxf(r.size.x, r.size.y) * grow
	g.size = Vector2(side, side * minf(r.size.y / maxf(r.size.x, 1.0) * 2.0, 1.0))
	g.position = r.get_center() - g.size / 2 - get_global_rect().position
	g.pivot_offset = g.size / 2
	g.modulate = colour
	add_child(g)
	if behind:  # under the plates (over them it washed the gem to a pink blob)
		move_child(g, 1)
	var t := g.create_tween().set_parallel(true)
	t.tween_property(g, "scale", Vector2.ONE * 1.25, 0.3).from(Vector2.ONE * 0.6)
	t.tween_property(g, "modulate:a", 0.0, 0.3).set_delay(0.06)
	t.chain().tween_callback(g.queue_free)


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
	return _pause.global_hit_rect().has_point(pos)


## The way home: a dark trail cut into the plate, his footprints faint on it (_Groove, drawn once), a thick
## bright gold fill with a lit top edge to where he is, Panoramic's
## face big in a gold ring at its tip (over the plate's edges, as the icons of top games' counters),
## and the house on a glowing gold disc at the end.
class _Track extends Control:
	const HEAD := preload("res://assets/art/ui/head.png")
	const GROOVE := 24.0
	const X0 := 36.0  ## where the trail starts (room for his face at the start)
	const FACE := 62.0  ## his portrait's side (bigger than the plate: over its edges)
	var progress := 0.0:
		set(value):
			if not is_equal_approx(value, progress):
				progress = value
				queue_redraw()
	var _clock := 0.0
	var _house: BoldIcon
	var _face: TextureRect  # his portrait, lifted (lift.gdshader): bright in its ring

	func _init() -> void:
		custom_minimum_size = Vector2(Hud.TRACK_W + 50, Hud.ROW_HEIGHT - 8.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_house = Ui.bold_icon("house-fill", 27, Ui.WHITE, Hud.PLATE_LINE)
		add_child(_house)
		_face = TextureRect.new()
		_face.texture = HEAD
		_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_face.size = Vector2(FACE, FACE)
		_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lift := ShaderMaterial.new()
		lift.shader = preload("res://src/ui/lift.gdshader")
		_face.material = lift
		add_child(_face)
		var groove := Hud._Groove.new()  # still: drawn once, behind the fill (not every frame)
		groove.show_behind_parent = true
		groove.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(groove)

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:  # every shape in one triangle array: one draw call (a call each added up)
		var ci := get_canvas_item()
		var y := size.y / 2
		var x0 := X0
		var w := Hud.TRACK_W - 34.0
		var fill_w := maxf(w * progress, 0.0)
		GlossStyle.begin_batch()
		# the way done: a bright gold fill in the groove's own shape, a rounded end, a lit top inside
		var groove := Rect2(x0, y - GROOVE / 2, w, GROOVE).grow(-2.0)
		GlossStyle.fill_bar(ci, groove, groove.size.y / 2, x0 + 2 + fill_w, Color("ffcf3a"), Color("e07a0c"), 0.75)
		# the house at the end, on a glowing gold disc
		var hc := Vector2(x0 + w + 12, y)
		var pulse := 0.5 + 0.5 * sin(_clock * 3.0)
		GlossStyle.fill_disc(ci, hc, 33.0 + pulse * 3.0, Color(1, 0.85, 0.4, 0.18 + 0.1 * pulse))
		GlossStyle.fill_disc(ci, hc, 27.0, Hud.PLATE_LINE)
		GlossStyle.fill_disc(ci, hc, 24.5, Color("e08a10"))
		GlossStyle.fill_disc(ci, hc + Vector2(0, -2), 22.0, Color("ffc93c"))
		GlossStyle.fill_disc(ci, hc + Vector2(-7, -10), 5.5, Color(1, 1, 0.9, 0.5))
		_house.position = hc - _house.size / 2 + Vector2(0, 1)
		# the face in its gold ring, bobbing a little as it runs
		var hx := x0 + 4 + fill_w
		var bob := absf(sin(_clock * 8.0)) * 2.0
		var c := Vector2(hx, y - bob)
		var ring := FACE / 2 + 5.0
		GlossStyle.fill_disc(ci, c + Vector2(0, 4), ring, Color(0, 0, 0, 0.32))
		GlossStyle.fill_disc(ci, c, ring, Hud.PLATE_LINE)
		GlossStyle.fill_disc(ci, c, ring - 2.5, Color("e08a10"))
		GlossStyle.fill_disc(ci, c + Vector2(0, -1), ring - 4.0, Color("ffd34a"))
		GlossStyle.end_batch(ci)
		_face.position = c - _face.size / 2



## The way home's trail (the _Track's, behind its fill): a dark groove cut into the plate (a shade under
## its upper edge, the plate's lit lip under it: sand read as already filled, or disabled), his
## footprints faint on it, leading to the house (the gold fill covers them as he goes). Drawn once.
class _Groove extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ci := get_canvas_item()
		var w := Hud.TRACK_W - 34.0
		var g := Rect2(_Track.X0, size.y / 2 - _Track.GROOVE / 2, w, _Track.GROOVE)
		var r := _Track.GROOVE / 2
		GlossStyle.begin_batch()  # the groove and its footprints in one draw call
		GlossStyle.fill_rounded(ci, Rect2(g.position + Vector2(0, 2.0), g.size).grow(2.0), r + 2.0,
				Color(1, 0.85, 0.6, 0.22), Color(1, 0.85, 0.6, 0.22))  # the plate's lit lip under it
		GlossStyle.fill_rounded(ci, g.grow(2.0), r + 2.0, Hud.PLATE_LINE, Hud.PLATE_LINE)
		GlossStyle.fill_rounded(ci, g, r, Color("1e0a05"), Color("4a2410"))  # dark: only the way done is coloured
		GlossStyle.fill_clipped(ci, g, r, Rect2(g.position, Vector2(w, _Track.GROOVE * 0.45)),
				Color(0, 0, 0, 0.55), Color(0, 0, 0, 0))
		var x := g.position.x + 22.0
		var k := 0
		var print_colour := Color(1, 0.82, 0.55, 0.13)  # faint on the dark
		while x < g.end.x - 18.0:  # footprints, left and right, walking towards the house
			var at := Vector2(x, g.get_center().y + (-3.2 if k % 2 == 0 else 3.2))
			var turn := 0.2 if k % 2 == 0 else -0.2
			GlossStyle.fill_disc(ci, at, 4.2, print_colour, Vector2(1.0, 0.62), turn)
			GlossStyle.fill_disc(ci, at + Vector2(5.6, 0).rotated(turn), 2.0, print_colour, Vector2(1.0, 0.62), turn)  # the toes
			x += 15.0
			k += 1
		GlossStyle.end_batch(ci)


## A heart: full, it is glossy red in an ink outline with a white shine on its left lobe; empty, a
## dark socket pressed into the plate with a lit lip below (the two read apart without colour).
class _Heart extends Control:
	const TEX := preload("res://assets/icons/heart-fill.svg")
	var full := true

	func _init(side: float, is_full: bool) -> void:
		full = is_full
		custom_minimum_size = Vector2(side, side) + Vector2(6, 8)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var side := minf(size.x - 6.0, size.y - 8.0)
		var r := Rect2(Vector2(3, 2), Vector2(side, side))
		if not full:
			draw_texture_rect(TEX, Rect2(r.position + Vector2(0, 2.0), r.size), false, Color(1, 0.85, 0.7, 0.35))
			draw_texture_rect(TEX, r, false, Color(0.05, 0.0, 0.0, 0.75))
			draw_texture_rect(TEX, r.grow(-3.0), false, Color(0.28, 0.1, 0.06, 0.9))
			return
		for i in 12:  # the ink outline and its depth below
			var d := Vector2.from_angle(TAU * i / 12) * 3.0
			draw_texture_rect(TEX, Rect2(r.position + d + Vector2(0, 2.5), r.size), false, Hud.PLATE_LINE.darkened(0.2))
			draw_texture_rect(TEX, Rect2(r.position + d, r.size), false, Hud.PLATE_LINE)
		draw_texture_rect(TEX, r, false, Color("c8140c"))
		draw_texture_rect(TEX, Rect2(r.position + Vector2(r.size.x * 0.06, 0), r.size * Vector2(0.88, 0.86)), false, Color("ff3a26"))
		GlossStyle.fill_disc(get_canvas_item(), r.position + r.size * Vector2(0.3, 0.3), side * 0.13, Color(1, 1, 1, 0.85),
				Vector2(1.0, 0.6), -0.6)  # the shine (no transform: it batches)


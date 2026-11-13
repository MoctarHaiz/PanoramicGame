class_name Hud
extends Control
## The game's heads-up display, inside the safe area, over a soft shade along the top that sets it apart from the
## vine. Inked, as the menu and the panels (the user, 2026-11-13: "the A, inked gold, but with the RED play in the C,
## bold action", then for the panels "C", no box, ink brush; and: "from now, choose the best option"): flat shapes in a
## thick ink line with a hard ink drop under them, no plate behind them, nothing glossy (it was navy glass pills in a
## gold rim with glossy hearts: the last of the older kit, beside a flat red PLAY). One family:
## - lives on the left: three flat red hearts, a darker band across their foot (a cel shade), a white tick of light;
##   a lost one flashes, cracks in two and its halves fall, leaving its place a dark heart in a thin gold line; the
##   last one beats when it is all that is left;
## - the way home in the middle: a leaning bar (the red plates' lean), dark in an ink line and a thin cream one,
##   filling with flat gold as the level scrolls (a lit gold start ahead of his face from the first step: UI r23,
##   near 0 % an empty bar "read as broken"), Panoramic's face in a flat gold ring riding its tip, a cream house past
##   its end;
## - the Red Bobs on the right (counted the moment one is taken, the counter punching and flashing): the Red Bob and
##   the count in leaning cream numbers, inked; and the pause button, a dark leaning plate in a thin gold line (the
##   panels' quiet plate).
## Every piece stays solid (a HUD held half see-through, or gone for seconds, reads as broken).

signal pause_pressed

const ROW_HEIGHT := 60.0
const BOB_ICON := 46.0  ## size of the Red Bob on the counter
const GEM_ICON := "res://assets/art/bob/icon.png"  ## art's ruby icon for the counter, when it is there
const TRACK_W := 300.0
const HEART := 40.0
const INK := Color("140607")  ## the kit's ink: every outline (SlantStyle.ink)
const DARK := Color("1c1310")  ## an empty place: the bar not yet run, a lost heart (the quiet plate's face)
const DROP := Vector2(1.5, 3.0)  ## the hard ink drop under every piece

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
var _lives_box: Control
var _hero_rect := Rect2()  # where Panoramic is on screen (game_screen sets it every frame)


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
	g.gradient.set_color(0, Color(0.05, 0.0, 0.03, 0.3))
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
	hearts.add_theme_constant_override(&"separation", 0)
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in World.LIVES:
		var slot := Control.new()  # its empty place under each heart
		slot.custom_minimum_size = _Heart.room(HEART)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(_Heart.new(HEART, false))
		var h := _Heart.new(HEART, true)
		h.pivot_offset = h.size / 2
		slot.add_child(h)
		hearts.add_child(slot)
		_hearts.append(h)
	_lives_box = hearts
	_lives_box.name = "HudLives"
	row.add_child(_lives_box)

	var middle := CenterContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(middle)
	_track = _Track.new()
	_track.name = "HudTrack"
	middle.add_child(_track)

	_count_box = _counter()
	_count_box.name = "HudCount"
	_count_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_count_box)
	var gap := Control.new()  # the counter never crowds the pause button
	gap.custom_minimum_size = Vector2(14, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	_pause = _pause_button(ROW_HEIGHT)
	_pause.name = "HudPause"
	_pause.pressed.connect(pause_pressed.emit)
	row.add_child(_pause)
	_fx = Node2D.new()
	_fx.scale = Vector2.ONE * 0.5
	add_child(_fx)
	refresh()


## The Red Bob counter: the Red Bob, then the count in leaning cream numbers, inked, with a hard ink drop (no plate).
func _counter() -> Control:
	_bob_icon = TextureRect.new()
	# art's ruby icon when there is one, else the Red Bob's own picture
	_bob_icon.texture = load(GEM_ICON) if ResourceLoader.exists(GEM_ICON) else BobView.texture()
	_bob_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bob_icon.custom_minimum_size = Vector2(BOB_ICON, BOB_ICON) * 1.2
	_bob_icon.size = _bob_icon.custom_minimum_size
	_bob_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bob_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number = Ui.display_text("000", 42, Ui.BONE, INK)
	_number.font = Ui.font_slant
	_number.outline_width = 4.0
	_number.depth = DROP.y
	_number.depth_colour = INK
	_number.shadow = Color(0, 0, 0, 0)
	_number.align = HORIZONTAL_ALIGNMENT_LEFT
	_number.refresh()
	var holder := Control.new()  # as wide as three digits (the pause button never moves), the count against the Bob
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var need := _number.get_combined_minimum_size()
	holder.custom_minimum_size = Vector2(need.x + 4.0, ROW_HEIGHT - 8.0)
	_number.position = Vector2(0.0, (holder.custom_minimum_size.y - need.y) / 2.0)
	_number.size = need
	holder.add_child(_number)
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_bob_icon)
	box.add_child(holder)
	return box


## The pause button: the panels' quiet plate (dark, leaning, a thin gold line), a cream pause sign.
func _pause_button(side: float) -> JuicyButton:
	var b := Ui.plate_button("pause-fill", Vector2(side * 1.22, side))
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
## spinning while a red light flashes over the lives; its place stays, a dark heart in a gold line.
func _lose_heart(h: Control) -> void:
	var slot := h.get_parent() as Control
	_glow_at(h.get_global_rect(), Color(1, 0.95, 0.85, 0.95), 1.6)
	_glow_at(_lives_box.get_global_rect(), Color(1, 0.15, 0.1, 0.7), 1.0)
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


## The way home: a leaning bar (the red plates' lean), dark in an ink line and a thin cream one on a hard ink drop
## (_Rail, drawn once), a flat gold fill with one cel step along its foot, Panoramic's face in a flat gold ring
## riding just behind its tip, and a cream house past its end. The fill always leads his face by a lit stretch (UI
## r23, the judges of j19: near 0 % "an empty dark groove with the portrait at its start reads as broken"): the run
## has started from the first step.
class _Track extends Control:
	const HEAD := preload("res://assets/art/ui/head.png")
	const BAR := 24.0  ## the bar's height
	const SLANT := 0.3  ## its ends lean this far right, a share of its height (SlantStyle.slant)
	const X0 := 34.0  ## where the bar starts (room for his face at the start)
	const FACE := 60.0  ## his portrait's side (taller than the bar: over its edges)
	const LEAD := 62.0  ## how far the gold's tip runs ahead of his face's middle (past his ring: the lit start)
	const GOLD := Color("ffc928")
	const GOLD_SHADE := Color("f0940e")
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
		_house = Ui.bold_icon("house-fill", 32, Ui.BONE, Hud.INK)
		_house.outline_width = 3.5
		_house.depth = Hud.DROP.y
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
		var rail := Hud._Rail.new()  # still: drawn once, behind the fill (not every frame)
		rail.show_behind_parent = true
		rail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(rail)

	## The bar's face in a control `height` tall.
	static func bar(height: float) -> Rect2:
		return Rect2(X0, height / 2 - BAR / 2, Hud.TRACK_W - 34.0, BAR)

	## The leaning piece of `r` from `x0` to `x1` along its foot, grown by `g` all round.
	static func piece(r: Rect2, x0: float, x1: float, g := 0.0) -> PackedVector2Array:
		var lean := (r.size.y + g * 2.0) * SLANT
		var foot := x0 - g - g * SLANT  # (grown along its lean: its ends stay parallel)
		var end := x1 + g - g * SLANT
		return PackedVector2Array([Vector2(foot + lean, r.position.y - g), Vector2(end + lean, r.position.y - g),
				Vector2(end, r.end.y + g), Vector2(foot, r.end.y + g)])

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:  # the fill and his ring in one triangle array: one draw call
		var ci := get_canvas_item()
		var y := size.y / 2
		var r := bar(size.y)
		var run := r.size.x - BAR * SLANT  # along its foot
		var tip := r.position.x + LEAD + clampf(progress, 0.0, 1.0) * (run - LEAD)  # the gold's tip, never at the start
		GlossStyle.begin_batch()
		var done := piece(r, r.position.x, tip)
		GlossStyle._batch.add_fan(done, PackedColorArray([GOLD, GOLD, GOLD, GOLD]))
		var step := r.position.y + BAR * 0.6  # one cel step along its foot
		var k := (r.end.y - step) / BAR
		GlossStyle._batch.add_fan(PackedVector2Array([Vector2(r.position.x + BAR * SLANT * k, step), Vector2(tip + BAR * SLANT * k, step),
				Vector2(tip, r.end.y), Vector2(r.position.x, r.end.y)]), PackedColorArray([GOLD_SHADE, GOLD_SHADE, GOLD_SHADE, GOLD_SHADE]))
		# his face in a flat gold ring just behind the tip, bobbing a little as it runs
		var bob := absf(sin(_clock * 8.0)) * 2.0
		var c := Vector2(tip - LEAD + 2.0, y - bob)
		var ring := FACE / 2 + 4.0
		GlossStyle.fill_disc(ci, c + Hud.DROP, ring + 3.0, Hud.INK)
		GlossStyle.fill_disc(ci, c, ring + 3.0, Hud.INK)
		GlossStyle.fill_disc(ci, c, ring, GOLD)
		GlossStyle.end_batch(ci)
		draw_line(done[1], done[2], Hud.INK, 2.0, true)  # the tip's edge, inked
		_face.position = c - _face.size / 2
		_house.position = Vector2(r.end.x + 6.0, y - _house.size.y / 2 + 1.0)



## The way home's bar, still (the _Track's, behind its fill): a hard ink drop, an ink line, a thin cream line, the
## dark not yet run. Drawn once.
class _Rail extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := _Track.bar(size.y)
		var end := r.end.x - _Track.BAR * _Track.SLANT
		for layer: Array in [[5.0, Hud.INK, Hud.DROP], [5.0, Hud.INK, Vector2.ZERO], [2.0, Color(Ui.BONE, 0.95), Vector2.ZERO],
				[0.0, Hud.DARK, Vector2.ZERO]]:
			var pts := _Track.piece(r, r.position.x, end, layer[0])
			for i in pts.size():
				pts[i] += layer[2] as Vector2
			draw_colored_polygon(pts, layer[1])
			pts.append(pts[0])
			draw_polyline(pts, layer[1], 1.0, true)  # (polygons are not antialiased)


## A heart: full, flat red with a darker band across its foot (a cel shade) and a white tick of light, in a thick ink
## line on a hard ink drop; lost, its place: a dark heart in a thin gold line (as an empty star: the two read apart
## without colour).
class _Heart extends Control:
	const TEX := preload("res://assets/icons/heart-fill.svg")
	const LINE := 3.5  ## the ink line's width
	const SHADE_FROM := 0.6  ## the darker band starts this far down the heart
	var full := true

	## The room a heart `side` wide takes with its line and its drop.
	static func room(side: float) -> Vector2:
		return Vector2(side, side) + Vector2(LINE * 2.0 + Hud.DROP.x, LINE * 2.0 + Hud.DROP.y) - Vector2(8.0, 6.0)

	func _init(side: float, is_full: bool) -> void:
		full = is_full
		custom_minimum_size = room(side)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var side := size.x - LINE * 2.0 - Hud.DROP.x + 8.0
		# (the glyph leaves a margin in its square: drawn a little larger than its room, centred)
		var r := Rect2(Vector2((size.x - Hud.DROP.x - side) / 2.0, (size.y - Hud.DROP.y - side) / 2.0), Vector2(side, side))
		for drop: Vector2 in [Hud.DROP, Vector2.ZERO]:  # the hard drop, then the ink line
			for i in 16:
				draw_texture_rect(TEX, Rect2(r.position + drop + Vector2.from_angle(TAU * i / 16) * LINE, r.size), false, Hud.INK)
		if not full:
			for i in 12:  # a thin gold line inside the ink
				draw_texture_rect(TEX, Rect2(r.position + Vector2.from_angle(TAU * i / 12) * 1.2, r.size), false, Color(Ui.INK_GOLD, 0.9))
			draw_texture_rect(TEX, r.grow(-0.8), false, Hud.DARK)
			return
		draw_texture_rect(TEX, r, false, Color("b0180f"))
		var tex := TEX.get_size()
		draw_texture_rect_region(TEX, Rect2(r.position, Vector2(r.size.x, r.size.y * SHADE_FROM)),
				Rect2(Vector2.ZERO, Vector2(tex.x, tex.y * SHADE_FROM)), Ui.SCARF_RED)
		# the tick of light on its left lobe, leaning as everything here does
		var at := r.position + r.size * Vector2(0.27, 0.3)
		var w := side * 0.15
		var h := side * 0.075
		draw_colored_polygon(PackedVector2Array([at + Vector2(h * 0.6, 0.0), at + Vector2(w + h * 0.6, 0.0), at + Vector2(w, h),
				at + Vector2(0.0, h)]), Color(1, 1, 1, 0.92))

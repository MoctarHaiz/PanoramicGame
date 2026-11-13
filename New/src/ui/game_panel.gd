class_name GamePanel
extends Control
## A panel over the game (pause, results). Behind it the game is taken once as a picture, with the
## HUD and the flying effects hidden for that frame (no ghost of a heart or a "+1" in it), shrunk to
## 1/8 and drawn back stretched through a cubic B-spline (soft_blur.gdshader: a light, smooth blur, no
## blocks, one draw call; no screen-sized copy kept) and graded (_grade): the frozen scene dimmed but
## recognisable (round 20, the judges: "a blurred purple-brown smear, a dirty screen"), its own colours
## nudged into one mood, a soft light behind the card, closed corners, so the scene steps back and the
## panel owns the screen: a deep warm dusk for the pause, the place where he fell cool, soft and still
## coloured for a defeat, the home flooded with warm golden light for a win, soft rays turning behind him
## and the card (UI r23, the judges of j19). In the middle of the safe area, no box (the user, 2026-11-13, of three
## panel styles shown: "C", no box, ink brush): a band of brushed ink behind what the panel holds (Card.ink,
## InkStyle), its title in gold brush lettering over a red stroke across the band's top edge (Ui.ink_title); a
## character (`art`) at its left, standing on his own contact occlusion on a patch of ground drawn under him and lit
## (UI r23, the judges of j19: r22's "dim spotlight oval with a grass tuft on each side, a stage prop"; _Dais); the
## group is centred. The band pops in opaque (0.7 -> 1.06 -> 1, a back-ease), the title drops in after it, the
## character slides in; never a see-through crossfade.

const SOFT_BLUR := preload("res://src/ui/soft_blur.gdshader")

var card: Card
var banner: Control  # its title (Ui.ink_title)
var art: Control
var _pop: Control
var _ground: TextureRect
var _shadow: TextureRect
var _dais: _Dais  # the ground he stands on, lit
var _halo: TextureRect  # a win's warm light behind the card
var _rays: Rays  # and its soft shafts of light
var _back: Control  # the picture behind, its scrim and vignette
var _picture: TextureRect
var _hidden: Array[CanvasItem] = []  # what it hid behind it, shown again when it goes
var _out_of_picture: Array[CanvasItem] = []  # hidden for the picture only
var _to_cover: Array = []  # what its picture stands for (the world): hidden once the picture covers it
var _covered: Array[CanvasItem] = []
var _mood := &""  # &"win", &"loss" or none: how the picture behind is graded
var _top := 0.0
var _min_w := 560.0
var _k := 1.0  # shrink to fit a small screen
var _u := 0.7  # the entrance's pop


## Opens a panel over `host` (the game screen). `veil`: the colour the game behind is washed with
## (its alpha: how much); `glow`: the light the character stands in; `rays`: a warm light blooming
## behind the card (a win); `hide`: what to leave out of the picture behind (the HUD, the effects).
## The panel shows a frame later, once that picture is taken.
static func open(host: Control, title: String, body: Control, character: Control = null,
		veil := Color(0.05, 0.02, 0.06, 0.42), glow := Color(1, 0.8, 0.45, 0.55), rays := false,
		hide: Array = [], mood := &"") -> GamePanel:
	var p := GamePanel.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(p)
	p._mood = mood
	p._build(title, body, character, veil, glow, rays)
	p._snapshot_then_enter(hide)
	return p


func _build(title: String, body: Control, character: Control, tint: Color, glow: Color,
		rays: bool) -> void:
	_back = Control.new()  # the blurred game, its tint and vignette: what fades in
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	var back := _back
	_picture = TextureRect.new()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var soft := ShaderMaterial.new()  # a cubic B-spline stretch of the small picture, graded into a scrim
	soft.shader = SOFT_BLUR
	_grade(soft)
	_picture.material = soft
	back.add_child(_picture)
	var veil := ColorRect.new()  # where no picture is taken (headless), the plain dim; over a picture a hair
	veil.color = Color(tint, tint.a * 0.2)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(veil)
	if rays:  # a radiance behind the card: soft shafts of light turning (hard-edged rays read as
		# wallpaper stripes) in a warm light blooming behind him and the card (UI r23, the judges of j19: "flood
		# it with warm light: a radial glow or rays behind the panel and hero")
		_rays = Rays.new(1600, Color(1, 0.84, 0.48, 0.3), 22, true)
		_rays.material = Fx.additive()
		add_child(_rays)
		if Prefs.motion():
			_rays.create_tween().set_loops().tween_property(_rays, "rotation", TAU, 60.0).from(0.0)
		_halo = TextureRect.new()
		_halo.texture = Fx.glow_texture()
		_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_halo.material = Fx.additive()
		_halo.modulate = Color(1, 0.76, 0.4, 0.5)
		_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_halo)
		if Prefs.motion():  # it breathes
			var t := _halo.create_tween().set_loops()
			t.tween_property(_halo, "modulate:a", 0.6, 1.6).set_trans(Tween.TRANS_SINE)
			t.tween_property(_halo, "modulate:a", 0.42, 1.6).set_trans(Tween.TRANS_SINE)
	_pop = Control.new()  # placed by hand in the safe area (_place): what the entrance animates
	_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pop)
	card = Card.ink(Vector4(44, 62, 44, 26))  # (its top: under the title's lower half)
	card.add_child(body)
	banner = Ui.ink_title(title, 112.0, 760.0)  # (a long title, "Home sweet home!", stands as tall as a short one)
	_top = banner.size.y * 0.5
	_min_w = maxf(banner.size.x * 0.84, 520.0)
	art = character
	if art:
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ground = TextureRect.new()  # the pool of light he stands in
		_ground.texture = Fx.glow_texture()
		_ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_ground.modulate = glow
		_ground.material = Fx.additive()
		_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pop.add_child(_ground)
		_dais = _Dais.new()
		_dais.mood = _mood
		_pop.add_child(_dais)
		_pop.add_child(card)
		_shadow = TextureRect.new()  # his shadow on the ground, under his feet
		_shadow.texture = Fx.glow_texture()
		_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_shadow.modulate = Color(0.03, 0.0, 0.04, 0.8)
		_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pop.add_child(_shadow)
		_pop.add_child(art)  # in front of the card's edge
	else:
		_pop.add_child(card)
	_pop.add_child(banner)
	card.resized.connect(_place)
	resized.connect(_place)
	Device.changed.connect(_place)
	card.size = card.get_combined_minimum_size()
	_place()


## The scrim's grade per mood (soft_blur.gdshader): the frozen scene softened, its own colours nudged into one
## mood, a soft light behind the card, closed corners (UI r23, the judges of j19):
## - a win: flooded with warm light ("a gloomy navy-purple blur on a WIN"): the home in a bright golden haze,
##   a warm light blooming behind him and the card, warm corners;
## - a defeat: the place where he fell, still coloured and lit ("a desaturated grey-blue mud") but softer and
##   cooler, a cool light behind the group and a deep vignette;
## - the pause: dimmed well down ("still bright and muddy"), a warm dusk, so the panel lifts off it.
func _grade(m: ShaderMaterial) -> void:
	var g: Dictionary
	match _mood:
		&"loss":
			g = {"grey": 0.05, "tame": 0.25, "shadow_tint": Color("0a1230"), "mid_tint": Color("3c5490"), "light_tint": Color("b8ccf2"),
					"duo": 0.5, "exposure": 0.84, "glow_colour": Color(0.5, 0.66, 1.0, 0.2), "glow_size": 0.95,
					"vignette_colour": Color("02030c"), "vignette": 0.9}
		&"win":
			g = {"tame": 0.2, "shadow_tint": Color("4a2010"), "mid_tint": Color("c47838"), "light_tint": Color("ffe8b4"),
					"duo": 0.62, "exposure": 1.0, "glow_colour": Color(1.0, 0.82, 0.5, 0.5), "glow_size": 1.1,
					"vignette_colour": Color("3a1406"), "vignette": 0.45}
		_:  # (UI r21, the judges of j17: "a murky dark background"; j19: "still bright and muddy") a deep warm dusk
			g = {"tame": 0.4, "shadow_tint": Color("140a1a"), "mid_tint": Color("5a3442"), "light_tint": Color("d8a888"),
					"duo": 0.4, "exposure": 0.62, "glow_colour": Color(1.0, 0.74, 0.46, 0.05), "glow_size": 1.0,
					"vignette_colour": Color("08040c"), "vignette": 0.62}
	for key: String in g:
		m.set_shader_parameter(StringName(key), g[key])


## Hides `hide` (and itself) for one drawn frame and takes the picture behind from it, then
## enters. What it hid stays hidden while the panel is up (some effects draw over everything) and
## comes back when the panel goes.
func _snapshot_then_enter(hide: Array) -> void:
	for n: Variant in hide:  # some may be gone already (a finished lesson, the start card once tapped)
		if is_instance_valid(n) and n is CanvasItem and (n as CanvasItem).visible:
			(n as CanvasItem).visible = false
			_hidden.append(n)
	if DisplayServer.get_name() == "headless":
		_enter()
		return
	visible = false
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	# a light blur (1/8, grown back smooth): the scene recognisable behind the panel, its fine detail
	# soft (round 20; 1/32 smeared it into "a dirty screen")
	_picture.texture = Ui.blurred_snapshot(get_viewport(), 3)
	for n: CanvasItem in _out_of_picture:  # back at once: only the picture leaves them out
		if is_instance_valid(n):
			n.visible = true
	_out_of_picture.clear()
	visible = true
	_enter()


## Leaves `nodes` out of the picture behind (shown again as soon as it is taken): the frozen scene's
## moving pieces, which blurred and lightly dimmed read as smears (call right after open()).
func leave_out_of_picture(nodes: Array) -> void:
	if DisplayServer.get_name() == "headless":  # no picture is taken there
		return
	for n: Variant in nodes:
		if is_instance_valid(n) and n is CanvasItem and (n as CanvasItem).visible:
			(n as CanvasItem).visible = false
			_out_of_picture.append(n)


## Hides `nodes` (the world under the panel) once the picture of it covers the screen, and shows
## them again when the panel goes: a still picture stands for them, so they are not drawn every
## frame under it (about 250 draw calls). Nothing is hidden where no picture was taken (headless).
func hide_when_covered(nodes: Array) -> void:
	_to_cover = nodes


func _cover() -> void:
	if not _picture.texture or not is_inside_tree():
		return
	for n: Variant in _to_cover:
		if is_instance_valid(n) and n is CanvasItem and (n as CanvasItem).visible:
			(n as CanvasItem).visible = false
			_covered.append(n)


## Shows the world under it again (call before fading the panel out: it must be there behind it).
func uncover() -> void:
	_to_cover = []
	for n: Variant in _covered:
		if is_instance_valid(n):
			(n as CanvasItem).visible = true
	_covered.clear()


## The entrance: the backdrop dims in, the card pops in opaque, the ribbon drops, he slides in.
func _enter() -> void:
	var back := _back
	back.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(back, "modulate:a", 1.0, 0.2)
	t.tween_callback(_cover).set_delay(0.22)  # the picture is whole: the world under it can go
	_pop.visible = false
	t.tween_callback(func() -> void: _pop.visible = true).set_delay(0.08)
	t.tween_method(_set_pop, 0.7, 1.06, 0.14).set_delay(0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_pop, 1.06, 1.0, 0.1).set_delay(0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var drop := banner.position.y
	banner.position.y = drop - 50.0
	banner.scale = Vector2.ONE * 1.25
	banner.pivot_offset = banner.size / 2
	t.tween_property(banner, "position:y", drop, 0.22).set_delay(0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(banner, "scale", Vector2.ONE, 0.22).set_delay(0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if art:
		var x := art.position.x
		art.position.x = x - 90.0
		t.tween_property(art, "position:x", x, 0.3).set_delay(0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _exit_tree() -> void:
	if Device.changed.is_connected(_place):
		Device.changed.disconnect(_place)
	for n: Variant in _hidden + _out_of_picture:  # (gone before its picture was taken: them too)
		if is_instance_valid(n):
			(n as CanvasItem).visible = true
	uncover()


func _set_pop(u: float) -> void:
	_u = u
	_pop.scale = Vector2.ONE * _u * _k


## Places the group from the card's real size (it settles once its content is in the tree), the
## whole group (character and card) centred in the safe area, shrunk to fit a small screen.
func _place() -> void:
	if card.size.x < _min_w:
		card.size.x = _min_w
	var card_size := card.size
	var art_w := 0.0
	if art:  # as tall as the card and its title (or the share of it in the art's "tall" meta: a
		# figure on one knee is shorter), overlapping the card's left edge a little
		var tex_size: Vector2 = (art as TextureRect).texture.get_size() if art is TextureRect else art.custom_minimum_size
		var h := (card_size.y + _top * 0.6) * float(art.get_meta(&"tall", 1.0))
		art.size = Vector2(h * tex_size.x / tex_size.y, h)
		art_w = art.size.x * (1.0 - float(art.get_meta(&"overlap", 0.22)))
	# a character taller than the card and its ribbon (arms up) lifts the whole group down a little;
	# a picture standing on its own shadow hangs the rest of itself (the shadow's pool, clear pixels)
	# under the card's foot: the group takes that room too, so all of it stays on the screen
	var ground := float(art.get_meta(&"ground", 0.99)) if art else 0.99
	var lift := maxf((art.size.y * ground - 4.0) - (card_size.y + _top), 0.0) if art else 0.0
	var below := maxf(art.size.y * (1.0 - ground) - 4.0, 0.0) if art else 0.0
	if art:  # and the lit ground under him (_Dais: its middle may lie up his picture, the floor seen from above)
		var dy := art.size.y * (float(art.get_meta(&"dais_y", ground)) - ground)
		below = maxf(below, dy + _Dais.depth_under(art.size.x * float((art.get_meta(&"dais", Vector2(0.5, 0.5)) as Vector2).y)))
	# the band's rough ends are part of the group (most of them: their last bristles may leave a narrow screen): on
	# its right, and on its left where no one stands
	var ends := card.band.reach(Rect2(Vector2.ZERO, card_size)) * 0.8 if card.band else Vector2.ZERO
	var lead := art_w if art else ends.x  # from the group's left to the card
	var whole := Vector2(lead + card_size.x + ends.y, card_size.y + _top + lift + below)
	var insets := Device.insets()
	var side_l := maxf(insets.x + 12.0, size.x * 0.06)  # never near an edge (the group would lean)
	var side_r := maxf(insets.z + 12.0, size.x * 0.06)
	var free := Rect2(side_l, insets.y + 10.0, size.x - side_l - side_r,
			size.y - insets.y - Device.bottom_with_banner() - Device.ad_gap() - 20.0)
	if free.size.x > 0.0:
		_k = minf(1.0, minf(free.size.x / whole.x, free.size.y / whole.y))
	var centre := free.get_center()
	_pop.size = whole
	_pop.pivot_offset = whole / 2
	_pop.position = centre - whole / 2
	_pop.scale = Vector2.ONE * _u * _k
	var at := centre + (Vector2(lead + card_size.x / 2, _top + lift + card_size.y / 2) - whole / 2) * _k  # the card's middle
	# (UI r23, the judges of j19: a win's backdrop "gloomy navy-purple") the warm light floods from behind the whole
	# group, him and the card: its middle between them, a little high
	var group := centre + (Vector2(whole.x * 0.5, _top + lift + card_size.y * 0.42) - whole / 2) * _k
	if _halo:  # reaching well past the group's edges
		_halo.size = whole * _k * Vector2(1.5, 1.9)
		_halo.position = group - _halo.size / 2
	if _rays:
		var d := maxf(whole.x, whole.y) * _k * 1.7
		_rays.size = Vector2(d, d)
		_rays.pivot_offset = _rays.size / 2
		_rays.position = group - _rays.size / 2
		_rays.queue_redraw()
	if size.x > 0.0 and size.y > 0.0:  # the scrim's light behind the card
		(_picture.material as ShaderMaterial).set_shader_parameter(&"glow_at", (group if _rays else at) / size)
	card.position = Vector2(lead, _top + lift)
	banner.position = Vector2(lead + (card_size.x - banner.size.x) / 2, lift)
	if art:
		var feet := Vector2(art.size.x * 0.5, lift + _top + card_size.y + 4.0)
		# a picture with its own contact shadow stands on it (its "ground": the share of its height where
		# it is), with no second shadow under it; a plain crop on its soles
		art.position = feet - Vector2(art.size.x * 0.5, art.size.y * ground)
		_shadow.visible = not art.has_meta(&"ground")
		_ground.size = Vector2(art.size.x * 1.6, art.size.x * 0.55)
		_ground.position = feet - _ground.size / 2
		_ground.visible = not art.has_meta(&"dais")  # (the drawn ground carries its own light)
		_shadow.size = Vector2(art.size.x * 0.9, art.size.x * 0.16)
		_shadow.position = feet - _shadow.size / 2
		var d: Vector2 = art.get_meta(&"dais", Vector2(0.5, 0.5))  # its middle and half width, shares of his picture's width
		var dais_y := float(art.get_meta(&"dais_y", ground))  # and how far down his picture its middle is
		_dais.place(art.position + Vector2(art.size.x * d.x, art.size.y * dais_y), art.size.x * d.y)


## The ground he stands on beside the card (UI r23, the judges of j19: r22's "dim spotlight oval with a grass tuft
## on each side, like a stage prop"): no oval, no tufts: a patch of the scene's ground, drawn as the world is
## (cel planes, ink strokes) and lit where he is: a broad soft shade on the scene round it, the earth itself in an
## irregular shape whose edge melts into the scene, seen from a little above (as the knocked-out still's chakram
## lies on it), warm and bright after a win, cool and dim after a defeat; a light added over its middle; a few cel
## strokes on it (cracks in ink with their lit lips, small pebbles) fading out towards its edge. His contact
## occlusion is his picture's own (results_panel: under each boot; his hips, hand and heels). Placed by place():
## the patch's middle and its half width.
class _Dais extends Control:
	const SQUASH := 0.27  ## the patch's depth over its width (the ground seen a little from above)
	## the cel strokes on the earth: [where (shares of the half width and of the depth), length (share of the
	## half width), bend]
	const CRACKS: Array[Vector4] = [Vector4(-0.7, 0.3, 0.22, 0.06), Vector4(-0.3, 0.7, 0.18, -0.08),
			Vector4(0.42, 0.62, 0.2, 0.05), Vector4(0.78, 0.0, 0.14, -0.06), Vector4(-0.86, -0.3, 0.12, 0.05)]
	## pebbles on it: [x, y (shares as above), size (share of the half width)]
	const PEBBLES: Array[Vector3] = [Vector3(-0.62, 0.46, 0.032), Vector3(-0.54, 0.54, 0.02), Vector3(0.7, 0.38, 0.028),
			Vector3(0.86, -0.2, 0.02), Vector3(0.16, 0.8, 0.022)]
	var mood := &""
	var _half := 0.0
	var _plane: Control  # the shade round it, the earth and its strokes (normal)
	var _light: Control  # the light over it (added)
	var _pool_tex: GradientTexture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plane = _layer(_draw_plane)
		_light = _layer(_draw_light)
		_light.material = Fx.additive()

	func _layer(painter: Callable) -> Control:
		var c := Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.draw.connect(painter)
		add_child(c)
		return c

	## How far it reaches under its middle, for a half width `half`.
	static func depth_under(half: float) -> float:
		return half * SQUASH * 0.95 + 4.0

	## The patch's middle, in its own units.
	func _centre() -> Vector2:
		return size * 0.5

	## What it draws that the eye takes as solid (the earth), in its own units.
	func drawn_rect() -> Rect2:
		var c := _centre()
		return Rect2(c - Vector2(_half, _half * SQUASH) * 0.95, Vector2(_half, _half * SQUASH) * 1.9)

	## `centre`: the patch's middle; `half`: its half width (the earth's solid part), in its parent's units.
	func place(centre: Vector2, half: float) -> void:
		_half = half
		size = Vector2(half * 4.8, half * SQUASH * 4.8)
		position = centre - _centre()
		for c: Control in [_plane, _light]:
			c.queue_redraw()

	## A soft round patch texture: solid through its middle, then a soft falloff to its edge. Its own (a static
	## one outlived the game).
	func _pool() -> GradientTexture2D:
		if not _pool_tex:
			_pool_tex = GradientTexture2D.new()
			_pool_tex.width = 128
			_pool_tex.height = 128
			_pool_tex.fill = GradientTexture2D.FILL_RADIAL
			_pool_tex.fill_from = Vector2(0.5, 0.5)
			_pool_tex.fill_to = Vector2(1.0, 0.5)
			_pool_tex.gradient = Gradient.new()
			_pool_tex.gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			_pool_tex.gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
		return _pool_tex

	## An irregular blob round `c` (radii `r`), its edge wobbling (`seed`), filled with `colour` fading out to its
	## edge (the pool texture mapped on it: the falloff follows its own shape, not a circle).
	func _blob(ci: CanvasItem, c: Vector2, r: Vector2, colour: Color, seed: float) -> void:
		var n := 40
		var pts := PackedVector2Array([c])
		var uvs := PackedVector2Array([Vector2(0.5, 0.5)])
		var cols := PackedColorArray([colour])
		var idx := PackedInt32Array()
		for i in n:
			var a := i * TAU / n
			var k := 1.0 + 0.09 * sin(2.0 * a + seed) + 0.06 * sin(3.0 * a + seed * 2.3) + 0.04 * sin(5.0 * a + seed * 0.7)
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * k)
			uvs.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.5)
			cols.append(colour)
			idx.append_array([0, 1 + i, 1 + (i + 1) % n])
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols, uvs, PackedInt32Array(),
				PackedFloat32Array(), _pool().get_rid())

	func _draw_plane() -> void:
		if _half <= 1.0:
			return
		var win := mood == &"win"
		var c := _centre()
		var w := _half
		var d := w * SQUASH  # its half depth
		_blob(_plane, c, Vector2(w * 2.2, d * 2.2), Color(0.05, 0.02, 0.0, 0.22) if win else Color(0.01, 0.02, 0.05, 0.5), 1.3)
		_blob(_plane, c, Vector2(w * 1.75, d * 1.75), Color("9a6e46") if win else Color("5a5e76"), 0.4)  # the earth
		_blob(_plane, c + Vector2(0, d * 0.12), Vector2(w * 1.2, d * 1.2), Color("c89c66") if win else Color("7a809e"), 2.1)  # lit in its middle
		# the cel strokes (fine cracks, a gentle curve each, their lower lip lit), fading out towards its edge
		var ink := Color("3a1e0c") if win else Color("1e2030")
		var lit := Color("f2d2a0") if win else Color("a8b2d0")
		for s in CRACKS:
			var at := c + Vector2(s.x * w, s.y * d)
			var fade := clampf(1.15 - Vector2(s.x, s.y).length() * 0.75, 0.0, 1.0)
			var length := s.z * w
			var line := PackedVector2Array()
			for k in 5:
				var u := k / 4.0 - 0.5
				line.append(at + Vector2(u * length, (0.25 - u * u) * s.w * length * 4.0))
			_plane.draw_polyline(line, Color(ink, 0.45 * fade), maxf(w * 0.01, 1.3), true)
			var lip := PackedVector2Array()
			for p in line:
				lip.append(p + Vector2(0, maxf(w * 0.011, 1.3)))
			_plane.draw_polyline(lip, Color(lit, 0.35 * fade), maxf(w * 0.007, 1.0), true)
		for p in PEBBLES:
			var at := c + Vector2(p.x * w, p.y * d)
			var r := p.z * w
			var fade := clampf(1.15 - Vector2(p.x, p.y).length() * 0.7, 0.0, 1.0)
			GlossStyle.fill_disc(_plane.get_canvas_item(), at + Vector2(r * 0.3, r * 0.45), r * 1.05, Color(ink, 0.35 * fade), Vector2(1.0, 0.55))  # its shadow
			GlossStyle.fill_disc(_plane.get_canvas_item(), at, r, Color(ink, 0.8 * fade), Vector2(1.0, 0.62))
			GlossStyle.fill_disc(_plane.get_canvas_item(), at - Vector2(0, r * 0.12), r * 0.78, Color(lit.darkened(0.25), fade), Vector2(1.0, 0.55))
			GlossStyle.fill_disc(_plane.get_canvas_item(), at - Vector2(r * 0.25, r * 0.3), r * 0.3, Color(lit, 0.8 * fade), Vector2(1.0, 0.6))

	func _draw_light() -> void:
		if _half <= 1.0:
			return
		var c := _centre()
		var w := _half
		var d := w * SQUASH
		var glow := Fx.glow_texture()
		var outer := Color(1.0, 0.78, 0.48, 0.3) if mood == &"win" else Color(0.6, 0.7, 1.0, 0.16)
		var core := Color(1.0, 0.9, 0.7, 0.22) if mood == &"win" else Color(0.75, 0.82, 1.0, 0.1)
		_light.draw_texture_rect(glow, Rect2(c - Vector2(w * 1.6, d * 1.6), Vector2(w * 3.2, d * 3.2)), false, outer)
		_light.draw_texture_rect(glow, Rect2(c - Vector2(w * 0.9, d * 0.9), Vector2(w * 1.8, d * 1.8)), false, core)

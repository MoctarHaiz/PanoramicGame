class_name GamePanel
extends Control
## A panel over the game (pause, results). Behind it the game is taken once as a picture, with the
## HUD and the flying effects hidden for that frame (no ghost of a heart or a "+1" in it), shrunk and
## drawn back stretched through a cubic B-spline (soft_blur.gdshader: a smooth blur, no blocks, one
## draw call; no screen-sized copy kept) and graded into a designed scrim (_grade: the scene's own
## shapes in one tinted mood, a soft light behind the card, closed corners, a few slow shafts of light),
## so the scene steps back and the panel owns the screen: a warm dusk for the pause, cold slate for a
## defeat, gold for a win. A Card in
## the middle of the safe area, its title on a ribbon over its top edge; a character (`art`) at its
## left, overlapping its edge, standing in a pool of light with his shadow under his feet; the group
## is centred. The card pops in opaque (0.7 -> 1.06 -> 1, a back-ease), the ribbon drops in after
## it, the character slides in; never a see-through crossfade.

const SOFT_BLUR := preload("res://src/ui/soft_blur.gdshader")

var card: Card
var banner: Banner
var art: Control
var _pop: Control
var _ground: TextureRect
var _shadow: TextureRect
var _halo: TextureRect  # a win's warm light behind the card
var _rays: Rays  # and its soft shafts of light
var _back: Control  # the picture behind, its scrim and vignette
var _picture: TextureRect
var _hidden: Array[CanvasItem] = []  # what it hid behind it, shown again when it goes
var _out_of_picture: Array[CanvasItem] = []  # hidden for the picture only
var _to_cover: Array = []  # what its picture stands for (the world): hidden once the picture covers it
var _covered: Array[CanvasItem] = []
var _mood := &""  # &"win", &"loss" or none (Card.set_mood)
var _gild: _Gilding  # a win's shine over the card
var _top := 0.0
var _min_w := 560.0
var _k := 1.0  # shrink to fit a small screen
var _u := 0.7  # the entrance's pop


## Opens a panel over `host` (the game screen). `veil`: the colour the game behind is washed with
## (its alpha: how much); `glow`: the light the character stands in; `rays`: a warm light blooming
## behind the card (a win); `hide`: what to leave out of the picture behind (the HUD, the effects).
## The panel shows a frame later, once that picture is taken.
static func open(host: Control, title: String, tone: Ui.Tone, body: Control, character: Control = null,
		veil := Color(0.05, 0.02, 0.06, 0.42), glow := Color(1, 0.8, 0.45, 0.55), rays := false,
		hide: Array = [], mood := &"") -> GamePanel:
	var p := GamePanel.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(p)
	p._mood = mood
	p._build(title, tone, body, character, veil, glow, rays)
	p._snapshot_then_enter(hide)
	return p


func _build(title: String, tone: Ui.Tone, body: Control, character: Control, tint: Color, glow: Color,
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
	if not rays:  # the pause and a defeat: a few slow soft shafts of the scrim's light behind the card (a
		# designed backdrop, not a dimmed photo; a win has its own bright burst)
		_rays = Rays.new(1600, Color(1, 0.86, 0.62, 0.07) if _mood == &"" else Color(0.75, 0.8, 1.0, 0.045), 16, true)
		_rays.material = Fx.additive()
		back.add_child(_rays)  # (it fades in with the scrim)
		if Prefs.motion():
			_rays.create_tween().set_loops().tween_property(_rays, "rotation", TAU, 120.0).from(0.0)
	if rays:  # a radiance behind the card: soft shafts of light turning (hard-edged rays read as
		# wallpaper stripes) in a warm light blooming
		_rays = Rays.new(1600, Color(1, 0.8, 0.38, 0.26), 22, true)
		_rays.material = Fx.additive()
		add_child(_rays)
		if Prefs.motion():
			_rays.create_tween().set_loops().tween_property(_rays, "rotation", TAU, 60.0).from(0.0)
		_halo = TextureRect.new()
		_halo.texture = Fx.glow_texture()
		_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_halo.material = Fx.additive()
		_halo.modulate = Color(1, 0.72, 0.32, 0.6)
		_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_halo)
		if Prefs.motion():  # it breathes
			var t := _halo.create_tween().set_loops()
			t.tween_property(_halo, "modulate:a", 0.75, 1.6).set_trans(Tween.TRANS_SINE)
			t.tween_property(_halo, "modulate:a", 0.5, 1.6).set_trans(Tween.TRANS_SINE)
	_pop = Control.new()  # placed by hand in the safe area (_place): what the entrance animates
	_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pop)
	card = Card.new(Vector4(54, 68, 54, 46))  # inside the thick frame and its trim
	card.set_mood(_mood)
	card.bosses = _mood != &""  # the jewelled corners for the results only
	card.inlays = _mood == &""  # the pause's: engraved gold corners
	card.add_child(body)
	banner = Banner.new(title, tone, 54)
	banner.size = banner.custom_minimum_size
	_top = banner.size.y * 0.55
	_min_w = maxf(banner.size.x + 60.0, 600.0)
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
	if _mood == &"win":  # the premium step up: a shine sweeping the panel, sparkles along its gold
		_gild = _Gilding.new()
		_gild.radius = card.radius
		_pop.add_child(_gild)
	_pop.add_child(banner)
	card.resized.connect(_place)
	resized.connect(_place)
	Device.changed.connect(_place)
	card.size = card.get_combined_minimum_size()
	_place()


## The scrim's grade per mood (soft_blur.gdshader): the frozen scene as one tinted mood, a soft light
## behind the card, closed corners. The pause: a warm dusk (the scene still readable, its shapes soft); a
## defeat: cold slate, drained, quiet; a win: gold.
func _grade(m: ShaderMaterial) -> void:
	var g: Dictionary
	match _mood:
		&"loss":
			g = {"grey": 0.5, "shadow_tint": Color("080a16"), "mid_tint": Color("262c46"), "light_tint": Color("8a90ae"),
					"duo": 0.9, "exposure": 0.85, "glow_colour": Color(0.55, 0.62, 0.95, 0.2), "glow_size": 1.1,
					"vignette_colour": Color("04050c"), "vignette": 0.8}
		&"win":
			g = {"shadow_tint": Color("2a0a06"), "mid_tint": Color("8e3412"), "light_tint": Color("ffc266"), "duo": 0.75,
					"exposure": 0.92, "glow_colour": Color(1.0, 0.7, 0.3, 0.3), "glow_size": 1.1,
					"vignette_colour": Color("140404"), "vignette": 0.6}
		_:
			g = {"tame": 0.4, "shadow_tint": Color("140b2c"), "mid_tint": Color("6e2c50"), "light_tint": Color("f2a862"),
					"duo": 0.82, "exposure": 0.9, "glow_colour": Color(1.0, 0.66, 0.38, 0.42), "glow_size": 1.0,
					"vignette_colour": Color("0a0414"), "vignette": 0.7}
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
	# a controlled blur (1/32): the scene's shapes soft but still there (1/64 smeared it into a muddy
	# wash; 1/16 showed its blocks under the grade)
	_picture.texture = Ui.blurred_snapshot(get_viewport(), 5)
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
	var whole := Vector2(card_size.x + art_w, card_size.y + _top + lift + below)
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
	var at := centre + (Vector2(art_w + card_size.x / 2, _top + lift + card_size.y / 2) - whole / 2) * _k  # the card's middle
	if _halo:  # centred on the card, reaching well past its edges
		_halo.size = card_size * _k * Vector2(1.9, 2.1)
		_halo.position = at - _halo.size / 2
	if _rays:
		var d := maxf(card_size.x, card_size.y) * _k * 2.0
		_rays.size = Vector2(d, d)
		_rays.pivot_offset = _rays.size / 2
		_rays.position = at - _rays.size / 2
		_rays.queue_redraw()
	if size.x > 0.0 and size.y > 0.0:  # the scrim's light behind the card
		(_picture.material as ShaderMaterial).set_shader_parameter(&"glow_at", at / size)
	card.position = Vector2(art_w, _top + lift)
	if _gild:
		_gild.position = card.position
		_gild.size = card_size
	banner.position = Vector2(art_w + (card_size.x - banner.size.x) / 2, lift)
	if art:
		var feet := Vector2(art.size.x * 0.5, lift + _top + card_size.y + 4.0)
		# a picture with its own contact shadow stands on it (its "ground": the share of its height where
		# it is), with no second shadow under it; a plain crop on its soles
		art.position = feet - Vector2(art.size.x * 0.5, art.size.y * ground)
		_shadow.visible = not art.has_meta(&"ground")
		_ground.size = Vector2(art.size.x * 1.6, art.size.x * 0.55)
		_ground.position = feet - _ground.size / 2
		_shadow.size = Vector2(art.size.x * 0.9, art.size.x * 0.16)
		_shadow.position = feet - _shadow.size / 2


## A win's gilding over its card (added light): a soft band of light sweeping across the panel now and
## then (the twinkling dots along its frame read as tiny marquee bulbs: gone).
class _Gilding extends Control:
	var radius := 34.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = Fx.additive()

	func _process(delta: float) -> void:
		if Prefs.motion():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if r.size.x < 10.0:
			return
		# the sweep: every 2.8 s, 0.9 s across, a slanted band, brightest in its middle
		var k := fposmod(_t - 1.2, 2.8) / 0.9
		if Prefs.motion() and _t > 1.2 and k < 1.0:
			var clip := GlossStyle.rounded_points(r, radius)
			var w := r.size.y * 0.35
			var slant := r.size.y * 0.45
			var x := lerpf(-w - slant, r.size.x + w, k)
			for i in 6:
				var a := x + w * i / 6.0
				var b := x + w * (i + 1) / 6.0
				var band := PackedVector2Array([Vector2(a + slant, 0), Vector2(b + slant, 0), Vector2(b, r.size.y), Vector2(a, r.size.y)])
				for poly in Geometry2D.intersect_polygons(clip, band):
					var cols := PackedColorArray()
					for p in poly:
						var u := (p.x - x - slant * (r.size.y - p.y) / r.size.y) / w
						cols.append(Color(1, 0.92, 0.7, sin(clampf(u, 0.0, 1.0) * PI) * 0.22))
					draw_polygon(poly, cols)

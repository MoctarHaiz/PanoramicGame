class_name GamePanel
extends Control
## A panel over the game (pause, results). Behind it the game is taken once as a picture, with the
## HUD and the flying effects hidden for that frame (no ghost of a heart or a "+1" in it), shrunk and
## drawn back stretched (a soft blur, Ui.blurred_snapshot: no shader, no screen-sized copy kept),
## under a dark scrim and a vignette, so the scene steps back and the panel owns the screen. A Card in
## the middle of the safe area, its title on a ribbon over its top edge; a character (`art`) at its
## left, overlapping its edge, standing in a pool of light with his shadow under his feet; the group
## is centred. The card pops in opaque (0.7 -> 1.06 -> 1, a back-ease), the ribbon drops in after
## it, the character slides in; never a see-through crossfade.

var card: Card
var banner: Banner
var art: Control
var _pop: Control
var _ground: TextureRect
var _shadow: TextureRect
var _rays: Rays
var _back: Control  # the picture behind, its scrim and vignette
var _picture: TextureRect
var _hidden: Array[CanvasItem] = []  # what it hid behind it, shown again when it goes
var _top := 0.0
var _min_w := 560.0
var _k := 1.0  # shrink to fit a small screen
var _u := 0.7  # the entrance's pop


## Opens a panel over `host` (the game screen). `veil`: the colour the game behind is washed with
## (its alpha: how much); `glow`: the light the character stands in; `rays`: a big burst of light
## turning behind the card; `hide`: what to leave out of the picture behind (the HUD, the effects).
## The panel shows a frame later, once that picture is taken.
static func open(host: Control, title: String, tone: Ui.Tone, body: Control, character: Control = null,
		veil := Color(0.05, 0.02, 0.08, 0.62), glow := Color(1, 0.8, 0.45, 0.55), rays := false,
		hide: Array = []) -> GamePanel:
	var p := GamePanel.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(p)
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
	back.add_child(_picture)
	var veil := ColorRect.new()
	veil.color = tint
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(veil)
	var vignette := TextureRect.new()
	vignette.texture = Fx.vignette_texture()
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.modulate = Color(0.02, 0.0, 0.02, 0.95)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(vignette)
	if rays:
		_rays = Rays.new(1800, Color(1, 0.82, 0.42, 0.22), 20)
		_rays.material = Fx.additive()
		add_child(_rays)
		if Prefs.motion():
			_rays.create_tween().set_loops().tween_property(_rays, "rotation", TAU, 40.0).from(0.0)
	_pop = Control.new()  # placed by hand in the safe area (_place): what the entrance animates
	_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pop)
	card = Card.new(Vector4(46, 64, 46, 40))
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
	_pop.add_child(banner)
	card.resized.connect(_place)
	resized.connect(_place)
	Device.changed.connect(_place)
	card.size = card.get_combined_minimum_size()
	_place()


## Hides `hide` (and itself) for one drawn frame and takes the picture behind from it, then
## enters. What it hid stays hidden while the panel is up (some effects draw over everything) and
## comes back when the panel goes.
func _snapshot_then_enter(hide: Array) -> void:
	for n: CanvasItem in hide:
		if is_instance_valid(n) and n.visible:
			n.visible = false
			_hidden.append(n)
	if DisplayServer.get_name() == "headless":
		_enter()
		return
	visible = false
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	_picture.texture = Ui.blurred_snapshot(get_viewport(), 5)
	visible = true
	_enter()


## The entrance: the backdrop dims in, the card pops in opaque, the ribbon drops, he slides in.
func _enter() -> void:
	var back := _back
	back.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(back, "modulate:a", 1.0, 0.2)
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
	for n: CanvasItem in _hidden:
		if is_instance_valid(n):
			n.visible = true


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
	# a character taller than the card and its ribbon (arms up) lifts the whole group down a little
	var lift := maxf((art.size.y - 4.0) - (card_size.y + _top), 0.0) if art else 0.0
	var whole := Vector2(card_size.x + art_w, card_size.y + _top + lift)
	var insets := Device.insets()
	var free := Rect2(insets.x + 12.0, insets.y + 10.0, size.x - insets.x - insets.z - 24.0,
			size.y - insets.y - Device.bottom_with_banner() - 20.0)
	if free.size.x > 0.0:
		_k = minf(1.0, minf(free.size.x / whole.x, free.size.y / whole.y))
	var centre := free.get_center()
	_pop.size = whole
	_pop.pivot_offset = whole / 2
	_pop.position = centre - whole / 2
	_pop.scale = Vector2.ONE * _u * _k
	if _rays:
		_rays.position = centre + Vector2(art_w / 2 * _k, 0) - _rays.size / 2
	card.position = Vector2(art_w, _top + lift)
	banner.position = Vector2(art_w + (card_size.x - banner.size.x) / 2, lift)
	if art:
		var feet := Vector2(art.size.x * 0.5, lift + _top + card_size.y + 4.0)
		art.position = feet - Vector2(art.size.x * 0.5, art.size.y * 0.99)
		_ground.size = Vector2(art.size.x * 1.6, art.size.x * 0.55)
		_ground.position = feet - _ground.size / 2
		_shadow.size = Vector2(art.size.x * 0.9, art.size.x * 0.16)
		_shadow.position = feet - _shadow.size / 2

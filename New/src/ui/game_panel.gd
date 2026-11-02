class_name GamePanel
extends Control
## A panel over the game (pause, results): the game behind dimmed to about half and vignetted
## (no blur: it banded on phones and cost a screen-sized copy), so the panel owns the screen; a Card in the middle of the safe area, its title on a
## ribbon over its top edge; a character (`art`) standing on a pool of light at the card's left,
## overlapping its edge, so the two read as one group. The card pops in, the ribbon after it.

var card: Card
var banner: Banner
var art: Control
var _pop: Control
var _ground: TextureRect
var _rays: Rays
var _top := 0.0
var _min_w := 560.0
var _k := 1.0  # shrink to fit a small screen
var _u := 0.75  # the entrance's pop


## Opens a panel over `host` (the game screen). `veil`: the colour the game behind is washed with
## (its alpha: how much); `glow`: the light the character stands in; `rays`: a big burst of light
## turning behind the card (a win).
static func open(host: Control, title: String, tone: Ui.Tone, body: Control, character: Control = null,
		veil := Color(0.08, 0.03, 0.1, 0.5), glow := Color(1, 0.8, 0.45, 0.55), rays := false) -> GamePanel:
	var p := GamePanel.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(p)
	p._build(title, tone, body, character, veil, glow, rays)
	return p


func _build(title: String, tone: Ui.Tone, body: Control, character: Control, tint: Color, glow: Color,
		rays: bool) -> void:
	var veil := ColorRect.new()
	veil.color = tint
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var vignette := TextureRect.new()
	vignette.texture = Fx.vignette_texture()
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.modulate = Color(0.04, 0.0, 0.03, 0.75)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	if rays:
		_rays = Rays.new(1700, Color(1, 0.82, 0.42, 0.16), 20)
		_rays.material = Fx.additive()
		add_child(_rays)
		if Prefs.motion():
			_rays.create_tween().set_loops().tween_property(_rays, "rotation", TAU, 40.0).from(0.0)
	_pop = Control.new()  # placed by hand in the safe area (_place): what the entrance animates
	_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pop)
	card = Card.new(Vector4(46, 64, 46, 40))
	card.add_child(body)
	banner = Banner.new(title, tone, 44)
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
		_pop.add_child(art)  # in front of the card's edge
	else:
		_pop.add_child(card)
	_pop.add_child(banner)
	card.resized.connect(_place)
	resized.connect(_place)
	Device.changed.connect(_place)
	card.size = card.get_combined_minimum_size()
	_place()
	_pop.modulate.a = 0.0
	var t := _pop.create_tween().set_parallel(true)
	t.tween_method(func(u: float) -> void:
		_u = u
		_pop.scale = Vector2.ONE * _u * _k, 0.75, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_pop, "modulate:a", 1.0, 0.15)
	veil.modulate.a = 0.0
	vignette.modulate.a = 0.0
	t.tween_property(veil, "modulate:a", 1.0, 0.25)
	t.tween_property(vignette, "modulate:a", 0.75, 0.3)
	banner.scale = Vector2(0.4, 0.4)
	banner.pivot_offset = banner.size / 2
	t.tween_property(banner, "scale", Vector2.ONE, 0.4).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if art:  # the character rises in beside the card
		art.modulate.a = 0.0
		t.tween_property(art, "modulate:a", 1.0, 0.25).set_delay(0.15)


func _exit_tree() -> void:
	if Device.changed.is_connected(_place):
		Device.changed.disconnect(_place)


## Places the group from the card's real size (it settles once its content is in the tree) in the
## middle of the safe area, shrunk to fit a small screen.
func _place() -> void:
	if card.size.x < _min_w:
		card.size.x = _min_w
	var card_size := card.size
	var art_w := 0.0
	var overlap := 0.0
	if art:  # as tall as the card and its title (or the share of it in the art's "tall" meta: a
		# figure on one knee is shorter), overlapping the card's left edge a little
		var tex_size: Vector2 = (art as TextureRect).texture.get_size() if art is TextureRect else art.custom_minimum_size
		var h := (card_size.y + _top * 0.6) * float(art.get_meta(&"tall", 1.0))
		art.size = Vector2(h * tex_size.x / tex_size.y, h)
		overlap = art.size.x * float(art.get_meta(&"overlap", 0.22))
		art_w = art.size.x - overlap
	var whole := Vector2(card_size.x + art_w, card_size.y + _top)
	var insets := Device.insets()
	var free := Rect2(insets.x + 12.0, insets.y + 10.0, size.x - insets.x - insets.z - 24.0,
			size.y - insets.y - Device.bottom_with_banner() - 20.0)
	_pop.size = whole
	_pop.pivot_offset = whole / 2
	# the card itself near the middle of the screen, the character hanging off its left, the whole
	# group kept inside the safe area (a 4:3 tablet has little room beside the card)
	if free.size.x > 0.0:
		_k = minf(1.0, minf(free.size.x / whole.x, free.size.y / whole.y))
	var half := whole.x * _k / 2
	var centre := free.get_center() + Vector2(art_w * 0.5 * 0.35, 0)
	centre.x = clampf(centre.x, free.position.x + half, maxf(free.end.x - half, free.position.x + half))
	_pop.position = centre - whole / 2
	_pop.scale = Vector2.ONE * _u * _k
	if _rays:
		_rays.position = centre - _rays.size / 2
	card.position = Vector2(art_w, _top)
	banner.position = Vector2(art_w + (card_size.x - banner.size.x) / 2, 0)
	if art:
		art.position = Vector2(0, _top + card_size.y - art.size.y + 6.0)
		_ground.size = Vector2(art.size.x * 1.5, art.size.x * 0.5)
		_ground.position = art.position + Vector2(art.size.x * 0.5, art.size.y - art.size.x * 0.06) - _ground.size / 2

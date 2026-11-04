class_name ShareCard
extends Control
## The picture shared with friends (1200 x 630, the size social apps preview), in the menu's look:
## the sunset with the sun behind Panoramic (full length: the menu's render, its own light) on the left; on
## the right the logo, the run's Red Bobs as a big number on a cream plaque, its stars, and the
## challenge on a red chip.

const SIZE := Vector2i(1200, 630)
const HERO := "res://assets/art/hero/hero_menu.png"  ## the art track's render, loaded when a card is made
const HERO_STAND := "res://assets/art/ui/hero_stand.png"  ## the fallback crop, lit here

var bobs := 0
var stars := 0


## Draws the card off screen and returns it as an image.
static func render(red_bobs: int, star_count: int) -> Image:
	var tree := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var card := ShareCard.new()
	card.bobs = red_bobs
	card.stars = star_count
	card.size = Vector2(SIZE)
	vp.add_child(card)
	tree.root.add_child(vp)
	for i in 3:
		await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	vp.queue_free()
	return image


func _ready() -> void:
	theme = Ui.theme
	var backdrop := SunsetBackdrop.new()
	backdrop.framing_tree = false
	add_child(backdrop)
	var rendered := ResourceLoader.exists(HERO)
	var h := SIZE.y * 0.92
	var hero := TextureRect.new()
	var hero_tex: Texture2D = load(HERO if rendered else HERO_STAND)
	hero.texture = hero_tex
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_SCALE
	hero.size = Vector2(h * hero_tex.get_width() / hero_tex.get_height(), h)
	if rendered:  # the render carries its own light; it stands on its contact shadow at 0.94 of its height
		hero.position = Vector2(maxf(470.0 - hero.size.x, 10.0), SIZE.y - 22.0 - h * 0.94)
	else:
		hero.position = Vector2(150, SIZE.y - h + 10)
		var lit := ShaderMaterial.new()
		lit.shader = preload("res://src/ui/hero.gdshader")
		hero.material = lit
	backdrop.sun_at = (hero.position + hero.size * Vector2(0.52, 0.3)) / Vector2(SIZE)
	add_child(hero)
	var col := VBoxContainer.new()
	col.position = Vector2(470, 24)
	col.size = Vector2(SIZE.x - 500, SIZE.y - 48)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 14)
	add_child(col)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/art/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 250)
	col.add_child(logo)
	var plaque := PanelContainer.new()
	var s := Ui.plaque_style(36.0)
	s.content_margin_left = 22
	s.content_margin_right = 30
	s.content_margin_top = 6
	s.content_margin_bottom = 16
	plaque.add_theme_stylebox_override(&"panel", s)
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	var bob := TextureRect.new()
	bob.texture = BobView.texture()
	bob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bob.custom_minimum_size = Vector2(96, 96)
	bob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bob)
	row.add_child(Ui.number_text(str(bobs), 110))
	var words := Ui.label(tr("SHARE_CARD_LINE"), 44, Color("5a2408"), Ui.font_title)
	row.add_child(words)
	if stars > 0:
		var star_row := StarRow.new(stars, 56)
		star_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(star_row)
	plaque.add_child(row)
	col.add_child(plaque)
	var cta := Ui.chip(tr("SHARE_CARD_CTA"), Ui.Tone.CRIMSON, 44)
	cta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(cta)

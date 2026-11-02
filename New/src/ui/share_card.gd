class_name ShareCard
extends Control
## The picture shared with friends (1200 x 630, the size social apps preview): the sunset,
## Panoramic, the title, the Red Bobs of the run, its stars and a challenge.

const SIZE := Vector2i(1200, 630)

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
	add_child(SunsetBackdrop.new())
	var hero := TextureRect.new()
	hero.texture = load("res://assets/art/hero/portrait.png")
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	var h := SIZE.y * 0.95
	hero.size = Vector2(h * hero.texture.get_width() / hero.texture.get_height(), h)
	hero.position = Vector2(SIZE.x - hero.size.x - 30, SIZE.y - h)
	add_child(hero)
	var col := VBoxContainer.new()
	col.position = Vector2(40, 40)
	col.size = Vector2(SIZE.x * 0.58, SIZE.y - 80)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 16)
	add_child(col)
	var title := Ui.display_text("CHAKA ZULU", 96, Ui.GOLD, Ui.NIGHT, Color("ff9a2e"))
	title.depth = 10.0
	title.refresh()
	col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 18)
	var bob := TextureRect.new()
	bob.texture = BobView.texture()
	bob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bob.custom_minimum_size = Vector2(110, 110)
	bob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bob)
	row.add_child(Ui.number_text(str(bobs), 150))
	row.add_child(Ui.display_text(tr("SHARE_CARD_LINE"), 52, Ui.WHITE, Ui.NIGHT))
	col.add_child(row)
	if stars > 0:
		col.add_child(StarRow.new(stars, 70))
	var cta := Ui.chip(tr("SHARE_CARD_CTA"), Ui.Tone.CRIMSON, 48)
	cta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(cta)

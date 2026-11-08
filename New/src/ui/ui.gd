extends Node
## The look of the interface: colours from the 2017 art (the menu's sunset, the icon's coral, the
## Red Bob, Panoramic's ring and shoulder guard), fonts, and helpers to build every screen.

# Colours sampled from the original game.
const BRAND := Color("f2662e")           ## sunset orange: pages, transitions (the 2017 menu sky)
const BRAND_SOFT := Color("ff9a5a")      ## lighter sunset
const BRAND_DARK := Color("b8461a")      ## its shading
const BRAND_DEEP := Color("d9481c")
const BRAND_LIGHT := Color("ffe2c6")
const BRAND_MIST := Color("fff4ea")
const CORAL := Color("f87878")           ## the 2017 icon background
const CRIMSON := Color("e82808")         ## the Red Bob
const BLUE := Color("3a8fd8")            ## the throwing ring, the shoulder guard
const SKY := Color("78b8f8")             ## the 2017 level sky
const GRASS := Color("a8c808")
const PLUS_ONE := Color("ffd84a")        ## the "+1" of a Red Bob
const INK := Color("3a1a0c")             ## text on light backgrounds
const INK_SOFT := Color("7a5642")
const LABEL_DEEP := Color("b8461a")      ## text and icons on white buttons over the sunset pages
const NIGHT := Color("3a1206")           ## deepest brand brown: outlines and shadows of text
const EDGE_WHITE := Color("f2c9a8")      ## the edge under a white button
const GOLD := Color("ffd36b")            ## stars, sparkles, the counter's flash
const WHITE := Color.WHITE
const BLACK := Color.BLACK
const SHADOW := Color(0.2, 0.08, 0.02, 0.22)
const MAX_TOAST_WIDTH := 700.0
## Smallest touch target in design units: 48 dp on a 360 dp-tall phone (Android), 52 pt on an iPhone
## (Apple asks for 44). Buttons drawn smaller still take touches this far (JuicyButton._has_point).
const MIN_TOUCH := 86.0
## Cream and sand: the inside of panels, where text is dark brown (contrast above 10:1).
const CREAM := Color("fff6e4")
const SAND := Color("f3d9ac")
const SAND_DEEP := Color("dcb47c")

## The colours of the interface kit (buttons, chips, banners, panels): clean, saturated faces (the
## colour that reads over warm art) with a soft light across their top (no glaze, no sticker
## highlight) in a thin bright brass ring (the panels' gold trim) over a deep drop shadow. GREEN is the
## go colour (one main action per screen: Play, Resume, Play again; also "on"), GOLD rewards and the
## pause's tiles, SUNSET the brand, BLUE the quiet buttons beside the main one, CRIMSON warnings,
## WHITE (bone) the quietest choice, SLATE the defeat's cool title.
enum Tone { GREEN, GOLD, SUNSET, BLUE, CRIMSON, WHITE, SLATE, AMBER }
## Per tone: face top, face bottom, edge (the bevel under the face), outline (and text outline).
const TONES := {
	Tone.GREEN: [Color("d2e874"), Color("68aa30"), Color("467c1e"), Color("1f3c0e")],  # warm leaf, not neon
	Tone.GOLD: [Color("ffe873"), Color("ffab1c"), Color("d5740b"), Color("6a3205")],
	Tone.SUNSET: [Color("ffb77a"), Color("f2662e"), Color("c0431a"), Color("5a1a06")],
	Tone.BLUE: [Color("7cd0ff"), Color("2f86e0"), Color("1c5cb2"), Color("0e2a5e")],
	Tone.CRIMSON: [Color("ff7a5c"), Color("e82808"), Color("a8180a"), Color("4e0804")],
	Tone.WHITE: [Color("fffaf0"), Color("f1e2c4"), Color("d2b48a"), Color("4a1e04")],
	Tone.SLATE: [Color("9aaccc"), Color("4e5f86"), Color("34415e"), Color("141a2c")],  # dusk blue-grey
	Tone.AMBER: [Color("ffcc4e"), Color("ec8c0c"), Color("b45a06"), Color("5a2604")],  # a richer gold (settings)
}
## The ring around a button's face: thin bright brass (lit along its top, deeper at its foot), per
## tone: ring top, ring bottom, the thickness under it (edge), the outline around it all. A gold face
## gets a copper ring (brass on gold would melt into it).
const BRASS := [Color("fff0a8"), Color("e8a030"), Color("9a5210"), Color("3a1606")]
const FRAMES := {
	Tone.GREEN: BRASS,
	Tone.GOLD: [Color("ffc27a"), Color("d8641c"), Color("8a340a"), Color("3a1404")],
	Tone.SUNSET: BRASS,
	Tone.BLUE: BRASS,
	Tone.CRIMSON: BRASS,
	Tone.WHITE: BRASS,
	Tone.SLATE: [Color("dfe6f2"), Color("8c98ae"), Color("4a5468"), Color("141a2c")],
	Tone.AMBER: [Color("ffc27a"), Color("d8641c"), Color("8a340a"), Color("3a1404")],
}

var font_title: FontVariation  ## Fredoka Bold: titles, buttons, numbers
var font_display: FontVariation  ## Fredoka at its heaviest: display text (DisplayText)
var font_strong: FontVariation  ## Fredoka SemiBold
var font_body: FontVariation  ## Quicksand SemiBold: sentences
var font_body_bold: FontVariation  ## Quicksand Bold
var theme: Theme

var _icons := {}
## Fredoka as static weights with their overlaps removed (made from the variable font with fontTools'
## instancer), imported as multichannel signed distance fields: one glyph cache per weight for every
## size and outline (a raster font makes a new glyph page, 1 to 2 MB, for each size and each outline
## size it is drawn at: 8 MB more for each new DisplayText size). The variable font's overlapping
## contours would show seams in a distance field, hence the static weights.
const FREDOKA := {580: "res://assets/fonts/Fredoka-580.ttf", 680: "res://assets/fonts/Fredoka-680.ttf",
		700: "res://assets/fonts/Fredoka-700.ttf"}


func _ready() -> void:
	var quicksand: FontFile = load("res://assets/fonts/Quicksand.ttf")
	font_title = title_font(680)
	font_display = title_font(700)
	font_strong = title_font(580)
	font_body = _weight(quicksand, 600)
	font_body_bold = _weight(quicksand, 700)
	theme = _build_theme()
	get_tree().root.theme = theme


## Fredoka at the nearest of its static weights (580, 680, 700), with optional extra space between
## letters.
func title_font(weight := 650, letter_spacing := 0) -> FontVariation:
	var nearest := 580
	for w: int in FREDOKA:
		if absi(w - weight) < absi(nearest - weight):
			nearest = w
	var v := FontVariation.new()
	v.base_font = load(FREDOKA[nearest])
	v.spacing_glyph = letter_spacing
	return v


func _weight(font: FontFile, weight: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = font
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return v


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 34
	t.set_color(&"font_color", &"Label", INK)
	t.set_stylebox(&"panel", &"PanelContainer", card_style())
	# Buttons are styled one by one (see pill_button / round_button); keep focus invisible.
	t.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(INK_SOFT, 0.35)
	grabber.set_corner_radius_all(6)
	grabber.content_margin_left = 6
	grabber.content_margin_right = 6
	t.set_stylebox(&"grabber", &"VScrollBar", grabber)
	t.set_stylebox(&"grabber_highlight", &"VScrollBar", grabber)
	t.set_stylebox(&"grabber_pressed", &"VScrollBar", grabber)
	t.set_stylebox(&"scroll", &"VScrollBar", StyleBoxEmpty.new())
	return t


# ---------------------------------------------------------------- styles

func card_style(bg := WHITE, radius := 40, shadow := 26) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 16
	s.shadow_color = SHADOW
	s.shadow_size = shadow
	s.shadow_offset = Vector2(0, shadow * 0.4)
	s.set_content_margin_all(28)
	return s


## The colours of a tone: top, bottom, edge, outline (and its button ring: frame).
func tone_colours(tone: Tone) -> Dictionary:
	var c: Array = TONES[tone]
	return {"top": c[0], "bottom": c[1], "edge": c[2], "outline": c[3], "frame": FRAMES[tone]}


## The colours of a candy made from any face and edge colour (the older builders' arguments).
func face_colours(face: Color, edge: Color) -> Dictionary:
	for tone: Tone in TONES:
		if TONES[tone][1].is_equal_approx(face) or _legacy_face(tone).is_equal_approx(face):
			return tone_colours(tone)
	return {"top": face.lerp(WHITE, 0.3), "bottom": face.darkened(0.06), "edge": edge,
			"outline": edge.darkened(0.55), "frame": FRAMES[Tone.SUNSET]}


## The face colours the screens passed before the tones existed map to the nearest tone.
func _legacy_face(tone: Tone) -> Color:
	match tone:
		Tone.SUNSET:
			return BRAND_SOFT
		Tone.WHITE:
			return WHITE
	return Color(0, 0, 0, 0)


## The interface's candy shape in a tone: a dark outline, a bevel `depth` px thick, a gradient
## face with a crisp gloss band and a spark (see GlossStyle).
func candy_style(tone: Tone, radius: float, pressed := false, depth := 10.0) -> GlossStyle:
	return _candy(tone_colours(tone), radius, pressed, depth)


func _candy(c: Dictionary, radius: float, pressed: bool, depth: float) -> GlossStyle:
	var white := (c.top as Color).get_luminance() > 0.95
	var s := GlossStyle.new(c.top, c.bottom, c.edge, radius, depth, pressed)
	s.set_outline(c.outline, clampf(roundf(depth * 0.45), 3.0, 6.0))
	s.gloss = 0.24 if not white else 0.0  # a soft light across the whole top (GlossStyle): not a glaze
	s.spark = 0.0
	s.rim = 0.3
	s.shadow.shadow_color = Color(NIGHT, 0.32)
	s.shadow.shadow_size = 6 if pressed else 14
	s.shadow.shadow_offset = Vector2(0, 4 if pressed else 10)
	return s


## A button's candy: the tone's face inside a thin bright brass ring (FRAMES) `ring` px wide, all of
## it on its edge (`depth`) and outlined, a darker lip along the bottom of the face, a deep soft drop
## shadow under it (it stands off the panel or the scene).
func _framed(c: Dictionary, radius: float, pressed: bool, depth: float, ring: float) -> GlossStyle:
	var s := _candy(c, radius, pressed, depth)
	var f: Array = c.get("frame", FRAMES[Tone.GREEN])
	s.edge = f[2]
	s.outline = f[3]
	s.outline_width = clampf(roundf(depth * 0.3), 2.5, 4.0)
	s.set_frame(ring, f[0], f[1], Color(c.outline, 0.85))
	s.rim = 0.25
	s.lip = 0.35
	s.shadow.shadow_color = Color(0.1, 0.02, 0.0, 0.5)
	s.shadow.shadow_size = 8 if pressed else 18
	s.shadow.shadow_offset = Vector2(0, 5 if pressed else 13)
	return s


## A raised, pressable candy shape: a lit, glossy face over a darker edge, outlined (see GlossStyle).
func button_style(face: Color, edge: Color, radius: int, pressed := false) -> GlossStyle:
	var s := _candy(face_colours(face, edge), radius, pressed, 9.0)
	s.content_margin_left = 34
	s.content_margin_right = 34
	s.content_margin_top = 12 if pressed else 6
	s.content_margin_bottom = 6
	return s


## A chunky raised panel in a tone (cards and boards on the pages): outlined, with a bevel and
## no gloss, so buttons stay the shiniest things on screen.
func panel_style(tone := Tone.WHITE, radius := 44.0, depth := 12.0) -> GlossStyle:
	var s := candy_style(tone, radius, false, depth)
	s.gloss = 0.0
	s.spark = 0.0
	s.rim = 0.5
	s.shadow.shadow_color = Color(NIGHT, 0.3)
	s.shadow.shadow_size = 24
	s.shadow.shadow_offset = Vector2(0, 14)
	s.set_content_margin_all(30)
	s.content_margin_bottom = 30 + depth
	return s


## Frosted glass on the sunset pages: a light veil with a fine white border.
func glass_style(radius := 40, alpha := 0.16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, alpha)
	s.border_color = Color(1, 1, 1, 0.32)
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.corner_detail = 16
	s.set_content_margin_all(24)
	return s


# ---------------------------------------------------------------- builders

func label(text: String, size: int, color := INK, font: Font = null,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # the text is already translated
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", font if font else font_strong)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func icon_texture(name: String) -> Texture2D:
	if not _icons.has(name):
		_icons[name] = load("res://assets/icons/%s.svg" % name)
	return _icons[name]


func icon(name: String, size: float, color := WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon_texture(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Display text (titles, buttons, numbers): Fredoka at its boldest, a fill (a gradient when
## `fill_bottom` is given), a thick `outline`, an extruded depth and a soft shadow (DisplayText).
func display_text(text: String, size: int, fill := WHITE, outline := NIGHT,
		fill_bottom := Color(0, 0, 0, 0)) -> DisplayText:
	var t := DisplayText.new(text, size)
	t.tracking = roundf(size * 0.03)  # the thick outlines of neighbouring letters don't fuse
	t.fill_top = fill
	t.fill_bottom = fill_bottom if fill_bottom.a > 0 else fill
	t.outline = outline
	t.refresh()
	return t


## A page or panel title on the sunset: white, lit from the top, deep brown outline and depth.
func title_text(text: String, size := 64) -> DisplayText:
	var t := display_text(text, size, WHITE, NIGHT, BRAND_LIGHT)
	t.highlight = 0.0
	t.refresh()
	return t


## A big score or count: white to mist, with the outline and depth of a tone.
func number_text(text: String, size := 120, tone := Tone.SUNSET) -> DisplayText:
	var t := display_text(text, size, WHITE, tone_colours(tone).outline, Color("ffe9d6"))
	t.depth = roundf(size * 0.08)
	t.refresh()
	return t


## An icon with the fill, outline and depth of the display text next to it (BoldIcon).
func bold_icon(name: String, size: float, fill := WHITE, outline := NIGHT) -> BoldIcon:
	return BoldIcon.new(icon_texture(name), size, fill, outline)


## The main candy button of a screen, in a tone (PLAY, Play again...): outlined, bevelled, glossy,
## with outlined white text and icon. Call idle() and shine() on the screen's one main action.
func candy_button(text: String, icon_name := "", tone := Tone.GREEN, height := 124,
		font_size := 50) -> JuicyButton:
	return _candy_button(text, icon_name, tone_colours(tone), height, font_size)


func _candy_button(text: String, icon_name: String, c: Dictionary, height: int, font_size: int) -> JuicyButton:
	var b := JuicyButton.new()
	b.custom_minimum_size = Vector2(0, height)
	var radius := height * 0.36  # a rounded slab, not a pill: chunkier, like top games' buttons
	var depth := roundf(height * 0.09)
	var ring := maxf(roundf(height * 0.05), 3.0)  # a thin bright rim: the face's colour carries the button
	var white := (c.top as Color).get_luminance() > 0.95
	b.add_theme_stylebox_override(&"normal", _framed(c, radius, false, depth, ring))
	b.add_theme_stylebox_override(&"hover", _framed(c, radius, false, depth, ring))
	b.add_theme_stylebox_override(&"pressed", _framed(c, radius, true, depth, ring))
	var dim := c.duplicate()
	for key: String in ["top", "bottom", "edge", "outline"]:
		dim[key] = (dim[key] as Color).lerp(WHITE, 0.45)
	b.add_theme_stylebox_override(&"disabled", _framed(dim, radius, false, depth, ring))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", roundi(font_size * 0.28))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outline: Color = c.outline
	var ink := LABEL_DEEP if white else WHITE
	if not icon_name.is_empty():
		if white:
			row.add_child(icon(icon_name, font_size * 0.95, ink))
		else:
			row.add_child(bold_icon(icon_name, font_size * 0.9, WHITE, outline))
	# White letters that dominate their heavy dark stroke, the stroke extruded below them.
	var l := display_text(text, font_size, ink, outline, ink if white else Color("fff3e8"))
	l.outline_width = 0.0 if white else roundf(font_size * 0.085)
	l.depth = 0.0 if white else roundf(font_size * 0.08)
	l.shadow = Color(0, 0, 0, 0)
	l.refresh()
	row.add_child(l)
	b.add_child(_face_holder(row, _framed(c, radius, false, depth, ring)))
	b.content = row
	return b


## A full-rect holder over a button's face (above its bevel), so the content centres on the face
## and can sink with it (JuicyButton moves `content` inside it).
func _face_holder(content: Control, style: GlossStyle) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_top = style.outline_width + style.frame_width
	holder.offset_bottom = -(style.outline_width + style.depth + style.frame_width)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(content)
	return holder


## Big pill button with a text and an optional icon (PLAY, Play again, Share...).
## White faces get deep orange text, coloured faces outlined white text (see candy_button).
func pill_button(text: String, icon_name := "", face := BRAND, edge := BRAND_DARK,
		height := 124, font_size := 50) -> JuicyButton:
	return _candy_button(text, icon_name, face_colours(face, edge), height, font_size)


## White pill button with lavender text: the quieter choice next to a main button.
func light_pill_button(text: String, icon_name := "", height := 104, font_size := 40) -> JuicyButton:
	return pill_button(text, icon_name, WHITE, EDGE_WHITE, height, font_size)


## Round icon button (menu, pause, home...), the same candy as the pill buttons.
func round_button(icon_name: String, diameter := 112, face := WHITE, edge := EDGE_WHITE,
		icon_color := LABEL_DEEP) -> JuicyButton:
	return _icon_button(icon_name, face_colours(face, edge), Vector2(diameter, diameter), diameter / 2.0, icon_color)


## A button in the panels' own wood: a cream parchment face in a wooden frame ring, a brown icon (the
## settings' back button, the menu's gear: they match the panels around them, not the candy tiles).
func wood_button(icon_name: String, button_size := Vector2(84, 84), radius := 42.0) -> JuicyButton:
	var c := {"top": Color("fff6e0"), "bottom": Color("efd29a"), "edge": Color("c08a48"), "outline": Color("4a1e04"),
			"frame": [Color("d8763a"), Color("7a2a0c"), Color("4a1604"), Color("2e0d04")]}
	var b := _icon_button(icon_name, c, button_size, radius, Color("6a2a08"))
	return b


## A round button set in a panel's frame (the settings' back and info, centred on its top corners): the
## frame's own carved wood for its face, the frame's gold trim for its ring, a cream glyph in a dark
## outline (UI r21, the judges of j17: r20's cream buttons in a wood ring read "bolted on").
func frame_button(icon_name: String, side: float) -> JuicyButton:
	var c := {"top": Card.FRAME_TOP.lightened(0.1), "bottom": Card.FRAME_BOTTOM, "edge": Color("4a1604"), "outline": Card.INK,
			"frame": [Card.TRIM_TOP, Card.TRIM_BOTTOM, Color("8a4a0c"), Card.INK]}
	return _icon_button(icon_name, c, Vector2(side, side), side / 2.0, Color("fff2d6"))


## A square-ish candy icon button in a tone (the menu's records and settings).
## `ring`: another ring than the tone's (FRAMES), e.g. the bright brass for a gold face on a dark HUD.
func icon_button(icon_name: String, tone := Tone.SUNSET, side := 124.0, radius := 38.0, ring: Array = []) -> JuicyButton:
	var c := tone_colours(tone)
	if not ring.is_empty():
		c.frame = ring
	return _icon_button(icon_name, c, Vector2(side, side), radius, LABEL_DEEP if tone == Tone.WHITE else WHITE)


func _icon_button(icon_name: String, c: Dictionary, button_size: Vector2, radius: float,
		icon_color: Color) -> JuicyButton:
	var b := JuicyButton.new()
	b.custom_minimum_size = button_size
	var depth := roundf(button_size.y * 0.09)
	var ring := maxf(roundf(button_size.y * 0.05), 3.0)
	for state in [&"normal", &"hover"]:
		b.add_theme_stylebox_override(state, _framed(c, radius, false, depth, ring))
	b.add_theme_stylebox_override(&"pressed", _framed(c, radius, true, depth, ring))
	var white := (c.top as Color).get_luminance() > 0.95
	var side := button_size.y * 0.46
	var i: Control
	if white:
		i = icon(icon_name, side, icon_color)
	else:
		i = bold_icon(icon_name, side, icon_color, c.outline)
	b.add_child(_face_holder(i, _framed(c, radius, false, depth, ring)))
	b.content = i
	return b


## A count on a dark glass pill, its icon (a BoldIcon, a baby...) overlapping the pill's left
## end, as the resource counters at the top of top games' menus.
func counter(icon_control: Control, text: String, font_size := 42) -> Control:
	var h := roundf(font_size * 1.3)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(NIGHT, 0.55)
	s.border_color = Color(1, 1, 1, 0.3)
	s.set_border_width_all(3)
	s.set_corner_radius_all(int(h / 2))
	s.corner_detail = 12
	s.content_margin_left = h * 0.9
	s.content_margin_right = h * 0.42
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override(&"panel", s)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number := display_text(text, font_size, WHITE, NIGHT, BRAND_LIGHT)
	number.outline_width = roundf(font_size * 0.12)
	number.depth = 3.0
	number.shadow = Color(0, 0, 0, 0)
	number.refresh()
	pill.add_child(number)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pill)
	box.add_child(icon_control)
	var icon_size := icon_control.get_combined_minimum_size()
	var pill_size := Vector2(pill.get_combined_minimum_size().x, h)
	var tall := maxf(icon_size.y, h)
	pill.position = Vector2(icon_size.x * 0.42, (tall - h) / 2)
	pill.size = pill_size
	icon_control.position = Vector2(0, (tall - icon_size.y) / 2)
	icon_control.size = icon_size
	box.custom_minimum_size = Vector2(pill.position.x + pill_size.x, tall)
	return box


## A warm parchment plaque in a thin bright brass ring (the counters and records of the menus, as the
## resource pills of top games): a golden face, darker at its foot, a firm ink outline and a deep
## shadow, so it holds its own on the dark ground; dark brown text on it.
func plaque_style(radius := 30.0, pressed := false) -> GlossStyle:
	var s := GlossStyle.new(Color("fff1cc"), Color("f0c272"), Color("a8601c"), radius, 7.0, pressed)
	s.set_outline(Color("3a1606"), 4.0)
	s.set_frame(4.0, BRASS[0], BRASS[1], Color("7a3c0c"))
	s.rim = 0.55
	s.lip = 0.3
	s.shadow.shadow_color = Color(0.1, 0.02, 0.0, 0.55)
	s.shadow.shadow_size = 18
	s.shadow.shadow_offset = Vector2(0, 12)
	return s


## A square button in the cream plaque's style (the menu's gear beside the Best plaque: the same
## frame, face and height), its icon in the panels' brown.
func plaque_button(icon_name: String, side: float) -> JuicyButton:
	var b := JuicyButton.new()
	b.custom_minimum_size = Vector2(side, side)
	for state in [&"normal", &"hover"]:
		b.add_theme_stylebox_override(state, plaque_style(26.0))
	b.add_theme_stylebox_override(&"pressed", plaque_style(26.0, true))
	var i := bold_icon(icon_name, side * 0.5, Color("d0641c"), Color("4a1e04"))
	b.add_child(_face_holder(i, plaque_style(26.0)))
	b.content = i
	return b


## A small candy pill with outlined text (and an icon): "NEW BEST!", "2×", tags.
func chip(text: String, tone := Tone.CRIMSON, font_size := 38, icon_name := "", icon_scale := 0.85) -> PanelContainer:
	var c := tone_colours(tone)
	var s := candy_style(tone, font_size * 0.8, false, roundf(font_size * 0.16))
	s.content_margin_left = font_size * 0.6
	s.content_margin_right = font_size * 0.6
	s.content_margin_top = s.outline_width
	s.content_margin_bottom = s.outline_width + s.depth
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", roundi(font_size * 0.2))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not icon_name.is_empty():
		row.add_child(bold_icon(icon_name, font_size * icon_scale, WHITE, c.outline))
	var l := display_text(text, font_size, WHITE, c.outline, Color("fff1e6"))
	l.outline_width = roundf(font_size * 0.12)
	l.depth = roundf(font_size * 0.06)
	l.shadow = Color(0, 0, 0, 0)
	l.refresh()
	row.add_child(l)
	p.add_child(row)
	return p


## The last frame of `vp` as a small, soft picture: shrunk `halvings` times (each a 2x2 average: the
## blur; 4 is 1/16 of the screen, 6 is 1/64), then grown back with bicubic interpolation to a quarter
## of the screen, so the picture drawn stretched over it has texels of 4 screen px (the GPU's bilinear
## steps between 16 px texels showed as a faint dot grid on the dimmed game). For the panels over the
## game; taken once, so nothing is copied every frame. Null where nothing is drawn (headless runs).
func blurred_snapshot(vp: Viewport, halvings := 4) -> Texture2D:
	if DisplayServer.get_name() == "headless" or not vp:
		return null
	var tex := vp.get_texture()
	var img := tex.get_image() if tex else null
	if not img or img.is_empty():
		return null
	var quarter := Vector2i(img.get_width() / 4, img.get_height() / 4)
	for i in halvings:
		if img.get_width() > 8 and img.get_height() > 8:
			img.shrink_x2()
	img.resize(quarter.x, quarter.y, Image.INTERPOLATE_CUBIC)
	return ImageTexture.create_from_image(img)


## Fills a Control with a white card style background.
func card(content: Control, bg := WHITE, radius := 40) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", card_style(bg, radius))
	p.add_child(content)
	return p


## A short message in a pill at the bottom of the screen (purchase done, nothing to restore...).
func toast(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	var style := card_style(INK, 40, 18)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override(&"panel", style)
	var view := get_tree().root.get_visible_rect().size
	var message := label(text, 34, WHITE, font_strong)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # long messages go on two lines
	var natural := font_strong.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x + 2
	message.custom_minimum_size.x = minf(natural, minf(view.x, MAX_TOAST_WIDTH) - 160)
	pill.add_child(message)
	layer.add_child(pill)
	pill.reset_size()
	pill.position = Vector2((view.x - pill.size.x) / 2, view.y - Device.bottom_with_banner() - pill.size.y - 60)
	pill.modulate.a = 0.0
	var t := pill.create_tween()
	t.tween_property(pill, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(pill, "position:y", pill.position.y - 24, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(clampf(text.length() * 0.05, 2.0, 3.5))  # time to read it
	t.tween_property(pill, "modulate:a", 0.0, 0.3)
	t.tween_callback(layer.queue_free)


## An empty Control that takes `ratio` shares of the free space in a box container.
func spacer(ratio := 1.0, min_size := 0.0) -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = ratio
	c.custom_minimum_size = Vector2(min_size, min_size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

class_name InsetStyle
extends StyleBox
## A groove cut into a panel (the results' count, the way-home bars): the panel's lit lip along its
## foot, a dark outline, a face darkest under its upper edge and lighter towards its foot, a deep
## shade cast by the upper edge into it, a little light caught along its bottom inside, a faint
## speckle if `grain`. It reads as sunk into the parchment, not as a slab laid on it.

var top := Color("2a0f05")  ## the face under its upper edge
var bottom := Color("5e3016")  ## the face at its foot
var outline := Color("2e0d04")
var outline_width := 3.0
var radius := 20.0
var shade := 0.7  ## the upper edge's shade inside (alpha)
var lip := Color(1, 0.96, 0.85, 0.85)  ## the panel's lit edge under the groove
var grain := 0.0  ## faint speckle over the face (0..1): a material, not a flat slab
static var _grain_tex: ImageTexture


func _init(corner := 20.0) -> void:
	radius = corner
	set_content_margin_all(14)
	content_margin_left = 24
	content_margin_right = 24


func _draw(ci: RID, rect: Rect2) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) / 2)
	GlossStyle.fill_rounded(ci, Rect2(rect.position + Vector2(0, 3.0), rect.size), r, lip, lip)
	GlossStyle.fill_rounded(ci, rect, r, outline, outline)
	var face := rect.grow(-outline_width)
	var fr := maxf(r - outline_width, 0.0)
	GlossStyle.fill_rounded(ci, face, fr, top, bottom)
	var deep := minf(face.size.y * 0.45, 30.0)  # the upper edge's shade, fading down into the groove
	GlossStyle.fill_clipped(ci, face, fr, Rect2(face.position, Vector2(face.size.x, deep)),
			Color(0, 0, 0, shade), Color(0, 0, 0, 0))
	GlossStyle.fill_clipped(ci, face, fr, Rect2(face.position.x, face.end.y - 6.0, face.size.x, 6.0),
			Color(1, 0.85, 0.6, 0.0), Color(1, 0.85, 0.6, 0.3))  # light caught at its foot: the bevel
	if grain > 0.0:  # the speckle, tiled over the face (the panel must repeat its textures)
		var pts := GlossStyle.rounded_points(face, fr)
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		for q in pts:
			uvs.append(q / 128.0)
			cols.append(Color(1, 1, 1, grain))
		RenderingServer.canvas_item_add_polygon(ci, pts, cols, uvs, _grain().get_rid())


## The speckle: faint light and dark dots, 128 px, tiling (made once).
static func _grain() -> ImageTexture:
	if not _grain_tex:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for y in 128:
			for x in 128:
				var v := rng.randf()
				img.set_pixel(x, y, Color(1, 1, 1, v * 0.5) if v > 0.55 else Color(0, 0, 0, (0.55 - v) * 0.7))
		_grain_tex = ImageTexture.create_from_image(img)
	return _grain_tex

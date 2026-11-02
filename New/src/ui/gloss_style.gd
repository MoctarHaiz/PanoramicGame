class_name GlossStyle
extends StyleBox
## A candy-like shape (buttons, chips, panels): a dark outline around a face with a top-to-bottom
## gradient and a crisp glossy band, standing on a darker edge (its thickness, the bevel), with a
## soft shadow below. Lit from the top, like the rest of the game. Edges are anti-aliased with a
## thin feather.
##
##   outline  ─ dark line all around (0 = none, as the older flat buttons)
##   edge     ─ the bevel: shows `depth` px under the face
##   face     ─ top → bottom gradient, a light rim along its top, the gloss band and a spark

const SEGMENTS := 10  # per rounded corner
const FEATHER := 0.9

var top := Color.WHITE
var bottom := Color.WHITE
var edge := Color.GRAY
var radius := 40.0
var depth := 9.0  ## thickness of the edge under the face
var gloss := 0.3  ## strength of the glossy band over the top of the face
var rim := 0.0  ## a light edge along the top of the face (0..1 towards white)
var outline := Color(0, 0, 0, 0)  ## dark line around the whole shape
var outline_width := 0.0
var spark := 0.0  ## a small white highlight at the top left of the face (0..1)
var pressed := false
var shadow := StyleBoxFlat.new()


func _init(face_top := Color.WHITE, face_bottom := Color.WHITE, edge_colour := Color.GRAY, corner := 40.0,
		thickness := 9.0, is_pressed := false) -> void:
	top = face_top
	bottom = face_bottom
	edge = edge_colour
	radius = corner
	depth = thickness
	pressed = is_pressed
	shadow.bg_color = Color(0, 0, 0, 0)
	shadow.shadow_color = Ui.SHADOW
	shadow.shadow_size = 6 if pressed else 16
	shadow.shadow_offset = Vector2(0, 3 if pressed else 8)
	shadow.corner_detail = 12


## Outlined candy look (see Ui.candy_style): a dark line, a crisp gloss and a spark.
func set_outline(colour: Color, width: float) -> GlossStyle:
	outline = colour
	outline_width = width
	return self


## Where the face is drawn inside `rect` (the part that sinks when pressed).
func face_rect(rect: Rect2) -> Rect2:
	var sink := _sink()
	var w := outline_width
	return Rect2(rect.position + Vector2(w, w + sink), rect.size - Vector2(w * 2, w * 2 + depth + sink))


## Corner radius of the face inside `rect`.
func face_radius(rect: Rect2) -> float:
	var f := face_rect(rect)
	return maxf(0.0, minf(_radius(rect) - outline_width, minf(f.size.x, f.size.y) / 2))


func _sink() -> float:
	return (depth - minf(depth, 3.0)) if pressed else 0.0  # the face sinks into its edge


func _radius(rect: Rect2) -> float:
	return minf(radius, minf(rect.size.x, rect.size.y) / 2)


func _draw(ci: RID, rect: Rect2) -> void:
	var sink := _sink()
	var r := _radius(rect)
	shadow.set_corner_radius_all(int(r))
	shadow.draw(ci, rect)
	var body := Rect2(rect.position + Vector2(0, sink), rect.size - Vector2(0, sink))
	var w := outline_width
	if w > 0:
		_rounded(ci, body, r, outline, outline)
		body = body.grow(-w)
	if depth > 0:
		_rounded(ci, body, maxf(0.0, r - w), edge, edge.darkened(0.12))
	var face := face_rect(rect)
	var fr := face_radius(rect)
	if rim > 0:  # a lighter crescent along the curved top edge, catching the light
		var light := top.lerp(Color.WHITE, rim)
		_rounded(ci, face, fr, light, light)
		var lowered := Rect2(face.position + Vector2(0, 2.5), face.size - Vector2(0, 2.5))
		_rounded(ci, lowered, minf(fr, lowered.size.y / 2), top, bottom)
	else:
		_rounded(ci, face, fr, top, bottom)
	if gloss > 0:
		if w > 0:  # outlined candy, two-tone: the top half lighter, with a crisp edge at the middle
			var inset := maxf(fr * 0.16, face.size.x * 0.025)
			var g := Rect2(face.position + Vector2(inset, face.size.y * 0.06),
					Vector2(face.size.x - inset * 2, face.size.y * 0.44))
			_rounded(ci, g, minf(fr * 0.85, g.size.y / 2), Color(1, 1, 1, gloss), Color(1, 1, 1, gloss * 0.55))
		else:
			var g := Rect2(face.position + Vector2(fr * 0.22, face.size.y * 0.07),
					Vector2(face.size.x - fr * 0.44, face.size.y * 0.46))
			_rounded(ci, g, minf(fr * 0.8, g.size.y / 2), Color(1, 1, 1, gloss), Color(1, 1, 1, 0.0))
	if spark > 0:  # the bright little reflection of the key light (upper left)
		# A long highlight along the top edge, then a dot after it.
		var s := minf(face.size.y, face.size.x) * 0.1
		var at := face.position + Vector2(maxf(fr * 0.55, s * 2.0), face.size.y * 0.13)
		var streak := Rect2(at, Vector2(maxf(s * 3.0, face.size.x * 0.22), s))
		_rounded(ci, streak, s / 2, Color(1, 1, 1, spark), Color(1, 1, 1, spark * 0.8))
		_rounded(ci, Rect2(at + Vector2(streak.size.x + s * 0.7, 0), Vector2(s, s)), s / 2,
				Color(1, 1, 1, spark * 0.9), Color(1, 1, 1, spark * 0.75))


## The outline of a rounded rectangle (for clipping effects to a face, see Shine).
static func rounded_points(rect: Rect2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	r = minf(r, minf(rect.size.x, rect.size.y) / 2)
	var centres := [Vector2(rect.end.x - r, rect.end.y - r), Vector2(rect.position.x + r, rect.end.y - r),
			Vector2(rect.position.x + r, rect.position.y + r), Vector2(rect.end.x - r, rect.position.y + r)]
	for c in 4:
		for i in SEGMENTS + 1:
			var a := (c + float(i) / SEGMENTS) * PI / 2
			pts.append(centres[c] + Vector2(cos(a), sin(a)) * r)
	return pts


## A filled, anti-aliased rounded rectangle with a vertical gradient, for code that draws itself.
static func fill_rounded(ci: RID, rect: Rect2, r: float, c_top: Color, c_bottom: Color) -> void:
	_rounded(ci, rect, maxf(0.0, minf(r, minf(rect.size.x, rect.size.y) / 2)), c_top, c_bottom)


## A filled rounded rectangle with a vertical gradient (exact, as colours vary linearly with y).
static func _rounded(ci: RID, rect: Rect2, r: float, c_top: Color, c_bottom: Color) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var pts := PackedVector2Array()
	var normals := PackedVector2Array()
	var centres := [Vector2(rect.end.x - r, rect.end.y - r), Vector2(rect.position.x + r, rect.end.y - r),
			Vector2(rect.position.x + r, rect.position.y + r), Vector2(rect.end.x - r, rect.position.y + r)]
	for c in 4:
		for i in SEGMENTS + 1:
			var a := (c + float(i) / SEGMENTS) * PI / 2
			normals.append(Vector2(cos(a), sin(a)))
			pts.append(centres[c] + normals[-1] * r)
	var n := pts.size()
	var outer := PackedVector2Array()
	var colours := PackedColorArray()
	var outer_colours := PackedColorArray()
	for k in n:
		var p := pts[k]
		var t := clampf((p.y - rect.position.y) / maxf(rect.size.y, 0.001), 0, 1)
		var c := c_top.lerp(c_bottom, t)
		colours.append(c)
		outer.append(p + normals[k] * FEATHER)
		outer_colours.append(Color(c, 0))
	var points := pts + outer
	var all_colours := colours + outer_colours
	var indices := PackedInt32Array()
	for i in range(1, n - 1):  # the face (convex fan)
		indices.append_array([0, i, i + 1])
	for i in n:  # the feathered border
		var j := (i + 1) % n
		indices.append_array([i, j, n + i, j, n + j, n + i])
	RenderingServer.canvas_item_add_triangle_array(ci, indices, points, all_colours)

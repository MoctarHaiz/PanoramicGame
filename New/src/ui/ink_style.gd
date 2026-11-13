class_name InkStyle
extends StyleBox
## A band of dark ink behind a panel's interface, no box (the user, 2026-11-13, of three panel styles shown for the
## pause, the results and the settings: "C", no box, ink brush; the panels before it: cream cards in a gold bezel).
##
## The band is one brush stroke (assets/art/ui/ink_band.png: tools/art/kie/panel_ui.py: a warm dark ink laid as a
## wash, full where the brush lands and dry where it leaves, a pooled line along its outline), as tall as what it
## covers and stretched in its solid middle only, so its two rough ends keep their painted bristles at any size; they
## lean as the red plates do. What it is given to cover (its rect, grown by `pad`) lies in the solid ink: the stroke's
## rough edges and its ends reach past it.
## (Blind round 12: "a dead, flat pure-black slab... its ends a regular spiky fringe that reads as procedural, not a
## brush... size it to its content". Round 13: "uniform horizontal streaks: scanlines or wood veneer... cut the band
## to a compact, genuinely painted stroke that hugs its content": it was five strokes laid one over the other, every
## other one turned round, their ten ends a comb down each side of the panel.)

const ART := "res://assets/art/ui/ink_band.png"
## the painted stroke, in shares of its size: solid ink across its middle from SOLID_X.x to SOLID_X.y, and from
## SOLID_Y.x down to SOLID_Y.y; its two ends are cut at END (a little inside the solid: nothing of them is stretched)
const SOLID_X := Vector2(0.095, 0.85)
const SOLID_Y := Vector2(0.125, 0.915)
const END := Vector2(0.16, 0.79)
const LEAN := 0.12  ## its ends lean this much (panel_ui.py LEAN): its solid starts that further right at its top
const ENDS := 0.8  ## its two ends, of their painted length (shorter: the band nearer what it holds)

var pad := Vector4(8.0, 14.0, 8.0, 8.0)  ## the solid ink reaches this far past the rect: left, top, right, bottom
var tint := Color.WHITE

var _art: Texture2D


## The strokes that cover `rect`: each [its rect, whether it is turned half a turn] (one stroke, as painted).
func strokes(rect: Rect2) -> Array:
	var solid := Rect2(rect.position - Vector2(pad.x, pad.y), rect.size + Vector2(pad.x + pad.z, pad.y + pad.w))
	var h := solid.size.y / (SOLID_Y.y - SOLID_Y.x)
	var w_art := h * _tex().get_width() / _tex().get_height() * ENDS
	var lean := solid.size.y * LEAN * 0.5  # (the solid's top left corner, and its bottom right one, in the ink too)
	var left := w_art * SOLID_X.x + lean
	var right := w_art * (1.0 - SOLID_X.y) + lean
	return [[Rect2(solid.position.x - left, solid.position.y - h * SOLID_Y.x, solid.size.x + left + right, h), false]]


## How far its strokes' rough ends reach past `rect`: on its left, on its right.
func reach(rect: Rect2) -> Vector2:
	var out := Vector2.ZERO
	for s: Array in strokes(rect):
		var r: Rect2 = s[0]
		out = out.max(Vector2(rect.position.x - r.position.x, r.end.x - rect.end.x))
	return out


func _tex() -> Texture2D:
	if not _art:
		_art = load(ART)
	return _art


func _draw(to: RID, rect: Rect2) -> void:
	var tex := _tex().get_size()
	for s: Array in strokes(rect):
		var r: Rect2 = s[0]
		if s[1]:  # half a turn round its own middle
			RenderingServer.canvas_item_add_set_transform(to, Transform2D(Vector2(-1.0, 0.0), Vector2(0.0, -1.0), r.get_center() * 2.0))
		var k := r.size.y / tex.y * ENDS
		var a := minf(END.x * tex.x * k, r.size.x * 0.4)  # its left end's length
		var b := minf((1.0 - END.y) * tex.x * k, r.size.x * 0.4)  # its right end's
		_piece(to, Rect2(r.position, Vector2(a, r.size.y)), Rect2(0.0, 0.0, END.x * tex.x, tex.y))
		_piece(to, Rect2(r.position + Vector2(a, 0.0), Vector2(r.size.x - a - b, r.size.y)),
				Rect2(END.x * tex.x, 0.0, (END.y - END.x) * tex.x, tex.y))
		_piece(to, Rect2(r.position + Vector2(r.size.x - b, 0.0), Vector2(b, r.size.y)), Rect2(END.y * tex.x, 0.0, (1.0 - END.y) * tex.x, tex.y))
		if s[1]:
			RenderingServer.canvas_item_add_set_transform(to, Transform2D.IDENTITY)


func _piece(to: RID, at: Rect2, from: Rect2) -> void:
	RenderingServer.canvas_item_add_texture_rect_region(to, at, _art.get_rid(), from, tint)

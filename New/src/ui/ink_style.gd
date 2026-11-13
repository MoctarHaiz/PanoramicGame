class_name InkStyle
extends StyleBox
## A band of dark ink behind a panel's interface, no box (the user, 2026-11-13, of three panel styles shown for the
## pause, the results and the settings: "C", no box, ink brush; the panels before it: cream cards in a gold bezel).
##
## The band is brushed, not drawn: several strokes of the one painted stroke (assets/art/ui/ink_band.png:
## tools/art/kie/panel_ui.py), laid one over the other from its top to its foot, each as long as the band and
## stretched in its solid middle only, so its two dry-brush ends keep their painted bristle streaks at any size; every
## other stroke is turned half a turn (no two ends alike), and each stroke starts a little further right than the one
## under it: the band leans as the red plates do. What it is given to cover (its rect, grown by `pad`) lies in the
## solid ink: the strokes' rough edges and their ends reach past it.

const ART := "res://assets/art/ui/ink_band.png"
## the painted stroke, in shares of its size: solid ink across its middle from SOLID_X.x to SOLID_X.y, and from
## SOLID_Y.x down to SOLID_Y.y; its two ends are cut at END (a little inside the solid: nothing of them is stretched)
const SOLID_X := Vector2(0.105, 0.835)
const SOLID_Y := Vector2(0.115, 0.89)
const END := Vector2(0.17, 0.775)
const STEP := 0.6  ## from a stroke down to the next, a share of a stroke's height (they overlap in solid ink)
const STROKE := 160.0  ## a stroke's height the band aims for, in units
## how much further each stroke runs on its left and on its right, in units, stroke after stroke (no two ends of a
## band stop at the same place: a brush, not a comb)
const RAGGED_LEFT: Array[float] = [0.0, 34.0, 8.0, 42.0, 18.0]
const RAGGED_RIGHT: Array[float] = [28.0, 0.0, 40.0, 10.0, 32.0]

var pad := Vector4(14.0, 18.0, 14.0, 10.0)  ## the solid ink reaches this far past the rect: left, top, right, bottom
var lean := 0.1  ## its top starts this far right of its foot, a share of its height
var tint := Color.WHITE

var _art: Texture2D


## The strokes that cover `rect`: each [its rect, whether it is turned half a turn].
func strokes(rect: Rect2) -> Array:
	var solid := Rect2(rect.position - Vector2(pad.x, pad.y), rect.size + Vector2(pad.x + pad.z, pad.y + pad.w))
	var cover := SOLID_Y.y - SOLID_Y.x  # the solid share of one stroke's height
	var n := maxi(roundi((solid.size.y / STROKE - cover) / STEP) + 1, 1)
	var h := solid.size.y / (cover + STEP * (n - 1))
	var out := []
	for i in n:
		var turned := i % 2 == 1
		var above := (1.0 - SOLID_Y.y) if turned else SOLID_Y.x  # the rough edge over its solid ink
		var y := solid.position.y + h * STEP * i - h * above
		var middle := y + h * 0.5
		var shift := (solid.get_center().y - middle) * lean
		# its solid ink from the solid's left to its right, moved by the lean; its ends past them
		var w_art := h * _tex().get_width() / _tex().get_height()
		var left := w_art * ((1.0 - SOLID_X.y) if turned else SOLID_X.x)
		var right := w_art * (SOLID_X.x if turned else (1.0 - SOLID_X.y))
		var reach := absf(solid.size.y * lean * 0.5)
		var more_l := RAGGED_LEFT[i % RAGGED_LEFT.size()]
		var more_r := RAGGED_RIGHT[i % RAGGED_RIGHT.size()]
		out.append([Rect2(solid.position.x - left - reach + shift - more_l, y,
				solid.size.x + left + right + reach * 2.0 + more_l + more_r, h), turned])
	return out


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
		var k := r.size.y / tex.y
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

@tool
class_name CanopyView
extends Node2D
## The canopy over the level: the great boughs of the riverside figs, hanging in from above the screen, that the
## liana (VineView) is tied to. Blind round 15: "a thin wavy vine that hangs from nothing", "the top half a flat
## saturated blue gradient": where the camera rises to the vine (he hangs, he stands high) the top of the picture is
## the trees' leafy ceiling, a thick bough just over the rope, its lianas hanging behind it. One painted strip
## (canopy.png: tools/art/kie/world.py canopy), in the play's plane, behind the ground and the pinnacles (they stand in
## front of its hanging strands), mirrored every other time so each end meets itself; in the trees' own shade, seen
## from under them against the sky, and in the dusk's colour near home, as the backdrop's trees are (SavannaView.dusk).

const TEXTURE := preload("res://assets/art/world/canopy.png")
const TOP := -166.0  ## play y of the picture's top: its bough at about -40, just over the rope (VineView.Y)
const HEIGHT := 400.0  ## units it is drawn tall: its hanging strands end about 86 units down, under the rope
const SHADE := Color(0.66, 0.72, 0.8)
const DUSK := Color(0.52, 0.52, 0.86)

var view_left := 0.0
var view_width := World.VIEW_W
var scroll := 0.0
var dusk := 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := HEIGHT * TEXTURE.get_width() / TEXTURE.get_height()
	var x0 := -view_left - 8.0
	var x1 := view_width - view_left + 8.0
	var colour := SHADE.lerp(SHADE * DUSK, dusk)
	for i in range(floori((x0 + scroll) / w), floori((x1 + scroll) / w) + 1):
		var across := -w if posmod(i, 2) == 1 else w  # (a negative size: mirrored in place)
		draw_texture_rect(TEXTURE, Rect2(i * w - scroll, TOP, across, HEIGHT), false, colour)
		# and its top again, upside down, above it: a camera drawn far back (a tablet) sees over the picture's top
		draw_texture_rect(TEXTURE, Rect2(i * w - scroll, TOP - HEIGHT, across, -HEIGHT), false, colour)

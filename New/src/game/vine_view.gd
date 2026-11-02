class_name VineView
extends Node2D
## A liana along the top of the screen, moving with the level: where Panoramic hooks his staff when
## a jump takes him to the top (the 2017 game drew a yellow bar there). Painted spans
## (tools/art/vine.py, VARIANTS of them, picked and mirrored by a fixed hash) sag between knots every
## SPAN units.

const Y := -7.0  ## top of the spans (their rope ends meet 2 units below): the rope hugs the top
## edge, so the HUD plates sit under it rather than tangled in it
const SPAN := 160.0  ## level units between two knots
const TEXTURE := preload("res://assets/art/world/vine.png")
const VARIANTS := 5

var view_left := 0.0
var view_width := World.VIEW_W
var scroll := 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var x0 := -view_left - SPAN
	var x1 := view_width - view_left + SPAN
	var first := floori((x0 + scroll) / SPAN)
	var h := TEXTURE.get_height() / float(VARIANTS)
	for i in range(first, first + int((x1 - x0) / SPAN) + 2):
		var v := posmod(i * 7 + (i >> 2) * 3, VARIANTS)
		var rect := Rect2(i * SPAN - scroll, Y, SPAN, h / 2.0)
		if posmod(i * 5 + (i >> 1), 3) == 0:  # mirrored now and then: a negative width flips in place
			rect.size.x = -SPAN
		draw_texture_rect_region(TEXTURE, rect, Rect2(0, v * h, TEXTURE.get_width(), h))

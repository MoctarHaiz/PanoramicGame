class_name SunsetBackdrop
extends Control
## The menu's (and settings', and the share card's) savanna at sunset, painted like the level
## (tools/art/savanna.py, tools/art/trees.py): an indigo-to-gold dusk sky with long lit stratus, a
## big low sun with soft rays fanning up, far escarpments it is setting behind, plum hills with
## tiny acacias, acacias in silhouette framing the left, a foreground of backlit grass that sways.
## Pollen glows in the last light and birds cross now and then. Composed for the menu: the title
## and buttons sit on the calmer left, the hero portrait on the right.

const DIR := "res://assets/art/world/"
const HORIZON := 0.74  ## share of the height (by default: see `horizon`)
const SUN_X := 0.36

## Where the sun is, as shares of the size (the menu puts it behind Panoramic, away from the buttons).
var sun_at := Vector2(SUN_X, HORIZON - 0.13)
## Where the land meets the sky, as a share of the height (lower: more sky, the frame not cut in half).
var horizon := HORIZON
## The large acacia framing the left edge and the baobab near it (off where a character stands there).
var framing_tree := true
## Where the small far acacia stands, as a share of the width (the menu keeps it clear of its buttons).
var tree_x := 0.6
## Pollen specks drifting up (off on the menu: they read as stars in a lit sky).
var motes := true
## How strong the shafts of light fanning from the sun are (1: a breath of light).
var shafts := 1.0
## Long sunset clouds across the upper sky (the level's painted clouds, tinted by the dusk).
var clouds := false
## The sun's white-hot disc (0: only its bloom; the menu paints its own layered sun over it: key art k6).
var sun_disc := 1.0
## How strong the sun's bloom is (the menu's is lower: its sky not washed white round the sun, key art k6).
var sun_glow := 0.85
var _clock := 0.0
var _tex := {}
var _painters: Array[Node2D] = []


class Painter extends Node2D:
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	for name in ["sunset_sky", "sunset_far", "sunset_hills", "sunset_grass", "rays", "mote", "bird",
			"tree_acacia_1", "tree_acacia_2", "tree_baobab_1"]:
		_tex[StringName(name)] = load(DIR + name + ".png")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var sway := ShaderMaterial.new()
	sway.shader = preload("res://src/game/sway.gdshader")
	sway.set_shader_parameter(&"amount", 4.0)
	_painter(_draw_sky)
	if clouds:
		for i in 4:
			_tex[StringName("cloud_%d" % (i + 1))] = load(DIR + "cloud_%d.png" % (i + 1))
		_painter(_draw_clouds)
	_painter(_draw_horizon_glow).material = _glow_material(0.0)  # smooth blooms (stacked discs stepped
	_painter(_draw_sun).material = _glow_material(sun_disc, 2.0)  # into rings round the sun)
	_painter(_draw_rays).material = add
	_painter(_draw_strip.bind(&"sunset_far", 0.0, 0.62, 2.0), true)
	_painter(_draw_strip.bind(&"sunset_hills", 0.2, 0.9, 5.0), true)
	_painter(_draw_trees)
	_painter(_draw_strip.bind(&"sunset_grass", 0.29, 0.75, 9.0), true).material = sway
	if motes:
		_painter(_draw_motes).material = add
	_painter(_draw_birds)


func _painter(fn: Callable, repeat := false) -> Painter:
	var p := Painter.new()
	p.paint = fn
	if repeat:
		p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(p)
	_painters.append(p)
	return p


func _process(delta: float) -> void:
	_clock += delta
	for p in _painters:
		p.queue_redraw()


func _k() -> float:  ## design units (640 tall) to this control's pixels
	return size.y / 640.0


func _sun() -> Vector2:
	return size * sun_at


func _draw_sky(ci: CanvasItem) -> void:
	ci.draw_texture_rect(_tex[&"sunset_sky"], Rect2(0, 0, size.x, size.y * (horizon + 0.06)), false)
	ci.draw_rect(Rect2(0, size.y * (horizon + 0.05), size.x, size.y), Color("3a1a30"))


## Long clouds lit from below by the sun gone down: the level's painted clouds, stretched wide,
## tinted rose and gold, drifting slowly; warmer and brighter the nearer they are to the sun.
func _draw_clouds(ci: CanvasItem) -> void:
	var k := _k()
	var sun := _sun()
	for c: Array in [[1, 0.1, 0.1, 1.5], [3, 0.52, 0.06, 1.25], [2, 0.86, 0.17, 1.6], [4, 0.33, 0.27, 1.0], [1, 0.68, 0.33, 0.8]]:
		var tex: Texture2D = _tex[StringName("cloud_%d" % c[0])]
		var sz := Vector2(tex.get_width() * 1.6, tex.get_height()) * k * float(c[3])
		var x := fposmod(size.x * float(c[1]) + _clock * 4.0 * k * float(c[3]), size.x + sz.x) - sz.x * 0.5
		var at := Vector2(x, size.y * float(c[2]))
		var near := clampf(1.0 - at.distance_to(sun) / (size.y * 1.1), 0.0, 1.0)
		var tint := Color(0.78, 0.5, 0.62, 0.5).lerp(Color(1.0, 0.72, 0.5, 0.75), near)
		ci.draw_texture_rect(tex, Rect2(at - sz / 2, sz), false, tint)


## A smooth bloom (sun_glow.gdshader: worked out per pixel, dithered), `core`: its white-hot disc.
func _glow_material(core: float, falloff := -1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/ui/sun_glow.gdshader")
	m.set_shader_parameter(&"core", core)
	m.set_shader_parameter(&"core_radius", 0.2)  # (the disc: 0.15 of the height, the bloom 0.75)
	m.set_shader_parameter(&"falloff", falloff if falloff > 0.0 else (2.0 if core > 0.0 else 1.6))
	return m


## The warm air along the horizon either side of the sun.
func _draw_horizon_glow(ci: CanvasItem) -> void:
	var c := _sun()
	var band := Vector2(size.y * 2.6, size.y * 0.42)
	ci.draw_rect(Rect2(Vector2(c.x, size.y * horizon) - band / 2, band), Color(1, 0.7, 0.45, 0.4))


## The sun: a blown-out disc, white-hot in its middle, blooming smoothly into the sky (no hard edge,
## no rings).
func _draw_sun(ci: CanvasItem) -> void:
	var c := _sun()
	var glow := size.y * 1.5 * (1.0 + sin(_clock * 0.8) * 0.01)
	ci.draw_rect(Rect2(c - Vector2(glow, glow) / 2, Vector2(glow, glow)), Color(1, 0.78, 0.55, sun_glow))


## Soft rays fanning up from the low sun, turning very slowly.
func _draw_rays(ci: CanvasItem) -> void:
	var tex: Texture2D = _tex[&"rays"]
	var c := _sun()
	var k := size.y / 560.0
	var a := 0.2 + 0.05 * sin(_clock * 0.5)
	for side in [-1.0, 1.0]:
		ci.draw_set_transform(c, -PI * 0.5 + side * (0.05 + sin(_clock * 0.07) * 0.03), Vector2(k * side, k))
		ci.draw_texture_rect(tex, Rect2(-Vector2(80, 80), Vector2(1280, 820)), false, Color(1, 0.85, 0.6, minf(a * shafts, 1.0)))
	ci.draw_set_transform(Vector2.ZERO)


## A strip that repeats across; `drop` (share of the height) puts its bottom below the horizon.
func _draw_strip(ci: CanvasItem, name: StringName, drop: float, units_per_px: float, drift: float) -> void:
	var tex: Texture2D = _tex[name]
	var k := _k() * units_per_px
	var h := tex.get_height() * k
	var bottom := size.y * (horizon + drop) + (size.y * 0.02 if name == &"sunset_far" else 0.0)
	if name == &"sunset_grass":
		bottom = size.y + 4.0
	var src_x := fposmod(_clock * drift / k + 300.0, tex.get_width())
	ci.draw_texture_rect_region(tex, Rect2(0, bottom - h, size.x, h), Rect2(src_x, 0, size.x / k, tex.get_height()))


## Acacias against the light: a large one framing the left edge, a small one and a baobab far off.
func _draw_trees(ci: CanvasItem) -> void:
	var dark := Color(0.2, 0.1, 0.17)
	var k := _k()
	if framing_tree:
		_tree(ci, &"tree_acacia_1", Vector2(size.x * 0.0 + 40.0 * k, size.y * (horizon + 0.2)), 360.0 * k, dark, true)
	_tree(ci, &"tree_acacia_2", Vector2(size.x * tree_x, size.y * (horizon + 0.06)), 120.0 * k, Color(0.3, 0.14, 0.24), false)
	if framing_tree:
		_tree(ci, &"tree_baobab_1", Vector2(size.x * 0.17, size.y * (horizon + 0.07)), 140.0 * k, Color(0.3, 0.15, 0.26), false)


func _tree(ci: CanvasItem, name: StringName, foot: Vector2, height: float, tint: Color, flip: bool) -> void:
	var tex: Texture2D = _tex[name]
	var s := height / tex.get_height()
	var sz := tex.get_size() * s
	var rect := Rect2(foot.x - sz.x / 2, foot.y - sz.y, sz.x, sz.y)
	if flip:  # a negative width mirrors the picture in place
		rect.size.x = -sz.x
	ci.draw_texture_rect(tex, rect, false, tint)


func _draw_motes(ci: CanvasItem) -> void:
	var tex: Texture2D = _tex[&"mote"]
	var k := _k()
	for i in 34:
		var sx := _hash(i * 13 + 1)
		var sy := _hash(i * 17 + 5)
		var speed := (8.0 + _hash(i * 7 + 3) * 12.0) * k
		var x := fposmod(sx * size.x * 1.3 + _clock * speed * 0.5 + sin(_clock * 0.4 + i) * 20.0 * k, size.x)
		var y := size.y * 0.35 + fposmod(sy * size.y * 0.65 - _clock * speed, size.y * 0.65)
		var tw := 0.5 + 0.5 * sin(_clock * (1.0 + sx * 2.0) + i * 1.7)
		var r := (3.0 + 5.0 * _hash(i * 23 + 9)) * k
		ci.draw_texture_rect(tex, Rect2(x - r, y - r, r * 2, r * 2), false, Color(1, 0.75, 0.45, 0.15 + 0.4 * tw))


func _draw_birds(ci: CanvasItem) -> void:
	var tex: Texture2D = _tex[&"bird"]
	var fw := tex.get_width() / 4.0
	var fh := float(tex.get_height())
	var k := _k()
	var t := fposmod(_clock + 6.0, 30.0) / 30.0
	for i in 4:
		var lag := i * 0.02
		var x := -100.0 * k + (size.x + 200.0 * k) * (t - lag)
		var y := size.y * 0.3 + i * 10.0 * k + (i % 2) * 7.0 * k + sin(_clock * 0.9 + i) * 4.0 * k - (t - lag) * 50.0 * k
		var frame := int(fposmod(_clock * 7.0 + i * 1.3, 4.0))
		var s := (0.5 - i * 0.03) * k
		ci.draw_texture_rect_region(tex, Rect2(x, y, fw * s, fh * s), Rect2(frame * fw, 0, fw, fh), Color(0.18, 0.08, 0.16, 0.9))


static func _hash(n: int) -> float:
	var x := sin(n * 12.9898) * 43758.5453
	return x - floor(x)

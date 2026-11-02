class_name SavannaView
extends Node2D
## The level's sky and the savanna behind the play, at golden hour, from pictures painted by
## tools/art/savanna.py and tools/art/trees.py. Back to front:
##   sky, sun glow (additive), clouds drifting, far escarpments, far hills with tiny acacias,
##   god rays (additive), mid hills, acacias and baobabs at three depths (warm haze laid over the
##   farther ones), tall golden grass, pollen motes in the light, a few birds.
## Farther layers scroll slower; the trees are placed from the level's x with a fixed hash, so the
## same tree is always in the same place. Everything is drawn from baked textures (cheap on phones):
## each layer is one canvas item redrawn every frame with a handful of rectangles.
## `front` (added by WorldView above the actors): dark out-of-focus grass passing in front of the
## play along the bottom edge, faster than the ground (it is nearer).

const DIR := "res://assets/art/world/"
const SUN_AT := Vector2(0.09, 64.0)  ## sun centre: share of the visible width, y (the upper left,
const SUN_SIZE := 640.0  ## where the light on every painted thing comes from)
const RAYS_ORIGIN := Vector2(80, 80)  ## where the sun is in the rays, in units (tools/art/savanna.py)
const RAYS_SIZE := Vector2(1280, 820)  ## drawn size of rays.png in units (stored at half that)

## Strips that repeat left to right: texture, scroll factor, bottom y, units per texture pixel.
const STRIPS := {
	&"far_mesas": [0.035, 486.0, 1.0],
	&"far_hills": [0.07, 548.0, 1.0],
	&"mid_hills": [0.15, 648.0, 1.0],
	&"near_grass": [0.42, 646.0, 0.5],
}
## Tree rows: scroll factor, spacing (level units of that layer), size (of the picture's height in
## units), ground y, haze, foot haze, share of empty slots, haze colour (the far rows sink into the
## cool blue of distance, the near one into the warm air at the horizon).
const TREE_ROWS := [
	[0.11, 170.0, 70.0, 488.0, 0.62, 0.3, 0.35, Color(0.62, 0.68, 0.82)],
	[0.2, 300.0, 132.0, 540.0, 0.34, 0.3, 0.45, Color(0.68, 0.72, 0.8)],
	[0.31, 520.0, 250.0, 604.0, 0.1, 0.3, 0.4, Color(0.96, 0.78, 0.5)],
]
const CLOUD_SCALE := 2.0  ## cloud_N.png are stored at half size (soft, no detail to lose)
const FRONT_SCROLL := 1.35  ## the foreground grass moves faster than the ground
const FRONT_DROP := 12.0  ## units its picture reaches below the bottom of the screen

## Play units visible left of the play window and the visible width (set by WorldView).
var view_left := 0.0
var view_width := World.VIEW_W
var view_top := 0.0  ## play y at the top of the screen (below 0: the camera drew back)
var scroll := 0.0
var _clock := 0.0
var _tex := {}
var _trees: Array[Texture2D] = []
var _tree_anchor: Array[float] = []
var _painters: Array[Node2D] = []
var front: Node2D  ## the foreground grass (WorldView adds it above the actors)


class Painter extends Node2D:
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


func _ready() -> void:
	for name in ["sky", "sun", "rays", "far_mesas", "far_hills", "mid_hills", "near_grass", "haze",
			"mote", "bird", "cloud_1", "cloud_2", "cloud_3", "cloud_4"]:
		_tex[StringName(name)] = load(DIR + name + ".png")
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "tree_info.json"))
	for name: String in info:
		_trees.append(load(DIR + name + ".png"))
		_tree_anchor.append(float(info[name].anchor_x))
	_tex[&"prop_termite"] = load(DIR + "prop_termite.png")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_painter(_draw_sky)
	_painter(_draw_sun).material = add
	_painter(_draw_clouds)
	_painter(_draw_strip.bind(&"far_mesas"), true)
	_painter(_draw_band.bind(470.0, 110.0, 0.12))
	_painter(_draw_strip.bind(&"far_hills"), true).material = _haze([0, 0, 0, 0, 0.3, 0.0, 0, Color(0.64, 0.7, 0.84)])
	_painter(_draw_trees.bind(0)).material = _haze(TREE_ROWS[0])
	_painter(_draw_band.bind(528.0, 80.0, 0.2))
	_painter(_draw_rays).material = add
	_painter(_draw_strip.bind(&"mid_hills"), true).material = _haze([0, 0, 0, 0, 0.14, 0.0, 0, Color(0.8, 0.78, 0.72)])
	_painter(_draw_trees.bind(1)).material = _haze(TREE_ROWS[1])
	_painter(_draw_band.bind(588.0, 70.0, 0.14))
	_painter(_draw_trees.bind(2)).material = _haze(TREE_ROWS[2])
	_painter(_draw_strip.bind(&"near_grass"), true)
	_painter(_draw_motes).material = add
	_painter(_draw_birds)
	_tex[&"fg_grass"] = load(DIR + "fg_grass.png")
	front = Painter.new()
	front.paint = _draw_front
	front.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_painters.append(front)


func _painter(fn: Callable, repeat := false) -> Painter:
	var p := Painter.new()
	p.paint = fn
	if repeat:
		p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(p)
	_painters.append(p)
	return p


func _haze(row: Array) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/game/haze.gdshader")
	m.set_shader_parameter(&"haze_colour", row[7])
	m.set_shader_parameter(&"amount", row[4])
	m.set_shader_parameter(&"foot", row[5])
	return m


func _process(delta: float) -> void:
	_clock += delta
	for p in _painters:
		p.queue_redraw()


func _x0() -> float:
	return -view_left - 2.0


func _x1() -> float:
	return view_width - view_left + 2.0


func _sun() -> Vector2:
	return Vector2(_x0() + (_x1() - _x0()) * SUN_AT.x - scroll * 0.004, SUN_AT.y)


func _draw_sky(ci: CanvasItem) -> void:
	var sky: Texture2D = _tex[&"sky"]
	if view_top < 0.0:  # the camera drew back (GameScreen): the top of the sky reaches up
		ci.draw_texture_rect_region(sky, Rect2(_x0(), view_top - 2.0, _x1() - _x0(), 4.0 - view_top),
				Rect2(0, 0, sky.get_width(), 1))
	ci.draw_texture_rect(sky, Rect2(_x0(), 0, _x1() - _x0(), World.VIEW_H + 4.0), false)


func _draw_sun(ci: CanvasItem) -> void:
	var s := SUN_SIZE * (1.0 + sin(_clock * 0.7) * 0.012)
	ci.draw_texture_rect(_tex[&"sun"], Rect2(_sun() - Vector2(s, s) / 2, Vector2(s, s)), false, Color(1, 1, 1, 0.85))


## God rays fanning from the sun to the lower right, breathing slowly.
func _draw_rays(ci: CanvasItem) -> void:
	var tex: Texture2D = _tex[&"rays"]
	var k := 1.2
	var a := 0.12 + 0.04 * sin(_clock * 0.45) + 0.02 * sin(_clock * 1.13)
	ci.draw_texture_rect(tex, Rect2(_sun() - RAYS_ORIGIN * k, RAYS_SIZE * k), false, Color(1, 1, 1, a))


func _draw_clouds(ci: CanvasItem) -> void:
	var x0 := _x0()
	var x1 := _x1()
	var offset := scroll * 0.03 + _clock * 5.0
	var spacing := 420.0
	var first := floori((x0 + offset) / spacing) - 2
	for i in range(first, first + int((x1 - x0) / spacing) + 4):
		if _hash(i * 5 + 11) < 0.3:
			continue
		var cx := i * spacing + _hash(i * 3 + 1) * 220.0 - offset
		var cy := 110.0 + _hash(i * 7 + 2) * 200.0
		var tex: Texture2D = _tex[StringName("cloud_%d" % (posmod(i, 4) + 1))]
		var k := (0.55 + _hash(i * 5 + 3) * 0.5) * (1.2 - cy / 520.0) * CLOUD_SCALE
		var size := tex.get_size() * k
		# lower clouds are farther: paler, taken by the haze
		var fade := clampf((cy - 110.0) / 200.0, 0.0, 1.0)
		var flip := _hash(i * 11 + 4) < 0.5
		var rect := Rect2(Vector2(cx - size.x / 2, cy - size.y), size)
		if flip:  # a negative width mirrors the picture in place
			rect.size.x = -size.x
		ci.draw_texture_rect(tex, rect, false, Color(1, 1, 1, 0.95 - fade * 0.35))


func _draw_strip(ci: CanvasItem, name: StringName) -> void:
	var tex: Texture2D = _tex[name]
	var s: Array = STRIPS[name]
	var k: float = s[2]
	var x0 := _x0()
	var x1 := _x1()
	var h := tex.get_height() * k
	var src_x := fposmod((scroll * s[0] + x0) / k, tex.get_width())
	ci.draw_texture_rect_region(tex, Rect2(x0, s[1] - h, x1 - x0, h),
			Rect2(src_x, 0, (x1 - x0) / k, tex.get_height()))


## The foreground grass along the bottom edge.
func _draw_front(ci: CanvasItem) -> void:
	var tex: Texture2D = _tex[&"fg_grass"]
	var x0 := _x0()
	var x1 := _x1()
	var h := float(tex.get_height())
	var src_x := fposmod(scroll * FRONT_SCROLL + x0, tex.get_width())
	ci.draw_texture_rect_region(tex, Rect2(x0, World.VIEW_H + FRONT_DROP - h, x1 - x0, h),
			Rect2(src_x, 0, x1 - x0, h))


## A soft band of warm air across the view.
func _draw_band(ci: CanvasItem, y: float, height: float, alpha: float) -> void:
	ci.draw_texture_rect(_tex[&"haze"], Rect2(_x0(), y - height / 2, _x1() - _x0(), height), false,
			Color(1, 1, 1, alpha))


func _draw_trees(ci: CanvasItem, row_index: int) -> void:
	var row: Array = TREE_ROWS[row_index]
	var factor: float = row[0]
	var spacing: float = row[1]
	var x0 := _x0()
	var x1 := _x1()
	var offset := scroll * factor
	var first := floori((x0 + offset) / spacing) - 2
	for i in range(first, first + int((x1 - x0) / spacing) + 4):
		var seed := i * 31 + row_index * 977
		if _hash(seed) < row[6]:
			continue
		var t := int(_hash(seed + 1) * _trees.size()) % _trees.size()
		var tex := _trees[t]
		var height: float = row[2] * (0.65 + _hash(seed + 2) * 0.7)
		if tex.get_height() > tex.get_width():  # baobabs: taller pictures, same tree scale
			height *= 1.15
		var anchor := _tree_anchor[t]
		if row_index > 0 and _hash(seed + 5) < 0.14:  # now and then a termite mound instead
			tex = _tex[&"prop_termite"]
			height = row[2] * 0.42 * (0.8 + _hash(seed + 2) * 0.4)
			anchor = tex.get_width() / 2.0
		var k := height / tex.get_height()
		var x := i * spacing + _hash(seed + 3) * spacing * 0.9 - offset
		var flip := _hash(seed + 4) < 0.5
		var wide := 0.78 + _hash(seed + 6) * 0.55  # wider or narrower crowns: no two trees alike
		var size := tex.get_size() * k * Vector2(wide, 1.0)
		var ax := anchor * k * wide
		if flip:
			ax = size.x - ax
		var rect := Rect2(x - ax, row[3] - size.y, size.x, size.y)
		if rect.end.x < x0 or rect.position.x > x1:
			continue
		if flip:  # a negative width mirrors the picture in place
			rect.size.x = -size.x
		ci.draw_texture_rect(tex, rect, false)


## Pollen and dust floating in the light, drifting up and to the right, twinkling.
func _draw_motes(ci: CanvasItem) -> void:
	var tex: Texture2D = _tex[&"mote"]
	var x0 := _x0()
	var w := _x1() - x0
	for i in 30:
		var sx := _hash(i * 13 + 1)
		var sy := _hash(i * 17 + 5)
		var speed := 6.0 + _hash(i * 7 + 3) * 10.0
		var depth := 0.3 + _hash(i * 19 + 2) * 0.5
		var x := x0 + fposmod(sx * w * 1.3 - scroll * depth * 0.5 + _clock * speed * 0.6 + sin(_clock * 0.5 + i) * 14.0, w)
		var y := 120.0 + fposmod(sy * 480.0 - _clock * speed, 480.0)
		var twinkle := 0.5 + 0.5 * sin(_clock * (1.2 + sx * 2.0) + i * 1.7)
		var r := (3.0 + 5.0 * _hash(i * 23 + 9)) * (0.7 + depth)
		var a := (0.08 + 0.3 * twinkle) * smoothstep(120.0, 220.0, y) * (1.0 - smoothstep(560.0, 600.0, y))
		ci.draw_texture_rect(tex, Rect2(x - r, y - r, r * 2, r * 2), false, Color(1, 0.85, 0.55, a))


## A few birds far away, crossing the sky now and then in a loose line.
func _draw_birds(ci: CanvasItem) -> void:
	var tex: Texture2D = _tex[&"bird"]
	var fw := tex.get_width() / 4.0
	var fh := float(tex.get_height())
	var x0 := _x0()
	var w := _x1() - x0
	var period := 38.0
	var t := fposmod(_clock + 9.0, period) / period
	for i in 5:
		var lag := i * 0.018
		var x := x0 - 80.0 + (w + 160.0) * (t - lag) - scroll * 0.02
		var y := 150.0 + i * 9.0 + (i % 2) * 6.0 + sin(_clock * 0.8 + i) * 4.0 - (t - lag) * 40.0
		var frame := int(fposmod(_clock * 7.0 + i * 1.3, 4.0))
		var s := 0.42 - i * 0.025
		ci.draw_texture_rect_region(tex, Rect2(x, y, fw * s, fh * s), Rect2(frame * fw, 0, fw, fh),
				Color(1, 1, 1, 0.85))


static func _hash(n: int) -> float:
	var x := sin(n * 12.9898) * 43758.5453
	return x - floor(x)

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
## play along the bottom edge, faster than the ground (it is nearer). Round 9: no boughs along the
## top edge any more (round 3's canopy: "dark branches cut off along the top edge look like dirt
## smudges on the screen").

const DIR := "res://assets/art/world/"
## sun centre: share of the visible width, y (the upper left, where the light on every painted thing
## comes from). Round 2: low over the escarpments (was y 64, behind the hearts): a golden-hour sun in
## the picture, everything rimmed and casting long shadows away from it
const SUN_AT := Vector2(0.1, 255.0)  # (round 3: lower, its glow off the HUD, half behind the far cliffs)
const SUN_SIZE := 640.0
const SUN_DISC := 15.0  ## round 12: units, the radius of its crisp disc
const SUN_STREAK := Vector2(420, 7)  ## round 12: units, the streak of light across it
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
## Round 4: haze only far away; the nearer rows darker and richer (TREE_TINT), so the play stands off
## the backdrop at a glance.
## Round 9: the far rows in a cool, darker slate blue ("the pale haze band across the middle
## washes everything out"): a cool, quiet background behind a warm, saturated playfield.
const TREE_ROWS := [
	[0.11, 190.0, 70.0, 488.0, 0.5, 0.25, 0.45, Color(0.44, 0.48, 0.64)],  # (round 9: sparser: a dotted line of stamps)
	[0.2, 300.0, 104.0, 540.0, 0.16, 0.1, 0.45, Color(0.5, 0.54, 0.68)],  # (round 7: crowns under the jump band:
	[0.31, 520.0, 130.0, 604.0, 0.0, 0.05, 0.4, Color(0.96, 0.78, 0.5)],  # they read as platforms there)
]
## (round 6: the near rows darker, warmer; round 9: a little lighter again, so their crowns' lit tops
## and shaded undersides read, not flat discs)
const TREE_TINT := [Color(1, 1, 1), Color(0.76, 0.7, 0.6), Color(0.72, 0.66, 0.54)]
## animals.png (tools/art/savanna.py): two giraffes, an elephant, a herd of wildebeest (px regions)
const ANIMALS := [Rect2(0, 0, 140, 220), Rect2(140, 12, 128, 208), Rect2(268, 68, 220, 152), Rect2(488, 132, 300, 88)]
const CLOUD_SHADOW_GAP := 700.0  ## round 10: units of the plain between two clouds' shadows
const CLOUD_SCALE := 2.0  ## cloud_N.png are stored at half size (soft, no detail to lose)
const FRONT_SCROLL := 1.35  ## the foreground grass moves faster than the ground
const FRONT_PROP_SCROLL := 1.6  ## round 9: the big things in front, nearer still
const FRONT_PROP := Vector2(260, 190)  ## one piece of fg_props.png (units, 1 px a unit)
const FRONT_PIECES := 4  ## tall grass, an aloe, a fallen log, a bush
const FRONT_PROP_GAP := 760.0  ## units of the foreground between two of them (some left open)
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
var hero_x := -999.0  ## round 7: his play x (WorldView): the near trees fade where they pass behind him


class Painter extends Node2D:
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


func _ready() -> void:
	for name in ["sky", "sun", "sun_halo", "rays", "far_mesas", "far_hills", "mid_hills", "near_grass", "haze",
			"mote", "bird", "cloud_1", "cloud_2", "cloud_3", "cloud_4"]:
		_tex[StringName(name)] = load(DIR + name + ".png")
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "tree_info.json"))
	for name: String in info:
		_trees.append(load(DIR + name + ".png"))
		_tree_anchor.append(float(info[name].anchor_x))
	_tex[&"prop_termite"] = load(DIR + "prop_termite.png")
	_tex[&"animals"] = load(DIR + "animals.png")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_painter(_draw_sky)
	_painter(_draw_sun.bind(false))  # (round 9: its halo laid over the blue, warm, not added to it:
	_painter(_draw_sun.bind(true)).material = add  # added, orange on blue made it a grey-white disc)
	_painter(_draw_clouds)
	# (round 9: the mesas' feet in cool air, not pale milk: the middle of the screen read washed out)
	_painter(_draw_strip.bind(&"far_mesas"), true).material = _haze([0, 0, 0, 0, 0.0, 0.22, 0, Color(0.5, 0.5, 0.68)])  # (round 12: lighter: "washed by haze")
	_painter(_draw_band.bind(470.0, 110.0, 0.035))  # (round 4: haze only around the far layers; round 9: fainter)
	# (round 9: the far hills slate blue and darker: they were the pale milky band)
	_painter(_draw_strip.bind(&"far_hills"), true).material = _haze([0, 0, 0, 0, 0.42, 0.0, 0, Color(0.42, 0.46, 0.64)], Color(0.78, 0.8, 0.92))
	_painter(_draw_trees.bind(0)).material = _haze(TREE_ROWS[0], TREE_TINT[0])
	_painter(_draw_rays).material = add  # (round 11: under the midground again: over it they washed it to beige)
	_painter(_draw_strip.bind(&"mid_hills"), true).material = _haze([0, 0, 0, 0, 0.0, 0.0, 0, Color(0.96, 0.76, 0.52)], Color(0.66, 0.56, 0.42))  # (round 6: the darker, warmer mid-ground)
	_painter(_draw_trees.bind(1)).material = _haze(TREE_ROWS[1], TREE_TINT[1])
	_painter(_draw_trees.bind(2)).material = _haze(TREE_ROWS[2], TREE_TINT[2])
	_painter(_draw_strip.bind(&"near_grass"), true).material = _haze([0, 0, 0, 0, 0.0, 0.0, 0, Color(1, 1, 1)], Color(0.84, 0.74, 0.58))
	_painter(_draw_cloud_shadows)  # (round 10) shadows of the clouds sliding over the plain
	_painter(_draw_lane).material = add  # (round 3) the low sun on the grass behind the play
	_painter(_draw_motes).material = add
	_painter(_draw_birds)
	_tex[&"fg_grass"] = load(DIR + "fg_grass.png")
	_tex[&"fg_props"] = load(DIR + "fg_props.png")
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


func _haze(row: Array, tint := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/game/haze.gdshader")
	m.set_shader_parameter(&"tint", tint)
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


## The sun's centre in this node's units (WorldView's light grade follows it).
func sun_position() -> Vector2:
	return _sun()


func _sun() -> Vector2:
	return Vector2(_x0() + (_x1() - _x0()) * SUN_AT.x - scroll * 0.004, SUN_AT.y)


func _draw_sky(ci: CanvasItem) -> void:
	var sky: Texture2D = _tex[&"sky"]
	if view_top < 0.0:  # the camera drew back (GameScreen): the top of the sky reaches up
		ci.draw_texture_rect_region(sky, Rect2(_x0(), view_top - 2.0, _x1() - _x0(), 4.0 - view_top),
				Rect2(0, 0, sky.get_width(), 1))
	ci.draw_texture_rect(sky, Rect2(_x0(), 0, _x1() - _x0(), World.VIEW_H + 4.0), false)


## The sun: its golden halo laid over the sky (`bloom` false), then its hot disc and bloom added.
func _draw_sun(ci: CanvasItem, bloom: bool) -> void:
	var s := SUN_SIZE * (1.0 + sin(_clock * 0.7) * 0.012)
	if bloom:  # (round 10: softer, warmer: "a hard white disc")
		ci.draw_texture_rect(_tex[&"sun"], Rect2(_sun() - Vector2(s, s) * 0.32, Vector2(s, s) * 0.64), false, Color(1, 0.9, 0.7, 0.62))
		# round 12 ("a blurry blob with no bloom structure"): a crisp disc in its bloom, and a thin
		# streak of light across it, as a lens catches a low sun
		var c := _sun()
		var mote: Texture2D = _tex[&"mote"]
		ci.draw_texture_rect(mote, Rect2(c - Vector2(SUN_STREAK.x / 2, SUN_STREAK.y / 2), SUN_STREAK), false, Color(1, 0.78, 0.48, 0.34))
		ci.draw_texture_rect(mote, Rect2(c - Vector2(SUN_STREAK.x * 0.17, SUN_STREAK.y * 0.9), Vector2(SUN_STREAK.x * 0.34, SUN_STREAK.y * 1.8)), false,
				Color(1, 0.86, 0.62, 0.3))
		ci.draw_circle(c, SUN_DISC, Color(1.0, 0.86, 0.6, 0.55))
		ci.draw_circle(c, SUN_DISC * 0.82, Color(1.0, 0.92, 0.76, 0.5))
	else:  # (round 12: tighter: the blur round it read as a blob)
		ci.draw_texture_rect(_tex[&"sun_halo"], Rect2(_sun() - Vector2(s, s) * 0.3, Vector2(s, s) * 0.6), false, Color(1, 1, 1, 0.7))


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
		# (round 2: quieter, and lit by the low sun: warm, not white blobs over the play)
		ci.draw_texture_rect(tex, rect, false, Color(1.0, 0.96, 0.92, 0.78 - fade * 0.32))  # (round 4: warm in the picture)


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


## The foreground grass along the bottom edge; round 9: and now and then a big thing near the camera
## passing (fg_props.png: tall grass, an aloe, a log, a bush), faster still, never over him (it
## fades where it passes in front of him).
func _draw_front(ci: CanvasItem) -> void:
	var tex: Texture2D = _tex[&"fg_grass"]
	var x0 := _x0()
	var x1 := _x1()
	var h := float(tex.get_height())
	var src_x := fposmod(scroll * FRONT_SCROLL + x0, tex.get_width())
	ci.draw_texture_rect_region(tex, Rect2(x0, World.VIEW_H + FRONT_DROP - h, x1 - x0, h),
			Rect2(src_x, 0, x1 - x0, h))
	var props: Texture2D = _tex[&"fg_props"]
	var offset := scroll * FRONT_PROP_SCROLL
	var first := floori((x0 + offset) / FRONT_PROP_GAP) - 1
	for i in range(first, first + int((x1 - x0) / FRONT_PROP_GAP) + 3):
		if _hash(i * 13 + 7) < 0.4:  # open stretches between them
			continue
		var k := 0.7 + _hash(i * 7 + 3) * 0.3
		var size := FRONT_PROP * k
		var cx := i * FRONT_PROP_GAP + _hash(i * 5 + 1) * FRONT_PROP_GAP * 0.5 - offset
		# (a third of it under the bottom edge: it rises at most ~45 units over the ground line)
		var rect := Rect2(cx - size.x / 2, World.VIEW_H + FRONT_DROP + 6.0 - size.y * 0.65, size.x, size.y)
		if rect.end.x < x0 or rect.position.x > x1:
			continue
		var fade := 0.3 + 0.7 * smoothstep(size.x * 0.3, size.x * 0.3 + 120.0, absf(cx - hero_x))
		if _hash(i * 11 + 4) < 0.5:
			rect.size.x = -rect.size.x  # mirrored in place
		var piece := posmod(int(_hash(i * 3 + 9) * FRONT_PIECES), FRONT_PIECES)
		ci.draw_texture_rect_region(props, rect, Rect2(piece * FRONT_PROP.x, 0, FRONT_PROP.x, FRONT_PROP.y), Color(1, 1, 1, fade))


## Round 3: the low sun warming the grass behind the runners: the play lane is the brightest band,
## dark bandits and the hero stand out against it.
func _draw_lane(ci: CanvasItem) -> void:  # (round 9: lower and fainter: it whitened the far plain)
	ci.draw_texture_rect(_tex[&"haze"], Rect2(_x0(), 540.0, _x1() - _x0(), 90.0), false, Color(1.0, 0.7, 0.36, 0.13))


## Round 10 ("a flat olive band"): the shadows of the clouds lying across the plain, long and soft,
## sliding slowly with the wind and the midground's scroll.
func _draw_cloud_shadows(ci: CanvasItem) -> void:
	var tex: Texture2D = _tex[&"mote"]
	var x0 := _x0()
	var x1 := _x1()
	var offset := scroll * 0.2 + _clock * 4.0
	var first := floori((x0 + offset) / CLOUD_SHADOW_GAP) - 1
	for i in range(first, first + int((x1 - x0) / CLOUD_SHADOW_GAP) + 3):
		if _hash(i * 17 + 3) < 0.35:
			continue
		var w := 380.0 + _hash(i * 7 + 1) * 520.0
		var cx := i * CLOUD_SHADOW_GAP + _hash(i * 5 + 2) * CLOUD_SHADOW_GAP * 0.6 - offset
		var cy := 590.0 + _hash(i * 3 + 4) * 30.0
		var hgt := 46.0 + _hash(i * 11 + 5) * 30.0
		ci.draw_texture_rect(tex, Rect2(cx - w / 2, cy - hgt / 2, w, hgt), false, Color(0.16, 0.12, 0.24, 0.3))


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
	for slot in range(first * 2, (first + int((x1 - x0) / spacing) + 4) * 2):
		# round 2: groves and open plain, not an even stamp: slots in groups of three share a
		# density; a dense group gets a second, smaller tree beside each (odd slots)
		var i := slot >> 1
		var grove := _hash(floori(i / 3.0) * 7 + row_index * 131)
		var seed := i * 31 + row_index * 977 + (slot & 1) * 5003
		if slot & 1 == 1 and (grove < 0.62 or _hash(seed + 11) < 0.35):
			continue
		if _hash(seed) < (row[6] + 0.3 if grove < 0.38 else row[6] * 0.4):
			continue
		var t := int(_hash(seed + 1) * _trees.size()) % _trees.size()
		var tex := _trees[t]
		var height: float = row[2] * (0.5 + _hash(seed + 2) * 0.95) * (0.62 if slot & 1 == 1 else 1.0)  # (round 10: more unequal)
		if tex.get_height() > tex.get_width():  # baobabs: taller pictures, same tree scale
			height *= 1.15
		var anchor := _tree_anchor[t]
		if row_index > 0 and _hash(seed + 5) < 0.14:  # now and then a termite mound instead
			tex = _tex[&"prop_termite"]
			height = row[2] * 0.42 * (0.8 + _hash(seed + 2) * 0.4)
			anchor = tex.get_width() / 2.0
		elif row_index < 2 and _hash(seed + 8) < 0.16:  # (round 2) or animals: giraffes, an elephant, a herd
			_draw_animal(ci, int(_hash(seed + 9) * ANIMALS.size()), i * spacing + _hash(seed + 3) * spacing * 0.9 - offset,
					row[3], row[2] / 132.0 * 0.7, _hash(seed + 4) < 0.5)
			continue
		var k := height / tex.get_height()
		var x := i * spacing + _hash(i * 31 + row_index * 977 + 3) * spacing * 0.9 - offset
		if slot & 1 == 1:  # beside the tree of its slot
			x += (0.22 + _hash(seed + 12) * 0.2) * spacing * (1.0 if _hash(seed + 13) < 0.5 else -1.0)
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
		# round 4: each tree leans its own way (a skew about its foot): no two alike
		var foot := Vector2(x, row[3])
		ci.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, (_hash(seed + 14) - 0.5) * 0.36, foot))
		var behind := 1.0 - 0.7 * (1.0 - smoothstep(40.0, 110.0, absf(x - hero_x))) if row_index == 2 else 1.0
		# (round 12, "tree clones": each its own shade, a little greener, yellower or darker)
		var v := 0.86 + _hash(seed + 15) * 0.26
		var warm := (_hash(seed + 16) - 0.5) * 0.16
		ci.draw_texture_rect(tex, Rect2(rect.position - foot, rect.size), false, Color(v + warm, v, v - warm, behind))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## One of the animals in animals.png (ANIMALS), standing on `ground` at x, `k` times its size, its
## feet a little in the grass.
func _draw_animal(ci: CanvasItem, which: int, x: float, ground: float, k: float, flip: bool) -> void:
	var a: Rect2 = ANIMALS[which]
	var size := a.size * 0.5 * k  # (2 px a unit)
	var rect := Rect2(x - size.x / 2, ground + 3.0 * k - size.y, size.x, size.y)
	if rect.end.x < _x0() or rect.position.x > _x1():
		return
	if flip:
		rect.size.x = -rect.size.x
	ci.draw_texture_rect_region(_tex[&"animals"], rect, a)


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


## A few birds far away, crossing the sky now and then in a loose line; round 3: and vultures
## circling slowly over the plain (they give the empty middle of the sky some life).
func _draw_birds(ci: CanvasItem) -> void:
	var tex: Texture2D = _tex[&"bird"]
	var fw := tex.get_width() / 4.0
	var fh := float(tex.get_height())
	var x0 := _x0()
	var w := _x1() - x0
	for v in 3:
		var cx := x0 + fposmod(w * (0.55 + v * 0.13) - scroll * 0.06, w + 300.0) - 150.0
		var a := _clock * (0.32 + v * 0.05) + v * 2.1
		var r := 34.0 + v * 9.0
		var flap := int(fposmod(_clock * 6.0 + v, 4.0)) if fposmod(_clock * 0.4 + v * 0.3, 1.0) < 0.15 else 1
		var s := 0.62 - v * 0.06
		ci.draw_texture_rect_region(tex, Rect2(cx + cos(a) * r * 1.6, 300.0 + v * 14.0 + sin(a) * r * 0.45, fw * s, fh * s),
				Rect2(flap * fw, 0, fw, fh), Color(0.32, 0.24, 0.26, 0.9))
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

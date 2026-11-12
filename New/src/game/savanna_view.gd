class_name SavannaView
extends Node2D
## The level's sky and the savanna behind the play, at golden hour. World redraw: the sky, the
## strips, the trees and the animals are painted with kie.ai in the menu key art's style (from the
## old pictures of tools/art/savanna.py and tools/art/trees.py as layouts). Back to front:
##   sky (one painted panorama, its clouds drifting), sun glow (additive), far escarpments (round 21: three
##   rows of landforms, the clouds' shadows sliding over the nearer two), far hills with tiny acacias,
##   god rays (additive), mid hills, acacias and baobabs at three depths in groves (warm haze laid over the
##   farther ones), tall golden grass, pollen motes in the light, a few birds (round 21: and a far skein).
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
## Round 19 (the judges: "the sun bloom is the brightest thing on screen, away from the action; the god rays
## fall from another direction than the sun"): the sun is above the screen's top left corner, high enough for
## the light shafts painted in the sky (falling from the upper left) and the rays to come from it, as the light
## on every painted thing does; only its warm glow spills into the corner (its disc is out of the picture).
## y is from the top of the screen.
const SUN_AT := Vector2(0.02, -70.0)
const SUN_SIZE := 640.0
const RAYS_ORIGIN := Vector2(80, 80)  ## where the sun is in the rays, in units (tools/art/savanna.py)
const RAYS_SIZE := Vector2(1280, 820)  ## drawn size of rays.png in units (stored at half that)
## World redraw: the painted sky (sky.png): top y and height it is drawn at (units), how much it
## moves with the run, and its drift with the wind (units a second).
const SKY_RECT := Vector2(-30.0, 600.0)
const SKY_SCROLL := 0.02
const SKY_DRIFT := 2.5

## Strips that repeat left to right: texture, scroll factor, bottom y, units per texture pixel.
const STRIPS := {
	&"far_hills": [0.07, 548.0, 1.0],
	&"mid_hills": [0.15, 648.0, 1.0],
	&"near_grass": [0.42, 646.0, 0.5],
}
## Round 20 (the judges, j16: "the same mesa shape x4, no atmospheric layering"): the escarpments placed one
## landform at a time (far_mesa_pieces.png, tools/art/world_mesas.py). Round 21 (the judges, j17: "still the same
## flat-topped striped block, stamped, evenly spaced"): twelve landforms (the strip's five and seven painted ones: a
## spire, hoodoos, an arch, a broken arch, a cracked butte, a cuesta), in three rows of depth, each in
## clusters of one to three overlapping landforms with stretches of open plain between, each landform its own
## scale, proportions and sink into the haze (so its visible height varies). Per row: scroll factor, bottom y,
## scale range, haze amount, foot haze, haze colour, tint, share mirrored, gap range (units of that row), weights
## of the kinds (block, spire, arch, low), cloud shadows.
## The farthest row a pale range of big forms melting into the sky (aerial perspective), the far row smaller, paler
## and cooler, the near row bigger, warmer and darker, never mirrored (lit from the left).
## Round 22 (the judges, j18: "the far mesas pastel lilac at the sky's value, cut paper, no planes"; "milky haze over the
## midground"): less haze on each row and a cooler, darker air, so the ranges sit a value under the bright sky; each
## landform inked (`ink`: the line's width in units, thinner far) and its painted light split into crisp cel planes
## (`planes`), as the characters are drawn.
## Round 23 (the judges, j19: "the far mesas see-through, double-exposed"; "the far mesas carry the playfield's heavy
## black ink: depth collapse"; "lavender mesas under one light, the grass under another"): every landform opaque
## (tools/art/mesa_solid.py; `solid` in haze.gdshader), distance done by mixing toward the sky's colour at that height;
## the ink weakens with each row back (`ink_amount`) and turns toward the row's shadow colour, then toward the sky
## (`ink_colour`); contrast and saturation drop with each row back (`flatten`); none mirrored, so every landform is lit
## from the same low sun on the left (a mirrored one was lit from the right).
const MESA_ROWS := [
	{scroll = 0.012, bottom = 456.0, scale = Vector2(0.62, 1.0), haze = 0.4, foot = 0.3, haze_colour = Color(0.7, 0.75, 0.86),
		tint = Color(1, 1, 1), mirror = 0.0, gap = Vector2(40.0, 260.0), kinds = [3.0, 1.5, 1.2, 0.4], cloud = 0.0, ink = 0.7, planes = 0.55,
		flatten = 0.6, ink_amount = 0.14, ink_colour = Color(0.5, 0.53, 0.68)},
	{scroll = 0.022, bottom = 470.0, scale = Vector2(0.48, 0.74), haze = 0.27, foot = 0.22, haze_colour = Color(0.68, 0.7, 0.85),
		tint = Color(1, 1, 1), mirror = 0.0, gap = Vector2(60.0, 330.0), kinds = [2.0, 2.0, 1.0, 1.0], cloud = 0.5, ink = 0.8, planes = 0.8,
		flatten = 0.36, ink_amount = 0.34, ink_colour = Color(0.42, 0.36, 0.55)},
	{scroll = 0.038, bottom = 494.0, scale = Vector2(0.78, 1.18), haze = 0.1, foot = 0.2, haze_colour = Color(0.64, 0.62, 0.8),
		tint = Color(0.98, 0.92, 0.88), mirror = 0.0, gap = Vector2(120.0, 520.0), kinds = [2.0, 2.0, 1.6, 1.4], cloud = 1.0, ink = 1.1, planes = 1.0,
		flatten = 0.14, ink_amount = 0.6, ink_colour = Color(0.3, 0.19, 0.29)},
]
## Round 23: the sky's cool light, laid into the shade side of the landforms, the plain and the grass (one light: the
## warm low sun for the lit faces, the sky's cool for the shade).
const SKY_AMBIENT := Color(0.72, 0.78, 1.0)
const MESA_KINDS := ["block", "spire", "arch", "low"]
const MESA_CLUSTERS := 6  ## clusters in a row before its order repeats
## Round 20 (the judges, j16: "home all orange, no cool complement: the hero melts into the backdrop"): over the
## last stretch to home dusk falls: the sky cools from the top to a blue-violet, the escarpments and the far
## plain to rose and mauve (each multiplied by these, as `dusk` goes 0 -> 1); the warm hut, fire and hero stand
## out against it.
const DUSK_HIGH := Color(0.56, 0.6, 1.0)
const DUSK_LOW := Color(0.8, 0.74, 0.96)
const DUSK_MESAS := [Color(0.66, 0.68, 1.0), Color(0.7, 0.72, 1.0), Color(0.74, 0.66, 0.92)]
const DUSK_STRIPS := {&"far_hills": Color(0.78, 0.78, 1.0), &"mid_hills": Color(0.9, 0.86, 0.98)}
## Tree rows: scroll factor, spacing (level units of that layer), size (of the picture's height in
## units), ground y, haze, foot haze, share of empty slots, haze colour (the far rows sink into the
## cool blue of distance, the near one into the warm air at the horizon).
## Round 4: haze only far away; the nearer rows darker and richer (TREE_TINT), so the play stands off
## the backdrop at a glance.
## Round 9: the far rows in a cool, darker slate blue ("the pale haze band across the middle
## washes everything out"): a cool, quiet background behind a warm, saturated playfield.
## Round 23 (the judges, j19: "the midground acacias one dark stamp repeated in rows"): mid_hills.png's painted row of
## acacias is gone (tools/art/hills_clean.py); the far rows sink into the pale air of the plain (no dark slate stamps).
const TREE_ROWS := [
	[0.11, 190.0, 70.0, 488.0, 0.38, 0.2, 0.4, Color(0.72, 0.68, 0.68)],  # (round 9: sparser: a dotted line of stamps)
	[0.2, 300.0, 104.0, 540.0, 0.1, 0.08, 0.38, Color(0.66, 0.66, 0.72)],  # (round 7: crowns under the jump band:
	[0.31, 520.0, 130.0, 604.0, 0.0, 0.05, 0.4, Color(0.96, 0.78, 0.5)],  # they read as platforms there)
]
## (round 6: the near rows darker, warmer; round 9: a little lighter again, so their crowns' lit tops
## and shaded undersides read, not flat discs)
const TREE_TINT := [Color(1, 1, 1), Color(0.76, 0.7, 0.6), Color(0.72, 0.66, 0.54)]
const TREE_INK := [0.7, 1.0, 1.35]  ## round 22: each row's ink line (units): thinner far
## Round 23: and fainter far, toward the air (the far row) and the row's shade (the middle one); flatter far; the sky's
## cool light in their shade
const TREE_INK_AMOUNT := [0.2, 0.5, 0.88]
const TREE_INK_COLOUR := [Color(0.5, 0.52, 0.62), Color(0.3, 0.26, 0.33), Color(0.17, 0.085, 0.06)]
const TREE_FLATTEN := [0.32, 0.1, 0.0]
const TREE_AMBIENT := [0.2, 0.35, 0.45]
## Round 22 (the judges, j18: "the hero's lane has no value separation: a mid-orange hero on mid-gold grass"): the tall
## grass behind his legs and the savanna behind his body a value darker and greener (an olive band), so his warm skin,
## white loincloth and red scarf read against it (the warm add of round 3's lane light is gone).
## Round 23 (the judges, j19: "he runs over the darkest band of the screen: his dark skin and black ink a smudge"): a
## sunlit mid value, cooler (a sage straw, its shade in the sky's cool light): he reads by his darker warm skin and ink
## against it, not against a dark olive band.
const MID_TINT := Color(0.76, 0.72, 0.56)
const LANE_TINT := Color(0.86, 0.86, 0.7)
## animals.png (tools/art/savanna.py): two giraffes, an elephant, a herd of wildebeest (px regions)
const ANIMALS := [Rect2(0, 0, 140, 220), Rect2(140, 12, 128, 208), Rect2(268, 68, 220, 152), Rect2(488, 132, 300, 88)]
const CLOUD_SHADOW_GAP := 700.0  ## round 10: units of the plain between two clouds' shadows
const FRONT_GRASS := false  ## the out-of-focus grass band along the bottom edge (off: it read as smudges)
const FRONT_SCROLL := 1.35  ## the foreground grass moves faster than the ground
const FRONT_PROP_SCROLL := 1.45  ## round 9: the big things in front, nearer still (round 20: 1.6 -> 1.45: longer in the corner)
const FRONT_PROP := Vector2(260, 190)  ## one piece of fg_props.png (units, 1 px a unit)
const FRONT_PIECES := 4  ## tall grass, an aloe, a fallen log, a bush
const FRONT_PROP_GAP := 420.0  ## units of the foreground between two of them (some left open)
const FRONT_ZONE := 95.0  ## round 20: they show only this far and more behind him (the corner behind his back)
const FRONT_DROP := 15.0  ## units its picture reaches below the bottom of the screen (round 20: 12 -> 4, fg_grass.png keeps every shape 2+ units under the ground line; round 22: 9, more of the bank shows; round 23: 15, more still)

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
var dusk := 0.0  ## round 20: 0..1, how far dusk has fallen (the last stretch to home)
var _mesa_src: Array[Rect2] = []  # round 20: each landform in far_mesa_pieces.png
var _mesa_kind: Array[int] = []  # round 21: its kind (MESA_KINDS)
var _mesa_slots := []  # per row: [[piece, x, scale, mirrored, height factor, sink], ...] (units of that row)
var _mesa_span: Array[float] = []  # per row: units before its order repeats
var _mesa_mats: Array[ShaderMaterial] = []  # round 21: per row (the clouds' shadows slide over them)
var _far_mat: ShaderMaterial  # round 23: the far plain's and the mid hills' (the dusk's colour over their haze)
var _mid_mat: ShaderMaterial


class Painter extends Node2D:
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


func _ready() -> void:
	for name in ["sky", "sun", "sun_halo", "rays", "far_mesa_pieces", "far_hills", "mid_hills", "near_grass",
			"mote", "bird"]:
		_tex[StringName(name)] = load(DIR + name + ".png")
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "tree_info.json"))
	for name: String in info:
		_trees.append(load(DIR + name + ".png"))
		_tree_anchor.append(float(info[name].anchor_x))
	_tex[&"prop_termite"] = load(DIR + "prop_termite.png")
	_tex[&"animals"] = load(DIR + "animals.png")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# (round 23, the judges, j19: "soft painted clouds that don't match the hard-inked mesas": the clouds' forms in cel
	# steps, sky_cel.gdshader; it reads sky.png's far mips for the broad light)
	var sky := _painter(_draw_sky, true)
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sky.material = ShaderMaterial.new()
	(sky.material as ShaderMaterial).shader = preload("res://src/game/sky_cel.gdshader")
	_painter(_draw_sun.bind(false))  # (round 9: its halo laid over the blue, warm, not added to it:
	_painter(_draw_sun.bind(true)).material = add  # added, orange on blue made it a grey-white disc)
	# (world redraw: the clouds are painted in the sky now, the drifting cloud sprites are gone)
	# (round 9: the mesas' feet in cool air, not pale milk: the middle of the screen read washed out)
	_place_mesas()
	for row in MESA_ROWS.size():  # (round 21: three rows of landforms, the farther ones paler and cooler)
		var m: Dictionary = MESA_ROWS[row]
		var hz := _haze([0, 0, 0, 0, m.haze, m.foot, 0, m.haze_colour], m.tint, m.ink, m.planes, false,
				{flatten = m.flatten, ink_amount = m.ink_amount, ink_colour = m.ink_colour, solid = true, ambient_k = 0.3 * (1.0 - m.flatten)})
		hz.set_shader_parameter(&"cloud", m.cloud)
		hz.set_shader_parameter(&"cell_px", 255.0)  # (far_mesa_pieces.png: two rows of cells 255 px apart)
		_painter(_draw_mesas.bind(row)).material = hz
		_mesa_mats.append(hz)
	# (round 23: no bands of haze laid over the ranges' feet with alpha: the foot's haze is mixed in each row's colour)
	# (round 9: the far hills slate blue and darker: they were the pale milky band)
	# (world redraw: the new far plain is painted pale: a little darker and cooler, not a milky band)
	# (round 22, the judges: "milky haze over the midground": the far plain a warmer dusty ochre a value under the sky,
	# its far edge in the blue of distance, not a pale lilac band)
	# (round 23: its haze the sky's at the horizon, the same air as over the far landforms, its ink faint)
	_far_mat = _haze([0, 0, 0, 0, 0.16, 0.0, 0, Color(0.74, 0.74, 0.8)], Color(0.78, 0.68, 0.52), 0.7, 0.0, true,
			{flatten = 0.3, ink_amount = 0.25, ink_colour = Color(0.5, 0.48, 0.58), ambient_k = 0.3})
	_painter(_draw_strip.bind(&"far_hills"), true).material = _far_mat
	_painter(_draw_trees.bind(0)).material = _tree_haze(0)
	# (round 11: under the midground again: over it they washed it to beige; round 23: cut into crisp shafts, fainter)
	_painter(_draw_rays).material = ShaderMaterial.new()
	(_painters[-1].material as ShaderMaterial).shader = preload("res://src/game/rays_cel.gdshader")
	_mid_mat = _haze([0, 0, 0, 0, 0.06, 0.0, 0, Color(0.8, 0.78, 0.8)], MID_TINT, 0.95, 0.0, true,
			{flatten = 0.12, ink_amount = 0.5, ink_colour = Color(0.3, 0.24, 0.27), ambient_k = 0.55})
	_painter(_draw_strip.bind(&"mid_hills"), true).material = _mid_mat  # (round 6: the darker, warmer mid-ground)
	_painter(_draw_trees.bind(1)).material = _tree_haze(1)
	_painter(_draw_trees.bind(2)).material = _tree_haze(2)
	_painter(_draw_strip.bind(&"near_grass"), true).material = _haze([0, 0, 0, 0, 0.0, 0.0, 0, Color(1, 1, 1)], LANE_TINT, 1.1, 0.0, true,
			{ink_amount = 0.7, ambient_k = 0.6})
	_painter(_draw_cloud_shadows)  # (round 10) shadows of the clouds sliding over the plain
	_painter(_draw_motes).material = add
	_painter(_draw_birds)
	_tex[&"fg_grass"] = load(DIR + "fg_grass.png")
	_tex[&"fg_props"] = load(DIR + "fg_props.png")
	front = Painter.new()
	front.name = &"Bg_front"
	front.paint = _draw_front
	front.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# round 22 (the judges, j18: "the bottom ~12 % a dark purple soil band wasted"): the out-of-focus grass in front a
	# deep warm earth brown, not black, lower (more of the ground's bank shows over it)
	front.material = _haze([0, 0, 0, 0, 0.55, 0.0, 0, Color(0.5, 0.32, 0.22)])  # (round 23: a warm mid brown, not a black mud band)
	_painters.append(front)


func _painter(fn: Callable, repeat := false) -> Painter:
	var p := Painter.new()
	p.paint = fn
	# (round 12, QA: named, so perf.tscn --hide can weigh each layer: Bg_strip_far_mesas, Bg_trees_1, ...)
	var parts := [fn.get_method().trim_prefix("_draw_")]
	for arg: Variant in fn.get_bound_arguments():
		parts.append(str(arg).replace(".", "_"))
	p.name = "Bg_" + "_".join(parts)
	if repeat:
		p.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(p)
	_painters.append(p)
	return p


## (round 22: `ink` the line round each sprite, its width in units; `planes` its painted light split into cel planes)
## (round 22: `strip` a wide strip repeating across the view: only its top edge inked, the cheap way)
## (round 23: `opts`: flatten, ink_amount, ink_colour, solid, ambient_k: haze.gdshader's depth and light)
func _haze(row: Array, tint := Color.WHITE, ink := 0.0, planes := 0.0, strip := false, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/game/haze.gdshader")
	for key: String in opts:
		m.set_shader_parameter(StringName(key), opts[key])
	m.set_shader_parameter(&"ambient", SKY_AMBIENT)
	m.set_shader_parameter(&"ink_units", ink)
	m.set_shader_parameter(&"planes", planes)
	m.set_shader_parameter(&"ink_sides", not strip)
	m.set_shader_parameter(&"tint", tint)
	m.set_shader_parameter(&"haze_colour", row[7])
	m.set_shader_parameter(&"amount", row[4])
	m.set_shader_parameter(&"foot", row[5])
	return m


## Round 23: a tree row's material: its haze, its ink fainter and toward the air or its shade further back, the sky's light.
func _tree_haze(row: int) -> ShaderMaterial:
	return _haze(TREE_ROWS[row], TREE_TINT[row], TREE_INK[row], 0.0, false, {ink_amount = TREE_INK_AMOUNT[row],
			ink_colour = TREE_INK_COLOUR[row], flatten = TREE_FLATTEN[row], ambient_k = TREE_AMBIENT[row]})


func _process(delta: float) -> void:
	_clock += delta
	# round 20: dusk falls over the last stretch to home
	dusk = smoothstep(HomeView.LEFT - 1800.0, HomeView.LEFT - 150.0, scroll)
	for row in _mesa_mats.size():  # round 21: the clouds' shadows over the landforms, sliding with the wind
		if float(MESA_ROWS[row].cloud) > 0.0:
			_mesa_mats[row].set_shader_parameter(&"cloud_x", scroll * float(MESA_ROWS[row].scroll) - _clock * 7.0)
		_mesa_mats[row].set_shader_parameter(&"air_tint", _dusk(DUSK_MESAS[row]))  # (round 23: the air dusks with them)
	_far_mat.set_shader_parameter(&"air_tint", _dusk(DUSK_STRIPS[&"far_hills"]))
	_mid_mat.set_shader_parameter(&"air_tint", _dusk(DUSK_STRIPS[&"mid_hills"]))
	for p in _painters:
		p.queue_redraw()


## Round 20: the dusk's colour over a layer (white: none).
func _dusk(c: Color) -> Color:
	return Color.WHITE.lerp(c, dusk)


func _x0() -> float:
	return -view_left - 2.0


func _x1() -> float:
	return view_width - view_left + 2.0


## The sun's centre in this node's units (WorldView's light grade follows it).
func sun_position() -> Vector2:
	return _sun()


func _sun() -> Vector2:
	return Vector2(_x0() + (_x1() - _x0()) * SUN_AT.x - scroll * 0.004, view_top + SUN_AT.y)


## World redraw: the sky is a painted panorama (kie.ai, from the menu's key art) that repeats left to
## right, its clouds sliding slowly with the wind and a little with the run. Above its top (the
## camera drew back) it goes on mirrored (more clouds, no streaks); below its bottom (behind the
## hills) its last row reaches on.
func _draw_sky(ci: CanvasItem) -> void:
	var sky: Texture2D = _tex[&"sky"]
	var k := SKY_RECT.y / sky.get_height()  # units per texture pixel
	var x0 := _x0()
	var w := _x1() - x0
	# (its top two rows left out: the picture repeats, so its top edge is filtered with its bottom row, the warm horizon:
	# a pale hairline across the sky where the mirrored half starts, seen as he climbs to the vines)
	var src := Rect2(fposmod((scroll * SKY_SCROLL + _clock * SKY_DRIFT + x0) / k, sky.get_width()), 2.0, w / k, sky.get_height() - 2.0)
	if view_top - 2.0 < SKY_RECT.x:  # mirrored about its top edge
		ci.draw_set_transform(Vector2(0.0, 2.0 * SKY_RECT.x + 1.0), 0.0, Vector2(1.0, -1.0))
		ci.draw_texture_rect_region(sky, Rect2(x0, SKY_RECT.x, w, SKY_RECT.y), src, _dusk(DUSK_HIGH))
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	# (round 20: at dusk, near home, the sky cools from the top: a blue-violet over the warm horizon)
	var size := sky.get_size()
	var uv0 := src.position / size
	var uv1 := src.end / size
	var top := _dusk(DUSK_HIGH)
	var low := _dusk(DUSK_LOW)
	ci.draw_polygon(PackedVector2Array([Vector2(x0, SKY_RECT.x), Vector2(x0 + w, SKY_RECT.x), Vector2(x0 + w, SKY_RECT.x + SKY_RECT.y),
			Vector2(x0, SKY_RECT.x + SKY_RECT.y)]), PackedColorArray([top, top, low, low]),
			PackedVector2Array([uv0, Vector2(uv1.x, uv0.y), uv1, Vector2(uv0.x, uv1.y)]), sky)
	var bottom := SKY_RECT.x + SKY_RECT.y
	if bottom < World.VIEW_H + 4.0:
		ci.draw_texture_rect_region(sky, Rect2(x0, bottom - 1.0, w, World.VIEW_H + 5.0 - bottom),
				Rect2(src.position.x, sky.get_height() - 1, src.size.x, 1), low)


## The sun: its golden halo laid over the sky (`bloom` false), then its hot disc and bloom added.
func _draw_sun(ci: CanvasItem, bloom: bool) -> void:
	var s := SUN_SIZE * (1.0 + sin(_clock * 0.7) * 0.012)
	if bloom:  # (round 10: softer, warmer: "a hard white disc"; round 19: out of the picture, its glow a
		# wide soft warmth in the corner, never brighter than the lit clouds)
		ci.draw_texture_rect(_tex[&"sun"], Rect2(_sun() - Vector2(s, s) * 0.5, Vector2(s, s) * 1.0), false, Color(1, 0.8, 0.52, 0.42 * (1.0 - 0.5 * dusk)))
	else:
		ci.draw_texture_rect(_tex[&"sun_halo"], Rect2(_sun() - Vector2(s, s) * 0.6, Vector2(s, s) * 1.2), false, Color(1, 0.84, 0.6, 0.6 * (1.0 - 0.5 * dusk)))


## God rays fanning from the sun to the lower right, breathing slowly.
func _draw_rays(ci: CanvasItem) -> void:
	var tex: Texture2D = _tex[&"rays"]
	var k := 1.2
	var a := 0.07 + 0.015 * sin(_clock * 0.45) + 0.008 * sin(_clock * 1.13)  # (round 22: fainter: they milked the midground; round 23: fainter still)
	ci.draw_texture_rect(tex, Rect2(_sun() - RAYS_ORIGIN * k, RAYS_SIZE * k), false, Color(1, 1, 1, a))


## Round 20: each row's order of landforms, worked out once. Round 21 (the judges, j17: "stamped, evenly spaced"):
## clusters of one to three landforms overlapping (the bigger behind), a stretch of open plain between two clusters;
## never the same landform twice in a row (nor across the repeat); each its own scale, proportions (a spire stands
## taller, a low one squats) and sink into the haze (its foot hidden lower: its visible height varies).
func _place_mesas() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "far_mesa_pieces.json"))
	var h := float(info["height"])
	for p: Array in info["pieces"]:
		_mesa_src.append(Rect2(float(p[0]), float(p[1]), float(p[2]), h))
		_mesa_kind.append(maxi(MESA_KINDS.find(String(p[3])), 0))
	for row in MESA_ROWS.size():
		var m: Dictionary = MESA_ROWS[row]
		var scales: Vector2 = m.scale
		var weights: Array = m.kinds
		var slots := []
		var x := 0.0
		var prev := -1
		var first := -1
		var n := 0
		for cluster in MESA_CLUSTERS:
			var count := 1 + int(_hash(cluster * 41 + row * 17 + 1) * 2.6)  # one to three landforms
			var group := []
			for j in count:
				var seed := n * 37 + row * 101 + 5
				n += 1
				var piece := _pick_mesa(weights, _hash(seed))
				var tries := 0
				while (piece == prev or (cluster == MESA_CLUSTERS - 1 and j == count - 1 and piece == first)) and tries < 12:
					piece = _pick_mesa(weights, _hash(seed + 7 + tries * 3))
					tries += 1
				if first < 0:
					first = piece
				prev = piece
				var kind := _mesa_kind[piece]
				var k := lerpf(scales.x, scales.y, _hash(seed + 2))
				if _mesa_src[piece].size.x > 500.0:
					k *= 0.8  # (the long plateau: never a wall across the whole view)
				var tall := 0.78 + _hash(seed + 4) * 0.4
				if kind == 1:
					tall += 0.18  # (a spire stands taller)
				elif kind == 3:
					tall -= 0.1
				var sink := _hash(seed + 6) * 46.0 * k if j > 0 or _hash(seed + 8) < 0.5 else 0.0
				var mirrored := _hash(seed + 3) < float(m.mirror)
				group.append([piece, x, k, mirrored, tall, sink])
				# the next one in the cluster overlaps this one; after the last, open plain
				x += _mesa_src[piece].size.x * k * (0.42 + _hash(seed + 9) * 0.34)
			x += _mesa_src[group[-1][0]].size.x * float(group[-1][2]) * 0.5 + lerpf(m.gap.x, m.gap.y, _hash(cluster * 23 + row * 3 + 9))
			# the bigger landforms behind, the smaller in front of them
			group.sort_custom(func(a: Array, b: Array) -> bool: return a[2] * a[4] > b[2] * b[4])
			slots.append_array(group)
		_mesa_slots.append(slots)
		_mesa_span.append(x)


## A landform of a kind drawn by its weight (0..1 `u`), then one of that kind.
func _pick_mesa(weights: Array, u: float) -> int:
	var total := 0.0
	for wk: float in weights:
		total += wk
	var pick := u * total
	var kind := 0
	for i in weights.size():
		pick -= float(weights[i])
		if pick <= 0.0:
			kind = i
			break
	var of_kind: Array[int] = []
	for i in _mesa_src.size():
		if _mesa_kind[i] == kind:
			of_kind.append(i)
	if of_kind.is_empty():
		return int(u * _mesa_src.size()) % _mesa_src.size()
	return of_kind[int(fposmod(u * 97.13, 1.0) * of_kind.size()) % of_kind.size()]


func _draw_mesas(ci: CanvasItem, row: int) -> void:
	var tex: Texture2D = _tex[&"far_mesa_pieces"]
	var m: Dictionary = MESA_ROWS[row]
	var x0 := _x0()
	var x1 := _x1()
	var offset: float = scroll * float(m.scroll) + [1700.0, 900.0, 0.0][row]  # (the rows never line up)
	var span: float = _mesa_span[row]
	var bottom: float = m.bottom
	var colour := _dusk(DUSK_MESAS[row])
	# (round 22, the judges, j18: "a pillar behind the hut's peak reads as a chimney"): at dusk, near home, the spires
	# sink away (a tall thin one stood behind the hut's peak); the broad landforms stay. Round 23 (the judges, j19:
	# "see-through mesas"): they sink below the plain's horizon, opaque (they faded out with alpha)
	var spire_a := 1.0 - smoothstep(0.45, 0.9, dusk)
	for cycle in range(floori((x0 + offset) / span) - 1, floori((x1 + offset) / span) + 1):
		for slot: Array in _mesa_slots[row]:
			var sunk := 0.0
			if _mesa_kind[slot[0]] == 1:
				if spire_a <= 0.0:
					continue
				sunk = 1.0 - spire_a
			var src: Rect2 = _mesa_src[slot[0]]
			var k: float = slot[2]
			var ky: float = k * float(slot[4])
			var rect := Rect2(cycle * span + float(slot[1]) - offset, bottom + float(slot[5]) - src.size.y * ky * (1.0 - sunk * 1.05),
					src.size.x * k, src.size.y * ky)
			if rect.end.x < x0 or rect.position.x > x1:
				continue
			if slot[3]:
				rect.size.x = -rect.size.x  # mirrored in place
			ci.draw_texture_rect_region(tex, rect, src, colour)


func _draw_strip(ci: CanvasItem, name: StringName) -> void:
	var tex: Texture2D = _tex[name]
	var s: Array = STRIPS[name]
	var k: float = s[2]
	var x0 := _x0()
	var x1 := _x1()
	var h := tex.get_height() * k
	var src_x := fposmod((scroll * s[0] + x0) / k, tex.get_width())
	ci.draw_texture_rect_region(tex, Rect2(x0, s[1] - h, x1 - x0, h),
			Rect2(src_x, 0, (x1 - x0) / k, tex.get_height()), _dusk(DUSK_STRIPS.get(name, Color.WHITE)))


## The foreground grass along the bottom edge (round 20: taller, denser, its top rising and falling, never
## over the ground line he runs on); round 9: and the big things near the camera (fg_props.png: tall grass,
## an aloe, a log, a bush), faster still. Round 20 (the judges, j16: "no foreground framing layer, a flat
## stage"; they faded only near him, so they covered the bandits' feet and the ground edge): the big things
## rise into view only in the corner behind him (left of FRONT_ZONE units before him), framing the shot there;
## anywhere else they are not drawn (they fade out as they pass into his space).
func _draw_front(ci: CanvasItem) -> void:
	var x0 := _x0()
	var x1 := _x1()
	# (2026-11-12, the blind judge, in three of five pictures: "the blurry maroon blobs along the bottom edge cut the
	# ground strip: compression smudges, not plants": the out-of-focus grass band is no longer drawn; FRONT_GRASS)
	if FRONT_GRASS:
		var tex: Texture2D = _tex[&"fg_grass"]
		var h := float(tex.get_height())
		var src_x := fposmod(scroll * FRONT_SCROLL + x0, tex.get_width())
		ci.draw_texture_rect_region(tex, Rect2(x0, World.VIEW_H + FRONT_DROP - h, x1 - x0, h),
				Rect2(src_x, 0, x1 - x0, h))
	var props: Texture2D = _tex[&"fg_props"]
	var offset := scroll * FRONT_PROP_SCROLL
	var zone := hero_x - FRONT_ZONE  # play x: right of this, nothing rises over the ground line
	var first := floori((x0 + offset) / FRONT_PROP_GAP) - 1
	for i in range(first, first + int((x1 - x0) / FRONT_PROP_GAP) + 3):
		if _hash(i * 13 + 7) < 0.25:  # open stretches between them
			continue
		var k := 0.82 + _hash(i * 7 + 3) * 0.3
		var size := FRONT_PROP * k
		var cx := i * FRONT_PROP_GAP + _hash(i * 5 + 1) * FRONT_PROP_GAP * 0.5 - offset
		var rect := Rect2(cx - size.x / 2, World.VIEW_H + FRONT_DROP + 6.0 - size.y * 0.8, size.x, size.y)
		if rect.end.x < x0 or rect.position.x > x1:
			continue
		var fade := 1.0 - smoothstep(zone - 70.0, zone, rect.end.x - size.x * 0.25)
		if fade <= 0.01:
			continue
		if _hash(i * 11 + 4) < 0.5:
			rect.size.x = -rect.size.x  # mirrored in place
		var piece := posmod(int(_hash(i * 3 + 9) * FRONT_PIECES), FRONT_PIECES)
		ci.draw_texture_rect_region(props, rect, Rect2(piece * FRONT_PROP.x, 0, FRONT_PROP.x, FRONT_PROP.y), Color(1, 1, 1, fade))


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


## Round 21 (the judges, j17: "acacias evenly spaced like wallpaper"): each row in groves of one to six trees
## standing close (the middle ones taller), with long stretches of open plain between (an animal or a termite mound
## alone in some), so the rows read as clumps and gaps.
func _draw_trees(ci: CanvasItem, row_index: int) -> void:
	var row: Array = TREE_ROWS[row_index]
	var factor: float = row[0]
	var grove_gap: float = row[1] * 2.6  # (units of this row between two groves' places)
	var x0 := _x0()
	var x1 := _x1()
	var offset := scroll * factor
	var first := floori((x0 + offset) / grove_gap) - 2
	for g in range(first, first + int((x1 - x0) / grove_gap) + 5):
		var gseed := g * 131 + row_index * 977
		var u := _hash(gseed)
		# (how many in this grove: none, a lone tree, a few, a thick clump; the far rows have the bigger clumps)
		var count := 0 if u < float(row[6]) * 0.7 else (1 if u < 0.55 else (2 + int(_hash(gseed + 1) * (3.0 if row_index == 2 else 5.0))))
		var cx := g * grove_gap + _hash(gseed + 2) * grove_gap * 0.7 - offset
		if count == 0:
			if row_index < 2 and _hash(gseed + 3) < 0.45:  # (round 2) the open plain: animals (giraffes, an elephant, a herd)
				_draw_animal(ci, int(_hash(gseed + 4) * ANIMALS.size()), cx, row[3], row[2] / 132.0 * 0.7, _hash(gseed + 5) < 0.5)
			elif row_index > 0 and _hash(gseed + 6) < 0.5:  # or a termite mound
				var mound: Texture2D = _tex[&"prop_termite"]
				var mh := float(row[2]) * 0.42 * (0.8 + _hash(gseed + 7) * 0.4)
				var mk := mh / mound.get_height()
				_draw_tree(ci, row_index, mound, mound.get_width() / 2.0, Vector2(cx, row[3]), Vector2(mk, mk), false, 0.0, 0.92, 0.0)
			continue
		var spread := float(row[1]) * (0.16 + _hash(gseed + 8) * 0.12)  # (units between two trees of the grove)
		var prev := -1
		for j in count:
			var seed := gseed * 7 + j * 31
			var t := int(_hash(seed + 1) * _trees.size()) % _trees.size()
			if t == prev:  # round 19 ("identical stamps"): never the same tree as the one beside it
				t = (t + 1 + j) % _trees.size()
			prev = t
			var tex := _trees[t]
			var mid := 1.0 - absf(j - (count - 1) * 0.5) / maxf(count * 0.5, 1.0)  # 1 in the grove's middle
			var height: float = row[2] * (0.45 + _hash(seed + 2) * 0.5 + 0.35 * mid) * (1.0 if count < 3 else 0.86)
			if tex.get_height() > tex.get_width():  # baobabs: taller pictures, same tree scale
				height *= 1.15
			var k := height / tex.get_height()
			var x := cx + (j - (count - 1) * 0.5) * spread * (0.7 + _hash(seed + 3) * 0.6)
			var wide := 0.78 + _hash(seed + 6) * 0.55  # wider or narrower crowns: no two trees alike
			# (round 23, the judges, j19: "one stamp repeated": each its own build too, squat and spreading or tall and lean)
			var build := 0.8 + _hash(seed + 21) * 0.42
			# (round 12, "tree clones": each its own shade, a little greener, yellower or darker)
			var v := 0.86 + _hash(seed + 15) * 0.26
			var warm := (_hash(seed + 16) - 0.5) * 0.16
			_draw_tree(ci, row_index, tex, _tree_anchor[t], Vector2(x, row[3]), Vector2(k * wide / sqrt(build), k * build), _hash(seed + 4) < 0.5,
					(_hash(seed + 14) - 0.5) * 0.36, v, warm)


## One tree (or mound) standing at `foot`: its picture `scale`d, mirrored, leaning (a skew about its foot), its
## shade.
func _draw_tree(ci: CanvasItem, row_index: int, tex: Texture2D, anchor: float, foot: Vector2, scale_k: Vector2, flip: bool,
		lean: float, v: float, warm: float) -> void:
	var size := tex.get_size() * scale_k
	var ax := anchor * scale_k.x
	if flip:
		ax = size.x - ax
	var rect := Rect2(foot.x - ax, foot.y - size.y, size.x, size.y)
	if rect.end.x < _x0() - 40.0 or rect.position.x > _x1() + 40.0:
		return
	# (the user, 2026-11-08: the round 21 fade of a tree behind his head and hands cut a hole in the trees round him;
	# every tree is drawn whole, he simply passes in front of it)
	var alpha := 1.0
	if flip:  # a negative width mirrors the picture in place
		rect.size.x = -size.x
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE, lean, foot))
	ci.draw_texture_rect(tex, Rect2(rect.position - foot, rect.size), false, Color(v + warm, v, v - warm, alpha))
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
	# round 21 (the judges, j17: "~60 % of the hang shot empty sky"): a skein of birds far off, small and hazy,
	# gliding slowly across the middle of the sky in a loose V, each flapping on its own beat
	# (over the open middle and right of the sky, where he rarely is: crossing it slowly to the left, fading in at
	# its right and out at its middle, then again)
	var leg := fposmod(_clock / 90.0 + 0.3, 1.0)
	var lead := x0 + w * lerpf(0.95, 0.42, leg)
	var seen := smoothstep(0.0, 0.12, leg) * (1.0 - smoothstep(0.85, 1.0, leg))
	for i in 9:
		var rank := (i + 1) / 2
		var side := -1.0 if i % 2 == 1 else 1.0
		var bx := lead + rank * 17.0 + sin(_clock * 0.6 + i * 1.7) * 2.5
		var by := 182.0 + rank * 7.5 * side + sin(_clock * 0.9 + i) * 2.0 + rank * 2.0
		var frame := int(fposmod(_clock * (3.2 + 0.4 * (i % 3)) + i * 1.9, 4.0)) if fposmod(_clock * 0.35 + i * 0.13, 1.0) < 0.4 else 1
		var s := 0.26 - rank * 0.008
		ci.draw_texture_rect_region(tex, Rect2(bx, by, fw * s, fh * s), Rect2(frame * fw, 0, fw, fh), Color(0.36, 0.32, 0.42, 0.62 * seen))
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

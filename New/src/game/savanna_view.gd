@tool
class_name SavannaView
extends Node2D
## The level's sky and the savanna behind the play, late in the afternoon.
## The world redesign (2026-11-12; four blind rounds flat at 6.8 against Prince of Persia's 8.9: "cel-inked characters
## on a pale painterly world", "one flat play plane: nothing between the ground and the far mesas"): one style frame
## in the key art's inked cel painting, then each of its layers painted alone (GPT Image 2.6 Sunburst;
## tools/art/kie/world.py cuts them). Back to front:
##   sky (one painted panorama: deep blue to apricot, cel cumulus drifting), the far escarpment (a blue-violet wall),
##   sandstone landforms in three rows of depth (twelve shapes, the clouds' shadows sliding over the nearer two),
##   the plain (groves, a village, giraffes, a river: one painting from its horizon down), acacias and baobabs behind
##   the middle-ground rise, the rise (boulders, termite mounds, aloes), big trees behind the tall grass, the tall
##   golden grass behind the path, pollen motes in the light, a few birds.
## Each layer is inked and cel-shaded as painted (the shader's ink and cel planes of rounds 22-23 are off): depth is
## each row's own colour drawn toward the far wall's blue-violet air.
## Farther layers scroll slower; the trees are placed from the level's x with a fixed hash, so the
## same tree is always in the same place. Everything is drawn from baked textures (cheap on phones):
## each layer is one canvas item redrawn every frame with a handful of rectangles.
## `front` (added by WorldView above the actors): dark out-of-focus grass passing in front of the
## play along the bottom edge, faster than the ground (it is nearer). Round 9: no boughs along the
## top edge any more (round 3's canopy: "dark branches cut off along the top edge look like dirt
## smudges on the screen").

const DIR := "res://assets/art/world/"
## Where the light comes from: above the screen's top left corner (share of the visible width, y from the top of the
## screen): the painted light of every layer, and the light grade's (WorldView). The redesign: no sun glow, no god
## rays (the judges: "a pale wash across the sky"): the sky is painted lit.
const SUN_AT := Vector2(0.02, -70.0)
## World redraw: the painted sky (sky.png): top y and height it is drawn at (units), how much it
## moves with the run, and its drift with the wind (units a second).
const SKY_RECT := Vector2(-150.0, 660.0)
const SKY_SCROLL := 0.02
const SKY_DRIFT := 2.5

## Strips that repeat left to right: texture, scroll factor, bottom y, units per texture pixel.
## (the redesign: far_wall the escarpment, its top edge near y 372; far_hills the plain, its horizon at HORIZON;
## mid_hills the rise, solid from y 532 (its mounds and boulders under his chest, not behind his head); near_grass solid from y 584, under the low ground's top, its tips over it)
const STRIPS := {
	&"far_wall": [0.008, 524.0, 1.0],
	&"far_hills": [0.07, 540.0, 0.5],
	&"mid_hills": [0.2, 648.0, 0.5],
	&"near_grass": [0.42, 649.0, 0.5],
}
const HORIZON := 432.0  ## play y of the plain's far edge: the landforms stand behind it
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
## The redesign: the landforms are painted inked and lit (ink, planes 0); the far row small and deep in the far wall's
## blue-violet air, the near row in its full orange and red; none mirrored (all lit from the upper left).
## (blind round 5: "the midground at the play layer's saturation, contrast and line detail: no quiet zone; push the
## whole background back one clear value step, lighter and hazier, a quarter less colour": every layer behind the
## play is drawn toward a pale air and flattened (haze.gdshader's flatten: less colour, less contrast, its ink with it),
## more the farther it is; the characters and the pickups are the only full-contrast layer)
const AIR := Color(0.7, 0.66, 0.86)  ## the far air, a pale blue-violet: what distance draws the landforms toward
const MESA_ROWS := [
	{scroll = 0.014, bottom = 438.0, scale = Vector2(0.2, 0.28), haze = 0.6, foot = 0.14, haze_colour = AIR,
		tint = Color(1, 1, 1), mirror = 0.0, gap = Vector2(30.0, 190.0), kinds = [3.0, 1.5, 1.2, 1.0], cloud = 0.0, ink = 0.0, planes = 0.0,
		flatten = 0.5, ink_amount = 0.0, ink_colour = Color(0.5, 0.53, 0.68)},
	{scroll = 0.024, bottom = 444.0, scale = Vector2(0.3, 0.4), haze = 0.42, foot = 0.14, haze_colour = AIR,
		tint = Color(1, 1, 1), mirror = 0.0, gap = Vector2(60.0, 300.0), kinds = [2.0, 2.0, 1.0, 1.4], cloud = 0.5, ink = 0.0, planes = 0.0,
		flatten = 0.36, ink_amount = 0.0, ink_colour = Color(0.42, 0.36, 0.55)},
	{scroll = 0.04, bottom = 452.0, scale = Vector2(0.44, 0.6), haze = 0.22, foot = 0.12, haze_colour = AIR,
		tint = Color(1, 1, 1), mirror = 0.0, gap = Vector2(160.0, 560.0), kinds = [2.0, 1.6, 1.6, 1.4], cloud = 1.0, ink = 0.0, planes = 0.0,
		flatten = 0.24, ink_amount = 0.0, ink_colour = Color(0.3, 0.19, 0.29)},
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
## (2026-11-12, three blind judges on the home picture: "the far mesas are translucent rectangular ghosts: a rendering
## fault": at dusk the two far rows stood at the sky's own value; now a clear step under it, solid silhouettes)
const DUSK_MESAS := [Color(0.5, 0.5, 0.8), Color(0.56, 0.56, 0.84), Color(0.74, 0.66, 0.92)]
const DUSK_STRIPS := {&"far_wall": Color(0.6, 0.6, 0.9), &"far_hills": Color(0.78, 0.78, 1.0), &"mid_hills": Color(0.9, 0.86, 0.98)}
## Tree rows: scroll factor, spacing (level units of that layer), size (of the picture's height in
## units), ground y, haze, foot haze, share of empty slots, haze colour.
## The redesign: two rows, each standing behind a rise so the foot of its trunks is hidden: smaller trees behind the
## middle-ground rise (they move between the plain's speed and the rise's), big ones behind the tall grass, their trunks
## passing behind him and their crowns over the landforms. (The plain has its own far groves painted in.)
const TREE_ROWS := [
	[0.14, 330.0, 96.0, 540.0, 0.28, 0.0, 0.42, LANE_AIR],
	[0.31, 760.0, 232.0, 594.0, 0.2, 0.0, 0.7, LANE_AIR],  # (few: "the baobab behind the action out-contrasts him")
]
## The big near row: only trees with a tall trunk, their crowns over his head: behind his body there is a trunk at
## most (a wide low crown behind him hid him and the bandits).
const TREE_TALL: Array[String] = ["tree_acacia_2", "tree_acacia_5", "tree_baobab_2", "tree_baobab_4"]
const TREE_TINT := [Color(0.96, 0.96, 1.0), Color(1, 1, 1)]
const TREE_INK := [0.0, 0.0]  ## (painted inked)
const TREE_INK_AMOUNT := [0.0, 0.0]
const TREE_INK_COLOUR := [Color(0.3, 0.26, 0.33), Color(0.17, 0.085, 0.06)]
const TREE_FLATTEN := [0.56, 0.44]
const TREE_AMBIENT := [0.0, 0.0]
## Blind round 11 ("the mid-ground is as sharp and saturated as the fighters: push it back"): the world behind the
## play out of focus, more with each layer back (haze.gdshader's soft: mipmap levels down), as a lens set on the
## runners draws it: the landforms and the far plain soft, the rise and the big trees less, the tall grass right behind
## his legs hardly. The ground he runs on, its props and the plants in front stay sharp.
const SOFT_MESAS := 1.3
const SOFT_PLAIN := 1.7
const SOFT_TREES := [1.6, 1.1]
const SOFT_MID := 1.4
const SOFT_LANE := 0.6
## Round 22 (the judges, j18: "the hero's lane has no value separation: a mid-orange hero on mid-gold grass"): the tall
## grass behind his legs and the savanna behind his body a value darker and greener (an olive band), so his warm skin,
## white loincloth and red scarf read against it (the warm add of round 3's lane light is gone).
## Round 23 (the judges, j19: "he runs over the darkest band of the screen: his dark skin and black ink a smudge"): a
## sunlit mid value, cooler (a sage straw, its shade in the sky's cool light): he reads by his darker warm skin and ink
## against it, not against a dark olive band.
## The redesign: the plain as painted; the rise and the tall grass behind his body a little paler and cooler than
## painted (a straw gold), so his darker, redder skin and his ink stand off them.
const MID_TINT := Color(0.97, 0.98, 0.94)
const LANE_TINT := Color(0.96, 0.98, 0.92)
## and each a little flatter than painted (less contrast, less colour: the shader's `flatten`), the plain most: the
## characters in front are the picture's strongest darks and colours
## (blind rounds 5 to 7, three judges: two asked for the band behind the characters lighter and quieter, one for it
## lower in contrast; the cool shade of round 7 lost ground: "brown-on-tan: his torso has the mound's hue and value")
## pale and quiet: the rise, the trees and the grass behind the path well flattened and drawn toward a pale air that
## is cooler and less coloured than his skin: he and the bandits are the darkest, most saturated shapes on screen
## (blind round 9, the fifth judge: "a uniformly milky, washed-out backdrop under a saturated sky: faded wallpaper;
## graded value layers: a pale far distance, a quiet middle value behind the lane": the far plain stays pale, the rise
## and the grass behind the path keep more of their own colour and value: between round 6's and round 8's)
const PLAIN_FLATTEN := 0.5
const PLAIN_HAZE := 0.15
const MID_FLATTEN := 0.46
const MID_HAZE := 0.1
const LANE_FLATTEN := 0.3
const LANE_HAZE := 0.04
const LANE_AIR := Color(0.93, 0.9, 0.84)  ## what the plain's and the lane's layers are drawn toward: a pale, nearly neutral air
## (blind round 6: "acacias, mound, pool and boulders at full strength right at his height; his white loincloth and legs
## on pale straw": pale was the wrong step for a hero who is both white cloth and dark skin) a cloud's shadow lies
## across the middle ground behind the play: from the far plain's near half down, everything behind the path is
## multiplied by a cool violet shade (soft-edged at its far side), a middle value under his whites and over his darks;
## the sky, the landforms and the far plain stay in the sun, and so do the path and the characters in front.
const LANE_SHADE := Color(0.95, 0.95, 0.99)  ## (round 7's (0.66, 0.66, 0.88) made the band his skin's value: nearly off)
const LANE_SHADE_FROM := 462.0  ## play y where the shade starts (the far plain: in the sun above it)
const LANE_SHADE_FULL := 508.0  ## and where it is full
const CLOUD_SHADOW_GAP := 700.0  ## round 10: units of the plain between two clouds' shadows
const FRONT_PROP_SCROLL := 1.45  ## round 9: the big things in front, nearer still (round 20: 1.6 -> 1.45: longer in the corner)
const FRONT_PROP := Vector2(260, 230)  ## one piece of fg_props.png (units, 2 px a unit), in 3 columns
const FRONT_PIECES := 6  ## tall grass, an aloe, a boulder, a fallen log, a thorn bush, broad leaves and a mound
const FRONT_COLS := 3
const FRONT_TINT := Color(0.74, 0.68, 0.72)
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
var _tall: Array[int] = []  # the trees of TREE_TALL in _trees
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
var _wall_mat: ShaderMaterial
var _mesa_pitch := 0.0  # px between two rows of landforms in far_mesa_pieces.png


class Painter extends Node2D:
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


func _ready() -> void:
	for name in ["sky", "far_wall", "far_mesa_pieces", "far_hills", "mid_hills", "near_grass", "mote", "bird"]:
		_tex[StringName(name)] = load(DIR + name + ".png")
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "tree_info.json"))
	for name: String in info:
		if name in TREE_TALL:
			_tall.append(_trees.size())
		_trees.append(load(DIR + name + ".png"))
		_tree_anchor.append(float(info[name].anchor_x))
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_painter(_draw_sky, true)
	# the far escarpment: as painted, its foot behind the plain
	_wall_mat = _haze([0, 0, 0, 0, 0.3, 0.0, 0, Color(0.8, 0.72, 0.86)], Color.WHITE, 0.0, 0.0, true, {flatten = 0.3})
	_painter(_draw_strip.bind(&"far_wall"), true).material = _wall_mat
	_place_mesas()
	for row in MESA_ROWS.size():  # three rows of landforms, the farther ones deeper in the air
		var m: Dictionary = MESA_ROWS[row]
		var hz := _haze([0, 0, 0, 0, m.haze, m.foot, 0, m.haze_colour], m.tint, m.ink, m.planes, false,
				{flatten = m.flatten, ink_amount = m.ink_amount, ink_colour = m.ink_colour, solid = true, soft = SOFT_MESAS})
		hz.set_shader_parameter(&"cloud", m.cloud)
		hz.set_shader_parameter(&"cell_px", _mesa_pitch)
		_painter(_draw_mesas.bind(row)).material = hz
		_mesa_mats.append(hz)
	_far_mat = _haze([0, 0, 0, 0, PLAIN_HAZE, 0.0, 0, LANE_AIR], Color.WHITE, 0.0, 0.0, true, {flatten = PLAIN_FLATTEN, soft = SOFT_PLAIN})
	_painter(_draw_strip.bind(&"far_hills"), true).material = _far_mat
	_painter(_draw_trees.bind(0)).material = _tree_haze(0)
	_mid_mat = _haze([0, 0, 0, 0, MID_HAZE, 0.0, 0, LANE_AIR], MID_TINT, 0.0, 0.0, true, {flatten = MID_FLATTEN, soft = SOFT_MID})
	_painter(_draw_strip.bind(&"mid_hills"), true).material = _mid_mat
	_painter(_draw_trees.bind(1)).material = _tree_haze(1)
	_painter(_draw_strip.bind(&"near_grass"), true).material = _haze([0, 0, 0, 0, LANE_HAZE, 0.0, 0, LANE_AIR], LANE_TINT, 0.0, 0.0, true, {flatten = LANE_FLATTEN, soft = SOFT_LANE})
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_painter(_draw_lane_shade).material = mul
	_painter(_draw_cloud_shadows)  # (round 10) shadows of the clouds sliding over the plain
	_painter(_draw_motes).material = add
	_painter(_draw_birds)
	_tex[&"fg_props"] = load(DIR + "fg_props.png")
	front = Painter.new()
	front.name = &"Bg_front"
	front.paint = _draw_front
	# the plants and rocks near the camera: in shade against the light, darker than anything behind them
	front.material = _haze([0, 0, 0, 0, 0.0, 0.0, 0, Color(0.2, 0.12, 0.14)], FRONT_TINT)
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
			ink_colour = TREE_INK_COLOUR[row], flatten = TREE_FLATTEN[row], ambient_k = TREE_AMBIENT[row], soft = SOFT_TREES[row]})


func _process(delta: float) -> void:
	_clock += delta
	# round 20: dusk falls over the last stretch to home
	dusk = smoothstep(HomeView.LEFT - 1800.0, HomeView.LEFT - 150.0, scroll)
	for row in _mesa_mats.size():  # round 21: the clouds' shadows over the landforms, sliding with the wind
		if float(MESA_ROWS[row].cloud) > 0.0:
			_mesa_mats[row].set_shader_parameter(&"cloud_x", scroll * float(MESA_ROWS[row].scroll) - _clock * 7.0)
		_mesa_mats[row].set_shader_parameter(&"air_tint", _dusk(DUSK_MESAS[row]))  # (round 23: the air dusks with them)
	_wall_mat.set_shader_parameter(&"air_tint", _dusk(DUSK_STRIPS[&"far_wall"]))
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


## The sky is a painted panorama that repeats left to right, its clouds sliding slowly with the wind and a little with
## the run. Above its top (the camera drew back, he climbed) its first rows, a plain deep blue, reach on; below its
## bottom (behind the plain) its last row does.
func _draw_sky(ci: CanvasItem) -> void:
	var sky: Texture2D = _tex[&"sky"]
	var k := SKY_RECT.y / sky.get_height()  # units per texture pixel
	var x0 := _x0()
	var w := _x1() - x0
	# (its top two rows left out: the picture repeats, so its top edge is filtered with its bottom row, the warm horizon)
	var src := Rect2(fposmod((scroll * SKY_SCROLL + _clock * SKY_DRIFT + x0) / k, sky.get_width()), 2.0, w / k, sky.get_height() - 2.0)
	# (at dusk, near home, the sky cools from the top: a blue-violet over the warm horizon)
	var top := _dusk(DUSK_HIGH)
	var low := _dusk(DUSK_LOW)
	if view_top - 2.0 < SKY_RECT.x:
		ci.draw_texture_rect_region(sky, Rect2(x0, view_top - 4.0, w, SKY_RECT.x - view_top + 5.0), Rect2(src.position.x, 3.0, src.size.x, 1.0), top)
	var size := sky.get_size()
	var uv0 := src.position / size
	var uv1 := src.end / size
	ci.draw_polygon(PackedVector2Array([Vector2(x0, SKY_RECT.x), Vector2(x0 + w, SKY_RECT.x), Vector2(x0 + w, SKY_RECT.x + SKY_RECT.y),
			Vector2(x0, SKY_RECT.x + SKY_RECT.y)]), PackedColorArray([top, top, low, low]),
			PackedVector2Array([uv0, Vector2(uv1.x, uv0.y), uv1, Vector2(uv0.x, uv1.y)]), sky)
	var bottom := SKY_RECT.x + SKY_RECT.y
	if bottom < World.VIEW_H + 4.0:
		ci.draw_texture_rect_region(sky, Rect2(x0, bottom - 1.0, w, World.VIEW_H + 5.0 - bottom),
				Rect2(src.position.x, sky.get_height() - 1, src.size.x, 1), low)


## Round 20: each row's order of landforms, worked out once. Round 21 (the judges, j17: "stamped, evenly spaced"):
## clusters of one to three landforms overlapping (the bigger behind), a stretch of open plain between two clusters;
## never the same landform twice in a row (nor across the repeat); each its own scale, proportions (a spire stands
## taller, a low one squats) and sink into the haze (its foot hidden lower: its visible height varies).
func _place_mesas() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "far_mesa_pieces.json"))
	var h := float(info["height"])
	_mesa_pitch = float(info.get("pitch", h + 6.0))
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
				var tall := 0.92 + _hash(seed + 4) * 0.18  # (painted forms: stretched a little, never squashed)
				if kind == 1:
					tall += 0.08  # (a spire stands taller)
				elif kind == 3:
					tall -= 0.05
				var sink := _hash(seed + 6) * 30.0 * k if j > 0 or _hash(seed + 8) < 0.5 else 0.0
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
	var props: Texture2D = _tex[&"fg_props"]
	var cell := props.get_size() / Vector2(FRONT_COLS, ceili(float(FRONT_PIECES) / FRONT_COLS))
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
		# (never mirrored: each is lit along its upper left edge, as everything is)
		var piece := posmod(int(_hash(i * 3 + 9) * FRONT_PIECES), FRONT_PIECES)
		ci.draw_texture_rect_region(props, rect, Rect2(Vector2(piece % FRONT_COLS, piece / FRONT_COLS) * cell, cell), Color(1, 1, 1, fade))


## The cloud's shade across the middle ground (LANE_SHADE), multiplied over every layer behind the path.
func _draw_lane_shade(ci: CanvasItem) -> void:
	var x0 := _x0()
	var x1 := _x1()
	var shade := Color.WHITE.lerp(LANE_SHADE, 1.0 - 0.5 * dusk)  # (at dusk the whole scene is in shade: half of it)
	ci.draw_polygon(PackedVector2Array([Vector2(x0, LANE_SHADE_FROM), Vector2(x1, LANE_SHADE_FROM), Vector2(x1, LANE_SHADE_FULL), Vector2(x0, LANE_SHADE_FULL)]),
			PackedColorArray([Color.WHITE, Color.WHITE, shade, shade]))
	ci.draw_rect(Rect2(x0, LANE_SHADE_FULL, x1 - x0, World.VIEW_H + 12.0 - LANE_SHADE_FULL), shade)


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


## Each row in groves of one to three trees standing close, with long stretches of open plain between, so the rows
## read as clumps and gaps; never the same tree twice side by side; each its own size, build and shade.
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
		if u < float(row[6]):
			continue
		# (a lone tree, or two or three; the big near ones mostly alone)
		var count := 1 if (row_index == 1 or u < 0.68) else (2 + int(_hash(gseed + 1) * 1.99))
		var cx := g * grove_gap + _hash(gseed + 2) * grove_gap * 0.7 - offset
		var spread := float(row[1]) * (0.3 + _hash(gseed + 8) * 0.2)  # (units between two trees of the grove)
		var prev := -1
		for j in count:
			var seed := gseed * 7 + j * 31
			var n := _tall.size() if row_index == 1 else _trees.size()
			var t := int(_hash(seed + 1) * n) % n
			if t == prev:
				t = (t + 1 + j) % n
			prev = t
			if row_index == 1:
				t = _tall[t]
			var tex := _trees[t]
			var height: float = row[2] * ((0.94 + _hash(seed + 2) * 0.12) if row_index == 1 else (0.8 + _hash(seed + 2) * 0.4))
			if tex.get_height() < tex.get_width() * 0.75:  # (a low wide crown: not as tall as the others)
				height *= 0.82
			var k := height / tex.get_height()
			var x := cx + (j - (count - 1) * 0.5) * spread * (0.8 + _hash(seed + 3) * 0.4)
			var build := 0.94 + _hash(seed + 21) * 0.12  # (painted trees: a little wider or taller, no more)
			var v := 0.92 + _hash(seed + 15) * 0.12
			var warm := (_hash(seed + 16) - 0.5) * 0.06
			_draw_tree(ci, row_index, tex, _tree_anchor[t], Vector2(x, row[3]), Vector2(k / build, k * build), false, 0.0, v, warm)


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


## Pollen and dust floating in the light, drifting up and to the right, twinkling.
func _draw_motes(ci: CanvasItem) -> void:
	var tex: Texture2D = _tex[&"mote"]
	var x0 := _x0()
	var w := _x1() - x0
	for i in 18:
		var sx := _hash(i * 13 + 1)
		var sy := _hash(i * 17 + 5)
		var speed := 6.0 + _hash(i * 7 + 3) * 10.0
		var depth := 0.3 + _hash(i * 19 + 2) * 0.5
		var x := x0 + fposmod(sx * w * 1.3 - scroll * depth * 0.5 + _clock * speed * 0.6 + sin(_clock * 0.5 + i) * 14.0, w)
		var y := 400.0 + fposmod(sy * 200.0 - _clock * speed, 200.0)  # (over the plain and the grass only: on the deep blue sky they were stars)
		var twinkle := 0.5 + 0.5 * sin(_clock * (1.2 + sx * 2.0) + i * 1.7)
		var r := (3.0 + 5.0 * _hash(i * 23 + 9)) * (0.7 + depth)
		var a := (0.08 + 0.3 * twinkle) * smoothstep(400.0, 450.0, y) * (1.0 - smoothstep(560.0, 600.0, y))
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

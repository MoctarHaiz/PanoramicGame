class_name TerrainView
extends Node2D
## The level's ground, painted (tools/art/terrain.py), drawn once in level units into chunks of
## 16 columns so the renderer batches each layer and skips what is off screen:
##   soil   every solid cell: terrain_shape.png for its outline and edge light, the paint from
##          soil.png / rock.png in level space (terrain.gdshader): no seams, no tiling grid
##   edges  sandstone chunks jutting from every wall's open sides below its top two cells: the
##          outline breaks into ledges and blocks, bigger towards the foot (poles taper upwards)
##   under  lumps of earth and roots hanging under cells open below (floating ledges): their
##          thickness varies along the ledge
##   caps   the grass along every walkable top (grass_cap.png), rounded ends wrapping the corners
##   roots  roots reaching into the soil under the grass
##   tufts  clumps of grass and wild flowers standing on some tops, swaying (sway.gdshader)
##   drape  grass hanging over each open side of a top: a tufted lip leaning out past the edge,
##          drooping down the face (over banks it hangs over the water)
##   foot   soft shade where a wall rises from a top: a short occlusion on the sun's side, a longer
##          cast shadow on the far side (the sun is upper left)
##   front  short blades in front of the runners' feet (WorldView puts it above the actors)
## Only how the ground looks: what is solid comes from the 2017 map, as for the rules.

const CHUNK := 16  ## columns per canvas item
const T := Level.TILE
const PX := 2.0  ## texture pixels per level unit
const SHAPE_STRIDE := 72.0  ## terrain_shape.png: 64 px cells with a 4 px border
const STRIP := 2048.0  ## px width of grass_cap.png and roots.png (the other strips: 1024)
const CAP_ABOVE := 18.0  ## grass_cap.png: blades above the surface, then the band
const CAP_H := 52.0
const END_OUT := 12.0  ## grass_ends.png: two pieces; each reaches 12 units past the open side,
const END_FADE := 10.0  ## covers its cell, and fades over 10 units of the next cell
const END_W := END_OUT + T + END_FADE
const END_H := 48.0
const ROOTS_H := 34.0
const UNDER_TOP := 6.0  ## underside.png: the cell's bottom edge 6 units below the strip's top
const UNDER_H := 44.0
const TUFT := Vector2(64, 48)  ## tufts.png: one row of 8
const FRONT_H := 24.0  ## front_grass.png: blades rise from 14 units under the surface
const FRONT_BASE := 18.0
const FOOT_SHADE := Color(0.18, 0.06, 0.14, 0.62)  ## at the foot of a wall
const EDGE := Vector2(22, 64)  ## rock_edges.png: 4 pieces (2 for a left side, 2 for a right one), tiling down
const EDGE_FACE := 6.0  ## units from a piece's inner side to the wall's face
const DRAPE := Vector2(30, 50)  ## grass_drape.png: two pieces (left side, right side), each this size
const DRAPE_IN := 8.0  ## units of a drape over its own cell (the rest hangs past the open side)
const DRAPE_TOP := 12.0  ## units of a drape above the grass surface
const DIR := "res://assets/art/world/"

var level: Level
var front: Node2D  ## blades in front of the runners: added by WorldView above them

var _layers := {}  # name -> Node2D holding that layer's chunks
var _solid := PackedByteArray()  # cached solid cells, columns first_col - 1 .. end_col, rows -1 .. ROWS
var _c0 := 0
var _cols := 0


class Batch extends Node2D:
	## Static rectangles of one texture, drawn once (Godot keeps the commands until a redraw).
	var texture: Texture2D
	var items := []  # [dest Rect2, src Rect2, Color]

	func _draw() -> void:
		for it: Array in items:
			draw_texture_rect_region(texture, it[0], it[1], it[2])


func build(lvl: Level, first_col: int, end_col: int) -> void:
	level = lvl
	_c0 = first_col - 1
	_cols = end_col - first_col + 2
	_solid.resize(_cols * (Level.ROWS + 2))
	for i in _cols:
		for r in range(-1, Level.ROWS + 1):
			_solid[(r + 1) * _cols + i] = 1 if _solid_at(_c0 + i, r) else 0
	var soil := ShaderMaterial.new()
	soil.shader = preload("res://src/game/terrain.gdshader")
	soil.set_shader_parameter(&"soil_tex", load(DIR + "soil.png"))
	soil.set_shader_parameter(&"rock_tex", load(DIR + "rock.png"))
	var sway := ShaderMaterial.new()
	sway.shader = preload("res://src/game/sway.gdshader")
	for name: StringName in [&"soil", &"edges", &"under", &"roots", &"caps", &"ends", &"tufts", &"drape", &"foot"]:
		var layer := Node2D.new()
		layer.name = name
		add_child(layer)
		_layers[name] = layer
	_layers[&"soil"].material = soil
	_layers[&"soil"].texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # data atlas: no mipmaps
	_layers[&"tufts"].material = sway
	front = Node2D.new()
	front.name = &"FrontGrass"
	_layers[&"front"] = front

	soil.set_shader_parameter(&"depth_tex", _depth_texture(first_col, end_col))
	soil.set_shader_parameter(&"first_col", first_col)
	var textures := {
		&"soil": load(DIR + "terrain_shape.png"), &"under": load(DIR + "underside.png"),
		&"roots": load(DIR + "roots.png"), &"caps": load(DIR + "grass_cap.png"),
		&"ends": load(DIR + "grass_ends.png"), &"tufts": load(DIR + "tufts.png"),
		&"front": load(DIR + "front_grass.png"), &"foot": soft_disc(),
		&"drape": load(DIR + "grass_drape.png"), &"edges": load(DIR + "rock_edges.png"),
	}
	var c0 := first_col
	while c0 < end_col:
		var c1 := mini(c0 + CHUNK, end_col)
		var batches := {}
		for name: StringName in textures:
			var b := Batch.new()
			b.texture = textures[name]
			b.use_parent_material = true  # the soil shader, the sway
			batches[name] = b
		for c in range(c0, c1):
			for r in Level.ROWS:
				_cell(c, r, batches)
		for name: StringName in batches:
			var b: Batch = batches[name]
			if b.items.is_empty():
				b.free()
			else:
				_layers[name].add_child(b)
		c0 = c1


func _cell(c: int, r: int, b: Dictionary) -> void:
	if not solid(c, r):
		return
	var open_n := not solid(c, r - 1)
	var open_e := not solid(c + 1, r)
	var open_s := r < Level.ROWS - 1 and not solid(c, r + 1)
	var open_w := not solid(c - 1, r)
	var mask := (1 if open_n else 0) | (2 if open_e else 0) | (4 if open_s else 0) | (8 if open_w else 0)
	if open_s and not open_w and not open_e:  # a ledge: its soil runs on into the earth hanging under it
		mask &= ~4
	var x := c * T
	var y := r * T
	var variant := _hash(c, r, 4)
	b[&"soil"].items.append([Rect2(x, y, T, T),
			Rect2(mask * SHAPE_STRIDE + 4.0, variant * SHAPE_STRIDE + 4.0, 64, 64), Color.WHITE])
	# rocks jutting from the open sides of a wall, below its top two cells
	var above := 0
	while above < 12 and solid(c, r - above - 1):
		above += 1
	if above >= 2 and not open_s:
		var k := 1.0 + minf(above - 2, 10) * 0.05  # bigger towards the foot
		var src_y := float(_hash(c, r + 11, 2)) * T * PX  # cell by cell from either half: no repeat up a pole
		if open_w:
			var v := _hash(c, r + 3, 2)
			b[&"edges"].items.append([Rect2(x + EDGE_FACE * k - EDGE.x * k, y, EDGE.x * k, T),
					Rect2(v * EDGE.x * PX, src_y, EDGE.x * PX, T * PX), Color.WHITE])
		if open_e:
			var v := 2 + _hash(c, r + 5, 2)
			b[&"edges"].items.append([Rect2(x + T - EDGE_FACE * k, y, EDGE.x * k, T),
					Rect2(v * EDGE.x * PX, src_y, EDGE.x * PX, T * PX), Color.WHITE])
	if open_s and not open_w and not open_e:
		b[&"under"].items.append([Rect2(x, y + T - UNDER_TOP, T, UNDER_H),
				Rect2(fposmod(x * PX, 1024.0), 0, T * PX, UNDER_H * PX), Color.WHITE])
	if not open_n or _kind(c, r) != Level.Kind.TOP:
		return
	# the grass cap: a strip that runs on in level x; a cell with an open side gets a rounded end
	# instead, which wraps the corner and fades into the next cell's strip
	if not open_w and not open_e:
		b[&"caps"].items.append([Rect2(x, y - CAP_ABOVE, T, CAP_H),
				Rect2(fposmod(x * PX, STRIP), 0, T * PX, CAP_H * PX), Color.WHITE])
	if open_w:
		b[&"ends"].items.append([Rect2(x - END_OUT, y - CAP_ABOVE, END_W, END_H),
				Rect2(0, 0, END_W * PX, END_H * PX), Color.WHITE])
	if open_e:
		b[&"ends"].items.append([Rect2(x - END_FADE, y - CAP_ABOVE, END_W, END_H),
				Rect2(END_W * PX, 0, END_W * PX, END_H * PX), Color.WHITE])
	if not open_w and not open_e:
		b[&"roots"].items.append([Rect2(x, y, T, ROOTS_H),
				Rect2(fposmod(x * PX, STRIP), 0, T * PX, ROOTS_H * PX), Color.WHITE])
	# the tufted lip over each open side
	if open_w:
		b[&"drape"].items.append([Rect2(x - (DRAPE.x - DRAPE_IN), y - DRAPE_TOP, DRAPE.x, DRAPE.y),
				Rect2(0, 0, DRAPE.x * PX, DRAPE.y * PX), Color.WHITE])
	if open_e:
		b[&"drape"].items.append([Rect2(x + T - DRAPE_IN, y - DRAPE_TOP, DRAPE.x, DRAPE.y),
				Rect2(DRAPE.x * PX, 0, DRAPE.x * PX, DRAPE.y * PX), Color.WHITE])
	# a wall rising from this top: shade at its foot (the disc's centre on the wall's face)
	var disc := Rect2(0, 0, 64, 64)
	if solid(c + 1, r - 1):  # the wall's lit face, on this cell's right: a short occlusion
		b[&"foot"].items.append([Rect2(x + T - 34.0, y - 26.0, 52.0, 52.0), disc, FOOT_SHADE])
	if solid(c - 1, r - 1):  # its shaded face, on the left: the shadow falls this way
		b[&"foot"].items.append([Rect2(x - 46.0, y - 30.0, 132.0, 60.0), disc, FOOT_SHADE])
	b[&"front"].items.append([Rect2(x, y - FRONT_BASE + 4.0, T, FRONT_H),
			Rect2(fposmod(x * PX, 1024.0), 0, T * PX, FRONT_H * PX), Color.WHITE])
	# some tops get a clump of grass or flowers (never on the edge cells)
	if not open_w and not open_e and _hash(c, r + 7, 100) < 30:
		var v := _hash(c + 3, r, 8)
		var dx := float(_hash(c, r + 1, 17)) - 8.0
		b[&"tufts"].items.append([Rect2(x + T / 2 - TUFT.x / 2 + dx, y - TUFT.y + 6.0, TUFT.x, TUFT.y),
				Rect2(v * TUFT.x * PX, 0, TUFT.x * PX, TUFT.y * PX), Color.WHITE])


## A soft round shade, opaque in the middle and fading out to its edge (64 px).
static func soft_disc() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## Per cell: R how many solid cells stand above it, G how many solid cells lie between it and the
## open air on its left, B the same on its right (each up to 15). The soil shader darkens and turns
## to rock with depth, and lights each wall from the sun's side (G) and shades its far side (B),
## continuously from cell to cell.
func _depth_texture(first_col: int, end_col: int) -> ImageTexture:
	var img := Image.create_empty(end_col - first_col, Level.ROWS, false, Image.FORMAT_RGB8)
	for c in range(first_col, end_col):
		for r in Level.ROWS:
			var depth := 0
			while depth < 15 and solid(c, r - depth - 1):
				depth += 1
			var left := 0
			while left < 15 and solid(c - left - 1, r):
				left += 1
			var right := 0
			while right < 15 and solid(c + right + 1, r):
				right += 1
			img.set_pixel(c - first_col, r, Color8(depth, left, right))
	return ImageTexture.create_from_image(img)


## Grass tops and walls are solid; past either end of the map the edge column repeats, and the
## bottom row goes on under the screen.
func solid(c: int, r: int) -> bool:
	var i := c - _c0
	if i >= 0 and i < _cols and r >= -1 and r <= Level.ROWS:
		return _solid[(r + 1) * _cols + i] == 1
	return _solid_at(c, r)


func _solid_at(c: int, r: int) -> bool:
	if r >= Level.ROWS:
		return _solid_at(c, Level.ROWS - 1)
	var k := _kind(c, r)
	return k == Level.Kind.TOP or k == Level.Kind.SIDE


func _kind(c: int, r: int) -> int:
	if r < 0:
		return Level.Kind.NONE
	return Level.kind_of(level.id_at(clampi(c, 0, Level.COLS - 1), r))


static func _hash(a: int, b: int, n: int) -> int:
	var h := (a * 73856093) ^ (b * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	return posmod(h ^ (h >> 16), n)

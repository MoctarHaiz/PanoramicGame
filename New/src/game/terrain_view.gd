class_name TerrainView
extends Node2D
## The level's ground, painted (tools/art/terrain.py), drawn once in level units into chunks of
## 16 columns so the renderer batches each layer and skips what is off screen:
##   soil   every solid cell: terrain_shape.png for its outline and edge light, the paint from
##          flat cel colours in level space (terrain.gdshader; round 5: blocks of rock, ink, no texture)
##   spires a one-cell-wide wall (the poles in the river) is a sandstone spire instead (spires.png:
##          painted like the buttes on the horizon, a cap rock, beds of stone, a flared foot),
##          its grass cap on top
##   (New: the sandstone chunks that jutted from walls are gone: they read as a zipper;
##          terrain.gdshader erodes a wall's sides instead. The banks of the pools slope into the
##          water in water.gdshader.)
##   mass   (round 2) the earth and rock a floating ledge carries under it, deepest under its middle
##   under  (round 4: no longer drawn: the masses make a ledge's underside)
##   caps   the grass along every walkable top (grass_cap.png), rounded ends wrapping the corners
##   roots  roots reaching into the soil under the grass
##   tufts  clumps of grass and wild flowers standing on some tops, swaying (sway.gdshader)
##   drape  grass hanging over each open side of a top: a tufted lip leaning out past the edge,
##          drooping down the face (over banks it hangs over the water)
##   foot   soft shade where a wall rises from a top: a short occlusion on the sun's side, a longer
##          one on the far side (the sun is upper left)
##   cast   (round 2) each wall's long shadow along the ground away from the sun
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
const CAST_SHADE := Color(0.16, 0.1, 0.2, 0.68)  ## a wall's long shadow on the ground (soft-started: no seam)
const CAST_K := 0.75  ## its length per unit of the wall's height (a low sun)
const DRAPE := Vector2(30, 50)  ## grass_drape.png: two pieces (left side, right side), each this size
const DRAPE_IN := 8.0  ## units of a drape over its own cell (the rest hangs past the open side)
const DRAPE_TOP := 12.0  ## units of a drape above the grass surface
const SPIRE := Vector2(96, 560)  ## spires.png: three spires side by side, each this size (round 2: taller, no stretch)
const MASS := Vector2(160, 120)  ## hanging.png: masses of earth hanging under a ledge, each this size
const MASS_VARIANTS := 4
const MASS_INSET := 44.0  ## units the masses stay in from a ledge's ends (its taper cuts up to ~34)
const DIR := "res://assets/art/world/"

var level: Level
var front: Node2D  ## blades in front of the runners: added by WorldView above them

var _layers := {}  # name -> Node2D holding that layer's chunks
var _textures := {}  # layer name -> its texture
var _built := {}  # first column of each chunk built so far -> true
var _first_col := 0
var _end_col := 0
var _poles := PackedInt32Array()  # per column from first_col - 1: its stack (_pole_column()), -1: none
var _solid := PackedByteArray()  # cached solid cells, columns first_col - 1 .. end_col, rows -1 .. ROWS
var _feet := PackedByteArray()  # cells at the ground line under a wall (_wall_foot()), rows 0 .. ROWS - 1
var _c0 := 0
var _cols := 0


class Batch extends Node2D:
	## Static rectangles of one texture, drawn once (Godot keeps the commands until a redraw).
	var texture: Texture2D
	var items := []  # [dest Rect2, src Rect2, Color]

	func _draw() -> void:
		for it: Array in items:
			draw_texture_rect_region(texture, it[0], it[1], it[2])


func _init() -> void:
	front = Node2D.new()  # (made here: WorldView places it before the ground is built)
	front.name = &"FrontGrass"
	var front_cast := Node2D.new()  # the walls' shadows over the blades too (above every chunk's)
	front_cast.z_index = 1
	front.add_child(front_cast)


## Whether build() has run (WorldView builds the ground a frame after the rest, under the wipe).
func is_built() -> bool:
	return level != null


func build(lvl: Level, first_col: int, end_col: int) -> void:
	level = lvl
	_c0 = first_col - 1
	_cols = end_col - first_col + 2
	_solid.resize(_cols * (Level.ROWS + 2))
	_solid.fill(0)
	var kinds := lvl.kinds  # (read straight from the map: ~10 ms faster than _solid_at() per cell)
	for i in _cols:
		var col := clampi(_c0 + i, 0, Level.COLS - 1)
		for r in range(0, Level.ROWS + 1):
			var k := kinds[mini(r, Level.ROWS - 1) * Level.COLS + col]
			_solid[(r + 1) * _cols + i] = 1 if k == Level.Kind.TOP or k == Level.Kind.SIDE else 0
	_first_col = first_col
	_end_col = end_col
	_poles.resize(end_col - first_col + 2)
	_poles.fill(-1)
	for c in range(first_col - 1, end_col + 1):
		if _poles[c - first_col + 1] != -1:  # the right half of a stack two cells wide
			continue
		var span := _pole_column(c)
		_poles[c - first_col + 1] = span
		if span >= 20000 and c + 1 <= end_col:
			_poles[c - first_col + 2] = span + 10000  # the same rows, drawn by its left column
	_find_feet()
	var soil := ShaderMaterial.new()
	soil.shader = preload("res://src/game/terrain.gdshader")
	var sway := ShaderMaterial.new()
	sway.shader = preload("res://src/game/sway.gdshader")
	for name: StringName in [&"mass", &"soil", &"spires", &"roots", &"caps", &"ends", &"tufts", &"drape", &"foot", &"cast"]:
		var layer := Node2D.new()
		layer.name = name
		add_child(layer)
		_layers[name] = layer
	_layers[&"soil"].material = soil
	_layers[&"soil"].texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # data atlas: no mipmaps
	_layers[&"tufts"].material = sway
	_layers[&"front"] = front
	_layers[&"front_cast"] = front.get_child(0)

	soil.set_shader_parameter(&"depth_tex", _depth_texture(first_col, end_col))
	soil.set_shader_parameter(&"first_col", first_col)
	var textures := {
		&"soil": load(DIR + "terrain_shape.png"),
		&"roots": load(DIR + "roots.png"), &"caps": load(DIR + "grass_cap.png"),
		&"ends": load(DIR + "grass_ends.png"), &"tufts": load(DIR + "tufts.png"),
		&"front": load(DIR + "front_grass.png"), &"foot": soft_disc(), &"cast": cast_shade(),
		&"drape": load(DIR + "grass_drape.png"),
		&"spires": load(DIR + "spires.png"), &"mass": load(DIR + "hanging.png"),
	}
	textures[&"front_cast"] = textures[&"cast"]
	_textures = textures


## Builds the chunks covering level x from x0 to x1 (units) that aren't built yet. New: the level
## used to be built whole when it opened (800 columns, ~75 ms in one frame); now WorldView asks
## for what is on screen and one more chunk ahead each frame.
func ensure(x0: float, x1: float) -> void:
	if not is_built():
		return
	var c := _first_col + maxi(floori((x0 / T - _first_col) / CHUNK), 0) * CHUNK
	while c < _end_col and c * T < x1:
		_build_chunk(c)
		c += CHUNK


## Builds the next chunk not built yet after level x (units), if any: a frame's share of the work.
func build_ahead(x: float) -> void:
	if not is_built():
		return
	var c := _first_col + maxi(floori((x / T - _first_col) / CHUNK), 0) * CHUNK
	while c < _end_col:
		if not _built.has(c):
			_build_chunk(c)
			return
		c += CHUNK


func _build_chunk(c0: int) -> void:
	if _built.has(c0):
		return
	_built[c0] = true
	var c1 := mini(c0 + CHUNK, _end_col)
	var batches := {}
	for name: StringName in _textures:
		var b := Batch.new()
		b.texture = _textures[name]
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
	var span := _poles[c - _first_col + 1] if c >= _first_col - 1 and c <= _end_col else -1
	var pole := _in_pole(c, r)
	if pole and open_n and (span / 10000 == 1 or span / 10000 == 2):  # the stack, from its top into the
		# ground it stands on (or under the screen); two cells wide: drawn wider from the left one
		var v := _hash(c, 13, 3)
		var end := span % 100
		var w := float(span / 10000)
		var h := (end - r) * T + (40.0 if end >= Level.ROWS else 22.0)
		var width := SPIRE.x * (1.0 if w == 1.0 else 1.7) * (0.86 + 0.34 * _hash(c, 21, 100) / 100.0)  # (round 6: each its own width)
		var rect := Rect2(x + T * w / 2 - width / 2, y - 6.0, width, h + 4.0)
		if _hash(c, 17, 2) == 0:  # mirrored now and then (a negative width flips in place): no twins
			rect.size.x = -rect.size.x
		b[&"spires"].items.append([rect, Rect2(v * SPIRE.x * PX, 0, SPIRE.x * PX, minf(h + 4.0, SPIRE.y) * PX), Color.WHITE])
	if not pole:
		b[&"soil"].items.append([Rect2(x, y, T, T),
				Rect2(mask * SHAPE_STRIDE + 4.0, variant * SHAPE_STRIDE + 4.0, 64, 64), Color.WHITE])
	# (round 4: no more strip of earth under a ledge's cells: it stopped square before the ledge's
	# rounded ends; the masses below and the ledge's own shade make its underside)
	if open_s and not pole and not (solid(c - 1, r) and not solid(c - 1, r + 1)):
		_hang_masses(c, r, b[&"mass"], b[&"foot"])
	if not open_n and _wall_foot(c, r):  # (round 2) the ground's grass runs on across a wall's foot
		b[&"caps"].items.append([Rect2(x, y - CAP_ABOVE, T, CAP_H),
				Rect2(fposmod(x * PX, STRIP), 0, T * PX, CAP_H * PX), Color.WHITE])
		b[&"front"].items.append([Rect2(x, y - FRONT_BASE + 4.0, T, FRONT_H),
				Rect2(fposmod(x * PX, 1024.0), 0, T * PX, FRONT_H * PX), Color.WHITE])
	if not open_n or _kind(c, r) != Level.Kind.TOP:
		return
	# the grass cap: a strip that runs on in level x; a cell with an open side gets a rounded end
	# instead, which wraps the corner and fades into the next cell's strip
	if not open_w and not open_e:
		b[&"caps"].items.append([Rect2(x, y - CAP_ABOVE, T, CAP_H),
				Rect2(_strip_x(c, x), 0, T * PX, CAP_H * PX), _grass_tone(c)])
	if open_w:
		b[&"ends"].items.append([Rect2(x - END_OUT, y - CAP_ABOVE, END_W, END_H),
				Rect2(0, 0, END_W * PX, END_H * PX), Color.WHITE])
	if open_e:
		b[&"ends"].items.append([Rect2(x - END_FADE, y - CAP_ABOVE, END_W, END_H),
				Rect2(END_W * PX, 0, END_W * PX, END_H * PX), Color.WHITE])
	if not open_w and not open_e:
		b[&"roots"].items.append([Rect2(x, y, T, ROOTS_H),
				Rect2(_strip_x(c, x), 0, T * PX, ROOTS_H * PX), Color.WHITE])
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
		# round 2: the wall's long shadow along the ground away from the low sun, as long as the
		# wall is tall (CAST_K), on this run of grass only (not over a pool)
		var tall := 0
		while tall < 16 and solid(c - 1, r - 1 - tall):
			tall += 1
		var run := 0
		while run < 12 and solid(c + run, r) and not solid(c + run, r - 1):
			run += 1
		var length := minf(tall * T * CAST_K, run * T + 6.0)
		if length > 40.0:
			b[&"cast"].items.append([Rect2(x - 4.0, y - 20.0, length, 46.0), Rect2(0, 0, 64, 32), CAST_SHADE])
			b[&"front_cast"].items.append([Rect2(x - 4.0, y - 8.0, length * 0.8, 18.0), Rect2(0, 0, 64, 32),
					Color(CAST_SHADE, CAST_SHADE.a * 0.45)])  # (trimmed: only the blades' lower half)
	b[&"front"].items.append([Rect2(x, y - FRONT_BASE + 4.0, T, FRONT_H),
			Rect2(fposmod(x * PX, 1024.0), 0, T * PX, FRONT_H * PX), Color.WHITE])
	# some tops get a clump of grass or flowers (never on the edge cells)
	if not open_w and not open_e and _hash(c, r + 7, 100) < 30:
		var v := _hash(c + 3, r, 8)
		var dx := float(_hash(c, r + 1, 17)) - 8.0
		b[&"tufts"].items.append([Rect2(x + T / 2 - TUFT.x / 2 + dx, y - TUFT.y + 6.0, TUFT.x, TUFT.y),
				Rect2(v * TUFT.x * PX, 0, TUFT.x * PX, TUFT.y * PX), Color.WHITE])


## Round 2: under a floating ledge (from its left end, cell c of row r), the earth and rock it
## carries (hanging.png): biggest under its middle, smaller to its ends, so it reads as a floating
## island; never down into what lies under it.
func _hang_masses(c: int, r: int, batch: Batch, batch_shadow: Batch) -> void:
	var n := 0
	while n < 60 and solid(c + n, r) and not solid(c + n, r + 1):
		n += 1
	var free := 0  # open cells under the ledge before anything (the pools' surface row included)
	while r + 1 + free < Level.ROWS - 2 and not solid(c + n / 2, r + 1 + free):
		free += 1
	var length := n * T
	var count := maxi(1, roundi(length / 130.0))
	var deepest := minf(MASS.y * clampf(0.45 + n / 10.0, 0.45, 1.0), free * T * 0.55)
	if deepest < 16.0:
		return
	var x0 := c * T + MASS_INSET  # round 4: the masses stay under the ledge, clear of its rounded ends
	var x1 := (c + n) * T - MASS_INSET  # (they ran ~2 cells past them, their flat tops showing)
	if x1 - x0 < 24.0:
		return
	# round 6: its shadow on the ground below, away from the low sun (further the higher it floats)
	var ground_r := r + 1 + free
	if ground_r < Level.ROWS and solid(c + n / 2, ground_r):
		var drop := free * T
		var sx := c * T + length * 0.5 + drop * 0.35
		var sw := length * 0.95 + 40.0
		batch_shadow.items.append([Rect2(sx - sw / 2, ground_r * T - 14.0, sw, 30.0), Rect2(0, 0, 64, 64),
				Color(0.14, 0.08, 0.18, clampf(0.55 - drop / 900.0, 0.2, 0.5))])
	for i in count:
		var u := (i + 0.5) / count
		var k := 0.5 + 0.5 * pow(sin(PI * u), 0.7) if count > 1 else 1.0
		var width := minf(length / count * 1.45 + 24.0, 260.0) * (0.85 + 0.15 * k)
		width = minf(width, x1 - x0)
		var cx := clampf(c * T + u * length, x0 + width / 2, x1 - width / 2)
		var v := _hash(c + i, r, MASS_VARIANTS)
		var rect := Rect2(cx - width / 2, (r + 1) * T - 10.0, width, deepest * k)
		if _hash(c + i, r + 3, 2) == 0:
			rect.size.x = -rect.size.x  # mirrored in place
		batch.items.append([rect, Rect2(v * MASS.x * PX, 0, MASS.x * PX, MASS.y * PX), Color.WHITE])


## A cell at the ground line under a wall: a run of cells with a wall over them (at most 16), with
## open ground (a top) at the same height next to it on a side. The ground runs on under the wall
## there (its grass and soil). Found once per row in build() (_feet).
func _wall_foot(c: int, r: int) -> bool:
	var i := c - _c0
	return i >= 0 and i < _cols and r >= 0 and r < Level.ROWS and _feet[r * _cols + i] == 1


func _find_feet() -> void:
	_feet.resize(_cols * Level.ROWS)
	_feet.fill(0)
	for r in range(1, Level.ROWS):
		var i := 0
		while i < _cols:
			var covered := _solid[(r + 1) * _cols + i] == 1 and _solid[r * _cols + i] == 1
			if not covered:
				i += 1
				continue
			var start := i
			while i < _cols and _solid[(r + 1) * _cols + i] == 1 and _solid[r * _cols + i] == 1:
				i += 1
			var top_left := start > 0 and _solid[(r + 1) * _cols + start - 1] == 1 and _solid[r * _cols + start - 1] == 0
			var top_right := i < _cols and _solid[(r + 1) * _cols + i] == 1 and _solid[r * _cols + i] == 0
			if (top_left or top_right) and i - start <= 16 and not _in_pole(_c0 + start, r - 1):
				for k in range(start, i):
					_feet[r * _cols + k] = 1


## Round 6: where a cell reads the grass strip: each run of 24 cells from its own place in it (the
## 1024-unit repeat showed), in px.
func _strip_x(c: int, x: float) -> float:
	return fposmod(x * PX + _hash(floori(c / 24.0), 77, 1000) * 1.7, STRIP)


## Round 6: the grass a little lighter or darker, warmer or greener, drifting slowly along the ground.
static func _grass_tone(c: int) -> Color:
	var i := floori(c / 7.0)
	var t := smoothstep(0.0, 1.0, c / 7.0 - i)
	var v := lerpf(_hash(i, 5, 100), _hash(i + 1, 5, 100), t) / 100.0
	return Color(0.94 + v * 0.12, 0.97 + v * 0.06, 0.92 + v * 0.06)


func _in_pole(c: int, r: int) -> bool:
	if c < _first_col - 1 or c > _end_col:
		return false
	var span := _poles[c - _first_col + 1]
	return span >= 0 and r >= (span % 10000) / 100 and r < span % 100


## A wall one or two cells wide and at least two tall at the top of a column (a pole in the river,
## a stack on the plain), starting at column c: width * 10000 + top row * 100 + the row under it
## (where it meets wider ground, or the bottom of the map); -1: none. The right column of a stack
## two wide gets 30000 + the same rows (drawn by the left one).
func _pole_column(c: int) -> int:
	if solid(c - 1, 0):
		return -1
	var top := 0
	while top < Level.ROWS and not solid(c, top):
		top += 1
	if top >= Level.ROWS or solid(c - 1, top):
		return -1
	var w := 2 if solid(c + 1, top) and not solid(c + 1, top - 1) else 1
	if solid(c + w, top):
		return -1
	var end := top
	while end < Level.ROWS and solid(c, end) and solid(c + w - 1, end) and not solid(c - 1, end) and not solid(c + w, end):
		end += 1
	return w * 10000 + top * 100 + end if end - top >= 2 else -1


## A shadow cast to the right (64 px): darkest on its left edge, fading out to the right, and soft
## above and below (it lies along the grass).
static func cast_shade() -> ImageTexture:
	var img := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	for x in 64:
		for y in 32:
			var across := pow(1.0 - x / 63.0, 1.3) * smoothstep(0.0, 10.0, float(x))  # (round 4: no hard edge at the wall)
			var band := 1.0 - pow(absf(y - 15.5) / 16.0, 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(across * band * 1.15, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


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
## open air on its left, B the same on its right, A how many cells of open wall lie below it
## before the foot (each up to 15), plus 128 when the cell is open below (a ledge). The soil shader darkens and turns
## to rock with depth, and lights each wall from the sun's side (G) and shades its far side (B),
## continuously from cell to cell.
func _depth_texture(first_col: int, end_col: int) -> ImageTexture:
	# New: running counts down each column and along each row (one pass each way) instead of
	# walking up to 15 cells from every cell: the same picture, ~10x faster (the level opens sooner)
	var n := end_col - first_col
	var rows := Level.ROWS
	var span := rows + 17  # rows -1 .. ROWS + 15 (the bottom row goes on under the screen)
	var s := PackedByteArray()  # solid, columns first_col - 1 .. end_col
	var soil := PackedByteArray()  # solid and not part of a stack (a stack is not soil over a cell)
	s.resize((n + 2) * span)
	soil.resize((n + 2) * span)
	for i in n + 2:  # (the solid cells cached by build(): the same columns, rows -1 .. ROWS)
		var pole := _poles[i]  # _in_pole(), inlined
		var pole_top := (pole % 10000) / 100 if pole >= 0 else 99
		var pole_end := pole % 100 if pole >= 0 else -1
		for j in span:
			var on := _solid[mini(j, rows + 1) * _cols + i]
			s[i * span + j] = on
			soil[i * span + j] = 0 if j - 1 >= pole_top and j - 1 < pole_end else on
	var px := PackedByteArray()
	px.resize(n * rows * 4)
	for i in n:
		var at := (i + 1) * span  # this column; row r is at + r + 1
		var run := 0  # R: solid cells above (rows r - 1, r - 2, ...), not counting stacks
		for r in rows:
			if r > 0 and _wall_foot(first_col + i, r):  # (round 2) the ground's soil runs on under a wall
				run = 0
			px[(r * n + i) * 4] = run
			run = mini(run + 1, 15) if soil[at + r + 1] == 1 else 0
		run = 0  # A: cells of open wall below (rows r + 1, r + 2, ...) before the foot, from under the screen up
		for r in range(span - 3, -1, -1):
			var wall := s[at + r + 2] == 1 and (s[at - span + r + 2] == 0 or s[at + span + r + 2] == 0)
			run = mini(run + 1, 15) if wall else 0
			if r < rows:
				var open_below := r < rows - 1 and s[at + r + 2] == 0
				px[(r * n + i) * 4 + 3] = run + (128 if open_below else 0)
	for r in rows:
		var run := 15 if s[r + 1] == 1 else 0  # (left of the map the edge column repeats)
		for i in n:  # G: solid cells to the left
			px[(r * n + i) * 4 + 1] = run
			run = mini(run + 1, 15) if s[(i + 1) * span + r + 1] == 1 else 0
		run = 15 if s[(n + 1) * span + r + 1] == 1 else 0
		for i in range(n - 1, -1, -1):  # B: and to the right
			px[(r * n + i) * 4 + 2] = run
			run = mini(run + 1, 15) if s[(i + 1) * span + r + 1] == 1 else 0
	return ImageTexture.create_from_image(Image.create_from_data(n, rows, false, Image.FORMAT_RGBA8, px))


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

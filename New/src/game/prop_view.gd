class_name PropView
extends Node2D
## Props standing on the ground (tools/art/props.py, tools/art/trees.py), behind the runners and
## under the grass blades of the ground (WorldView adds this before TerrainView):
##   - each 2017 decoration of the map becomes a new prop (DECOR), placed by its anchor cell;
##   - long grass runs get a few low rocks, shrubs and aloes, from a fixed hash of the column, set a
##     little into the grass and a shade darker, so they read as standing back from the path;
##   - reeds stand in the water against each bank and at the foot of each pole in a pool (a
##     shoreline, instead of water cut square against the soil).
## Drawing only: nothing here is solid.
## Round 3: built a chunk of columns at a time as the camera gets there (ensure(), build_ahead()), each
## chunk one canvas item drawing its pictures (it was 400 sprites made when the level opened); reeds
## are mirrored in the water under them.

const DIR := "res://assets/art/world/"
## 2017 tile id -> [picture, where its foot goes in the cell (in cells, from the top left),
## drawn height in units (0: the picture's own size)]. Only one id of a multi-tile object anchors it.
const DECOR := {
	17: [&"tree_acacia_3", Vector2(1, 1), 150.0],  # tree (ids 5, 6, 17, 18)
	41: [&"tree_acacia_1", Vector2(1, 1), 140.0],  # tree (ids 29, 30, 41, 42)
	8: [&"prop_stump", Vector2(0.5, 1), 0.0],  # trunk
	7: [&"prop_aloe", Vector2(0.5, 1), 64.0],  # mushrooms
	19: [&"prop_aloe", Vector2(0.5, 1), 56.0],
	9: [&"prop_rock_a", Vector2(1, 1), 0.0],  # boulder (ids 9, 10)
	31: [&"prop_reeds", Vector2(1, 1), 0.0],  # bushes (pairs 31-32, 33-34, 43-44, 45-46)
	33: [&"prop_reeds", Vector2(1, 1), 0.0],
	43: [&"prop_bush_a", Vector2(1, 1), 0.0],
	45: [&"prop_reeds", Vector2(1, 1), 0.0],
}
## Dressing for grass runs: picture, weight, height range (units; 0 = own size).
const DRESSING := [
	[&"prop_rock_b", 3.0, 0.0],
	[&"prop_bush_b", 2.5, 0.0],
	[&"prop_rock_a", 1.5, 0.0],
	[&"prop_bush_a", 1.5, 0.0],
	[&"prop_aloe", 1.5, 52.0],
]
const SINK := 5.0  ## dressing stands this far into the grass band
const HOME_COL := 765  ## the homestead has its own composition from here
const CHUNK := 16  ## columns per chunk (as TerrainView)
const REFLECT := Color(0.42, 0.58, 0.68, 0.42)  ## a reed's reflection in the pool (round 3)

var _tex := {}
var _tree_anchor := {}  # tree picture -> x of its trunk (tools/art/trees.py)
var _items := []  # the props of the chunk being built: [[texture, rect, colour], ...]
var _built := {}  # first column of each chunk built so far -> true
var _first_col := 0
var _end_col := 0
var _level: Level
var _solid: Callable
var _dressing_total := 0.0


class Chunk extends Node2D:
	## Pictures drawn once (Godot keeps the commands until a redraw).
	var items := []  # [texture, rect (a negative size mirrors), colour]

	func _draw() -> void:
		for it: Array in items:
			draw_texture_rect(it[0], it[1], false, it[2])


func build(level: Level, solid: Callable, first_col: int, end_col: int) -> void:
	_level = level
	_solid = solid
	_first_col = first_col
	_end_col = end_col
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "tree_info.json"))
	for name: String in info:
		_tree_anchor[StringName(name)] = float(info[name].anchor_x)
	for d: Array in DRESSING:
		_dressing_total += d[1]


## The props standing in columns c0 .. c1 - 1 (anchored there).
func _scan(c0: int, c1: int) -> void:
	for c in range(maxi(c0, 0), mini(c1, Level.COLS)):
		for r in Level.ROWS:
			var id := _level.id_at(c, r)
			if DECOR.has(id):
				var d: Array = DECOR[id]
				var foot: Vector2 = (Vector2(c, r) + d[1]) * Level.TILE
				_add(d[0], foot, d[2], _hash(c, r, 2) == 0, Color.WHITE)
	_bank_reeds(_level, c0, c1)
	for c in range(maxi(c0, _first_col + 2), mini(c1, mini(_end_col, HOME_COL))):
		for r in range(1, Level.ROWS):
			if not _dress_here(_level, _solid, c, r):
				continue
			var pick := float(_hash(c, r + 3, 1000)) / 1000.0 * _dressing_total
			for d: Array in DRESSING:
				pick -= d[1]
				if pick <= 0.0:
					var x := (c + 0.5) * Level.TILE + float(_hash(c, r + 5, 17)) - 8.0
					var shade := 0.82 + float(_hash(c, r + 9, 10)) * 0.01
					_add(d[0], Vector2(x, r * Level.TILE + SINK), d[2], _hash(c, r + 7, 2) == 0,
							Color(shade, shade * 0.97, shade * 0.98))
					break


## Reeds in the water against every bank and pole: where solid ground meets a pool at the surface
## row, one clump (most of the time) standing a little out in the water, its foot under the surface.
func _bank_reeds(level: Level, first_col: int, end_col: int) -> void:
	var r := Level.ROWS - 2  # the pools' surface row
	for c in range(maxi(first_col, 0), mini(end_col, Level.COLS)):
		var k := level.kind_at(c, r)
		if k != Level.Kind.TOP and k != Level.Kind.SIDE:
			continue
		for side: int in [-1, 1]:
			if level.kind_at(c + side, r) != Level.Kind.WATER or _hash(c, side + 5, 10) < 2:
				continue
			var x := (c + 0.5 + side * 0.5) * Level.TILE + side * (5.0 + _hash(c, side + 7, 6))
			var height := 40.0 + _hash(c, side + 9, 18)
			_add(&"prop_reeds", Vector2(x, r * Level.TILE + 16.0), height, side < 0, Color(0.92, 0.94, 0.9))
			# its reflection: upside down under the surface, in the water's colours
			_add(&"prop_reeds", Vector2(x, r * Level.TILE + 6.0), -height * 0.7, side < 0, REFLECT)


## A grass top in the middle of a run of at least 6, not under Red Bobs, about one in eight.
func _dress_here(level: Level, solid: Callable, c: int, r: int) -> bool:
	if not solid.call(c, r) or solid.call(c, r - 1) or level.kind_at(c, r) != Level.Kind.TOP:
		return false
	if _hash(c, r, 100) >= 13:
		return false
	for dc in range(-3, 4):
		if not solid.call(c + dc, r) or solid.call(c + dc, r - 1):
			return false
	for dr in range(1, 4):
		if level.kind_at(c, r - dr) == Level.Kind.BOB:
			return false
	return true


## A picture standing with its foot at `foot` (level units), `height` units tall (0: its own size; less
## than 0: upside down, hanging from `foot`: a reflection), kept for its chunk.
func _add(name: StringName, foot: Vector2, height: float, flip: bool, colour: Color) -> void:
	if not _tex.has(name):
		_tex[name] = load(DIR + String(name) + ".png")
	var tex: Texture2D = _tex[name]
	var k := 0.5 if height == 0.0 else absf(height) / tex.get_height()  # pictures are 2 px per unit
	var size := tex.get_size() * k
	var rect := Rect2(foot.x - _tree_anchor.get(name, tex.get_width() / 2.0) * k, foot.y - size.y, size.x, size.y)
	if flip and not _tree_anchor.has(name):  # a negative width mirrors the picture in place
		rect.size.x = -rect.size.x
	if height < 0.0:  # upside down under the foot (a negative height mirrors the picture in place)
		rect = Rect2(rect.position.x, foot.y, rect.size.x, -size.y)
	_items.append([tex, rect, colour])


## Draws the chunks of props between level x0 and x1 (units) not drawn yet (and one chunk either side:
## trees reach past their column).
func ensure(x0: float, x1: float) -> void:
	var c := _first_col + maxi(floori((x0 / Level.TILE - _first_col) / CHUNK) - 1, 0) * CHUNK
	while c < _end_col and c * Level.TILE < x1 + CHUNK * Level.TILE:
		_build_chunk(c)
		c += CHUNK


## Draws the next chunk not drawn yet after level x (units), if any: a frame's share of the work.
func build_ahead(x: float) -> void:
	var c := _first_col + floori((x / Level.TILE - _first_col) / CHUNK) * CHUNK
	while c < _end_col:
		if not _built.has(c):
			_build_chunk(c)
			return
		c += CHUNK


func _build_chunk(c0: int) -> void:
	if _built.has(c0):
		return
	_built[c0] = true
	_items = []
	_scan(c0, mini(c0 + CHUNK, _end_col))
	if _items.is_empty():
		return
	var chunk := Chunk.new()
	chunk.items = _items
	add_child(chunk)


static func _hash(a: int, b: int, n: int) -> int:
	var h := (a * 73856093) ^ (b * 83492791) ^ 0x27d4eb2d
	h = (h ^ (h >> 15)) * 2246822519
	return posmod(h ^ (h >> 13), n)

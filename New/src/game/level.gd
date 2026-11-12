@tool
class_name Level
extends RefCounted
## The map of the 2017 game: 800 columns by 20 rows of 32-unit tiles (Old/.../res/raw/level.csv,
## kept as assets/level/level.txt so Godot doesn't import it as translations). Tile ids index the
## 12-column tile set; what each id does comes from the old Tile.java.

const TILE := 32.0
const COLS := 800
const ROWS := 20
const WIDTH := COLS * TILE  # 25,600 units
const HEIGHT := ROWS * TILE  # 640 units
const PATH := "res://assets/level/level.txt"
const WATER_TOP := 4  ## old waterTop: the surface of a pool
const WATER_BODY := 16  ## old water under the surface (drawn only)

enum Kind {
	NONE,   ## empty (ids -1, 0 and 86+)
	TOP,    ## grass top: Panoramic and the bandits land on it (old type tileGrass1)
	SIDE,   ## wall: blocks the scrolling (old tileGrass2 and tileGrass3)
	WATER,  ## water surface: nothing holds you (old waterTop)
	BOB,    ## a Red Bob to collect (old bubble1 and bubble2)
	DECOR,  ## drawn only: water below the surface, trees, mushrooms, signs, crates, grass
}

var ids := PackedInt32Array()
var kinds := PackedByteArray()
var bobs_total := 0


static func load_default() -> Level:
	var level := Level.new()
	level.parse(FileAccess.get_file_as_string(PATH))
	return level


static func kind_of(id: int) -> Kind:
	if id <= 0 or id > 85:
		return Kind.NONE
	if id <= 3 or id in [22, 24, 28] or (id >= 37 and id <= 39) or (id >= 48 and id <= 59):
		return Kind.TOP
	if id in [13, 14, 15, 25, 26, 27] or (id >= 60 and id <= 83):
		return Kind.SIDE
	if id == 4:
		return Kind.WATER
	if id == 84 or id == 85:
		return Kind.BOB
	return Kind.DECOR


func parse(text: String) -> void:
	ids.resize(COLS * ROWS)
	ids.fill(-1)
	kinds.resize(COLS * ROWS)
	kinds.fill(Kind.NONE)
	var row := 0
	for line in text.split("\n", false):
		if line.begins_with("!") or row >= ROWS:
			continue
		var col := 0
		for cell in line.split(","):
			if cell.is_empty() or col >= COLS:
				continue
			var id := cell.to_int()
			ids[row * COLS + col] = id
			kinds[row * COLS + col] = kind_of(id)
			col += 1
		row += 1
	_flood_pits()
	bobs_total = kinds.count(Kind.BOB)


## New: in 2017 some pits were bare holes (under the stairs, between the pillars, the long stretch
## after them): the savanna painted behind them read as ground at the height of the real ground, so
## a deadly drop looked safe. Every pit is now a pool, like the others: the same holes to fall
## through, now plain to see (water holds nothing either).
func _flood_pits() -> void:
	for c in COLS:
		var surface := (ROWS - 2) * COLS + c
		var bottom := (ROWS - 1) * COLS + c
		if kinds[surface] != Kind.NONE or kinds[bottom] in [Kind.TOP, Kind.SIDE]:
			continue
		ids[surface] = WATER_TOP
		kinds[surface] = Kind.WATER
		if kinds[bottom] == Kind.NONE:
			ids[bottom] = WATER_BODY
			kinds[bottom] = kind_of(WATER_BODY)


func id_at(col: int, row: int) -> int:
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return -1
	return ids[row * COLS + col]


func kind_at(col: int, row: int) -> int:
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return Kind.NONE
	return kinds[row * COLS + col]


## A collected Red Bob disappears from the map.
func clear(col: int, row: int) -> void:
	ids[row * COLS + col] = -1
	kinds[row * COLS + col] = Kind.NONE


func copy() -> Level:
	var l := Level.new()
	l.ids = ids.duplicate()
	l.kinds = kinds.duplicate()
	l.bobs_total = bobs_total
	return l

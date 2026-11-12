@tool
extends Node2D
## The level editor: open level_editor.tscn in the Godot editor, paint on its Tiles layer with the
## TileMap editor (the 2017 tile set), save the scene (Ctrl/Cmd+S) and level.txt is written.
## level.txt stays the only source of truth: the game and the tests read it, never this scene. The
## layer is filled from the file when the scene opens and emptied while the scene is saved, so the
## .tscn holds no level of its own.
##
## A tile's id in level.txt is its place in the 12-column picture (id = row * 12 + column: 4 the
## water's surface, 84 and 85 the Red Bobs); -1 is an empty cell. Level.parse() floods the bare pits
## when the game loads; that is not in the file and never shown or written here.

const PATH := Level.PATH
const COLUMNS := 12  ## the tile set picture's columns
const IDS := 96  ## 12 x 8 tiles: ids 0 to 95 (0 and 86+ draw nothing in the game, but the file has them)
const GRASS_ROW := Level.ROWS - 2  ## the low ground's grass

## A level read whole from the file: only then is it ever written back (a failed read never
## saves an empty or half level over the file).
var _loaded := false

@export_tool_button("Reload from level.txt") var reload_button := reload
@export_tool_button("Save to level.txt") var save_button := save

var tiles: TileMapLayer:
	get:
		return $Tiles


func _ready() -> void:
	if Engine.is_editor_hint():
		reload()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		if save():
			tiles.clear()  # (not kept in the .tscn: the file is the level)
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		if tiles.get_used_cells().is_empty():
			reload()


## Fills the layer from level.txt.
func reload() -> void:
	var error := fill(FileAccess.get_file_as_string(PATH))
	if error:
		push_error("Level editor: %s not loaded (%s); nothing will be saved over it." % [PATH, error])
	else:
		print("Level editor: loaded %s." % PATH)
	queue_redraw()


## Writes level.txt from the layer. Returns false (and writes nothing) when it can't be done safely.
func save() -> bool:
	if not _loaded:
		push_error("Level editor: %s was not loaded, so it is not saved (press Reload from level.txt)." % PATH)
		return false
	var text := level_text()
	if text.is_empty():
		return false
	if text == FileAccess.get_file_as_string(PATH):
		return true
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Level editor: can't write %s (%s)." % [PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	file.close()
	print("Level editor: saved %s." % PATH)
	return true


## Puts the ids of a level.txt text in the layer. Returns what is wrong with the text ("" if
## nothing): it must be 20 lines of 800 ids the tile set has, or the layer is left as it was.
func fill(text: String) -> String:
	var lines := text.split("\n", false)
	if lines.size() != Level.ROWS:
		return "%d lines, not %d" % [lines.size(), Level.ROWS]
	var rows := []
	for line in lines:
		var cells := line.split(",")
		if cells.size() != Level.COLS:
			return "a line of %d ids, not %d" % [cells.size(), Level.COLS]
		for cell in cells:
			if not cell.is_valid_int() or cell.to_int() < -1 or cell.to_int() >= IDS:
				return "\"%s\" is not a tile id" % cell
		rows.append(cells)
	tiles.clear()
	for r in Level.ROWS:
		for c in Level.COLS:
			var id: int = rows[r][c].to_int()
			if id >= 0:
				@warning_ignore("integer_division")
				tiles.set_cell(Vector2i(c, r), 0, Vector2i(id % COLUMNS, id / COLUMNS))
	_loaded = true
	return ""


## The layer as level.txt: 20 lines of 800 comma-separated ids, each line ending in a newline.
## Cells painted outside the 800 x 20 grid are left out, with a warning. "" if the layer can't be
## written (empty, or a tile that isn't from the tile set).
func level_text() -> String:
	var used := tiles.get_used_cells()
	if used.is_empty():
		push_error("Level editor: the layer is empty; %s is not emptied." % PATH)
		return ""
	var outside := used.filter(func(p: Vector2i) -> bool: return p.x < 0 or p.y < 0 or p.x >= Level.COLS or p.y >= Level.ROWS)
	if outside:
		push_warning("Level editor: %d cells outside the 800 x 20 level are not saved (the first at %s)." % [outside.size(), outside[0]])
	var text := ""
	for r in Level.ROWS:
		var ids := PackedStringArray()
		for c in Level.COLS:
			var at := Vector2i(c, r)
			var atlas := tiles.get_cell_atlas_coords(at)
			if tiles.get_cell_source_id(at) == -1:
				ids.append("-1")
			elif tiles.get_cell_source_id(at) != 0 or atlas.x < 0 or atlas.x >= COLUMNS or atlas.y * COLUMNS + atlas.x >= IDS:
				push_error("Level editor: the tile at %s isn't from the level's tile set; nothing saved." % at)
				return ""
			else:
				ids.append(str(atlas.y * COLUMNS + atlas.x))
		text += ",".join(ids) + "\n"
	return text


## Guides, in the editor only (drawn over the tiles: the layer shows behind its parent): the level's
## bounds, the low ground's grass row, a line at every play screen (960 units), the last screen and
## the x where Panoramic is home, and where each bandit starts (World._init: it then drops to the
## ground ahead of it).
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var font := ThemeDB.fallback_font
	var guide := Color(1, 1, 1, 0.5)
	draw_rect(Rect2(0, 0, Level.WIDTH, Level.HEIGHT), guide, false, -1)
	draw_line(Vector2(0, GRASS_ROW * Level.TILE), Vector2(Level.WIDTH, GRASS_ROW * Level.TILE), Color(0.4, 1, 0.4, 0.6), -1)
	for i in ceili(Level.WIDTH / World.VIEW_W):
		var x := i * World.VIEW_W
		draw_line(Vector2(x, 0), Vector2(x, Level.HEIGHT), guide, -1)
		draw_string(font, Vector2(x + 4, 14), "screen %d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, guide)
	draw_rect(Rect2(World.SCROLL_END, 0, World.VIEW_W, Level.HEIGHT), Color(1, 0.8, 0.2, 0.12))
	var home := World.SCROLL_END + World.HOME_X
	draw_line(Vector2(home, 0), Vector2(home, Level.HEIGHT), Color(1, 0.8, 0.2, 0.8), -1)
	draw_string(font, Vector2(home + 4, 30), "home", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.8, 0.2))
	for i in range(1, World.BANDIT_COUNT + 1):  # (as World._init places them)
		var x := i * Level.WIDTH / World.BANDIT_COUNT
		if x < World.FIRST_BANDIT_X:
			continue
		var colour := Color(0.8, 0.4, 1, 0.8) if World.is_strong(i) else Color(1, 0.4, 0.4, 0.8)
		draw_rect(Rect2(Vector2(x, World.BANDIT_START_Y) - World.BANDIT_SIZE / 2, World.BANDIT_SIZE), colour, false, -1)
		draw_string(font, Vector2(x - World.BANDIT_SIZE.x / 2, World.BANDIT_START_Y - World.BANDIT_SIZE.y / 2 - 4), str(i),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, colour)

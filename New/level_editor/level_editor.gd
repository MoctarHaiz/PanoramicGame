@tool
extends Node2D
## The level editor: open level_editor.tscn in the Godot editor, paint on its Tiles layer with the
## TileMap editor, save the scene (Ctrl/Cmd+S) and level.txt is written.
## level.txt stays the only source of truth: the game and the tests read it, never this scene. The
## layer is filled from the file when the scene opens and emptied while the scene is saved, so the
## .tscn holds no level of its own.
##
## Under the layer, the level as the game draws it today (the owner, 2026-11-12: "I want the level
## editor with the current version of the world"): the game's own views (SavannaView, TerrainView,
## the pools of WorldView, PropView, BobView, VineView, HomeView), built from the layer's ids through
## Level.parse() (so the pits it floods show as pools), rebuilt a moment after each change. The
## layer itself is drawn faint over it (`tiles_opacity`): it only shows where the cells are.
##
## Two tile sources: "2017 tiles" (source 0), whose place in the 12-column picture is the id in
## level.txt (id = row * 12 + column: 4 the water's surface, 84 and 85 the Red Bobs; -1 an empty
## cell), and "Current world" (source 1), brushes in the game's look (tools/art/level_brushes.py):
## each writes its thing's id (BRUSHES). Cells read from the file keep their exact ids, so an
## untouched level is written back byte for byte. Run as a scene (F6), the same picture with a
## camera the arrow keys move (Shift: faster).

const PATH := Level.PATH
const COLUMNS := 12  ## the 2017 picture's columns
const IDS := 96  ## 12 x 8 tiles: ids 0 to 95 (0 and 86+ draw nothing in the game, but the file has them)
const GRASS_ROW := Level.ROWS - 2  ## the low ground's grass
## "Current world" brushes, in the order of brushes.png: the id each writes (the one the level uses
## most for that thing; for the props, the id PropView draws it from).
const BRUSHES := [
	[48, "grass top"],
	[60, "wall / soil"],
	[4, "water surface"],
	[16, "deep water"],
	[84, "Red Bob"],
	[41, "tree (an acacia)"],
	[8, "stump"],
	[7, "aloe"],
	[9, "rock"],
	[31, "reeds"],
	[43, "bush"],
]
const REBUILD_DELAY := 300  ## ms after the last change before the preview is rebuilt
const LOOK_EVERY := 150  ## ms between two looks at the layer for changes
const PAN_SPEED := 1200.0  ## units a second the camera moves when run (F6)

## The level as the game draws it, under the tiles (off: just the tiles, if it is slow in the editor).
@export var preview := true:
	set(on):
		preview = on
		if is_node_ready():
			_drop_preview()
			_rebuild_at = 0
## How strongly the tiles are drawn over the preview (0 hides them).
@export_range(0.0, 1.0, 0.05) var tiles_opacity := 0.25:
	set(k):
		tiles_opacity = k
		if is_node_ready():
			tiles.modulate.a = k

@export_tool_button("Reload from level.txt") var reload_button := reload
@export_tool_button("Save to level.txt") var save_button := save

## A level read whole from the file: only then is it ever written back (a failed read never
## saves an empty or half level over the file).
var _loaded := false
var _view: WorldView  # the preview (not owned: never saved in the scene)
var _view_text := ""  # the level it was built from
var _rebuild_at := -1  # msec time to rebuild it at (-1: none due)
var _seen_cells := PackedByteArray()  # the layer's cells at the last look (TileMapLayer's `changed`
var _look_at := 0  # signal doesn't come for painted cells: the layer is looked at instead)
var _camera: Camera2D  # run as a scene only

var tiles: TileMapLayer:
	get:
		return $Tiles


func _ready() -> void:
	tiles.modulate.a = tiles_opacity
	if not Engine.is_editor_hint():
		_camera = Camera2D.new()
		_camera.position = Vector2(World.VIEW_W, World.VIEW_H) / 2.0
		add_child(_camera)
		_camera.make_current()
	reload()  # (the preview follows: built from the layer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		if save():
			tiles.clear()  # (not kept in the .tscn: the file is the level)
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		if tiles.get_used_cells().is_empty():
			reload()


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now >= _look_at:  # a change: the preview is rebuilt once it has stopped changing for a moment
		_look_at = now + LOOK_EVERY
		var cells := tiles.tile_map_data
		if cells != _seen_cells:
			_seen_cells = cells
			_rebuild_at = now + REBUILD_DELAY
	if _rebuild_at >= 0 and now >= _rebuild_at:
		_rebuild_at = -1
		_rebuild()
	if _camera:
		var move := Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
				float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
		_camera.position += move * PAN_SPEED * delta * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)


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


## Puts the ids of a level.txt text in the layer (as 2017 tiles). Returns what is wrong with the text
## ("" if nothing): it must be 20 lines of 800 ids the tile set has, or the layer is left as it was.
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
	if tiles.get_used_cells().is_empty():
		push_error("Level editor: the layer is empty; %s is not emptied." % PATH)
		return ""
	var ids := _layer_ids(true)
	return _text(ids) if not ids.is_empty() else ""


## The layer's ids, row after row (-1 where nothing is painted); empty if a cell holds a tile from
## neither source. `warn`: say so, and warn about cells outside the grid.
func _layer_ids(warn: bool) -> PackedInt32Array:
	var ids := PackedInt32Array()
	ids.resize(Level.COLS * Level.ROWS)
	ids.fill(-1)
	var outside := []
	for at in tiles.get_used_cells():
		if at.x < 0 or at.y < 0 or at.x >= Level.COLS or at.y >= Level.ROWS:
			outside.append(at)
			continue
		var atlas := tiles.get_cell_atlas_coords(at)
		var source := tiles.get_cell_source_id(at)
		var id := -2
		if source == 0 and atlas.x >= 0 and atlas.x < COLUMNS and atlas.y >= 0 and atlas.y * COLUMNS + atlas.x < IDS:
			id = atlas.y * COLUMNS + atlas.x
		elif source == 1 and atlas.y == 0 and atlas.x >= 0 and atlas.x < BRUSHES.size():
			id = BRUSHES[atlas.x][0]
		if id == -2:
			if warn:
				push_error("Level editor: the tile at %s isn't from the level's tile set; nothing saved." % at)
			return PackedInt32Array()
		ids[at.y * Level.COLS + at.x] = id
	if warn and outside:
		push_warning("Level editor: %d cells outside the 800 x 20 level are not saved (the first at %s)." % [outside.size(), outside[0]])
	return ids


static func _text(ids: PackedInt32Array) -> String:
	var text := ""
	for r in Level.ROWS:
		var row := PackedStringArray()
		for c in Level.COLS:
			row.append(str(ids[r * Level.COLS + c]))
		text += ",".join(row) + "\n"
	return text


func _drop_preview() -> void:
	if _view:
		remove_child(_view)
		_view.queue_free()
		_view = null
		_view_text = ""


## Builds the preview from the layer: WorldView's own pieces, assembled as WorldView.setup() does
## for the level (its backdrop, home, pools, props, ground, banks, Red Bobs and vine; no actors, no
## light grade), with the backdrop at scroll 0 stretched over the whole level and drawn once.
func _rebuild() -> void:
	if not preview or tiles.get_used_cells().is_empty():  # (emptied while the scene is saved: kept)
		return
	var ids := _layer_ids(false)
	if ids.is_empty():
		return
	var text := _text(ids)
	if _view and text == _view_text:
		return
	_drop_preview()
	var t0 := Time.get_ticks_msec()
	var level := Level.new()
	level.parse(text)
	var view := WorldView.new()
	view.name = &"Preview"
	view.show_behind_parent = true  # (with the tiles, under the guides)
	view.world = World.new(level, false)
	view.view_width = Level.WIDTH
	view._background = SavannaView.new()
	view._background.view_width = Level.WIDTH
	view.add_child(view._background)
	view._level_root = Node2D.new()
	view.add_child(view._level_root)
	view._add_home()
	view._add_water()
	view._add_props()
	view._add_ground()
	view._add_water_front()
	view._level_root.add_child(view._home.yard)
	for c in Level.COLS:
		for r in Level.ROWS:
			if level.kind_at(c, r) == Level.Kind.BOB:
				var bob := BobView.new(c, r)
				bob.position = Vector2(c + 0.5, r + 0.5) * Level.TILE
				view._level_root.add_child(bob)
	view._vine = VineView.new()
	view._vine.view_width = Level.WIDTH
	view.add_child(view._vine)
	view.add_child(view._ground.front)
	view._home.front.visible = false  # (the hut's jamb over him once home: in the tree, so freed with it)
	view.add_child(view._home.front)
	var span := Vector2(-12.0, Level.COLS + WorldView.EXTRA_COLUMNS) * Level.TILE
	view._ground.ensure(span.x, span.y)
	view._props.ensure(span.x, span.y)
	if Engine.is_editor_hint():  # (still in the editor: nothing redrawn every frame)
		view.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(view)
	move_child(view, 0)
	view._background.front.visible = false  # (the plants passing in front of the camera: made by its _ready)
	view.add_child(view._background.front)
	view._background._process(0.0)  # (its colours, once; then it stays as drawn)
	view._background.set_process(false)
	view._vine.set_process(false)
	_view = view
	_view_text = text
	print("Level editor: preview built in %d ms." % (Time.get_ticks_msec() - t0))


## Guides over the preview (the layer and the preview show behind this node): the level's bounds,
## the low ground's grass row, a line at every play screen (960 units), the last screen and the x
## where Panoramic is home, and where each bandit starts (World._init: it then drops to the ground
## ahead of it).
func _draw() -> void:
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

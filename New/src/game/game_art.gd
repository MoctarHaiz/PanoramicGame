class_name GameArt
extends RefCounted
## Shared sizes for drawing the actors. The art itself lives with each view (HeroView, BanditView,
## BobView, TerrainView, SavannaView, PropView, HomeView); docs/art/asset-manifest.json lists it all.

## Drawn size of Panoramic (head to boots) and the bandits, in design units, and where feet stand.
const HERO_DRAW_HEIGHT := 150.0
const BANDIT_DRAW_HEIGHT := 92.0
const FEET_SINK := 15.0 * World.KY  ## old tileAndFeetShading: the feet stand a little in the grass

## Folders whose pictures are loaded on background threads while the logo and the menu show, then
## kept, so starting a run doesn't stall on decoding textures (about 0.3 s on a desktop at first).
const PRELOAD_DIRS := ["res://assets/art/world", "res://assets/art/hero", "res://assets/art/bandit",
		"res://assets/art/bob"]
const LEVEL_SCRIPT := "res://src/game/game_screen.gd"  ## kept loaded with the art (preload_art)
## Menu-only pictures (the menu and the cards load them themselves): not kept, so they leave memory
## with the menu.
const MENU_ONLY := ["sunset_", "portrait", "hero_menu", "hero_win", "hero_defeat"]

static var _pending := PackedStringArray()
static var _kept: Array[Resource] = []


static func preload_art() -> void:
	if not _pending.is_empty() or not _kept.is_empty():
		return
	for dir: String in PRELOAD_DIRS:
		for file in ResourceLoader.list_directory(dir):
			if not file.ends_with(".png") or MENU_ONLY.any(func(p: String) -> bool: return file.begins_with(p)):
				continue
			if ResourceLoader.load_threaded_request(dir.path_join(file)) == OK:
				_pending.append(dir.path_join(file))
	# New (env, round 3): the level's scripts too (loading and compiling them took ~160 ms in the frame
	# the level opened, under the wipe)
	if ResourceLoader.load_threaded_request(LEVEL_SCRIPT) == OK:
		_pending.append(LEVEL_SCRIPT)


## Keeps what has finished loading (called every frame by the menu; cheap).
static func collect_preloaded() -> void:
	for path in _pending.duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_kept.append(ResourceLoader.load_threaded_get(path))
			_pending.remove_at(_pending.find(path))
			if path == LEVEL_SCRIPT:  # (env) and the level's shaders compiled, unseen, before it opens
				load("res://src/game/world_view.gd").call(&"warm_up")
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_pending.remove_at(_pending.find(path))


static func preloaded_count() -> int:
	return _kept.size()

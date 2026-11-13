extends RefCounted
## --level=FILE for the captures and the tests: that file is played as the level instead of the project's own
## (Level.PATH), which may be half-way through an edit in the level editor (2026-11-13: a pit dug for a new pillar, the
## bot fell into it and every shot past it waited for ever). The file is laid over the project's as a resource pack, so
## the game reads it through its own code and nothing in src/ knows.
##
##   const LevelPack := preload("res://tests/level_pack.gd")
##   LevelPack.use("build/level_kept.txt")  # before the first World.new()


static func use(path: String) -> void:
	var pack := OS.get_user_data_dir().path_join("level_pack.pck")
	var packer := PCKPacker.new()
	var failed := packer.pck_start(pack) != OK or packer.add_file(Level.PATH, path) != OK or packer.flush() != OK
	if failed or not ProjectSettings.load_resource_pack(pack):
		push_error("level_pack: cannot play %s as the level" % path)
		return
	print("  level: %s" % path)

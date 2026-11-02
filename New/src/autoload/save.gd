extends Node
## Player progress and settings, kept in user://save.cfg. (The 2017 game saved nothing.)
##
## New: a save can't be lost or half written. Each write goes to save.cfg.tmp first, then takes the
## place of save.cfg by a rename (atomic on Android and iOS); the save it replaces is kept as
## save.cfg.bak. Every file carries a version and a checksum of its values: a file cut short by a
## killed app, emptied or garbled is skipped, and the next good one (the new one not yet renamed,
## then the backup) is read instead. Older versions are migrated when read. Values of the wrong type
## or out of range are dropped one by one, the rest of the save is kept.

signal changed

const PATH := "user://save.cfg"
const VERSION := 2  ## 1: the first release (no version, no checksum); 2: version and checksum
const _KEYS: Array[StringName] = [
	&"best_bobs", &"best_stars", &"best_progress", &"games_played", &"wins", &"total_bobs",
	&"total_knocked_out", &"music_on", &"sounds_on", &"vibration_on", &"language", &"ads_removed",
	&"tutorial_seen", &"notifications_asked", &"music_volume", &"sounds_volume", &"screen_shake",
	&"reduce_motion", &"tutorial_learned",
]
const LANGUAGES := ["", "en", "fr"]

var best_bobs := 0
var best_stars := 0
var best_progress := 0.0
var games_played := 0
var wins := 0
var total_bobs := 0
var total_knocked_out := 0
var music_on := true
var sounds_on := true
var vibration_on := true
## "" follows the phone's language, otherwise "en" or "fr".
var language := ""
var ads_removed := false
var tutorial_seen := false
var notifications_asked := false
## New (UX): volumes 0..1 (music_on / sounds_on stay the mute switches), the screen shake, fewer
## moving things for players sensitive to motion, and the moves the tutorial has taught (bit flags,
## Tutorial.Move).
var music_volume := 1.0
var sounds_volume := 1.0
var screen_shake := true
var reduce_motion := false
var tutorial_learned := 0
## Off in tests and screenshots: nothing is written to disk.
var persist := true
## Where this save lives (tests point it elsewhere).
var path := PATH
## Which file the last load read: "save", "tmp", "bak" or "" (none: a fresh start).
var loaded_from := ""

## Game overs since the last full-screen ad (per session).
var game_overs_since_ad := 0


func _ready() -> void:
	_load()
	apply_language()


## Records a finished run. Returns what's new: {"best_bobs": bool, "best_stars": bool}.
func record_run(w: World) -> Dictionary:
	games_played += 1
	total_bobs += w.bobs
	total_knocked_out += w.knocked_out
	if w.state == World.State.WON:
		wins += 1
	else:
		game_overs_since_ad += 1
	var news := {"best_bobs": w.bobs > best_bobs, "best_stars": w.stars() > best_stars}
	best_bobs = maxi(best_bobs, w.bobs)
	best_stars = maxi(best_stars, w.stars())
	best_progress = maxf(best_progress, w.progress())
	write()
	return news


## Changes one setting and saves it (nothing is written if it didn't change).
func set_option(key: StringName, value: Variant) -> void:
	if get(key) == value:
		return
	set(key, value)
	write()


func apply_language() -> void:
	TranslationServer.set_locale(OS.get_locale() if language.is_empty() else language)


## Saves everything: the new file is complete on disk before it replaces the old one.
func write() -> void:
	changed.emit()
	if not persist:
		return
	var err := _write_file(path + ".tmp", encode())
	if err == OK and FileAccess.file_exists(path):
		if decode(FileAccess.get_file_as_string(path)).is_empty():  # damaged: never the backup
			err = DirAccess.remove_absolute(path)
		else:
			DirAccess.remove_absolute(path + ".bak")
			err = DirAccess.rename_absolute(path, path + ".bak")
	if err == OK:
		err = DirAccess.rename_absolute(path + ".tmp", path)
	if err != OK:
		push_warning("Couldn't save progress (error %d)" % err)


## The save as text: [meta] version and checksum, [save] the values.
func encode() -> String:
	var values := _values()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("meta", "checksum", _checksum(values))
	for key in _KEYS:
		cfg.set_value("save", key, values[key])
	return cfg.encode_to_text()


func _values() -> Dictionary:
	var out := {}
	for key in _KEYS:
		out[key] = get(key)
	return out


## (Fractions are summed to 6 decimals: the text keeps them, not always to the last bit.)
static func _checksum(values: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in _KEYS:
		var v: Variant = values.get(key)
		parts.append("%s=%s" % [key, "%.6f" % v if v is float else var_to_str(v)])
	return "\n".join(parts).md5_text()


static func _write_file(file: String, text: String) -> Error:
	var f := FileAccess.open(file, FileAccess.WRITE)
	if not f:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	return err


## Reads the newest good save: a complete .tmp (a write killed before its renames: it is newer than
## save.cfg), else save.cfg, else the backup (.bak). Recovered from .tmp or .bak, it is saved again
## at once. A save.cfg that is there but unreadable is kept aside as .corrupt (for a bug report).
func _load() -> void:
	loaded_from = ""
	for source: String in ["tmp", "save", "bak"]:
		var file := path + ("" if source == "save" else "." + source)
		if not FileAccess.file_exists(file):
			continue
		var values := decode(FileAccess.get_file_as_string(file))
		if values.is_empty():
			if source == "save":
				DirAccess.remove_absolute(path + ".corrupt")
				DirAccess.copy_absolute(file, path + ".corrupt")
			if source != "tmp":  # (a .tmp cut short is the normal trace of a killed write)
				push_warning("Save file %s is damaged: skipped" % file.get_file())
			continue
		apply(values)
		loaded_from = source
		break
	if loaded_from in ["tmp", "bak"] and persist:
		write()


## Sets the values read from a save (each checked; a bad one keeps its current value).
func apply(values: Dictionary) -> void:
	for key: StringName in values:
		var v: Variant = _valid(key, values[key])
		if v != null:
			set(key, v)


## The values of a save's text, migrated to this version; {} if the text is damaged.
static func decode(text: String) -> Dictionary:
	if text.strip_edges().is_empty():
		return {}
	var cfg := ConfigFile.new()
	if cfg.parse(text) != OK or not cfg.has_section("save"):
		return {}
	var version: int = cfg.get_value("meta", "version", 1)
	var values := {}
	for key in cfg.get_section_keys("save"):
		if StringName(key) in _KEYS:
			values[StringName(key)] = cfg.get_value("save", key)
	if version >= 2:
		var full := {}
		for key in _KEYS:
			full[key] = values.get(key)
		if cfg.get_value("meta", "checksum", "") != _checksum(full):
			return {}  # cut short or garbled
	return migrate(values, version)


## Brings the values of an older save up to this version.
static func migrate(values: Dictionary, from_version: int) -> Dictionary:
	var out := values.duplicate()
	if from_version < 2:
		pass  # version 1 had the same keys: only the version and the checksum are new
	return out


## `value` if it suits `key` (type and range), converted if need be; null if not.
func _valid(key: StringName, value: Variant) -> Variant:
	var current: Variant = get(key)
	match typeof(current):
		TYPE_BOOL:
			return value if value is bool else null
		TYPE_INT:
			if not (value is int or value is float) or is_nan(float(value)):
				return null
			var n := int(value)
			if key == &"best_stars":
				return clampi(n, 0, 3)
			return maxi(n, 0)
		TYPE_FLOAT:
			if not (value is int or value is float) or is_nan(float(value)):
				return null
			return clampf(float(value), 0.0, 1.0)
		TYPE_STRING:
			return value if value is String and value in LANGUAGES else null
	return null

extends Node
## Player progress and settings, kept in user://save.cfg. (The 2017 game saved nothing.)

signal changed

const PATH := "user://save.cfg"
const _KEYS: Array[StringName] = [
	&"best_bobs", &"best_stars", &"best_progress", &"games_played", &"wins", &"total_bobs",
	&"total_knocked_out", &"music_on", &"sounds_on", &"vibration_on", &"language", &"ads_removed",
	&"tutorial_seen", &"notifications_asked",
]

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
## Off in tests and screenshots: nothing is written to disk.
var persist := true

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


func set_option(key: StringName, value: Variant) -> void:
	set(key, value)
	write()


func apply_language() -> void:
	TranslationServer.set_locale(OS.get_locale() if language.is_empty() else language)


func write() -> void:
	changed.emit()
	if not persist:
		return
	var cfg := ConfigFile.new()
	for key in _KEYS:
		cfg.set_value("save", key, get(key))
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Couldn't save progress (error %d)" % err)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in _KEYS:
		set(key, cfg.get_value("save", key, get(key)))

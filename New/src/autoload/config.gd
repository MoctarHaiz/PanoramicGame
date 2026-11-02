extends Node
## Settings from config/game_config.cfg (ad ids, store links, feature switches) and platform facts.

const PATH := "res://config/game_config.cfg"
const ANDROID_PACKAGE := "com.HaizStudio.ChakaZulu"

var _cfg := ConfigFile.new()


func _init() -> void:
	var err := _cfg.load(PATH)
	if err != OK:
		push_error("Can't read %s (error %d)" % [PATH, err])


func value(section: String, key: String, default: Variant = null) -> Variant:
	return _cfg.get_value(section, key, default)


var version: String:
	get:
		return ProjectSettings.get_setting("application/config/version", "")

var is_android: bool:
	get:
		return OS.has_feature("android")

var is_ios: bool:
	get:
		return OS.has_feature("ios")

var is_mobile: bool:
	get:
		return is_android or is_ios

var is_debug: bool:
	get:
		return OS.is_debug_build()


## Link to the game on this platform's store (shared with friends).
func store_url() -> String:
	if is_ios:
		var id: String = value("store", "app_store_id", "")
		if not id.is_empty():
			return "https://apps.apple.com/app/id%s" % id
	return value("store", "play_url", "")


## Opens the store page where the player can rate the game.
func open_store_review() -> void:
	if is_ios:
		var id: String = value("store", "app_store_id", "")
		if not id.is_empty():
			OS.shell_open("https://apps.apple.com/app/id%s?action=write-review" % id)
			return
	if is_android:
		OS.shell_open("market://details?id=" + ANDROID_PACKAGE)
		return
	OS.shell_open(value("store", "play_url", ""))


func open_privacy_policy() -> void:
	OS.shell_open(value("store", "privacy_policy_url", ""))

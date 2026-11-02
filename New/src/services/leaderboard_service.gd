class_name LeaderboardService
extends Node
## Best-score leaderboard: Google Play Games on Android, Game Center on iPhone.
## Off until config/game_config.cfg [leaderboards] enabled=true; tools/extras.py then adds the
## plugins to the build. The plugins are reached by name only, so the game runs without them.

## Game Center: all-time scores of everybody.
const GK_SCOPE_GLOBAL := 0
const GK_TIME_ALL := 2

## True when the platform's game service is in the build (the player may still need to sign in).
var available := false
var signed_in := false
var _play: Object
var _game_center: RefCounted
var _show_after_sign_in := false


func _ready() -> void:
	if not enabled() or board_id().is_empty():
		return
	if Config.is_android and Engine.has_singleton("GodotPlayGameServices"):
		_play = Engine.get_singleton("GodotPlayGameServices")
		_play.initialize()
		_play.connect("userAuthenticated", _on_signed_in)
		_play.isAuthenticated()  # Play Games signs returning players in by itself
		available = true
	elif Config.is_ios and ClassDB.class_exists(&"GameCenterManager"):
		_game_center = ClassDB.instantiate(&"GameCenterManager")
		_game_center.authentication_result.connect(_on_signed_in)
		_game_center.authentication_error.connect(func(message: String) -> void:
			Services.trace("Game Center: %s" % message)
			_on_signed_in(false))
		_game_center.authenticate()
		available = true


func enabled() -> bool:
	return Config.value("leaderboards", "enabled", false)


func board_id() -> String:
	return Config.value("leaderboards", "ios_leaderboard_id" if Config.is_ios else "android_leaderboard_id", "")


func submit(score: int) -> void:
	if score <= 0:
		return
	if not signed_in:
		Services.trace("leaderboard submit %d" % score)
		return  # sent after signing in (the best score is kept)
	if _play:
		_play.submitScore(board_id(), score)
	elif _game_center:
		ClassDB.class_call_static(&"GKLeaderboard", &"load_leaderboards", PackedStringArray([board_id()]),
				func(boards: Array, error: Variant) -> void:
					if error or boards.is_empty():
						Services.trace("Game Center leaderboard: %s" % error)
						return
					boards[0].submit_score(score, 0, _game_center.local_player, func(_error: Variant) -> void: pass))


func show() -> void:
	Services.analytics.log_event("leaderboard_open")
	if not available:
		Services.trace("leaderboard show")
		return
	if not signed_in:
		if _play:
			_show_after_sign_in = true
			_play.signIn()
		else:  # iOS shows its sign-in sheet once per launch: after that it is done in Settings
			Ui.toast(tr("SIGN_IN_FAILED_IOS"))
		return
	if _play:
		_play.showLeaderboard(board_id())
	else:
		ClassDB.class_call_static(&"GKGameCenterViewController", &"show_leaderboard_time_period",
				board_id(), GK_SCOPE_GLOBAL, GK_TIME_ALL)


func _on_signed_in(ok: bool) -> void:
	var asked := _show_after_sign_in
	_show_after_sign_in = false
	signed_in = ok
	if not ok:
		if asked:
			Ui.toast(tr("SIGN_IN_FAILED_IOS" if Config.is_ios else "SIGN_IN_FAILED_ANDROID"))
		return
	submit(Save.best_bobs)  # scores made before signing in
	if asked:
		show()

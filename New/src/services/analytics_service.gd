class_name AnalyticsService
extends Node
## Firebase Analytics and Crashlytics (godot-x/firebase), present when the game is built with
## Firebase: tools/firebase.py turns it on once the config files are in config/.
## Nothing is collected until AdsService has checked where the player is: collection runs only
## where no consent form is needed (see AdsService._after_consent).

var available := false
var _analytics: Object
var _crashlytics: Object
var _consent := false


func _ready() -> void:
	if not Engine.has_singleton("GodotxFirebaseCore"):
		return
	var core := Engine.get_singleton("GodotxFirebaseCore")
	core.core_initialized.connect(_on_core_ready)
	core.initialize()


## Called after Google's consent form: collection follows the player's choice.
func set_consent(granted: bool) -> void:
	_consent = granted
	_apply_consent()


func log_event(name: String, params := {}) -> void:
	if available:
		_analytics.log_event(name, params)
	else:
		Services.trace("event %s %s" % [name, params])


## Extra information attached to crash reports (current screen, score...).
func set_crash_key(key: String, value: Variant) -> void:
	if not _crashlytics:
		return
	match typeof(value):
		TYPE_INT:
			_crashlytics.set_custom_value_int(key, value)
		TYPE_FLOAT:
			_crashlytics.set_custom_value_float(key, value)
		TYPE_BOOL:
			_crashlytics.set_custom_value_bool(key, value)
		_:
			_crashlytics.set_custom_value_string(key, str(value))


func log_message(message: String) -> void:
	if _crashlytics:
		_crashlytics.log_message(message)


func _on_core_ready(ok: bool) -> void:
	if not ok:
		return
	if Engine.has_singleton("GodotxFirebaseAnalytics"):
		_analytics = Engine.get_singleton("GodotxFirebaseAnalytics")
		_analytics.analytics_initialized.connect(func(success: bool) -> void:
			available = success
			_apply_consent())
		_analytics.initialize()
	if Engine.has_singleton("GodotxFirebaseCrashlytics"):
		_crashlytics = Engine.get_singleton("GodotxFirebaseCrashlytics")
		_crashlytics.crashlytics_initialized.connect(func(_success: bool) -> void: _apply_consent())
		_crashlytics.initialize()
	Services.push.firebase_ready()


func _apply_consent() -> void:
	var state := "granted" if _consent else "denied"
	if _analytics:
		_analytics.set_consent({"analytics_storage": state, "ad_storage": state,
				"ad_user_data": state, "ad_personalization": state})
		_analytics.set_analytics_collection_enabled(_consent)
	if _crashlytics:
		_crashlytics.set_crashlytics_collection_enabled(_consent)

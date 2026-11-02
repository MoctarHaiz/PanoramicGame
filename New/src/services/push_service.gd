class_name PushService
extends Node
## Push notifications (Firebase Cloud Messaging), present when the game is built with Firebase.

var available := false
var _messaging: Object


## Called by AnalyticsService once Firebase is up.
func firebase_ready() -> void:
	if not Engine.has_singleton("GodotxFirebaseMessaging"):
		return
	_messaging = Engine.get_singleton("GodotxFirebaseMessaging")
	_messaging.initialize()
	available = true


## Asks once for permission to send notifications, after the first game (as version 2 did).
func request_permission_once() -> void:
	if Save.notifications_asked or not available:
		return
	Save.set_option(&"notifications_asked", true)
	_messaging.request_permission()

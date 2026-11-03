extends Node
## Screen shape in design units (640 tall, wider phones are wider): the parts hidden by notches,
## camera islands, rounded corners and the home bar (the safe area), and the room taken by the ad
## banner. In landscape the notch is on the left or the right.

signal changed

## Test override: hidden margins (left, top, right, bottom) in design units. x < 0 = use the phone.
var debug_insets := Vector4(-1, -1, -1, -1)
## Height of the ad banner at the bottom of the screen, in design units (0 when none).
var banner_height := 0.0:
	set(value):
		if not is_equal_approx(value, banner_height):
			banner_height = value
			changed.emit()


func _ready() -> void:
	get_tree().root.size_changed.connect(changed.emit)


## Margins (left, top, right, bottom) that interface elements should stay inside of.
func insets() -> Vector4:
	if debug_insets.x >= 0:
		return debug_insets
	if not Config.is_mobile:
		return Vector4.ZERO
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0 or window.y <= 0:
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var k := get_tree().root.get_visible_rect().size / window
	return Vector4(
		maxf(safe.position.x, 0) * k.x,
		maxf(safe.position.y, 0) * k.y,
		maxf(window.x - safe.end.x, 0) * k.x,
		maxf(window.y - safe.end.y, 0) * k.y)


## Bottom margin including the ad banner (the banner is shown above the home bar).
func bottom_with_banner() -> float:
	return insets().w + banner_height


## Extra room between buttons and the ad banner when one is shown (AdMob: no button so close to an ad
## that a tap meant for it lands on the ad).
func ad_gap() -> float:
	return 40.0 if banner_height > 0.0 else 0.0

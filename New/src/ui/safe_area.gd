class_name SafeArea
extends MarginContainer
## A full-screen container whose margins follow the safe area (notch, rounded corners, home bar)
## and, if asked, the ad banner at the bottom.

var include_banner := false
var extra := 24.0


func _init(with_banner := false, margin := 24.0) -> void:
	include_banner = with_banner
	extra = margin
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _enter_tree() -> void:
	Device.changed.connect(_apply)
	_apply()


func _exit_tree() -> void:
	Device.changed.disconnect(_apply)


func _apply() -> void:
	var i := Device.insets()
	add_theme_constant_override(&"margin_left", int(i.x + extra))
	add_theme_constant_override(&"margin_top", int(i.y + extra))
	add_theme_constant_override(&"margin_right", int(i.z + extra))
	var bottom := Device.bottom_with_banner() if include_banner else i.w
	add_theme_constant_override(&"margin_bottom", int(bottom + extra))

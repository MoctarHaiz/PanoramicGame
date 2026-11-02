extends Node
## Entry point: holds the current screen and opens the first one.


func _ready() -> void:
	var host := Control.new()
	host.name = "Screens"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	Nav.attach(host)
	Nav.go(&"boot")

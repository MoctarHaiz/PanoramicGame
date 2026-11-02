class_name Screen
extends Control
## A full-screen page of the game (menu, game, settings...). Opened with Nav.go().


## Called once the screen is in the tree, with the data passed to Nav.go().
func enter(_data: Dictionary) -> void:
	pass


## Android back button.
func back() -> void:
	Nav.go(&"menu")


## Title bar of a page: a back button and the page title.
func header(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back_button := Ui.round_button("arrow-left-bold", 60)
	back_button.pressed.connect(func() -> void: Nav.go(&"menu", {}, back_button.get_global_rect().get_center()))
	row.add_child(back_button)
	var middle := CenterContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(Banner.new(title, Ui.Tone.SUNSET, 30))
	row.add_child(middle)
	var balance := Control.new()  # keeps the title centred
	balance.custom_minimum_size = Vector2(60, 60)
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(balance)
	return row


## A full-screen container whose margins follow the safe area (and the ad banner if asked).
func safe_area(include_banner := false, extra := 16.0) -> SafeArea:
	return SafeArea.new(include_banner, extra)

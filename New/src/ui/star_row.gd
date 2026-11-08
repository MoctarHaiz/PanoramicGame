class_name StarRow
extends HBoxContainer
## Three stars, the first `count` gold, the others pale greyed stars (not yet earned) (results and best run),
## the middle one a little bigger and higher (StarBadge).


func _init(count: int, star_size := 40.0) -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", roundi(star_size * 0.02))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var s := StarBadge.new(star_size * (1.2 if i == 1 else 1.0), i < count)
		s.size_flags_vertical = Control.SIZE_SHRINK_END if i != 1 else Control.SIZE_SHRINK_BEGIN
		add_child(s)

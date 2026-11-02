extends CanvasLayer
## Moves between screens with a sunset circle wipe, and routes the Android back button. The
## screen being left sinks back a little as the colour covers it; the next one settles into place
## (from a little closer) as the colour opens.

const SCREENS := {
	&"boot": "res://src/screens/boot_screen.gd",
	&"menu": "res://src/screens/menu_screen.gd",
	&"game": "res://src/game/game_screen.gd",

	&"settings": "res://src/screens/settings_screen.gd",
}
const COVER_TIME := 0.28
const REVEAL_TIME := 0.36
const RECEDE := 0.965  ## scale the screen being left sinks to
const SETTLE := 1.04  ## scale the next screen settles from

var current: Screen
var current_name := &""
var _host: Control
var _wipe: ColorRect
var _busy := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wipe = ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/ui/wipe.gdshader")
	mat.set_shader_parameter("color", Ui.BRAND)
	_wipe.material = mat
	_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.visible = false
	add_child(_wipe)

## The Control that holds the current screen (set by the main scene).
func attach(host: Control) -> void:
	_host = host

## Opens a screen. `from` is where the wipe starts (the button that was tapped), in screen units.
func go(name: StringName, data := {}, from := Vector2(-1, -1)) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	var view := _host.get_viewport_rect().size
	var center := from if from.x >= 0 else view / 2
	if current:
		_wipe.mouse_filter = Control.MOUSE_FILTER_STOP
		_ease_scale(current, center, 1.0, RECEDE, COVER_TIME, Tween.EASE_IN)
		Audio.play_sfx(&"wipe", 1.0, 0.8)
		await _wipe_step(center, view, false)
	_swap(name, data)
	if _wipe.visible:
		await get_tree().process_frame  # let the new screen lay itself out under the cover
		_ease_scale(current, center, SETTLE, 1.0, REVEAL_TIME + 0.12, Tween.EASE_OUT)
		await _wipe_step(center, view, true)
	_wipe.visible = false
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func reset() -> void:
	current = null
	current_name = &""
	_busy = false
	_wipe.visible = false

func is_busy() -> bool:
	return _busy

func _swap(name: StringName, data: Dictionary) -> void:
	if current:
		current.queue_free()
	current = load(SCREENS[name]).new()
	current_name = name
	_host.add_child(current)
	current.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current.enter(data)
	Services.analytics.set_crash_key("screen", String(name))

## Scales a screen around `pivot` (where the wipe starts), from `from` to `to`.
func _ease_scale(screen: Control, pivot: Vector2, from: float, to: float, time: float, ease: Tween.EaseType) -> void:
	screen.pivot_offset = pivot
	screen.scale = Vector2.ONE * from
	screen.create_tween().tween_property(screen, "scale", Vector2.ONE * to, time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(ease)

func _wipe_step(center: Vector2, view: Vector2, reveal: bool) -> void:
	_wipe.visible = true
	var mat := _wipe.material as ShaderMaterial
	mat.set_shader_parameter("reveal", reveal)
	mat.set_shader_parameter("center", center / view)
	mat.set_shader_parameter("rect_size", view)
	mat.set_shader_parameter("progress", 0.0)
	var t := create_tween()
	t.tween_method(func(p: float) -> void: mat.set_shader_parameter("progress", p), 0.0, 1.0,
			REVEAL_TIME if reveal else COVER_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if reveal else Tween.EASE_IN)
	await t.finished

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and current and not _busy:
		current.back()

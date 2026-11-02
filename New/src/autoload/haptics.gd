extends Node
## Vibrations (when the player keeps them on). Each is a short pattern of pulses,
## [delay from the start (s), length (ms), strength 0-1], shaped like what happens.

const TAP := [[0.0, 8, 0.25]]
const PICKUP := [[0.0, 10, 0.35]]
const LAND := [[0.0, 16, 0.45]]
const KNOCK := [[0.0, 14, 0.55], [0.07, 9, 0.3]]
const HURT := [[0.0, 45, 1.0], [0.11, 30, 0.6], [0.22, 22, 0.35]]
const FALL := [[0.0, 30, 0.6], [0.16, 40, 0.35], [0.36, 26, 0.18]]
const CELEBRATE := [[0.0, 12, 0.4], [0.09, 12, 0.6], [0.18, 30, 0.9]]


func tap() -> void:
	_play(TAP)


## A Red Bob collected.
func pickup() -> void:
	_play(PICKUP)


## A bandit knocked out.
## A hard landing (a long drop).
func land() -> void:
	_play(LAND)


func knock() -> void:
	_play(KNOCK)


func hurt() -> void:
	_play(HURT)


func fall() -> void:
	_play(FALL)


func celebrate() -> void:
	_play(CELEBRATE)


func _play(pattern: Array) -> void:
	if not (Save.vibration_on and Config.is_mobile):
		return
	for pulse: Array in pattern:
		if pulse[0] > 0.0:
			get_tree().create_timer(pulse[0], true, false, true).timeout.connect(_vibrate.bind(pulse[1], pulse[2]))
		else:
			_vibrate(pulse[1], pulse[2])


func _vibrate(ms: int, amplitude: float) -> void:
	Input.vibrate_handheld(ms, amplitude)

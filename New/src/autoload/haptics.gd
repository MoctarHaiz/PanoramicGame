extends Node
## Vibrations (when the player keeps them on, on a phone). Each is a short pattern of pulses,
## [delay from the start (s), length (ms), strength 0-1], shaped like what happens, from light (a
## tap on a button) to heavy (a blow). On iPhone Godot plays them through Core Haptics (strength is
## the intensity), on Android through the vibrator's amplitude (Android 8+).
##
## Never over-used: while a pattern plays, a lighter one is dropped (a streak of Red Bobs is one
## tick each, not a buzz), and the same light pattern waits `REPEAT_MS` before it plays again.

const TAP := [[0.0, 8, 0.3]]  ## a button: the lightest tick
const SELECT := [[0.0, 6, 0.22]]  ## a switch, a count of the countdown
const PICKUP := [[0.0, 9, 0.38]]  ## a Red Bob
const STEP := [[0.0, 10, 0.3]]  ## a step forward
const LAND := [[0.0, 18, 0.5]]  ## a hard landing (a long drop)
const HANG := [[0.0, 12, 0.42]]  ## catching the vine
const KNOCK := [[0.0, 16, 0.65], [0.07, 10, 0.35]]  ## a bandit knocked out: a thump and its rebound
const HURT := [[0.0, 45, 1.0], [0.11, 30, 0.6], [0.22, 22, 0.35]]  ## a blow: heavy, shaking out
const FALL := [[0.0, 30, 0.6], [0.16, 40, 0.35], [0.36, 26, 0.18]]  ## falling away
const DEATH := [[0.0, 60, 1.0], [0.14, 50, 0.7], [0.3, 40, 0.45], [0.5, 30, 0.25]]  ## caught for good
const STAR := [[0.0, 14, 0.55]]  ## a result star landing
const SUCCESS := [[0.0, 12, 0.45], [0.1, 14, 0.7], [0.2, 34, 1.0]]  ## home: rising, like iOS's success
const CELEBRATE := SUCCESS
const REPEAT_MS := 70  ## a light pattern (strength under 0.5) waits this long before it plays again
const ANDROID_MIN_MS := 12  ## shorter pulses don't move most Android motors

var _busy_until := 0  # ticks (ms) the pattern playing ends
var _busy_strength := 0.0
var _last := {}  # pattern (as a string) -> ticks it last started
## Records the patterns asked for (tests).
var record := false
var played: Array[String] = []


func tap() -> void:
	_play(TAP, "tap")


func select() -> void:
	_play(SELECT, "select")


## A Red Bob collected.
func pickup() -> void:
	_play(PICKUP, "pickup")


func step() -> void:
	_play(STEP, "step")


## A hard landing (a long drop).
func land() -> void:
	_play(LAND, "land")


func hang() -> void:
	_play(HANG, "hang")


## A bandit knocked out.
func knock() -> void:
	_play(KNOCK, "knock")


func hurt() -> void:
	_play(HURT, "hurt")


func fall() -> void:
	_play(FALL, "fall")


func death() -> void:
	_play(DEATH, "death")


func star() -> void:
	_play(STAR, "star")


func success() -> void:
	_play(SUCCESS, "success")


func celebrate() -> void:
	_play(CELEBRATE, "success")


func enabled() -> bool:
	return Save.vibration_on and Config.is_mobile


func _play(pattern: Array, name: String) -> void:
	if not Save.vibration_on:
		return
	var now := Time.get_ticks_msec()
	var strength: float = pattern.map(func(p: Array) -> float: return p[2]).max()
	if now < _busy_until and strength < _busy_strength:
		return  # a lighter pattern doesn't cut into a heavier one
	if strength < 0.5 and now - int(_last.get(name, -100000)) < REPEAT_MS:
		return
	_last[name] = now
	var last: Array = pattern[pattern.size() - 1]
	_busy_until = now + int(last[0] * 1000.0) + int(last[1])
	_busy_strength = strength
	if record:
		played.append(name)
	if not Config.is_mobile:
		return
	for pulse: Array in pattern:
		if pulse[0] > 0.0:
			get_tree().create_timer(pulse[0], true, false, true).timeout.connect(_vibrate.bind(pulse[1], pulse[2]))
		else:
			_vibrate(pulse[1], pulse[2])


func _vibrate(ms: int, amplitude: float) -> void:
	Input.vibrate_handheld(maxi(ms, ANDROID_MIN_MS) if Config.is_android else ms, amplitude)

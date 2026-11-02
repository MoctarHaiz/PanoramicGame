class_name Prefs
extends RefCounted
## The player's comfort options (saved in Save): sound volumes, the screen shake, reduced motion.
## Music and sounds also keep their on/off switches (Audio.apply_settings mutes the buses); the
## volumes scale the buses themselves.

const MIN_DB := -40.0  ## a volume slider at its lowest step


## Sets the Music and SFX buses to the saved volumes.
static func apply_volumes() -> void:
	for pair: Array in [[&"Music", Save.music_volume], [&"SFX", Save.sounds_volume]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, maxf(linear_to_db(maxf(pair[1], 0.0001)), MIN_DB))


## How much of the screen shake to play (0 when the player turned it off or asked for less motion).
static func shake() -> float:
	return 0.0 if Save.reduce_motion or not Save.screen_shake else 1.0


## Whether decorative motion plays (breathing buttons, turning rays, drifting dust).
static func motion() -> bool:
	return not Save.reduce_motion

extends Node
## Music, ambience and sound effects on their own buses, following the player's settings.
##
## Buses: Music (the themes; a gain stage for the mood and the dips, and a low-pass that muffles
## them while the game is paused), SFX (the game), with UI (taps, panels, counts: they play over
## the pause) and Ambience (the savanna under the music) both sent into SFX, so the sounds switch
## and volume (Prefs) cover them; Master ends in a limiter at -1 dB, so a pile of sounds never
## clips. The player's volumes set the Music and SFX faders (Prefs.apply_volumes): this script
## never touches them.
## In play the theme sits about 7 dB under the menu's (-23 LUFS: the effects lead), dips 4-6 dB
## for 0.3 s under a hit, a knock-out or the death, and its drive layer (music_game_drive.ogg,
## in sync) comes in with set_intensity() on the home stretch. A sound name maps to several takes:
## one is picked at random, never the same twice in a row, with a random pitch and level; a voice
## limit keeps a burst of one sound from stacking (its oldest voice starts again), and when every
## voice is busy a sound only takes the place of a less important one.
## Everything is made by tools/sfx_synth.py and tools/music_synth.py (levels in docs/agent_audio.md).

const DIR := "res://assets/audio/"
const MUSIC := {&"menu": "music_menu.ogg", &"game": "music_game.ogg"}
const MUSIC_DB := {&"menu": -1.0, &"game": -7.0}  ## the themes are mastered at -16 LUFS
const DRIVE := "music_game_drive.ogg"  ## the game theme's drive layer (-22 LUFS, same length)
const AMBIENCE := "amb_savanna.ogg"  ## mastered at -30 LUFS: a bed, under the music
## The mood of the music: its level (dB) and the cutoff of its low-pass (Hz).
const MOODS := {&"play": [0.0, 20500.0], &"paused": [-9.0, 900.0], &"results": [-5.0, 20500.0]}
## Sound name -> its takes (WAV files in DIR). One is picked at random unless the sound is tuned.
const SFX := {
	&"button": ["sfx_button_1", "sfx_button_2", "sfx_button_3"],
	&"toggle_on": ["sfx_toggle_on"],
	&"toggle_off": ["sfx_toggle_off"],
	&"panel_open": ["sfx_panel_open"],
	&"panel_close": ["sfx_panel_close"],
	&"wipe": ["sfx_wipe"],
	&"tick": ["sfx_tick"],
	&"counter": ["sfx_tick"],
	&"count": ["sfx_count_3", "sfx_count_2", "sfx_count_1", "sfx_count_go"],
	&"star": ["sfx_star_1", "sfx_star_2", "sfx_star_3"],
	&"new_best": ["sfx_new_best"],
	&"coins": ["sfx_coins_1", "sfx_coins_2"],
	&"footstep": ["sfx_footstep_1", "sfx_footstep_2", "sfx_footstep_3", "sfx_footstep_4", "sfx_footstep_5", "sfx_footstep_6"],
	&"jump": ["sfx_jump_1", "sfx_jump_2", "sfx_jump_3", "sfx_jump_4", "sfx_jump_5"],
	&"land": ["sfx_land_1", "sfx_land_2", "sfx_land_3", "sfx_land_4", "sfx_land_5"],
	&"step": ["sfx_step_1", "sfx_step_2", "sfx_step_3", "sfx_step_4"],
	&"throw": ["sfx_throw_1", "sfx_throw_2", "sfx_throw_3", "sfx_throw_4", "sfx_throw_5"],
	&"ring_hit": ["sfx_ring_hit_1", "sfx_ring_hit_2", "sfx_ring_hit_3", "sfx_ring_hit_4", "sfx_ring_hit_5"],
	&"knock_out": ["sfx_knock_out_1", "sfx_knock_out_2", "sfx_knock_out_3", "sfx_knock_out_4", "sfx_knock_out_5"],
	&"bob": ["sfx_bob_1", "sfx_bob_2", "sfx_bob_3", "sfx_bob_4", "sfx_bob_5", "sfx_bob_6", "sfx_bob_7", "sfx_bob_8"],
	&"streak": ["sfx_streak"],
	&"hurt": ["sfx_hurt_1", "sfx_hurt_2", "sfx_hurt_3", "sfx_hurt_4", "sfx_hurt_5"],
	&"heart_break": ["sfx_heart_break"],
	&"last_heart": ["sfx_last_heart"],
	&"death": ["sfx_death"],
	&"fall": ["sfx_fall_1", "sfx_fall_2"],
	&"fell": ["sfx_fell"],
	&"spring": ["sfx_spring"],
	&"splash": ["sfx_splash_1", "sfx_splash_2", "sfx_splash_3", "sfx_splash_4"],
	&"hang": ["sfx_hang_1", "sfx_hang_2", "sfx_hang_3", "sfx_hang_4"],
	&"vine_creak": ["sfx_vine_creak_1", "sfx_vine_creak_2", "sfx_vine_creak_3"],
	&"let_go": ["sfx_let_go"],
	&"grab": ["sfx_grab_1", "sfx_grab_2", "sfx_grab_3", "sfx_grab_4"],
	&"mantle": ["sfx_mantle_1", "sfx_mantle_2"],
	&"bump": ["sfx_bump_1", "sfx_bump_2", "sfx_bump_3"],
	&"door": ["sfx_door"],
}
## How a sound plays (anything left out: DEFAULT). Keys: db (level: the files are mastered for the
## mix, 0 dB); vary (random pitch, ± semitones); spread (random level, ± dB); voices (at most this
## many at once); priority (0 footsteps .. 4 the end of a run: a busy pool gives way upwards);
## duck (dB the music dips under it, for 0.3 s); ui (the UI bus: plays over the pause); tuned (the
## game picks the take: a Red Bob's step up the scale, a star, a count).
const HOW := {
	&"button": {"vary": 0.25, "voices": 2, "ui": true},
	&"toggle_on": {"vary": 0.0, "ui": true},
	&"toggle_off": {"vary": 0.0, "ui": true},
	&"panel_open": {"vary": 0.0, "ui": true},
	&"panel_close": {"vary": 0.0, "ui": true},
	&"wipe": {"vary": 0.3, "ui": true},
	&"tick": {"vary": 0.0, "voices": 2, "ui": true},
	&"counter": {"vary": 0.0, "voices": 2, "ui": true},
	&"count": {"tuned": true, "ui": true},
	&"star": {"tuned": true, "ui": true, "priority": 3},
	&"new_best": {"vary": 0.0, "ui": true, "priority": 3, "duck": 6.0},
	&"coins": {"vary": 0.5, "voices": 1, "ui": true},
	&"footstep": {"vary": 1.2, "spread": 1.5, "voices": 2, "priority": 0},
	&"jump": {"vary": 1.2, "spread": 1.5, "voices": 2},
	&"land": {"vary": 1.2, "spread": 1.5, "voices": 2},
	&"step": {"vary": 1.2, "spread": 1.5, "voices": 2},
	&"throw": {"vary": 1.0, "spread": 1.5, "voices": 3},
	&"ring_hit": {"vary": 1.2, "spread": 1.5, "voices": 2, "priority": 2},
	&"knock_out": {"vary": 0.3, "spread": 1.0, "voices": 2, "priority": 3, "duck": 4.0},
	&"bob": {"tuned": true, "voices": 4, "priority": 2},
	&"streak": {"vary": 0.0, "priority": 2},
	&"hurt": {"vary": 1.2, "spread": 1.0, "priority": 3, "duck": 5.0},
	&"heart_break": {"vary": 0.3, "priority": 3},
	&"last_heart": {"vary": 0.0, "priority": 3},
	&"death": {"vary": 0.0, "priority": 4, "duck": 6.0},
	&"fall": {"vary": 0.4, "priority": 4, "duck": 6.0},
	&"fell": {"vary": 0.0, "priority": 3, "duck": 4.0},
	&"spring": {"vary": 0.2, "priority": 2},
	&"splash": {"vary": 1.0, "voices": 2, "priority": 2},
	&"hang": {"vary": 1.0, "voices": 1},
	&"vine_creak": {"vary": 1.5, "spread": 2.0, "voices": 1, "priority": 0},
	&"let_go": {"vary": 0.8, "voices": 1},
	&"grab": {"vary": 1.2, "spread": 1.5, "voices": 2},
	&"mantle": {"vary": 1.0, "voices": 1},
	&"bump": {"vary": 1.2, "voices": 1, "priority": 2},
	&"door": {"vary": 0.0, "priority": 3},
}
const DEFAULT := {"db": 0.0, "vary": 0.5, "spread": 1.0, "priority": 1}
## The stingers (Ogg: they are long), played by stinger() on the SFX bus, so they sound with the music off.
const STINGERS := {&"win": "sting_win.ogg", &"game_over": "sting_lose.ogg"}
const SFX_VOICES := 20
const UI_VOICES := 6
const SILENT_DB := -60.0
const DUCK_HOLD := 0.3  ## seconds the music stays down under a big sound
const DUCK_RECOVER := 14.0  ## dB a second it comes back after
const STINGER_FADE := 0.25  ## seconds the music takes to make way for a stinger

var _streams := {}  # name -> Array[AudioStream]
var _music_streams := {}
var _music: AudioStreamPlayer
var _music_out: AudioStreamPlayer
var _drive: AudioStreamPlayer  # the game theme's drive layer, started with it, in sync
var _ambience: AudioStreamPlayer
var _current := &""
var _sfx: Array[AudioStreamPlayer] = []
var _ui: Array[AudioStreamPlayer] = []
var _last_variant := {}  # name -> index of the take played last
var _left_foot := false
var _mood := &"play"
var _mood_db := 0.0  # the music's level for its mood (moves towards MOODS)
var _cutoff := 20500.0
var _duck := 0.0  # dB the music is dipped by under a big sound (recovers)
var _duck_hold := 0.0
var _intensity := 0.0  # 0..1: how much of the drive layer plays (set_intensity)
var _drive_db := SILENT_DB
var _stinger_left := 0.0  # seconds of stinger still playing (the music waits)
var _after_stinger := &""
var _bus := {}  # name -> index
var _gain: AudioEffectAmplify  # the mood and the dips (the fader is the player's volume)
var _lowpass: AudioEffectLowPassFilter
## The last sound asked for and how many were (for the checks in tests/run_tests.gd).
var last_sfx := &""
var sfx_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	# Silent in debug runs started from the command line (tests, captures, scripted checks). Runs
	# from the Godot editor (debugger attached) and release builds play normally.
	AudioServer.set_bus_mute(0, OS.is_debug_build() and not EngineDebugger.is_active())
	for name: StringName in SFX:
		var list: Array[AudioStream] = []
		for file: String in SFX[name]:
			if ResourceLoader.exists(DIR + file + ".wav"):
				list.append(load(DIR + file + ".wav"))
		_streams[name] = list
	for name: StringName in STINGERS:
		if ResourceLoader.exists(DIR + STINGERS[name]):
			_streams[name] = [load(DIR + STINGERS[name])] as Array[AudioStream]
	for name: StringName in MUSIC:
		if ResourceLoader.exists(DIR + MUSIC[name]):
			var stream: AudioStreamOggVorbis = load(DIR + MUSIC[name])
			stream.loop = true
			_music_streams[name] = stream
	_music = _player(&"Music")
	_music_out = _player(&"Music")
	_drive = _player(&"Music")
	if ResourceLoader.exists(DIR + DRIVE):
		var layer: AudioStreamOggVorbis = load(DIR + DRIVE)
		layer.loop = true
		_drive.stream = layer
	_ambience = _player(&"Ambience")
	if ResourceLoader.exists(DIR + AMBIENCE):
		var bed: AudioStreamOggVorbis = load(DIR + AMBIENCE)
		bed.loop = true
		_ambience.stream = bed
	for i in SFX_VOICES:
		_sfx.append(_player(&"SFX"))
	for i in UI_VOICES:
		_ui.append(_player(&"UI"))
	apply_settings()


## Music and SFX into Master, UI and Ambience into SFX; on Music a gain (mood, dips) and a low-pass
## (off until the music is muffled); a limiter at the end of Master.
func _make_buses() -> void:
	for pair: Array in [[&"Music", &"Master"], [&"SFX", &"Master"], [&"Ambience", &"SFX"], [&"UI", &"SFX"]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index == -1:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, pair[0])
		AudioServer.set_bus_send(index, pair[1])
		_bus[pair[0]] = index
	var music: int = _bus[&"Music"]
	if AudioServer.get_bus_effect_count(music) == 0:
		AudioServer.add_bus_effect(music, AudioEffectAmplify.new())
		var lowpass := AudioEffectLowPassFilter.new()
		lowpass.cutoff_hz = 20500.0
		lowpass.resonance = 0.6
		AudioServer.add_bus_effect(music, lowpass)
		AudioServer.set_bus_effect_enabled(music, 1, false)
	_gain = AudioServer.get_bus_effect(music, 0)
	_lowpass = AudioServer.get_bus_effect(music, 1)
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		limiter.release = 0.08
		AudioServer.add_bus_effect(0, limiter)


func apply_settings() -> void:
	AudioServer.set_bus_mute(_bus[&"Music"], not Save.music_on)
	for bus: StringName in [&"SFX", &"UI", &"Ambience"]:
		AudioServer.set_bus_mute(_bus[bus], not Save.sounds_on)


func _process(delta: float) -> void:
	if _duck_hold > 0.0:
		_duck_hold -= delta
	else:
		_duck = move_toward(_duck, 0.0, DUCK_RECOVER * delta)
	if _stinger_left > 0.0:
		_stinger_left -= delta
		if _stinger_left <= 0.0 and not _after_stinger.is_empty():
			var next := _after_stinger
			_after_stinger = &""
			_current = &""
			play_music(next, 1.6)
			set_mood(&"results")
	var mood: Array = MOODS[_mood]
	_mood_db = move_toward(_mood_db, mood[0], 30.0 * delta)
	_cutoff = clampf(_cutoff * pow(mood[1] / _cutoff, minf(delta * 6.0, 1.0)), 200.0, 20500.0)
	_gain.volume_db = _mood_db - _duck
	_lowpass.cutoff_hz = _cutoff
	AudioServer.set_bus_effect_enabled(_bus[&"Music"], 1, _cutoff < 20000.0)
	AudioServer.set_bus_volume_db(_bus[&"Ambience"], minf(_mood_db, 0.0) * 0.6)
	if _drive.playing:  # the drive layer follows the intensity (2 s to come in, 1 s to go)
		var target := MUSIC_DB[&"game"] + linear_to_db(maxf(_intensity, 0.001)) if _intensity > 0.01 else SILENT_DB
		_drive_db = move_toward(_drive_db, target, (30.0 if target > _drive_db else 60.0) * delta)
		_drive.volume_db = _drive_db


## Starts a theme (cross-faded from the one playing) and the savanna under it; the same theme again
## just comes back to its full level. The game theme starts its drive layer with it, silent.
func play_music(name: StringName, fade := 0.6) -> void:
	if _ambience.stream and not _ambience.playing:
		_ambience.volume_db = SILENT_DB
		_ambience.play()
		create_tween().tween_property(_ambience, "volume_db", 0.0, 2.0)
	_after_stinger = &""
	set_mood(&"play")
	if name == _current or not _music_streams.has(name):
		if _music.playing and _music.stream == _music_streams.get(name):
			create_tween().tween_property(_music, "volume_db", MUSIC_DB[name], fade)
		return
	_current = name
	var old := _music
	_music = _music_out
	_music_out = old
	var t := create_tween().set_parallel(true)
	if _music_out.playing:
		t.tween_property(_music_out, "volume_db", SILENT_DB, fade)
		t.chain().tween_callback(_music_out.stop)
	_music.stream = _music_streams[name]
	_music.volume_db = SILENT_DB
	_music.play()
	t.tween_property(_music, "volume_db", MUSIC_DB[name], fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intensity = 0.0
	_drive_db = SILENT_DB
	_drive.stop()
	if name == &"game" and _drive.stream:
		_drive.volume_db = SILENT_DB
		_drive.play()  # in the same mix step as the theme: they stay in sync (same length, both loop)


## How much of the game theme's drive layer plays: 0 (none) to 1 (all of it).
func set_intensity(amount: float) -> void:
	_intensity = clampf(amount, 0.0, 1.0)


## How the music sits: &"play" (full), &"paused" (lower and muffled, as if heard through a wall),
## &"results" (lower, clear).
func set_mood(mood: StringName) -> void:
	_mood = mood


## Lowers the music while the game is paused, or brings it back (set_mood).
func duck_music(ducked: bool) -> void:
	set_mood(&"paused" if ducked else &"play")


## Dips the music by `db` for a moment (held `hold` seconds, then it comes back).
func duck(db: float, hold := DUCK_HOLD) -> void:
	_duck = maxf(_duck, db)
	_duck_hold = maxf(_duck_hold, hold)


## A stinger (STINGERS: win, game_over): the music makes way, the stinger plays, then `then` (a
## theme) comes back under the results.
func stinger(name: StringName, then := &"menu") -> void:
	var stream := _pick(name)
	if not stream:
		return
	for m: AudioStreamPlayer in [_music, _drive]:
		if m.playing:
			var t := create_tween()
			t.tween_property(m, "volume_db", SILENT_DB, STINGER_FADE)
			t.tween_callback(m.stop)
	_current = &""
	_stinger_left = stream.get_length() - 0.4
	_after_stinger = then
	_play(name, stream, 1.0, 1.0)


## Plays a sound effect: a random take, its pitch varied a little (unless `vary` is off), times
## `pitch`, at `volume` (linear, 1 = as mastered).
func play_sfx(name: StringName, pitch := 1.0, volume := 1.0, vary := true) -> void:
	var stream := _pick(name)
	if not stream:
		return
	var semis: float = _how(name).vary if vary else 0.0
	_play(name, stream, pitch * pow(2.0, randf_range(-semis, semis) / 12.0), volume)


## Plays take `index` of a tuned sound (a Red Bob's step up the scale, a star, a count).
func play_tuned(name: StringName, index: int, volume := 1.0) -> void:
	var takes: Array = _streams.get(name, [])
	if takes.is_empty():
		return
	_play(name, takes[clampi(index, 0, takes.size() - 1)], 1.0, volume)


## A foot touching the ground in the run (HeroView's run cycle): left and right a hair apart.
func footstep(strength := 1.0) -> void:
	_left_foot = not _left_foot
	play_sfx(&"footstep", 1.0 if _left_foot else 0.97, strength)


func has_sfx(name: StringName) -> bool:
	return not _streams.get(name, []).is_empty()


func _pick(name: StringName) -> AudioStream:
	var takes: Array = _streams.get(name, [])
	if takes.is_empty():
		return null
	var pick := 0
	if takes.size() > 1:
		pick = randi() % (takes.size() - 1)
		if pick >= _last_variant.get(name, -1):
			pick += 1
	_last_variant[name] = pick
	return takes[pick]


## How `name` plays: its HOW entry over DEFAULT.
func _how(name: StringName) -> Dictionary:
	var how := DEFAULT.duplicate()
	how.merge(HOW.get(name, {}), true)
	return how


func _play(name: StringName, stream: AudioStream, pitch: float, volume: float) -> void:
	var spec := _how(name)
	var pool := _ui if spec.get("ui", false) else _sfx
	var priority: int = spec.priority
	var player: AudioStreamPlayer
	if spec.has("voices"):  # all its voices busy: the oldest of them starts again (a streak never drops one)
		var same: Array[AudioStreamPlayer] = []
		for p in pool:
			if p.playing and p.get_meta(&"name", &"") == name:
				same.append(p)
		if same.size() >= spec.voices:
			same.sort_custom(func(a: AudioStreamPlayer, b: AudioStreamPlayer) -> bool: return a.get_meta(&"start", 0) < b.get_meta(&"start", 0))
			player = same[0]
	if not player:
		player = _free_voice(pool, priority)
	if not player:
		return
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = spec.db + linear_to_db(maxf(volume, 0.001)) + randf_range(-spec.spread, spec.spread)
	player.set_meta(&"name", name)
	player.set_meta(&"priority", priority)
	player.set_meta(&"start", Time.get_ticks_msec())
	player.play()
	last_sfx = name
	sfx_count += 1
	if spec.has("duck"):
		duck(spec.duck)


## A voice that is free, or the oldest playing one no more important than `priority`.
func _free_voice(pool: Array[AudioStreamPlayer], priority: int) -> AudioStreamPlayer:
	var best: AudioStreamPlayer
	for p in pool:
		if not p.playing:
			return p
		if p.get_meta(&"priority", 0) <= priority and (not best or p.get_meta(&"start", 0) < best.get_meta(&"start", 0)):
			best = p
	return best


func _player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

extends Node
## Music (cross-faded between screens) and sound effects, following the player's settings.
## A sound name maps to several variant files; one is picked at random, never the same twice in a
## row, with a small random pitch, and a voice limit keeps a burst of the same sound from stacking.

const MUSIC := {
	&"menu": "res://assets/audio/music_menu.ogg",
	&"game": "res://assets/audio/music_game.ogg",
}
const MUSIC_FALLBACK := "res://assets/audio/music_game.ogg"  ## one theme for the menu and the game
const MUSIC_VOLUME := {&"menu": 0.8, &"game": 0.55}
## Sound name -> variant files (missing files are skipped, so the game runs while sounds are made).
const SFX := {
	&"button": ["sfx_button_1", "sfx_button_2", "sfx_button_3"],
	&"toggle_on": ["sfx_toggle_on"],
	&"toggle_off": ["sfx_toggle_off"],
	&"panel_open": ["sfx_panel_open"],
	&"panel_close": ["sfx_panel_close"],
	&"wipe": ["sfx_wipe"],
	&"jump": ["sfx_jump_1", "sfx_jump_2", "sfx_jump_3"],
	&"land": ["sfx_land_1", "sfx_land_2", "sfx_land_3"],
	&"hang": ["sfx_hang"],
	&"let_go": ["sfx_let_go"],
	&"step": ["sfx_step"],
	&"throw": ["sfx_throw_1", "sfx_throw_2", "sfx_throw_3", "old_projectile"],
	&"ring_hit": ["sfx_ring_hit_1", "sfx_ring_hit_2", "old_enemy"],
	&"knock_out": ["sfx_knock_out", "old_enemy2"],
	&"bob": ["sfx_bob_1", "sfx_bob_2", "sfx_bob_3"],
	&"hurt": ["sfx_hurt", "old_enemy"],
	&"fall": ["sfx_fall"],
	&"fell": ["sfx_fell"],
	&"spring": ["sfx_spring"],
	&"splash": ["sfx_splash_1", "sfx_splash_2"],
	&"game_over": ["sfx_game_over"],
	&"win": ["sfx_win"],
	&"star": ["sfx_star"],
	&"counter": ["sfx_counter"],
	&"tick": ["sfx_tick"],
	&"new_best": ["sfx_new_best"],
}
## At most this many copies of one sound at a time.
const VOICES := {&"throw": 3, &"ring_hit": 2, &"bob": 2, &"tick": 1, &"step": 1, &"land": 1, &"splash": 2}
const SFX_VOLUME := 0.85
const SILENT_DB := -60.0

var _streams := {}  # name -> Array[AudioStream]
var _music_streams := {}
var _music: AudioStreamPlayer
var _music_out: AudioStreamPlayer
var _current := &""
var _ducked := false
var _sfx: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _last_variant := {}  # name -> index of the variant played last


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Silent in debug runs started from the command line (tests, captures, scripted checks). Runs
	# from the Godot editor (debugger attached) and release builds play normally.
	AudioServer.set_bus_mute(0, OS.is_debug_build() and not EngineDebugger.is_active())
	for bus: StringName in [&"Music", &"SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	for name: StringName in SFX:
		var list: Array[AudioStream] = []
		for file: String in SFX[name]:
			var path := "res://assets/audio/%s.wav" % file
			if ResourceLoader.exists(path):
				list.append(load(path))
		# The 2017 sounds stand in only until new ones exist.
		if list.size() > 1:
			list = list.filter(func(s: AudioStream) -> bool: return not s.resource_path.contains("/old_"))
		_streams[name] = list
	for name: StringName in MUSIC:
		var path: String = MUSIC[name] if ResourceLoader.exists(MUSIC[name]) else MUSIC_FALLBACK
		if ResourceLoader.exists(path):
			var stream: AudioStreamOggVorbis = load(path)
			stream.loop = true
			_music_streams[name] = stream
	_music = _player(&"Music")
	_music_out = _player(&"Music")
	for i in 12:
		_sfx.append(_player(&"SFX"))
	apply_settings()


func apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), not Save.music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"SFX"), not Save.sounds_on)


func play_music(name: StringName, fade := 0.6) -> void:
	if name == _current and _ducked:  # the same screen again (Play again): back to full volume
		duck_music(false)
	if name == _current or not _music_streams.has(name):
		return
	_ducked = false
	var same_stream: bool = _music.playing and _music.stream == _music_streams[name]
	_current = name
	if same_stream:  # one track for both screens: just change its volume
		create_tween().tween_property(_music, "volume_db", linear_to_db(MUSIC_VOLUME[name]), fade)
		return
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
	t.tween_property(_music, "volume_db", linear_to_db(MUSIC_VOLUME[name]), fade) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Lowers the music while the game is paused or over, or brings it back.
func duck_music(ducked: bool) -> void:
	if _current.is_empty():
		return
	_ducked = ducked
	var target := linear_to_db(MUSIC_VOLUME[_current] * (0.35 if ducked else 1.0))
	create_tween().tween_property(_music, "volume_db", target, 0.25)


## Plays a sound effect. `pitch` multiplies a small random variation (±3 %) unless `vary` is off.
func play_sfx(name: StringName, pitch := 1.0, volume := 1.0, vary := true) -> void:
	var variants: Array = _streams.get(name, [])
	if variants.is_empty():
		return
	var pick := 0
	if variants.size() > 1:
		pick = randi() % (variants.size() - 1)
		if pick >= _last_variant.get(name, -1):
			pick += 1
	_last_variant[name] = pick
	var stream: AudioStream = variants[pick]
	if VOICES.has(name):
		var playing := 0
		for p in _sfx:
			if p.playing and variants.has(p.stream):
				playing += 1
		if playing >= VOICES[name]:
			return
	var p := _sfx[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx.size()
	p.stream = stream
	p.pitch_scale = pitch * (randf_range(0.97, 1.03) if vary else 1.0)
	p.volume_db = linear_to_db(SFX_VOLUME * volume)
	p.play()


func has_sfx(name: StringName) -> bool:
	return not _streams.get(name, []).is_empty()


func _player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

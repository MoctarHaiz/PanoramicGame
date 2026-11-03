extends Node
## Renders screens of the game at exact phone and tablet resolutions, off screen, to review the
## look and to make store screenshots. Game time is fixed (run with --fixed-fps 60), so pictures
## are repeatable.
##
## Godot --path . --fixed-fps 60 --resolution 200x200 --always-on-top res://tests/capture.tscn -- \
##     --out=DIR [--devices=a,b] [--shots=x,y] [--lang=fr|en,fr] [--ads=off]
## Each picture is drawn on demand (_draw_now): macOS skips drawing covered windows.
## --lang=en,fr takes every picture in each language, into DIR/en/ and DIR/fr/.
##
## Shots in the level start from worlds the bot reached first (before any picture), so every device
## shows the same moment. The bot's run is recorded once (BotReplay, build/qa/: about 5 minutes the
## first time, then instant) and replayed to each moment.
##
## Shots: the screens of a store release. boot, menu (a returning player), first_menu (the first
## launch: no best yet), start (the first run's card), game, throw (a ring flying at a bandit), hurt
## (the instant after a hit), climb, hang, home (1.2 s after he is home: in the doorway, the
## HUD gone), pause, resume (the countdown after Resume),
## gameover (caught), fell (game over by a fall), win, settings, settings_end (scrolled to the bottom:
## About and the version).

## Screen size (landscape) and safe-area margins (left, top, right, bottom) in device pixels.
const DEVICES := {
	"phone_1280x720": {"size": Vector2i(1280, 720), "insets": Vector4(0, 0, 0, 0)},
	"phone_1920x1080": {"size": Vector2i(1920, 1080), "insets": Vector4(0, 0, 0, 0)},  # Play store pictures
	"pixel_2400x1080": {"size": Vector2i(2400, 1080), "insets": Vector4(118, 0, 0, 0)},
	"iphone15_2556x1179": {"size": Vector2i(2556, 1179), "insets": Vector4(177, 0, 177, 63)},
	"iphone17promax_2868x1320": {"size": Vector2i(2868, 1320), "insets": Vector4(186, 0, 186, 63)},
	"ipad13_2752x2064": {"size": Vector2i(2752, 2064), "insets": Vector4(0, 48, 0, 40)},
}
const SHOTS := ["boot", "menu", "first_menu", "start", "game", "throw", "hurt", "climb", "hang", "home", "pause", "resume",
		"gameover", "fell", "win", "settings", "settings_end"]
## Shots that start from another one's moment.
const MOMENT_OF := {"pause": "game", "resume": "game", "throw": "game", "hurt": "game", "gameover": "climb",
		"fell": "climb", "win": "home"}
## Moments of the bot's run used by the level shots: name -> condition on the world.
const MOMENTS := {
	"game": "ticks >= 250",
	"climb": "scroll > 5200 and y < 260",
	"hang": "hanging and scroll > 18000",
	"home": "at_end and x > 330",
}

var _out := ""
var _ads := true
var _moments := {}  # name -> World snapshot


func _ready() -> void:
	Save.persist = false
	var args := _args()
	var out: String = args.get("out", "user://captures")
	var langs: PackedStringArray = String(args.get("lang", "")).split(",", false)
	_ads = args.get("ads", "on") != "off"
	var devices: Array = args.get("devices", ",".join(DEVICES.keys())).split(",")
	var shots: Array = args.get("shots", ",".join(SHOTS)).split(",")
	var needed := {}
	for shot: String in shots:
		var m: String = MOMENT_OF.get(shot, shot)
		if MOMENTS.has(m):
			needed[m] = MOMENTS[m]
	if not needed.is_empty():
		_collect_moments(needed)
	for lang in (langs if not langs.is_empty() else PackedStringArray([""])):
		_out = out.path_join(lang) if langs.size() > 1 else out
		DirAccess.make_dir_recursive_absolute(_out)
		if not lang.is_empty():
			Save.language = lang
			Save.apply_language()
		for device: String in devices:
			for shot: String in shots:
				await _capture(device, shot)
		print("captures saved to ", ProjectSettings.globalize_path(_out))
	get_tree().quit()


## The bot's recorded run is replayed once, headless; the world is copied at each moment.
func _collect_moments(needed: Dictionary) -> void:
	var replay := BotReplay.recorded(1)
	var w := World.new()
	var t0 := Time.get_ticks_msec()
	while w.state == World.State.RUNNING and w.ticks < 9000 and _moments.size() < needed.size():
		replay.act(w)
		w.tick()
		for name: String in needed:
			if not _moments.has(name) and _check(w, needed[name]):
				_moments[name] = BotReplay.snapshot(w)
				print("  moment %s at %.1f s" % [name, w.ticks * World.TICK])
	print("  moments found in %d ms" % (Time.get_ticks_msec() - t0))


func _check(w: World, condition: String) -> bool:
	var e := Expression.new()
	e.parse(condition, ["ticks", "scroll", "x", "y", "hanging", "at_end"])
	return e.execute([w.ticks, w.scroll, w.x, w.y, w.hanging, w.at_end])


func _capture(device: String, shot: String) -> void:
	var d: Dictionary = DEVICES[device]
	var px: Vector2i = d.size
	# Same rule as the project's "keep_height" stretch: 640 tall, as wide as the screen's shape.
	var design := Vector2(640.0 * px.x / px.y, 640.0)
	var k := design.y / px.y
	Device.debug_insets = d.insets * k
	Device.banner_height = 50.0 * px.y / 411.0 * k if _ads and Config.is_debug else 0.0  # a 50 dp banner
	_reset_state()
	seed(shot.hash())  # the effects' random sparks and leaves: the same on every device and run

	var vp := SubViewport.new()
	vp.size = px
	vp.size_2d_override = Vector2i(design.round())
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var host := Control.new()
	host.size = design
	vp.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Nav.custom_viewport = vp
	Nav.attach(host)
	var banner: CanvasLayer = _fake_banner(vp, design) if Device.banner_height > 0 else null

	match shot:
		"boot":
			Nav.go(&"boot")
			await _wait(0.7)
		"menu":
			Save.games_played = 6
			Save.best_bobs = 64
			Save.best_stars = 2
			Nav.go(&"menu")
			await _wait(1.3)
		"first_menu":
			Save.tutorial_seen = false
			Nav.go(&"menu")
			await _wait(1.3)
		"start":  # the first run: the start card waits for a touch
			Save.tutorial_seen = false
			Nav.go(&"game", {})
			await _wait(1.0)
		"game", "climb", "hang":
			await _start_game(shot)
			await _wait(1.0)
		"home":  # in the doorway, the HUD gone (not caught in the middle of its fade)
			await _start_game(shot)
			await get_tree().process_frame  # (the autopilot starts the run)
			Nav.current.autopilot = null  # the run home is his own: no rings thrown at the hut
			await _wait_for(func() -> bool: return Nav.current.world.state != World.State.RUNNING, 5.0)
			await _wait(1.2)
		"throw":  # a bandit ahead, a ring on its way
			await _start_game("game")
			await _wait(0.3)
			var game: Node = Nav.current
			game.autopilot = null
			_bandit_ahead(game.world, 330.0)
			game.world.throw()
			await _wait(0.3)
		"hurt":  # a bandit runs into him: the instant after the blow
			await _start_game("game")
			await _wait(0.3)
			var game: Node = Nav.current
			game.autopilot = null
			var lives: int = game.world.lives
			game.world.mercy = 0
			_bandit_ahead(game.world, 150.0)
			await _wait_for(func() -> bool: return game.world.lives < lives, 3.0)
			await _wait(0.12)
		"pause":
			await _start_game("game")
			await _wait(0.5)
			Nav.current.pause_game()
			await _wait(0.6)
		"resume":  # the countdown's first number
			await _start_game("game")
			await _wait(0.5)
			Nav.current.pause_game()
			await _wait(0.6)
			Nav.current.resume_game()
			await _wait(0.2)
		"gameover", "fell":
			await _start_game("climb")
			await _wait(0.4)
			var game: Node = Nav.current
			game.autopilot = null
			game.world._die(&"bandit" if shot == "gameover" else &"fall")
			# his death plays first, then the panel arrives and settles (its buttons last)
			await _wait((World.DYING_TIME if shot == "gameover" else World.FALL_DEATH_TIME) + 1.5)
		"win":
			await _start_game("home")
			await get_tree().process_frame
			Nav.current.autopilot = null
			await _wait(4.5)
		"settings":
			Nav.go(&"settings")
			await _wait(1.0)
		"settings_end":  # every scrolling list scrolled to its end
			Nav.go(&"settings")
			await _wait(0.8)
			for s: ScrollContainer in Nav.current.find_children("*", "ScrollContainer", true, false):
				s.scroll_vertical = 100000
			await _wait(0.3)
	if banner:  # only where the game asks for one (not during play: [ads] banner_in_play)
		banner.visible = Services.ads.get(&"_banner_wanted") != false
	_draw_now()
	_save(vp.get_texture().get_image(), device, shot)
	if Nav.current:
		Nav.current.queue_free()
	Nav.reset()
	Nav.custom_viewport = get_tree().root
	if banner:
		banner.queue_free()
	vp.queue_free()
	await get_tree().process_frame


func _start_game(moment: String) -> void:
	var w: World = BotReplay.snapshot(_moments[moment]) if _moments.has(moment) else World.new()
	Nav.go(&"game", {"world": w})
	await get_tree().process_frame
	await get_tree().process_frame
	Nav.current.autopilot = Bot.new(7)


## Brings the last bandit (far away) `ahead` units in front of Panoramic, on his ground; the others
## near him go.
func _bandit_ahead(w: World, ahead: float) -> void:
	for b in w.bandits:
		if absf(b.x - w.scroll - w.x) < 1500.0:
			b.gone = true
	var b: World.Bandit = w.bandits[-1]
	b.gone = false
	b.active = true
	b.health = World.BANDIT_HEALTH
	b.x = w.scroll + w.x + ahead
	b.y = w.ground_y + 10.0
	b.prev_x = b.x
	b.prev_y = b.y


## Waits until `done` is true, at most `seconds`.
func _wait_for(done: Callable, seconds: float) -> void:
	var t := 0.0
	while not done.call() and t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


## A grey stand-in where AdMob's banner goes (debug builds), so layouts can be checked.
func _fake_banner(vp: SubViewport, design: Vector2) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 90
	vp.add_child(layer)
	var r := ColorRect.new()
	r.color = Color(0.15, 0.15, 0.15, 0.9)
	var w := 320.0 * Device.banner_height / 50.0
	r.size = Vector2(w, Device.banner_height)
	r.position = Vector2((design.x - w) / 2, design.y - Device.banner_height - Device.debug_insets.w)
	layer.add_child(r)
	var l := Label.new()
	l.text = "Ad banner (test)"
	l.add_theme_font_size_override(&"font_size", 14)
	l.position = r.position + Vector2(10, 6)
	layer.add_child(l)
	return layer


func _reset_state() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Save.best_bobs = 0
	Save.best_stars = 0
	Save.games_played = 0
	Save.game_overs_since_ad = 0
	Save.tutorial_seen = true


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _save(img: Image, device: String, shot: String) -> void:
	var path := "%s/%s__%s.png" % [_out, device, shot]
	img.save_png(path)
	print("  ", device, " ", shot, " ", img.get_size())


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			out[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	return out


## Draws this frame now. macOS doesn't draw a covered window, or one on another desktop, while the
## game keeps running: waiting for the next drawn frame could skip moments or wait forever.
func _draw_now() -> void:
	RenderingServer.force_draw(false)

@tool
class_name WorldView
extends Node2D
## Draws a World in play-window units (the game screen scales this node to the screen): the
## parallax background, the tiles, Red Bobs, home, bandits, rings and Panoramic, each placed
## between two ticks of the rules so motion is smooth at any refresh rate.

signal bob_popped(at: Vector2)  ## where a Red Bob was collected, in this node's units
signal bandit_leapt(strong: bool)  ## (2026-11-10) a bandit left the ground on a leap, and came down (for the sounds)
signal bandit_landed(strong: bool, hard: float)

const HANG_DRAW_DROP := 58.0  ## the rules hang him half above the screen: draw him below its top
const BANDIT_RIGHT := 46.0  ## round 10: units a bandit's picture reaches right of its feet (QA: 960-1069 at x 1024)
## Round 9: the pictures the pools mirror (their savanna strips and the sky)
const WATER_MIRRORS := {"grass_tex": "near_grass", "hills_tex": "mid_hills", "sky_tex": "sky"}
const EXTRA_COLUMNS := 70  ## ground drawn past the end of the map for wide screens

var world: World
## Play units visible left of the play window (under a notch) and the total visible width.
var view_left := 0.0
var view_width := World.VIEW_W
## Play y at the top of the screen: below 0 when the camera draws back (GameScreen), sky above.
var view_top := 0.0
## Round 10 (QA ENV-1): while the start card holds the world (GameScreen), a waiting bandit whose
## picture is not wholly inside the screen's safe area is not drawn (the level's first one stood
## cut by the right edge, in the phone's rounded corner); it fades in once the run starts.
var start_hold := false
var safe_right := INF  ## play x of the right edge of the screen's safe area (GameScreen)

var _background: SavannaView
var _vine: VineView
var _level_root: Node2D
var _props: PropView  # trees, rocks, shrubs: the 2017 decorations redrawn, and some dressing
var _ground: TerrainView  # the painted ground (its front blades are drawn above the actors)
var _grade: ColorRect  # the light over the whole world (light_grade.gdshader), under the effects
var _splash_feet := {}  # -1 (Panoramic) or a bandit id -> feet y in the last frame
var _home: HomeView  # the homestead on the last screen (its front is drawn above the actors)
var _actors: Node2D
var _bobs := {}  # Vector2i -> BobView
var _bandits := {}  # bandit id -> BanditView
var _rings := {}  # ring id -> RingView
var _ring_of := {}  # ring id -> [its World.Ring, the tick it was last flying at] (_place_rings)
var _struck := -1  # the id of the ring that just struck a bandit (_ring_contact), or -1
var _hero: HeroView
## Effects layer: the Fx kit is sized for a 1280-tall design, so it draws at half scale here.
var fx: Node2D
var _dust_clock := 0.0
var _ground_task := -1  # round 10: the worker thread working out the ground's data (-1: none)
var _water: Array[ShaderMaterial] = []  # the pools' (round 9: the scroll for their reflection)
var _was_climbing := false
var _bandit_air := {}  # bandit id -> it was in a leap in the last frame


func setup(w: World) -> void:
	world = w
	_background = SavannaView.new()
	_background.name = &"Savanna"  # (round 12, QA: names for perf.tscn --hide)
	add_child(_background)

	_level_root = Node2D.new()
	_level_root.name = &"Level"
	add_child(_level_root)
	_add_home()
	_add_water()
	_add_props()
	_add_ground()
	_add_water_front()
	_level_root.add_child(_home.yard)  # trodden earth over the grass before the hut's door
	for c in Level.COLS:
		for r in Level.ROWS:
			if w.level.kind_at(c, r) == Level.Kind.BOB:
				var bob := BobView.new(c, r)
				bob.position = Vector2(c + 0.5, r + 0.5) * Level.TILE
				_level_root.add_child(bob)
				_bobs[Vector2i(c, r)] = bob

	_vine = VineView.new()
	_vine.name = &"Vine"
	add_child(_vine)
	_actors = Node2D.new()
	_actors.name = &"Actors"
	add_child(_actors)
	_hero = HeroView.new()
	_actors.add_child(_hero)
	add_child(_ground.front)
	w.landed.connect(_hero.landed)
	w.jumped.connect(_hero.jumped)
	w.thrown.connect(func(_r: World.Ring) -> void: _hero.threw())
	w.hurt.connect(func(_b: World.Bandit, _l: int) -> void: _hero.hurt())
	add_child(_home.front)
	add_child(_background.front)
	_add_grade()
	fx = Node2D.new()
	fx.name = &"WorldFx"
	fx.scale = Vector2.ONE * 0.5
	# (over everything in the level by its place, the last child: round 4: no z_index, which put the
	# effects over the HUD too)
	add_child(fx)
	if OS.is_debug_build():  # the rules' boxes over everything, off until F3 (never in a release)
		add_child(CollisionOverlay.new(w))

	w.bob_collected.connect(_on_bob)
	w.bandit_hit.connect(_on_bandit_hit)
	w.hurt.connect(func(_b: World.Bandit, _l: int) -> void: Fx.impact(fx, _fx(world.draw_hero()), -1.0))
	w.landed.connect(func() -> void: _dust(int(lerpf(6.0, 22.0, clampf(w.land_speed / 50.0, 0.0, 1.0))), Vector2(70, 190)))
	w.jumped.connect(func() -> void: _dust(8, Vector2(40, 120)))
	w.hung.connect(_on_hung)
	refresh()



## Round 3: the world's shaders, compiled before the level opens (warm_up()).
const SHADERS := ["res://src/game/terrain.gdshader", "res://src/game/water.gdshader",
		"res://src/game/water_front.gdshader", "res://src/game/haze.gdshader", "res://src/game/light_grade.gdshader",
		"res://src/game/form.gdshader", "res://src/game/sway.gdshader", "res://src/game/actor.gdshader",
		"res://src/game/flash.gdshader", "res://src/game/shine_text.gdshader", "res://src/game/ink.gdshader",
		"res://src/game/bandit.gdshader"]


## Draws each of the world's shaders once, unseen (a pixel in a corner, nearly transparent, for half
## a second), so they are compiled before the level opens (GameArt calls it from the menu once the
## level's scripts are loaded): they cost ~60 ms in the frame the level first showed.
static func warm_up() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return
	var holder := Node2D.new()
	holder.name = &"ShaderWarmUp"
	for path: String in SHADERS:
		var r := ColorRect.new()
		r.size = Vector2.ONE
		r.modulate.a = 0.02
		var m := ShaderMaterial.new()
		m.shader = load(path)
		r.material = m
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(r)
	tree.root.add_child.call_deferred(holder)  # (called from a menu's _ready too: the root may be busy)
	holder.create_tween().tween_callback(holder.queue_free).set_delay(0.5)  # (dies with it: no timer)


## The painted ground (TerrainView), from a little before the map to past its end for wide screens.
## Round 3: its picture of the map is worked out on the next frame (both are under the screen
## wipe's cover): the frame the level opened in was too long (ENV-1).
func _add_ground() -> void:
	_ground = TerrainView.new()
	_ground.name = &"Ground"
	_level_root.add_child(_ground)
	if is_inside_tree():
		# (round 10, QA: the open frame took ~80 ms: the ground's data is worked out on a worker
		# thread meanwhile, only its layers are made the next frame)
		_ground_task = WorkerThreadPool.add_task(_ground.prepare.bind(world.level, -12, Level.COLS + EXTRA_COLUMNS))
		get_tree().process_frame.connect(_build_ground, CONNECT_ONE_SHOT)
	else:
		_build_ground()


func _build_ground() -> void:
	_join_ground()
	if not _ground.is_built():
		_ground.build(world.level, -12, Level.COLS + EXTRA_COLUMNS)


func _join_ground() -> void:
	if _ground_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_ground_task)
		_ground_task = -1


func _exit_tree() -> void:
	_join_ground()  # (the thread must not outlive the ground it fills)


## HOME: the homestead over the last screen; Panoramic walks into the hut's doorway.
func _add_home() -> void:
	_home = HomeView.new()
	add_child(_home)  # for its clock (the fire's flicker)
	_home.build()
	world.won.connect(_home.welcome)
	_level_root.add_child(_home.back)


## The props of the map (each 2017 decoration as a new picture) and the dressing of grass runs,
## behind the ground's grass blades.
func _add_props() -> void:
	_props = PropView.new()
	_props.name = &"Props"
	_level_root.add_child(_props)
	_props.build(world.level, _solid, -12, Level.COLS + EXTRA_COLUMNS)


## Grass tops and walls are solid; past either end of the map the edge column repeats.
func _solid(c: int, r: int) -> bool:
	if r >= Level.ROWS:
		return _solid(c, Level.ROWS - 1)
	var k := Level.kind_of(world.level.id_at(clampi(c, 0, Level.COLS - 1), r))
	return k == Level.Kind.TOP or k == Level.Kind.SIDE


## One shaded pool per run of water-surface tiles, down past the bottom of the screen.
func _add_water() -> void:
	for r in Level.ROWS:
		var c := 0
		while c < Level.COLS:
			if world.level.kind_at(c, r) != Level.Kind.WATER:
				c += 1
				continue
			var start := c
			while c < Level.COLS and world.level.kind_at(c, r) == Level.Kind.WATER:
				c += 1
			var rect := ColorRect.new()
			rect.name = "Water%d" % start
			# a little wider than the gap: the banks (drawn after) overlap it, no sky shows between
			rect.position = Vector2(start * Level.TILE - 8.0, r * Level.TILE)
			rect.size = Vector2((c - start) * Level.TILE + 16.0, World.VIEW_H - r * Level.TILE + 40.0)
			var m := ShaderMaterial.new()
			m.shader = preload("res://src/game/water.gdshader")
			m.set_shader_parameter("rect_size", rect.size)
			m.set_shader_parameter("x_offset", rect.position.x)
			m.set_shader_parameter("soil_tex", load("res://assets/art/world/soil.png"))
			m.set_shader_parameter("level_top", rect.position.y)  # (round 9) the savanna mirrored in it
			for name: String in ["grass_tex", "hills_tex", "sky_tex"]:
				m.set_shader_parameter(name, load(SavannaView.DIR + WATER_MIRRORS[name] + ".png"))
			m.set_shader_parameter("grass_strip", _strip(&"near_grass"))
			m.set_shader_parameter("hills_strip", _strip(&"mid_hills"))
			_water.append(m)
			rect.material = m
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_level_root.add_child(rect)


## Round 9: a strip of the savanna as the water shader reads it: scroll factor, bottom y, units a
## texture pixel, height in units.
func _strip(name: StringName) -> Vector4:
	var s: Array = SavannaView.STRIPS[name]
	var tex: Texture2D = load(SavannaView.DIR + String(name) + ".png")
	return Vector4(s[0], s[1], s[2], tex.get_height() * s[2])


## The banks and the poles standing in the pools, seen through the water under its surface, with
## foam lapping round them (water_front.gdshader), over the ground.
func _add_water_front() -> void:
	var r := Level.ROWS - 2  # the pools' surface row
	for c in Level.COLS:
		var k := world.level.kind_at(c, r)
		if k != Level.Kind.TOP and k != Level.Kind.SIDE:
			continue
		var water_w := world.level.kind_at(c - 1, r) == Level.Kind.WATER
		var water_e := world.level.kind_at(c + 1, r) == Level.Kind.WATER
		if not water_w and not water_e:
			continue
		var x0 := c * Level.TILE - 2.0 if water_w else c * Level.TILE + Level.TILE - 18.0
		var x1 := (c + 1) * Level.TILE + 2.0 if water_e else c * Level.TILE + 18.0
		var rect := ColorRect.new()
		rect.position = Vector2(x0, r * Level.TILE)
		rect.size = Vector2(x1 - x0, World.VIEW_H - r * Level.TILE + 40.0)
		var m := ShaderMaterial.new()
		m.shader = preload("res://src/game/water_front.gdshader")
		m.set_shader_parameter("rect_size", rect.size)
		m.set_shader_parameter("x_offset", rect.position.x)
		m.set_shader_parameter("fade_left", 0.0 if water_w else 14.0)
		m.set_shader_parameter("fade_right", 0.0 if water_e else 14.0)
		rect.material = m
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_level_root.add_child(rect)


## A splash when Panoramic or a bandit drops through the surface of a pool.
func _watch_splashes(scroll: float) -> void:
	var surface := (Level.ROWS - 2) * Level.TILE + 6.0
	var p := world.draw_hero()
	_splash_check(-1, p.x + scroll, p.y + World.HERO_SIZE.y / 2, surface, scroll, 1.0)
	for b in world.bandits:
		if not b.gone and b.active:
			_splash_check(b.id, b.x, b.y + World.BANDIT_SIZE.y / 2, surface, scroll, 0.7)


func _splash_check(id: int, level_x: float, feet: float, surface: float, scroll: float, size: float) -> void:
	var before: float = _splash_feet.get(id, feet)
	_splash_feet[id] = feet
	var into := before < surface and feet >= surface
	var out := id == -1 and before > surface and feet <= surface and world.vy < -10.0  # he springs back out (World.sprang)
	if out:  # back from the pit: a flash of light where he breaks the surface, a trail as he rises
		var at0 := _fx(Vector2(level_x - scroll, surface))
		Fx.glow(fx, at0, Color(0.75, 0.9, 1.0, 0.9), 0.3, 1.6, 0.3)
		Fx.ring(fx, at0, 20.0, 150.0, 0.35, Color(1, 1, 1, 0.9), 10.0)
		var trail := Fx.trail(fx, _hero, Color(0.8, 0.93, 1.0, 0.55), 36.0, 0.22, true)
		# (New: timed on the trail itself, a tween dies with its node: a timer outlived the screen)
		trail.create_tween().tween_callback(trail.set.bind(&"target", null)).set_delay(0.45)
	if (into or out) and world.level.kind_at(int(level_x / Level.TILE), Level.ROWS - 2) == Level.Kind.WATER:
		Fx.splash(fx, _fx(Vector2(level_x - scroll, surface)), size * (0.8 if out else 1.0))


## The low sun's light and the vignette over the world: one rectangle with light_grade.gdshader.
func _add_grade() -> void:
	_grade = ColorRect.new()
	_grade.name = &"LightGrade"
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/game/light_grade.gdshader")
	_grade.material = m
	add_child(_grade)


func _place_grade() -> void:
	# (2 units past the view on every side: a Control snaps to whole units, and where the camera's top fell between two
	# the screen's first row was left ungraded: a bright hairline along the top edge as he climbed)
	var at := Vector2(-view_left - 2.0, view_top - 2.0)
	var size := Vector2(view_width + 4.0, World.VIEW_H - view_top + 4.0)
	var m := _grade.material as ShaderMaterial
	if _grade.size != size or _grade.position != at:
		_grade.position = at
		_grade.size = size
		m.set_shader_parameter(&"aspect", size.x / size.y)
	m.set_shader_parameter(&"sun", (_background.sun_position() - _grade.position) / size)  # the light comes from it


## Places everything for the current frame (after the world has advanced).
func refresh(delta := 0.0) -> void:
	var scroll := world.draw_scroll()
	for layer: Node in [_background, _vine]:
		layer.scroll = scroll
		layer.view_left = view_left
		layer.view_width = view_width
	_background.view_top = view_top
	_background.hero_x = world.draw_hero().x
	_level_root.position.x = -scroll
	_ground.front.position.x = -scroll
	_ground.ensure(scroll - view_left - 96.0, scroll - view_left + view_width + 96.0)
	_ground.build_ahead(scroll - view_left + view_width)
	_props.ensure(scroll - view_left - 96.0, scroll - view_left + view_width + 96.0)
	_props.build_ahead(scroll - view_left + view_width)
	_home.front.position.x = -scroll
	# (round 3) the jamb and the wall right of the doorway go over him from his walk in
	_home.front.visible = world.state == World.State.WON and world.end_time >= World.HOME_CHEER
	# (round 5) home: the dark grass along the bottom edge clears, his feet on a clear ground line
	var home_k := 1.0 if world.state == World.State.WON else 0.0
	_background.front.modulate.a = move_toward(_background.front.modulate.a, 1.0 - 0.85 * home_k, delta * 2.0)
	_place_grade()
	for m in _water:
		m.set_shader_parameter(&"scroll", scroll)
	_watch_splashes(scroll)
	_place_hero(delta)
	_place_bandits(scroll, delta)
	_place_rings()


func _place_hero(delta: float) -> void:
	var p := world.draw_hero()
	_hero.show_state(world, p, delta)
	_vine.hold(world.hanging and world.state == World.State.RUNNING, p.x, delta)
	if world.hanging:  # (round 2) he hangs from the vine where it is: it dips under him
		_hero.position.y += _vine.sag_at(p.x)
	if world.climbing and not _was_climbing:  # his feet hit the wall: a puff of grit off its face
		_dust(12, Vector2(60, 160), 26.0)
	_was_climbing = world.climbing
	# small puffs of dust behind his feet while he runs
	if world.on_ground and not world.hanging and not world.blocked and world.state == World.State.RUNNING:
		_dust_clock += delta
		if _dust_clock > 0.22:
			_dust_clock = 0.0
			_dust(3, Vector2(20, 60), -18.0)


func _feet() -> Vector2:
	var p := world.draw_hero()
	return Vector2(p.x, p.y + World.HERO_SIZE.y / 2 + GameArt.FEET_SINK - 4.0)


## Savanna dust at Panoramic's feet.
func _dust(amount: int, speed: Vector2, dx := 0.0) -> void:
	var drift := 0.0 if world.blocked or world.at_end else -World.SCROLL_SPEED / World.TICK * 2.0
	Fx.dust(fx, _fx(_feet() + Vector2(dx, 2)), amount, speed.y * 1.6, drift, 0.8 + amount / 18.0)


func _fx(p: Vector2) -> Vector2:
	return p * 2.0


func _on_bandit_hit(b: World.Bandit, knocked_out: bool) -> void:
	var v: BanditView = _bandits.get(b.id)
	if v:
		v.hit(knocked_out)
	if knocked_out:
		_hero.cheer()
	var at := _ring_contact(b)
	_ring_back(at)
	if knocked_out:
		Fx.knock_out(fx, _fx(at), _fx(Vector2(b.x - world.scroll, b.y + World.BANDIT_SIZE.y / 2 + GameArt.FEET_SINK)))
	else:
		Fx.ring_hit(fx, _fx(at))


## The chakram comes back (RingView.rebound): the ring that just struck a bandit at `at` flies back to his hand; a
## glint as he takes it.
func _ring_back(at: Vector2) -> void:
	var s: RingView = _rings.get(_struck)
	if not s:
		return
	_rings.erase(_struck)
	_ring_of.erase(_struck)
	s.position = at
	s.rebound(_catch_point)
	s.caught.connect(func(p: Vector2) -> void: Fx.glint(fx, _fx(p), 44.0, 0.16))


## Where his hand takes the chakram back (the actors' units): his thrown fist's height on the run, his chest else.
func _catch_point() -> Vector2:
	var p := world.draw_hero()
	if world.on_ground and not world.hanging:
		return p + Vector2(HeroView.THROW_FIST.x * 0.5, World.HERO_SIZE.y / 2 + HeroView.THROW_FIST.y)
	return p + Vector2(16.0, -10.0)


## (collision pass) Where the ring that just hit bandit `b` met its drawn body: at the ring, on the front of its
## body (the burst was at its 2017 box, on the back of its picture, ~35 units behind where the ring hits).
func _ring_contact(b: World.Bandit) -> Vector2:
	var body := world.bandit_hit_rect(b)
	var at := Vector2(body.position.x + 8.0, body.get_center().y - 12.0)
	_struck = -1
	for id: int in _ring_of:
		var r: World.Ring = _ring_of[id][0]
		var box := World.ring_box(r.x, r.y)
		if not world.rings.has(r) and box.intersects(body):
			_struck = id
			at = Vector2(maxf(box.get_center().x, body.position.x + 4.0), clampf(box.get_center().y, body.position.y + 8.0, body.end.y - 8.0))
	return at


func _on_hung() -> void:
	_vine.caught()
	var p := _fx(Vector2(world.x, HeroView.VINE_Y + 2.0))
	Fx.ring(fx, p, 8.0, 60.0, 0.3, Color(1, 0.9, 0.55, 0.9), 8.0)
	Confetti.make(fx, p).sparkle(5, Fx.SPARKS, Vector2(100, 260), 0.8, Vector2(0.3, 0.5))


## His drawn body in screen pixels (hanging, the pose reaches down from the vine).
func hero_screen_rect() -> Rect2:
	var p := world.draw_hero()
	var k := HeroView.DRAW_SCALE
	var feet := p.y + World.HERO_SIZE.y / 2  # standing poses are drawn up from the feet, ~180 units at 1x
	var r := Rect2(p.x - 44.0 * k, 0.0, 88.0 * k, 165.0 * k) if world.hanging \
			else Rect2(p.x - 50.0 * k, feet - 180.0 * k, 100.0 * k, 180.0 * k)
	return _actors.get_global_transform() * r


func _place_bandits(scroll: float, delta: float) -> void:
	for b in world.bandits:
		var v: BanditView = _bandits.get(b.id)
		if b.gone:
			if v:
				_bandits.erase(b.id)
				if b.health <= 0:  # knocked out: it tumbles away in the level (BanditView.hit)
					v.reparent(_level_root)
				else:
					v.leave()
			continue
		var near := b.x - scroll > -view_left - 100 and b.x - scroll < view_width + 100
		if not near:
			if v:
				v.queue_free()
				_bandits.erase(b.id)
			continue
		if not v:
			v = BanditView.new(world, b)
			_actors.add_child(v)
			_actors.move_child(v, 0)  # behind Panoramic and the rings
			_bandits[b.id] = v
		var standing := absf(b.y - b.prev_y) < 4.0 and b.arc == 0 and not b.leaping
		var y := minf(b.prev_y, b.y) if standing else lerpf(b.prev_y, b.y, world.alpha)  # not the snap flicker
		var x := lerpf(b.prev_x, b.x, world.alpha) - scroll
		if not b.active:  # waiting: where its first tick will put it (out of a rock, on its grass)
			x = b.wait_x - scroll
			y = b.wait_y
		# pressed on a wall (the rules let it 8 units from the face and shove it back on each touch):
		# drawn with its club on the face, steady, not inside the wall and not jittering
		var face := world.wall_behind(x, y, World.BANDIT_SIZE.y / 2, BanditView.REACH, scroll) if b.health > 0 else -1.0
		var push := maxf(face + BanditView.REACH - x, 0.0) if face >= 0.0 else 0.0
		v.wall_shift = push if push > v.wall_shift else lerpf(v.wall_shift, push, 1.0 - exp(-delta * 12.0))
		v.position = Vector2(x + v.wall_shift, y + World.BANDIT_SIZE.y / 2 + GameArt.FEET_SINK)
		# (the user, 2026-11-08: "at a wall they keep running up it: they must jump") on the ground when it barely moved
		# up or down this tick (the rules' snap onto its ledge moves it < 4 units) and is not pressed on a wall's face:
		# against a wall, hopping up it, it shows its leap
		v.show_state((standing and push <= 0.0) or not b.active, delta)
		# (2026-11-10) its leaps: a puff of dust and a stretch as it leaves the ground, dust and a squash as it lands
		# (a drop off a ledge too: World.Bandit.landed_tick)
		var in_air := b.arc > 0 or b.leaping
		var was_air: bool = _bandit_air.get(b.id, false)
		_bandit_air[b.id] = in_air
		var feet := Vector2(x + v.wall_shift, y + World.BANDIT_SIZE.y / 2 + GameArt.FEET_SINK - 2.0)
		if in_air and not was_air and world.state == World.State.RUNNING:
			v.took_off()
			Fx.dust(fx, _fx(feet), 7, 150.0, 0.0, 0.9)
			bandit_leapt.emit(b.strong)
		elif b.active and b.landed_tick == world.ticks and v.landed_seen != b.landed_tick:
			v.landed_seen = b.landed_tick
			var hard := 1.0 if b.strong else 0.75
			v.touched_down(hard)
			Fx.dust(fx, _fx(feet), 10 if b.strong else 7, 190.0, 0.0, 1.0)
			bandit_landed.emit(b.strong, hard)
		var held := start_hold and not b.active and x + v.wall_shift + BANDIT_RIGHT > safe_right
		if world.state == World.State.WON:  # home: one still standing (a jumper that dodged) fades away, not frozen there
			v.modulate.a = move_toward(v.modulate.a, 0.0, delta * 4.0)
		else:
			v.modulate.a = 0.0 if held else move_toward(v.modulate.a, 1.0, delta * 4.0)
		# one still waiting out of the play window over a hole would stand on air: not drawn
		if not b.active:
			var feet_row := floori((b.wait_y + World.BANDIT_SIZE.y / 2 + 4.0) / Level.TILE)
			v.visible = world.level.kind_at(clampi(floori(b.wait_x / Level.TILE), 0, Level.COLS - 1), clampi(feet_row, 0, Level.ROWS - 1)) == Level.Kind.TOP
		else:
			v.visible = true


func _place_rings() -> void:
	var seen := {}
	for r in world.rings:
		seen[r.id] = true
		_ring_of[r.id] = [r, world.ticks]
		var s: RingView = _rings.get(r.id)
		if not s:
			s = RingView.new()
			_actors.add_child(s)
			_rings[r.id] = s
			if world.on_ground and not world.hanging:  # thrown on the run: out of his thrown fist
				var feet := world.draw_hero() + Vector2(0.0, World.HERO_SIZE.y / 2)
				s.from_hand = feet + HeroView.THROW_FIST - (Vector2(r.x, r.y) + World.RING_CENTRE)
				s.hand_time = RingView.HAND_ARC
		s.position = Vector2(lerpf(r.prev_x, r.x, world.alpha), r.y) + World.RING_CENTRE
		if world.state == World.State.WON:  # home: rings still flying fade away (none lies about the yard)
			s.modulate.a = move_toward(s.modulate.a, 0.0, 0.08)
	for id: int in _rings.keys():
		if seen.has(id):
			continue
		# (collision pass) a ring that met a bandit or rock in the last tick is drawn where it met it while that tick
		# is drawn (and held through the hit-stop): the rules met it there against the bandit as it is drawn then (its
		# place before this tick's run); interpolated, it vanished a tick short of what it hit
		var last: Array = _ring_of.get(id, [])
		if not last.is_empty() and world.ticks == last[1] + 1 and world.state == World.State.RUNNING:
			var r: World.Ring = last[0]
			_rings[id].position = Vector2(r.x, r.y) + World.RING_CENTRE
			_rings[id].met()
			continue
		_rings[id].queue_free()
		_rings.erase(id)
		_ring_of.erase(id)


## A Red Bob taken: a puff of warm light and sparks where it was; the game screen flies a copy of
## it to the counter (bob_popped).
func _on_bob(col: int, row: int) -> void:
	var bob: BobView = _bobs.get(Vector2i(col, row))
	if not bob:
		return
	_bobs.erase(Vector2i(col, row))
	var at := bob.position + _level_root.position
	bob_popped.emit(at)
	var p := _fx(at)
	Fx.glow(fx, p, Color(1, 0.55, 0.35, 0.75), 0.25, 1.1, 0.22)
	Fx.ring(fx, p, 10.0, 52.0, 0.24, Color(1, 0.86, 0.6, 0.85), 6.0)
	Confetti.make(fx, p).sparkle(6, Fx.BOB_BITS, Vector2(120, 320), 0.7, Vector2(0.3, 0.5))
	bob.queue_free()


func hero_position() -> Vector2:
	return world.draw_hero()

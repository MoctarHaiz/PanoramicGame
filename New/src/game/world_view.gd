class_name WorldView
extends Node2D
## Draws a World in play-window units (the game screen scales this node to the screen): the
## parallax background, the tiles, Red Bobs, home, bandits, rings and Panoramic, each placed
## between two ticks of the rules so motion is smooth at any refresh rate.

signal bob_popped(at: Vector2)  ## where a Red Bob was collected, in this node's units

const HANG_DRAW_DROP := 58.0  ## the rules hang him half above the screen: draw him below its top
const EXTRA_COLUMNS := 70  ## ground drawn past the end of the map for wide screens

var world: World
## Play units visible left of the play window (under a notch) and the total visible width.
var view_left := 0.0
var view_width := World.VIEW_W
## Play y at the top of the screen: below 0 when the camera draws back (GameScreen), sky above.
var view_top := 0.0

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
var _hero: HeroView
## Effects layer: the Fx kit is sized for a 1280-tall design, so it draws at half scale here.
var fx: Node2D
var _dust_clock := 0.0
var _was_climbing := false


func setup(w: World) -> void:
	world = w
	_background = SavannaView.new()
	add_child(_background)

	_level_root = Node2D.new()
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
	add_child(_vine)
	_actors = Node2D.new()
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
	fx.scale = Vector2.ONE * 0.5
	fx.z_index = 10  # over everything in the level (the Red Bobs included)
	add_child(fx)

	w.bob_collected.connect(_on_bob)
	w.bandit_hit.connect(_on_bandit_hit)
	w.hurt.connect(func(_b: World.Bandit, _l: int) -> void: Fx.impact(fx, _fx(world.draw_hero()), -1.0))
	w.landed.connect(func() -> void: _dust(int(lerpf(6.0, 22.0, clampf(w.land_speed / 50.0, 0.0, 1.0))), Vector2(70, 190)))
	w.jumped.connect(func() -> void: _dust(8, Vector2(40, 120)))
	w.hung.connect(_on_hung)
	w.won.connect(_on_won)
	refresh()


## The painted ground (TerrainView), from a little before the map to past its end for wide screens.
func _add_ground() -> void:
	_ground = TerrainView.new()
	_level_root.add_child(_ground)
	_ground.build(world.level, -12, Level.COLS + EXTRA_COLUMNS)


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
			# a little wider than the gap: the banks (drawn after) overlap it, no sky shows between
			rect.position = Vector2(start * Level.TILE - 8.0, r * Level.TILE)
			rect.size = Vector2((c - start) * Level.TILE + 16.0, World.VIEW_H - r * Level.TILE + 40.0)
			var m := ShaderMaterial.new()
			m.shader = preload("res://src/game/water.gdshader")
			m.set_shader_parameter("rect_size", rect.size)
			m.set_shader_parameter("x_offset", rect.position.x)
			m.set_shader_parameter("soil_tex", load("res://assets/art/world/soil.png"))
			rect.material = m
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_level_root.add_child(rect)


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
		get_tree().create_timer(0.45).timeout.connect(func() -> void: trail.target = null)
	if (into or out) and world.level.kind_at(int(level_x / Level.TILE), Level.ROWS - 2) == Level.Kind.WATER:
		Fx.splash(fx, _fx(Vector2(level_x - scroll, surface)), size * (0.8 if out else 1.0))


## The low sun's light and the vignette over the world: one rectangle with light_grade.gdshader.
func _add_grade() -> void:
	_grade = ColorRect.new()
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/game/light_grade.gdshader")
	_grade.material = m
	add_child(_grade)


func _place_grade() -> void:
	var size := Vector2(view_width, World.VIEW_H - view_top)
	if _grade.size != size or _grade.position != Vector2(-view_left, view_top):
		_grade.position = Vector2(-view_left, view_top)
		_grade.size = size
		(_grade.material as ShaderMaterial).set_shader_parameter(&"aspect", size.x / size.y)


## Places everything for the current frame (after the world has advanced).
func refresh(delta := 0.0) -> void:
	var scroll := world.draw_scroll()
	for layer: Node in [_background, _vine]:
		layer.scroll = scroll
		layer.view_left = view_left
		layer.view_width = view_width
	_background.view_top = view_top
	_level_root.position.x = -scroll
	_ground.front.position.x = -scroll
	_ground.ensure(scroll - view_left - 96.0, scroll - view_left + view_width + 96.0)
	_ground.build_ahead(scroll - view_left + view_width)
	_home.front.position.x = -scroll
	_place_grade()
	_watch_splashes(scroll)
	_place_hero(delta)
	_place_bandits(scroll, delta)
	_place_rings()


func _place_hero(delta: float) -> void:
	var p := world.draw_hero()
	_hero.show_state(world, p, delta)
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
	var at := Vector2(b.x - world.scroll - 6.0, b.y - 10.0)
	if knocked_out:
		Fx.knock_out(fx, _fx(at), _fx(Vector2(at.x + 6.0, b.y + World.BANDIT_SIZE.y / 2 + GameArt.FEET_SINK)))
	else:
		Fx.ring_hit(fx, _fx(at))


## Home: confetti bursting out of the doorway as he goes in.
func _on_won() -> void:
	var door := Vector2(HomeView.DOOR_RIGHT - 40.0, HomeView.GROUND - 70.0)
	get_tree().create_timer(0.55).timeout.connect(func() -> void: Fx.confetti_burst(fx, _fx(door)))


func _on_hung() -> void:
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
		var standing := absf(b.y - b.prev_y) < 4.0
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
		v.show_state(standing)
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
		var s: RingView = _rings.get(r.id)
		if not s:
			s = RingView.new()
			_actors.add_child(s)
			_rings[r.id] = s
		s.position = Vector2(lerpf(r.prev_x, r.x, world.alpha) + 12.0, r.y + 14.0)
		if world.state == World.State.WON:  # home: rings still flying fade away (none lies about the yard)
			s.modulate.a = move_toward(s.modulate.a, 0.0, 0.08)
	for id: int in _rings.keys():
		if not seen.has(id):
			_rings[id].queue_free()
			_rings.erase(id)


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

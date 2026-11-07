class_name CollisionOverlay
extends Node2D
## Debug builds only (WorldView adds it; a release never has it): every box the rules test, drawn over
## the pictures in play units where they are drawn (between two ticks), so what the player sees can be
## checked against what the game counts. Off by default: F3 shows it (tests/capture.gd: --boxes=on).
## The boxes come from World's own functions, so they are always the ones the rules use:
##   white            his body (body_rect): stands on grass, climbs ledges, takes Red Bobs
##   blue             his chest and feet (chest_rect, feet_rect): walls stop them
##   magenta, filled  what a bandit's blow hurts (hurt_rect)
##   orange           a bandit's 2017 box (bandit_rect): its ground and walls
##   yellow           its drawn body (bandit_hit_rect): what rings hit
##   red; filled      what its blow comes from: its body to the back of its head (bandit_blow_rect); its fist
##   cyan / blue      a ring: what hits bandits (ring_hit_rect) / what stops at rock (ring_wall_rect)
##   green / brown    grass tops, walls (as he and bandits meet them: SIDE_SHRINK smaller; rings meet whole cells);
##                    gold: Red Bobs; light blue: the pools' surface; the dashed line: his centre there hangs him

static var shown := false

const HERO_BODY := Color(1, 1, 1, 0.9)
const HERO_WALL := Color(0.3, 0.55, 1.0, 0.9)
const HURT := Color(1.0, 0.2, 0.9, 0.95)
const BANDIT_BOX := Color(1.0, 0.6, 0.1, 0.9)
const BANDIT_HIT := Color(1.0, 0.95, 0.2, 0.95)
const BLOW := Color(1.0, 0.15, 0.1, 0.95)
const RING_HIT := Color(0.2, 1.0, 1.0, 0.95)
const RING_WALL := Color(0.2, 0.35, 1.0, 0.95)
const TOP := Color(0.3, 1.0, 0.3, 0.7)
const SIDE := Color(0.75, 0.4, 0.2, 0.75)
const BOB := Color(1.0, 0.8, 0.1, 0.9)
const WATER := Color(0.5, 0.85, 1.0, 0.9)
const LINE := 1.5

var world: World
var _font: Font


func _init(w: World) -> void:
	world = w
	name = &"CollisionOverlay"
	_font = ThemeDB.fallback_font
	visible = shown


func _process(_delta: float) -> void:
	visible = shown
	if shown:
		queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F3:
		shown = not shown
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var w := world
	var view := get_parent() as WorldView
	var left := -view.view_left if view else 0.0
	var width := view.view_width if view else World.VIEW_W
	var top := view.view_top if view else 0.0
	var sc := w.draw_scroll()
	_draw_tiles(sc, left, width)
	# the vine: his centre reaching y 0 hangs him (he is drawn under it, VINE_DRAW_Y lower)
	_dashed(Vector2(left, 0.0), Vector2(left + width, 0.0), Color(0.6, 1.0, 0.6, 0.8))
	# rings, at their drawn place
	for r in w.rings:
		var off := Vector2(lerpf(r.prev_x, r.x, w.alpha) - r.x, 0.0)
		_box(_moved(w.ring_hit_rect(r), off), RING_HIT)
		_box(_moved(w.ring_wall_rect(r), off), RING_WALL)
	# bandits, where WorldView draws them (without its wall shift)
	for b in w.bandits:
		if b.gone:
			continue
		var standing := absf(b.y - b.prev_y) < 4.0
		var dx := lerpf(b.prev_x, b.x, w.alpha) - sc
		var dy := minf(b.prev_y, b.y) if standing else lerpf(b.prev_y, b.y, w.alpha)
		if not b.active:
			dx = b.wait_x - sc
			dy = b.wait_y
		if dx < left - 150.0 or dx > left + width + 150.0:
			continue
		var off := Vector2(dx - (b.x - w.scroll), dy - b.y)
		_box(_moved(w.bandit_rect(b), off), BANDIT_BOX)
		_box(_moved(w.bandit_hit_rect(b), off), BANDIT_HIT)
		var blow := w.bandit_blow_rect(b)
		if blow.has_area():
			_box(_moved(blow, off).grow(-2.0), BLOW, 1.0)
		var fist := w.bandit_fist_rect(b)
		if fist.has_area():
			fist = _moved(fist, off)
			draw_rect(fist, Color(BLOW, 0.3))
			_box(fist, BLOW)
		_cross(Vector2(dx, dy), BANDIT_BOX)
	# Panoramic
	var p := w.draw_hero()
	var hoff := p - Vector2(w.x, w.y)
	_box(_moved(w.body_rect(), hoff), HERO_BODY)
	_box(_moved(w.chest_rect(), hoff), HERO_WALL)
	_box(_moved(w.feet_rect(), hoff), HERO_WALL)
	var hurt := _moved(w.hurt_rect(), hoff)
	draw_rect(hurt, Color(HURT, 0.18))
	_box(hurt, HURT)
	_cross(p, HERO_BODY)
	_legend(Vector2(left + width - 226.0, maxf(top, 0.0) + 96.0))  # (top right: sky; he is on the left)


func _draw_tiles(sc: float, left: float, width: float) -> void:
	var c0 := maxi(floori((sc + left) / Level.TILE) - 1, 0)
	var c1 := mini(floori((sc + left + width) / Level.TILE) + 1, Level.COLS - 1)
	var t := Level.TILE
	for c in range(c0, c1 + 1):
		for r in Level.ROWS:
			var k := world.level.kind_at(c, r)
			var at := Vector2(c * t - sc, r * t)
			match k:
				Level.Kind.TOP:
					_box(Rect2(at, Vector2(t, t)), TOP, 1.0)
					draw_line(at, at + Vector2(t, 0), TOP, 2.5)
				Level.Kind.SIDE:
					_box(Rect2(at, Vector2(t - World.SIDE_SHRINK, t - World.SIDE_SHRINK)), SIDE, 1.0)
				Level.Kind.BOB:
					_box(Rect2(at, Vector2(t, t)), BOB, 1.5)
				Level.Kind.WATER:
					draw_line(Vector2(at.x, World.SURFACE_Y), Vector2(at.x + t, World.SURFACE_Y), WATER, 2.0)


func _moved(r: Rect2, by: Vector2) -> Rect2:
	return Rect2(r.position + by, r.size)


func _box(r: Rect2, colour: Color, width := LINE) -> void:
	draw_rect(r, colour, false, width)


func _cross(at: Vector2, colour: Color) -> void:
	draw_line(at - Vector2(5, 0), at + Vector2(5, 0), colour, 1.5)
	draw_line(at - Vector2(0, 5), at + Vector2(0, 5), colour, 1.5)


func _dashed(a: Vector2, b: Vector2, colour: Color) -> void:
	var n := int(a.distance_to(b) / 12.0)
	for i in n:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), colour, 1.5)


func _legend(at: Vector2) -> void:
	var rows := [["his body (ground, ledges, Red Bobs)", HERO_BODY], ["his chest, feet (walls)", HERO_WALL],
			["hurt by a blow", HURT], ["bandit: 2017 box (ground, walls)", BANDIT_BOX], ["bandit: body (rings hit)", BANDIT_HIT],
			["bandit: body, fist (its blow)", BLOW], ["ring: hits bandits", RING_HIT], ["ring: stops at rock", RING_WALL],
			["grass top / wall (tested) / Red Bob", TOP]]
	draw_rect(Rect2(at - Vector2(4, 12), Vector2(214, rows.size() * 13.0 + 6.0)), Color(0, 0, 0, 0.55))
	for i in rows.size():
		var y := at.y + i * 13.0
		draw_rect(Rect2(at.x, y - 8.0, 10.0, 8.0), rows[i][1])
		draw_string(_font, Vector2(at.x + 14.0, y), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1, 1, 1, 0.95))

class_name Twinkles
extends Control
## Little four-pointed glints that pop, turn and fade at random spots of an area (around the
## logo, over a reward), each on its own rhythm, with a soft halo.

const STAR := preload("res://assets/icons/star-four-fill.svg")

var count := 9
var colour := Color(1, 0.98, 0.9)
var smallest := 18.0
var largest := 46.0

var _spots: Array[Vector4] = []  # x, y (0..1 of the area), phase, period
var _t := 0.0


func _init(stars := 9, star_colour := Color(1, 0.97, 0.85)) -> void:
	count = stars
	colour = star_colour
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		_spots.append(Vector4(rng.randf(), rng.randf(), rng.randf(), rng.randf_range(2.2, 4.2)))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for i in _spots.size():
		var s := _spots[i]
		var k := fposmod(_t / s.w + s.z, 1.0)
		if k > 0.3:
			continue  # resting: each glint shows for 30 % of its period
		var life := sin(k / 0.3 * PI)
		var cycle := floorf(_t / s.w + s.z)  # a new place every time it comes back
		var at := Vector2(fposmod(s.x + cycle * 0.618, 1.0), fposmod(s.y + cycle * 0.382, 1.0)) * size
		var side := lerpf(smallest, largest, fposmod(s.x * 7.0 + cycle * 0.3, 1.0)) * life
		draw_set_transform(at, k * 2.0, Vector2.ONE)
		draw_texture_rect(Fx.glow_texture(), Rect2(-Vector2(side, side) * 0.9, Vector2(side, side) * 1.8), false,
				Color(colour, 0.5 * life))
		draw_texture_rect(STAR, Rect2(-Vector2(side, side) / 2, Vector2(side, side)), false, Color(colour, life))
	draw_set_transform(Vector2.ZERO)

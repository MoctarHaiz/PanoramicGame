class_name Feel
extends Node
## The game's feel between its events (added by the game screen, which places everything first:
## this runs after it every frame, as its child, and only nudges what is drawn; the rules never move):
## - the knockbacks of the impacts (Fx.knock) drawn on Panoramic and the bandits; their clock holds
##   during a hit-stop and the pause, so a blow freezes, then knocks;
## - the climb: a hand grabbing the stone as he starts up a ledge, the pull over its top;
## - the vine creaking now and then while he hangs;
## - the music's drive layer coming in on the home stretch (Audio.set_intensity).
## (The views may apply Fx.knock_offset() themselves one day: then set APPLY_KNOCKS to false.)

const APPLY_KNOCKS := true
const INTENSITY_FROM := 0.62  ## progress where the drive layer starts to come in ...
const INTENSITY_FULL := 0.8  ## ... and where it plays in full
const CREAK_EVERY := Vector2(1.1, 2.2)  ## seconds between the vine's creaks while he hangs

var world: World
var view: WorldView
var game: Node  ## the game screen (its _freeze and _paused)
var _climbing := false
var _creak := 1.0


func _init(g: Node, w: World, v: WorldView) -> void:
	game = g
	world = w
	view = v


func _process(delta: float) -> void:
	var held: bool = game.get(&"_freeze") > 0.0 or game.get(&"_paused")
	if not held:
		Fx.advance_knocks(delta)
	if APPLY_KNOCKS:
		_apply_knocks()
	if held or world.state != World.State.RUNNING or world.ticks == 0:
		return
	if world.climbing and not _climbing:
		Audio.play_sfx(&"grab")
	elif _climbing and not world.climbing and world.on_ground:
		Audio.play_sfx(&"mantle")
	_climbing = world.climbing
	if world.hanging:
		_creak -= delta
		if _creak <= 0.0:
			Audio.play_sfx(&"vine_creak")
			_creak = randf_range(CREAK_EVERY.x, CREAK_EVERY.y)
	else:
		_creak = randf_range(0.8, 1.3)  # the catch has its own creak: the next one comes later
	Audio.set_intensity(smoothstep(INTENSITY_FROM, INTENSITY_FULL, world.progress()))


## Adds each knock to where the views have just placed Panoramic and the bandits.
func _apply_knocks() -> void:
	var hero: Node2D = view.get(&"_hero")
	if is_instance_valid(hero):
		hero.position += Fx.knock_offset(&"hero")
	var bandits: Dictionary = view.get(&"_bandits")
	for v: Node2D in bandits.values():
		if is_instance_valid(v):
			v.position += Fx.knock_offset(v.get(&"bandit"))

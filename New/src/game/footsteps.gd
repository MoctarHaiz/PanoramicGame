class_name Footsteps
extends Node
## Footsteps in time with the run: a step sounds when one of Panoramic's feet touches the ground
## in his run animation (HeroView), never on a clock of its own, so sound and picture can't drift.
##
## The contract with the run animation (HeroView):
## - the drawn run (a Seedance sprint, 16 slots a loop): if HeroView has run_frame() (the frame
##   showing, 0..16 fractional, -1 when he isn't running), a step sounds as the frame passes a
##   contact, CONTACTS: a boot lands on slots 1, 5, 9 and 13 (video frames 8, 14, 20, 26 of the
##   clip, 6 apart). Four steps a loop, 4 slots apart: at 16 frames a second, 4 steps a second.
## - until HeroView has run_frame(): its run clock (_run, 0..16) while pose() is &"run" or &"throw"
##   (the throwing arm is drawn over the running legs);
## - the two drawn run poses of the old painted hero (run_a, run_b): a foot lands at each change.
## A step against a wall (pushing, blocked) is softer.

const RUN_FRAMES := 16  ## the run loop's length in frames
const CONTACTS: Array[float] = [1.0, 5.0, 9.0, 13.0]  ## frames where a foot touches the ground (0-based)
const RUN_POSES: Array[StringName] = [&"run_a", &"run_b"]

var world: World
var hero: Node  ## HeroView (anything with pose() or run_frame())
var _frame := -1.0
var _pose := &""


func _init(w: World, h: Node) -> void:
	world = w
	hero = h


func _process(_delta: float) -> void:
	if not is_instance_valid(hero) or world.state != World.State.RUNNING:
		return
	var grounded := world.on_ground and not world.hanging and not world.jumping
	if hero.has_method(&"run_frame") or (hero.has_method(&"pose") and hero.get(&"_run") != null):
		var f: float = _run_frame()
		if grounded and f >= 0.0 and _frame >= 0.0:
			for c in CONTACTS:
				if crossed(_frame, f, c):
					_step()
		_frame = f
	else:
		var pose: StringName = hero.pose()
		if grounded and pose != _pose and pose in RUN_POSES and _pose in RUN_POSES:
			_step()
		_pose = pose


## The frame of the 3D run showing (-1 when he isn't running): HeroView.run_frame(), or until the
## art track adds it, its run clock while its animation is the run.
func _run_frame() -> float:
	if hero.has_method(&"run_frame"):
		return hero.run_frame()
	return float(hero.get(&"_run")) if hero.pose() in [&"run", &"throw"] else -1.0  # a throw keeps the legs running


## True when the run went past frame `c` going from frame `a` to `b` (the loop wraps at RUN_FRAMES).
static func crossed(a: float, b: float, c: float) -> bool:
	if b >= a:
		return a < c and c <= b
	return a < c or c <= b


func _step() -> void:
	Audio.footstep(0.55 if world.blocked else 1.0)

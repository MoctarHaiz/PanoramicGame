class_name TouchReader
extends RefCounted
## Reads fingers on the game screen into moves: a tap throws a ring (&"throw"), a swipe up jumps
## (&"jump"), down lets go or crouches (&"down"), right steps forward (&"right"); a swipe left does
## nothing (&"left"). Each finger is read on its own: a thumb tapping while the other swipes is a
## throw and a swipe. Positions are in design units, times in seconds.
##
## - A swipe counts as soon as the finger has gone `swipe_min` (about 4 mm), in the middle of the
##   move: nobody waits for the finger to lift. A fast flick counts from FLICK_FRACTION of that.
## - New: a flick lifted before that but past the tap slop is still a swipe (it was read as a tap:
##   a ring thrown instead of a jump).
## - New: one finger can swipe again without lifting. After a swipe the finger's starting point
##   follows it while it keeps going the same way; turning another way for AGAIN x swipe_min is a
##   new swipe (up, then down: jump, then let go).
## - A finger that stays within the tap slop and lifts within TAP_MAX_TIME is a tap.

const TAP_MAX_TIME := 0.45  ## seconds: longer touches that didn't move aren't taps
const TAP_SLOP := 0.4  ## of swipe_min: a finger that moved less than this (~1.6 mm) still taps
const FLICK_FRACTION := 0.65  ## of swipe_min: a fast flick counts from here (~2.6 mm)
const FLICK_SPEED := 25.0  ## swipe_min a second (~100 mm/s): what makes a flick fast
const AGAIN := 1.5  ## of swipe_min: the turn to another direction that makes a second swipe
## Up and down win a slanted swipe up to this ratio |x| / |y| (about 58° from vertical): a thumb's
## jump often leans right, and a jump matters far more than the small step right.
const VERTICAL_BIAS := 1.6

## Design units a finger must travel to swipe (GameScreen sets it from the screen's dpi).
var swipe_min := 30.0
var _touches := {}  # finger index -> {"start", "anchor": Vector2, "time": float, "last": StringName}


## What a swipe `d` (design units) asks for: &"jump", &"down", &"right" or &"left". The 2017 game
## split at 45°; up and down now win slanted swipes (VERTICAL_BIAS).
static func swipe_action(d: Vector2) -> StringName:
	if absf(d.x) <= absf(d.y) * VERTICAL_BIAS:
		return &"jump" if d.y < 0 else &"down"
	return &"right" if d.x > 0 else &"left"


func press(index: int, at: Vector2, time: float) -> void:
	_touches[index] = {"start": at, "anchor": at, "time": time, "last": &""}


## The swipe this move of finger `index` makes, or &"".
func drag(index: int, at: Vector2, time: float) -> StringName:
	var t: Dictionary = _touches.get(index, {})
	if t.is_empty():
		return &""
	var d: Vector2 = at - t.anchor
	if t.last != &"":  # swiped already: the same way on, or a turn
		var turn := swipe_action(d)
		if turn == t.last:
			t.anchor = at
			return &""
		if d.length() < AGAIN * swipe_min:
			return &""
		t.last = turn
		t.anchor = at
		return turn
	var fast := d.length() / maxf(time - float(t.time), 0.001) >= FLICK_SPEED * swipe_min
	if d.length() >= swipe_min or (fast and d.length() >= FLICK_FRACTION * swipe_min):
		t.last = swipe_action(d)
		t.anchor = at
		return t.last
	return &""


## What lifting finger `index` makes: &"throw" (a tap), a swipe (a short flick), or &"".
func release(index: int, at: Vector2, time: float) -> StringName:
	var t: Dictionary = _touches.get(index, {})
	_touches.erase(index)
	if t.is_empty() or t.last != &"" or time - float(t.time) > TAP_MAX_TIME:
		return &""
	var d: Vector2 = at - t.start
	return &"throw" if d.length() < TAP_SLOP * swipe_min else swipe_action(d)


## Forgets every finger (pause, the end of a run).
func clear() -> void:
	_touches.clear()


func is_down(index: int) -> bool:
	return _touches.has(index)

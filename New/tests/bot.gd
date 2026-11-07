class_name Bot
extends RefCounted
## Plays a whole level by looking ahead: every few ticks it tries random action plans on copies of
## the world (jump, let go, step forward, at random moments over the next 3 seconds), keeps the plan
## that ends best, and plays its first ticks. It throws a ring every few ticks while a bandit is
## ahead, like a player tapping, and once the hut is in sight it lets him run home (no hops: the
## screenshots and strips of the ending show his own arrival).
## Used by the tests to prove the level can be finished with these rules, and by the screen tour.

const HORIZON := 120  ## ticks looked ahead (3 s)
const REPLAN := 5  ## ticks played between two plans
const PLANS := 18
const THROW_EVERY := 6
const ACTIONS: Array[StringName] = [&"jump", &"down", &"right"]

var rng := RandomNumberGenerator.new()
## A Red Bob the bot goes for above all (probes: can it be taken and survived?); (-1, -1): none.
var target := Vector2i(-1, -1)
var plans := PLANS
var _plan: Array = []  # [[tick offset, action], ...] of the plan being played
var _plan_tick := 0


func _init(seed_value := 1) -> void:
	rng.seed = seed_value


## Plays `w` until it ends or `max_ticks` pass. Returns a summary.
func play(w: World, max_ticks := 9000) -> Dictionary:
	while w.state == World.State.RUNNING and w.ticks < max_ticks:
		act(w)
		w.tick()
	return {"state": w.state, "reason": w.death_reason, "ticks": w.ticks, "progress": w.progress(),
			"bobs": w.bobs, "lives": w.lives, "knocked_out": w.knocked_out, "stars": w.stars()}


## Gives `w` the bot's input for its next tick.
func act(w: World) -> void:
	if w.at_end and w.on_ground and not w.hanging:
		if w.ticks % THROW_EVERY == 0 and _bandit_ahead(w):
			w.throw()
		return
	if _plan_tick % REPLAN == 0 or _plan.is_empty():
		_plan = _best_plan(w)
		_plan_tick = 0
	for step: Array in _plan:
		if step[0] == _plan_tick:
			_apply(w, step[1])
	if w.ticks % THROW_EVERY == 0 and _bandit_ahead(w):
		w.throw()
	_plan_tick += 1


## A bandit ahead that a ring thrown now would meet (at his height, within 600 units) and that the
## rings already flying won't finish: worth a ring. (Not a ring every few ticks: no spray of rings.)
static func _bandit_ahead(w: World) -> bool:
	var ring := World.ring_box(0.0, World.VINE_DRAW_Y if w.hanging else w.y)
	for b in w.bandits:
		if not b.active or b.gone or b.health <= 0:
			continue
		var ahead := b.x - w.scroll - w.x
		var body := w.bandit_hit_rect(b)
		if ahead <= 0.0 or ahead > 600.0 or ring.end.y <= body.position.y or ring.position.y >= body.end.y:
			continue
		var flying := 0
		for r in w.rings:
			var box := World.ring_box(r.x, r.y)
			if r.x < b.x - w.scroll and box.end.y > body.position.y and box.position.y < body.end.y:
				flying += 1
		if flying < b.health:
			return true
	return false


func _best_plan(w: World) -> Array:
	var candidates: Array = [[], [[0, &"jump"]], [[0, &"down"]], [[0, &"right"]]]
	# Keep the rest of the current plan as a candidate, shifted to now.
	var rest := []
	for step: Array in _plan:
		if step[0] >= _plan_tick:
			rest.append([step[0] - _plan_tick, step[1]])
	candidates.append(rest)
	while candidates.size() < plans:
		var plan := []
		for i in rng.randi_range(1, 3):
			plan.append([rng.randi_range(0, HORIZON / 2), ACTIONS[rng.randi() % ACTIONS.size()]])
		plan.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		candidates.append(plan)
	var best: Array = []
	var best_score := -INF
	for plan: Array in candidates:
		var s := _score(w, plan)
		if s > best_score:
			best_score = s
			best = plan
	return best


func _score(w: World, plan: Array) -> float:
	var sim := w.clone()
	var start := sim.ticks
	for t in HORIZON:
		for step: Array in plan:
			if step[0] == t:
				_apply(sim, step[1])
		if sim.ticks % THROW_EVERY == 0 and _bandit_ahead(sim):
			sim.throw()
		sim.tick()
		if sim.state != World.State.RUNNING:
			break
	var lived := sim.ticks - start
	var s := sim.scroll + sim.x + sim.lives * 3000.0 + sim.bobs * 60.0
	if sim.state == World.State.DEAD:
		s += -1.0e6 + lived * 100.0
	elif sim.state == World.State.WON:
		s += 1.0e6 - lived * 10.0
	if sim.hanging:
		s -= 150.0
	if target.x >= 0 and sim.level.kind_at(target.x, target.y) != Level.Kind.BOB:
		s += 50000.0
	return s


static func _apply(w: World, action: StringName) -> void:
	match action:
		&"jump": w.jump()
		&"down": w.down()
		&"right": w.step_forward()

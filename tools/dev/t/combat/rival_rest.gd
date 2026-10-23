extends SceneTree
## A rival crew waits its turn at the side of the duel (RivalEncounter._crew_corner, CaptainBrain "rest"): they walk to
## a corner off to one side, settle and stay put (no circling the fight), each at their own side work (drills, a book,
## tinkering, an instrument, sat on the ground; never two the same) or standing watching, their captain always
## watching, the watchers' heads on the duel; a knockdown on the captain isn't a loss (only beaten is: Player.is_standing);
## when a mate goes down the next gets up from their work and walks in.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var e
var at0 := {}
var next_up
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func brain(r):
	return r.get_node("Brain")


func resting() -> Array:
	return e.rivals.filter(func(r): return is_instance_valid(r) and brain(r).order == "rest")


func fighting() -> Array:
	return e.rivals.filter(func(r): return is_instance_valid(r) and brain(r).order == "fight")


func flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			root.get_node("GameManager").rivals.clear()
			# (notorious: a bigger crew, more of them waiting)
			p.bounty = 160000
			# (it stands idle while they duel it: never beaten, or the crew wins and leaves)
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			e = load("res://scripts/ai/rival_encounter.gd").start(p, "gilded_gulls")
			until = TK.wait_secs(0.4)
		1:
			var cs = load("res://scripts/dialogue/cutscene.gd").active
			if cs:
				cs.end(true)
			# (a few ticks: the first duel picks its rival)
			until = TK.wait_ticks(3)
		2:
			# (the roll gives each mate side work at 60%: here each waiting mate gets one, so every kind is seen settling)
			var kinds := ["music", "read", "sit", "train", "tinker"]
			for r in e.rivals.slice(0, e.rivals.size() - 1):
				if brain(r).order == "rest" and not kinds.is_empty():
					brain(r).activity = kinds.pop_front()
					if brain(r).activity == "music":
						r.body_model.look["instrument"] = "fiddle"
			until = TK.wait_secs(7.0)
		3:
			var rs := resting()
			var acts: Array = rs.map(func(r): return brain(r).activity)
			print("resting: ", rs.map(func(r): return "%s %s" % [r.name, brain(r).activity]))
			check("one fights, the rest of the crew rests (%d of %d)" % [rs.size(), e.rivals.size()], fighting().size() == 1 and rs.size() == e.rivals.size() - 1)
			check("everyone waiting has settled (%s)" % str(rs.map(func(r): return brain(r)._settled)), rs.all(func(r): return brain(r)._settled))
			var dists: Array = rs.map(func(r): return snappedf(flat(r.global_position - p.global_position), 0.1))
			check("in a corner off to the side, 8-17 m from the duel (%s)" % str(dists), dists.all(func(d): return d > 8.0 and d < 17.0))
			var side_work := acts.filter(func(a): return a != "watch")
			var uniq := {}
			for a in side_work:
				uniq[a] = true
			check("no two at the same side work (%s)" % str(acts), uniq.size() == side_work.size())
			check("their captain watches", brain(e.rivals[-1]).activity == "watch" and e.rivals[-1] in rs)
			var ok := true
			for r in rs:
				var a: String = brain(r).activity
				var on := true
				match a:
					"train", "read", "tinker":
						on = r.body_model.current_action() == load("res://scripts/game/downtime.gd").pose_of(r, a)
					"sit":
						on = r.current_state_name() == "Sit"
					"music":
						on = r.jam.playing
				if not on:
					print("  not at it: %s %s (action %s, state %s)" % [r.name, a, r.body_model.current_action(), r.current_state_name()])
				ok = ok and on
			check("each is at their activity (the pose, sat, playing)", ok)
			var watchers := rs.filter(func(r): return brain(r).activity == "watch")
			check("the watchers' heads follow the duel (%s)" % str(watchers.map(func(r): return snappedf(r.body_model.look_weight, 0.01))),
				watchers.all(func(r): return r.body_model.look_weight > 0.8 and flat(r.body_model.look_target - p.global_position) < 3.0))
			for r in rs:
				at0[r] = r.global_position
			# (a heavy hit throws you off your feet: Downed, but not beaten)
			p.knock_down(Vector3(0, 3.0, 2.0))
			until = TK.wait_secs(3.0)
		4:
			check("knocked off your feet isn't beaten: the fight goes on (phase %s, captain %s)" % [e.phase, p.current_state_name()], e.phase == "fight")
			var moved: Array = resting().map(func(r): return snappedf(flat(r.global_position - at0[r]), 0.01))
			check("and they stay put: no circling the fight (moved %s m)" % str(moved), moved.all(func(m): return m < 0.3))
			var f := fighting()
			# who's next: the queue's first standing one
			next_up = null
			for r in e._queue:
				if is_instance_valid(r) and r != f[0]:
					next_up = r
					break
			f[0].health_component.take_damage(99999.0)
			until = TK.wait_secs(2.5)
		5:
			check("a mate down: the next gets up from their %s and walks in (phase %s, order %s, settled %s, %.1f m from the captain)" % [brain(next_up).activity, e.phase,
				brain(next_up).order, brain(next_up)._settled, flat(next_up.global_position - p.global_position)],
				brain(next_up).order == "fight" and not brain(next_up)._settled and next_up.current_state_name() != "Sit"
				and not next_up.jam.playing and flat(next_up.global_position - p.global_position) < flat(at0[next_up] - p.global_position) - 1.0)
			return TK.done(fails)
	step += 1
	return false

extends SceneTree
## The stronghold's alarm (1.30, StrongholdAlarm, StrongholdReinforce): a fight with a district's garrison raises its
## alarm (only that district's) after a few seconds; then its gate swings open on waves of hunters who come straight for
## the captain, wave after wave until its pool is spent; with every man down the district is cleared for good and nothing
## more comes. The Landing's waves come by boat and leap ashore onto the quay.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var alarm
var gate
var step := 0
var until := 0
var fails := 0
var t0 := 0
var waves_seen := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _flag(f: String) -> bool:
	return root.get_node("GameManager").world_flags.has(f)


func _heal() -> void:
	var hc = stage.player.health_component
	hc.current_health = hc.max_health


func _put(q: Vector2, y: float) -> void:
	stage.player.global_position = isl.city.to_global(Vector3(q.x, y + 0.4, q.y))
	stage.player.reset_physics_interpolation()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	_heal()
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			stage.player.global_position = Vector3(900, 2, 1300)
			stage.player.reset_physics_interpolation()
			until = TK.wait_secs(14.0)
		2:
			alarm = isl.city.get_node("Alarm")
			gate = isl.city.get_node("Reinforce_prison_0")
			check("no alarm anywhere before a fight", not ["landing", "ward", "arsenal", "prison", "keep"].any(func(d): return alarm.alarmed(d)))
			_put(Vector2(-62, -34), 14.0)
			t0 = Engine.get_physics_frames()
			step = 3
			until = TK.wait_secs(0.5)
			return false
		3:
			# (up to 10 s for the post to notice and the fight to run ALARM_AFTER)
			if not alarm.alarmed("prison") and Engine.get_physics_frames() - t0 < 600:
				until = TK.wait_secs(0.5)
				return false
			check("a fight with the prison's garrison raises its alarm (%.1f s)" % ((Engine.get_physics_frames() - t0) / 60.0), alarm.alarmed("prison"))
			check("...that district's only", not alarm.alarmed("ward") and not alarm.alarmed("arsenal"))
			until = TK.wait_secs(alarm.FIRST_WAVE + 1.5)
		4:
			check("the prison's gate musters a wave (%d)" % gate.gen, gate.gen >= 1 and gate.alive_count() > 0)
			check("...its leaves swing open", absf(gate._gate_l.rotation.y) > 0.5)
			until = TK.wait_secs(2.5)
		5:
			var hunters: Array = gate.grunts.filter(func(g): return is_instance_valid(g) and not g.is_dead())
			var p = stage.player
			check("...hunters, in the fight and coming for the captain (%s)" % [hunters.map(func(g): return "%d %.0fm" % [g.state, g.global_position.distance_to(p.global_position)])],
				not hunters.is_empty() and hunters.all(func(g): return g.hunt and g.in_combat()))
			t0 = Engine.get_physics_frames()
			step = 6
			return false
		6:
			# everything in the prison down, again and again, until it's cleared (the pool's waves all come)
			for c in [isl.city.get_node("Garrison_prison"), gate]:
				for g in c.grunts:
					if is_instance_valid(g):
						g.health.take_damage(99999.0)
			if not _flag("sh_clear_prison") and Engine.get_physics_frames() - t0 < 60 * 90:
				until = TK.wait_secs(1.0)
				return false
			check("the prison cleared once its pool was spent (%d waves of %d)" % [gate.gen, alarm.POOL["prison"]], _flag("sh_clear_prison") and gate.gen == alarm.POOL["prison"])
			waves_seen = gate.gen
			until = TK.wait_secs(alarm.WAVE_EVERY + 2.0)
		7:
			check("...and nothing more comes", gate.gen == waves_seen and gate.alive_count() == 0)
			# the Landing: its waves come by boat
			_put(Vector2(0, 46), StrongholdPlan.QUAY_Y)
			alarm.raise("landing")
			until = TK.wait_secs(alarm.FIRST_WAVE + 3.0)
		8:
			var boats: Array = [isl.city.get_node("Reinforce_landing_0"), isl.city.get_node("Reinforce_landing_1")]
			check("the Landing's alarm sends a boat rowing in", boats.any(func(b): return b._boat.visible and b.busy()))
			until = TK.wait_secs(9.0)
		9:
			var boats: Array = [isl.city.get_node("Reinforce_landing_0"), isl.city.get_node("Reinforce_landing_1")]
			var men: Array = []
			for b in boats:
				men.append_array(b.grunts.filter(func(g): return is_instance_valid(g)))
			var ashore: Array = men.filter(func(g):
				var l: Vector3 = isl.city.to_local(g.global_position)
				return l.y > StrongholdPlan.QUAY_Y - 0.6 and l.z < StrongholdPlan.FRONT_Z)
			check("...its marines leap ashore onto the quay (%d of %d)" % [ashore.size(), men.size()], men.size() >= 6 and ashore.size() >= men.size() - 1)
			return TK.done(fails)
	step += 1
	return false

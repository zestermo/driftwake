extends SceneTree
## Stealth in the stronghold (1.30, FodderMarine takedowns, StrongholdBell, StrongholdAlarm): a blow struck out of a
## sneak from behind an unaware sentry takes him down silently (nobody else stirs, no alarm); from the front it doesn't.
## Once its garrison is fighting, a marine runs for the district's bell; cut him down and another goes; the one who gets
## there rings it and the alarm is up. A district whose bells are all cut sends no runner: the alarm only goes up when
## the fight runs long, and its waves come slower.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var alarm
var step := 0
var until := 0
var fails := 0
var t0 := 0
var first_runner
var killed_runner := false


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _flag(f: String) -> bool:
	return root.get_node("GameManager").world_flags.has(f)


func _put(at: Vector3, _face: Vector3) -> void:
	var p = stage.player
	p.global_position = at
	p.reset_physics_interpolation()


func _sentry(at: Vector2):
	for g in isl.city.get_node("Garrison_ward").grunts:
		var l: Vector3 = isl.city.to_local(g.post)
		if Vector2(l.x, l.z).distance_to(at) < 0.5:
			return g
	return null


func _strike(g) -> void:
	var p = stage.player
	var hd = p.melee_hit(11.0)
	g.hurtbox.take_hit(hd, p)


func _process(_d: float) -> bool:
	if stage.up:
		stage.player.health_component.current_health = stage.player.health_component.max_health
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			p.global_position = Vector3(900, 2, 1300)
			p.reset_physics_interpolation()
			until = TK.wait_secs(14.0)
		2:
			alarm = isl.city.get_node("Alarm")
			check("bells stand in every district (%d)" % isl.city.get_children().filter(func(c): return str(c.name).begins_with("Bell_")).size(),
				["landing", "ward", "arsenal", "prison", "keep"].all(func(d): return isl.city.get_children().any(func(c): return str(c.name).begins_with("Bell_" + d))))
			# behind the ward's west sentry (he looks west), sneaking
			# (landing from the teleport he isn't sneaking for a tick or two: set down well behind, out of earshot, first)
			_put(isl.city.to_global(Vector3(-33.0, 12.05, -12)), Vector3.ZERO)
			until = TK.wait_ticks(20)
		3:
			p.state_machine.force_state("Crouch", {})
			p.global_position = isl.city.to_global(Vector3(-38.2, 12.0, -12))
			p.reset_physics_interpolation()
			until = TK.wait_ticks(30)
		4:
			var s = _sentry(Vector2(-40, -12))
			check("the captain sneaking (%s)" % p.current_state_name(), p.current_state_name() == "Crouch")
			check("...unaware of a captain sneaking up behind him", s.state == s.S.IDLE)
			_strike(s)
			until = TK.wait_secs(1.0)
		5:
			var s = _sentry(Vector2(-40, -12))
			var ward = isl.city.get_node("Garrison_ward")
			var stirred: Array = ward.grunts.filter(func(g): return is_instance_valid(g) and not g.is_dead() and g.in_combat())
			check("a blow from a sneak behind him: a silent takedown", s.is_dead())
			check("...nobody else stirs (%d), no alarm, no runner" % stirred.size(), stirred.is_empty() and not alarm.alarmed("ward") and not alarm.runner.has("ward"))
			# in front of the east stair sentry (he looks out to the stair), sneaking all the same
			var f = _sentry(Vector2(7, 18))
			_put(isl.city.to_global(Vector3(7, 12.05, 19.6)), Vector3.ZERO)
			until = TK.wait_ticks(4)
		6:
			var f = _sentry(Vector2(7, 18))
			p.state_machine.force_state("Crouch", {})
			_strike(f)
			until = TK.wait_secs(2.0)
		7:
			var f = _sentry(Vector2(7, 18))
			check("from the front it's no takedown: he's up and fighting", not f.is_dead() and f.in_combat())
			p.state_machine.force_state("Idle", {})
			first_runner = alarm.runner.get("ward")
			check("the ward's garrison fighting: a marine runs for the bell", first_runner != null and first_runner.bell != null)
			first_runner.health.take_damage(99999.0)
			killed_runner = true
			until = TK.wait_secs(alarm.RUNNER_GAP + 1.0)
		8:
			var r = alarm.runner.get("ward")
			check("...cut him down and another goes", r != null and is_instance_valid(r) and r != first_runner and r.bell != null and not alarm.alarmed("ward"))
			t0 = Engine.get_physics_frames()
			step = 9
			return false
		9:
			if not alarm.alarmed("ward") and Engine.get_physics_frames() - t0 < 60 * 25:
				until = TK.wait_secs(0.5)
				return false
			var r = alarm.runner.get("ward")
			check("...he gets there and rings it: the ward's alarm is up (%.1f s)" % ((Engine.get_physics_frames() - t0) / 60.0), alarm.alarmed("ward") and r != null and r.rang)
			# the prison's bell cut: no runner, the alarm only once the fight runs long (the ward's men out of the way first:
			# with them in the fight the fortress is at its PEAK and no wave would come anywhere)
			alarm.pool["ward"] = 0
			for c in isl.city.get_children():
				if str(c.name) == "Garrison_ward" or str(c.name).begins_with("Reinforce_ward"):
					for g in c.grunts:
						if is_instance_valid(g):
							g.health.take_damage(99999.0)
			var b = isl.city.get_node("Bell_prison_0")
			b._on_use(p)
			until = TK.wait_ticks(10)
		10:
			var b = isl.city.get_node("Bell_prison_0")
			check("F at the bell cuts its rope (flag, rope gone)", _flag("sh_bell_prison_0") and not b._rope.visible and b.cut())
			# (the ward's crowd may have the captain down: up first)
			p.state_machine.force_state("Idle", {})
			_put(isl.city.to_global(Vector3(-62, 14.4, -34)), Vector3.FORWARD)
			t0 = Engine.get_physics_frames()
			until = TK.wait_secs(8.0)
		11:
			check("bells cut: a fight in the prison sends no runner, no alarm yet", not alarm.runner.has("prison") and not alarm.alarmed("prison"))
			until = TK.wait_secs(alarm.LONG_FIGHT)
		12:
			var fighting: int = isl.city.get_node("Garrison_prison").grunts.filter(func(g): return is_instance_valid(g) and g.in_combat()).size()
			check("...but a long fight raises it all the same (fighting %.1f s, %d in it)" % [alarm._fight_t["prison"], fighting], alarm.alarmed("prison"))
			until = TK.wait_secs(alarm.FIRST_WAVE + 1.0)
		13:
			var gate = isl.city.get_node("Reinforce_prison_0")
			check("...its waves come (%d), and slower: every %.0f s against the ward's %.0f" % [gate.gen, alarm.wave_every("prison"), alarm.wave_every("ward")],
				gate.gen >= 1 and alarm.wave_every("prison") > alarm.wave_every("ward") and alarm._wave_t["prison"] > 0.0)
			# dazed (flash powder, smoke): a takedown from any side, sneaking or not
			var f = isl.city.get_node("Garrison_prison").grunts.filter(func(g): return is_instance_valid(g) and g.is_in_group("fodder") and not g.is_dead())[0]
			f._set_state(f.S.STAGGER)
			f.stunned_until = 1.0e9
			p.state_machine.force_state("Idle", {})
			_put(f.global_position + (f._fwd() * 1.5), Vector3.ZERO)
			_strike(f)
			until = TK.wait_ticks(5)
		14:
			var dead: Array = isl.city.get_node("Garrison_prison").grunts.filter(func(g): return is_instance_valid(g) and g.is_in_group("fodder") and g.is_dead())
			check("a dazed marine goes down to one blow from the front, no sneak (%d down)" % dead.size(), dead.size() >= 1)
			return TK.done(fails)
	step += 1
	return false

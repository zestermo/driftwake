extends SceneTree
## The silverback (JungleApe in its BeastArena on the first chain island):
## asleep until a captain comes near, wakes with a roar (and the boss bar);
## its slam, leap and boulder each land on a captain standing in their ring;
## poise built up by hits staggers it, a parried swipe staggers it; below 60%
## it roars into phase 2; everyone leaving resets it (healed, back to sleep);
## killed: the victory, the flag, its hoard, the village's job done.
var t := 0.0
var step := 0
var wait := 0.0
var p
var gm
var world
var isl
var arena
var ape
var hp0 := 0.0
var fails := 0
func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func finish() -> void:
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()
func put(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = at + Vector3.UP * 1.0
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
## A spot `d` m from the ape toward the village, on the ground.
func near(d: float) -> Vector3:
	var c: Vector2 = isl.sites["boss"]
	var q: Vector2 = c + (isl.sites["village"] - c).normalized() * d
	return isl.to_global(Vector3(q.x, isl.height_at(q.x, q.y), q.y))
func heal() -> void:
	p.health_component.max_health = 9000.0
	p.health_component.current_health = 9000.0
	hp0 = 9000.0
func _process(d: float) -> bool:
	t += d
	if t > 120.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = get_first_node_in_group("player")
			gm = root.get_node("GameManager")
			world = root.get_node("World/Islands")
			if not world.chain_ready():
				return false
			isl = world.chain_islands[world.chain().start_next[0]]
			arena = isl.get_node("Site_boss/Arena")
			ape = arena.boss
			check("a silverback sleeps on the beast's ground", ape != null and ape.state == 0 and ape.humanoid.stance == "ape")
			check("...twice a man's height", ape.humanoid.scale.y > 2.0)
			heal()
			put(near(40.0))
			wait = 1.0
			step = 1
		1:
			check("it doesn't stir with you 40 m off", ape.state == 0)
			put(near(15.0))
			wait = 0.6
			step = 2
		2:
			check("come close and it wakes with a roar", ape._special == "roar" and ape.humanoid.current_action() == "ape_beat")
			var hud = get_first_node_in_group("hud")
			check("...the boss bar shows", hud._boss_box.visible)
			wait = 2.2
			step = 3
		3:
			check("then it comes for you", ape.state in [2, 5, 7] and ape._special in ["", "swipe", "slam", "leap", "throw"])
			# the slam: stand in front of it
			heal()
			ape._cd = {"swipe": 99.0, "slam": 99.0, "leap": 99.0, "throw": 99.0}
			put(ape.global_position + ape._fwd() * 3.0)
			ape._special = ""
			ape._begin_special("slam")
			wait = 1.2
			step = 4
		4:
			check("the slam lands on you in front of it (%.0f)" % (hp0 - p.health_component.current_health), p.health_component.current_health < hp0)
			wait = 3.0
			step = 5
		5:
			heal()
			var inland: Vector2 = (isl.sites["village"] - isl.sites["boss"]).normalized()
			var target: Vector3 = ape.global_position + Vector3(inland.x, 0, inland.y) * 14.0
			put(target)
			ape._special = ""
			ape._begin_special("leap")
			set_meta("leap_to", ape._sp_target)
			wait = 0.6
			step = 6
		6:
			check("it leaps: up in the air", ape.global_position.y > (get_meta("leap_to") as Vector3).y + 2.0)
			wait = 1.0
			step = 7
		7:
			check("...and lands where it aimed (%.1f m off), on you" % ape.global_position.distance_to(get_meta("leap_to")),
				ape.global_position.distance_to(get_meta("leap_to")) < 2.0 and p.health_component.current_health < hp0)
			wait = 3.0
			step = 8
		8:
			heal()
			# (inland, toward the village: the far side's coast is close)
			var inland: Vector2 = (isl.sites["village"] - isl.sites["boss"]).normalized()
			put(ape.global_position + Vector3(inland.x, 0, inland.y) * 15.0)
			ape._special = ""
			ape._begin_special("throw")
			wait = 0.7
			step = 9
		9:
			check("it rips up a boulder", ape._rock != null)
			wait = 2.7
			step = 10
		10:
			print("   rock held %s, flying %d, hp %.0f / %.0f, special '%s', state %s, hurtbox %s" % [ape._rock != null, ape._rocks.size(), p.health_component.current_health, hp0, ape._special, p.current_state_name(), p.get_node("Hurtbox").monitorable])
			check("...hurls it, and it comes down on you", ape._rock == null and ape._rocks.is_empty() and p.health_component.current_health < hp0)
			wait = 2.5
			step = 11
		11:
			ape._special = ""
			ape._set_state(2)
			var hd := HitData.new()
			hd.damage = 90.0
			for k in range(3):
				ape._on_hit(hd, p)
			check("enough hits and it staggers", ape.state == 9)
			wait = 2.5
			step = 12
		12:
			ape._special = ""
			ape._begin_special("swipe")
			ape.parried(p)
			check("a parried swipe staggers it", ape.state == 9 and ape._special == "")
			ape.health.current_health = ape.health.max_health * 0.55
			wait = 0.3
			step = 13
		13:
			check("below 60%: phase 2, and it roars", ape.phase == 2 and ape._special == "roar")
			put(near(90.0))
			wait = 8.0
			step = 14
		14:
			check("everyone gone: it heads back, healed", ape.state in [0, 13] and ape.health.current_health == ape.health.max_health and ape.phase == 1)
			put(near(12.0))
			wait = 1.0
			step = 15
		15:
			ape.health.take_damage(999999.0)
			wait = 1.0
			step = 16
		16:
			check("killed: the victory", arena._celebrated)
			check("...the flag the village and the log pose read", root.get_node("Dialogue").has_flag(isl.save_key("boss_beaten")))
			check("...its hoard (with the Silverback Pelt)", arena.get_node_or_null("Hoard") != null and arena.get_node("Hoard").contents.any(func(s): return s.item.display_name == "Silverback Pelt"))
			var vil = isl.get_node("Site_village/Village")
			check("...and the village's job on it is done", vil.jobs["beast"]["check"].call())
			finish()
	return false

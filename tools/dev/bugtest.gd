extends SceneTree
## Scuttlebugs: spawned in the jungle, notice -> rear -> ram, hitstun, knockdown, death + gold.
var t := 0.0
var step := 0
var wait := 0.0
var p
var fails := 0
var nest
var bug
var seen := {}
var t0 := 0.0
var gold0 := 0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		if bug and is_instance_valid(bug): seen[bug.state] = true
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			var isl = root.get_node("World/Islands/Brinehollow")
			nest = isl.get_node("ScuttlebugNest")
			check("nest exists", nest != null)
			check("4 bugs spawned", nest.alive_count() == 4)
			var bigs := 0
			for s in nest.spots: if s["big"]: bigs += 1
			check("one big one", bigs == 1)
			for s in nest.spots:
				if not s["big"]: bug = s["bug"]; break
			check("small bug hp 30", is_equal_approx(bug.health.max_health, 30.0))
			print("   bug at ", bug.global_position, " on floor ", bug.is_on_floor())
			gold0 = p.inventory_component.count("gold")
			# stand 7 m from it
			var fwd := Vector3(1, 0, 0)
			p.global_position = bug.global_position + fwd * 7.0 + Vector3.UP * 0.5
			p.reset_physics_interpolation()
			seen.clear()
			wait = 4.0
		1:
			print("   states seen: ", seen.keys())
			check("noticed the player", seen.has(1) or seen.has(2))
			check("reared up (telegraph)", seen.has(3))
			check("rammed", seen.has(4))
			check("dazed afterwards", seen.has(6) or seen.has(5))
			check("ram hurt the player", p.health_component.current_health < p.health_component.max_health)
			# light hit -> hitstun
			var hit := HitData.new(); hit.damage = 8.0; hit.knockback_force = 6.0
			bug.hurtbox.take_hit(hit, p)
			check("light hit -> hitstun", bug.state == 7)
			wait = 0.4
		2:
			check("hitstun is brief", bug.state != 7)
			var hit := HitData.new(); hit.damage = 5.0; hit.knockback_force = 9.0; hit.knockdown = true
			bug.hurtbox.take_hit(hit, p)
			check("heavy hit -> ragdoll", bug.state == 8 and bug._rag != null)
			t0 = t
			step += 1
			return false
		3:
			if bug.state != 8 or t - t0 > 9.0:
				print("   down for ", snappedf(t - t0, 0.01), " s, flips tried ", bug._flip_tries)
				check("gets back up", bug.state != 8)
				check("ragdoll freed", bug._rag == null)
				check("upright again", bug.body_node.global_basis.orthonormalized().y.y > 0.9 or bug._settle_t < 1.0)
				step += 1
			return false
		4:
			wait = 0.5
		5:
			check("upright after settle", bug.body_node.global_basis.orthonormalized().y.y > 0.9)
			var hit := HitData.new(); hit.damage = 99.0; hit.knockback_force = 6.0
			p.global_position = bug.global_position + Vector3(1.5, 0.5, 0)
			bug.hurtbox.take_hit(hit, p)
			check("dies", bug.state == 9)
			check("death ragdoll", bug._rag != null)
			check("coins dropped", root.get_tree().current_scene.find_children("Coin*", "", false, false).size() > 0)
			wait = 2.5
		6:
			print("   gold ", gold0, " -> ", p.inventory_component.count("gold"))
			check("coins fly to the player", p.inventory_component.count("gold") > gold0)
			wait = 2.5
		7:
			check("dead bug sinks away", not is_instance_valid(bug))
			check("3 left alive", nest.alive_count() == 3)
			# respawn once far away
			nest.respawn_time = 0.5
			p.global_position = p.global_position + Vector3(60, 5, 0)
			wait = 1.5
		8:
			check("respawns when you're away", nest.alive_count() == 4)
			print("RESULT ", "OK" if fails == 0 else "%d FAILED" % fails)
			return true
	step += 1
	return false

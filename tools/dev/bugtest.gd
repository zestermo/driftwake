extends SceneTree
## Scuttlebugs: spawned in the jungle, notice -> rear -> ram, hitstun, knockdown, death + gold.
var t := 0.0
var step := 0
const TK := preload("res://tools/dev/test_kit.gd")
var until := 0
var p
var fails := 0
var nest
var bug
var seen := {}
var t0 := 0
var gold0 := 0
func _initialize(): load("res://tools/dev/test_kit.gd").seed_of(self); change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func _process(d: float) -> bool:
	t += d
	if TK.ticking(until):
		if bug and is_instance_valid(bug): seen[bug.state] = true
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			var isl = root.get_node("World/Islands/Brinehollow")
			nest = isl.get_node("ScuttlebugNest")
			check("nest exists", nest != null)
			check("a bug at every burrow (%d)" % nest.spots.size(), nest.spots.size() >= 10 and nest.alive_count() == nest.spots.size())
			var bigs := 0
			for s in nest.spots: if s["big"]: bigs += 1
			check("a few big ones (%d)" % bigs, bigs == 3)
			for s in nest.spots:
				if not s["big"]: bug = s["bug"]; break
			check("small bug hp 30", is_equal_approx(bug.health.max_health, 30.0))
			print("   bug at ", bug.global_position, " on floor ", bug.is_on_floor())
			gold0 = p.inventory_component.count("gold")
			# stand 7 m from it, on level ground (not off a cliff into the sea)
			var space := root.world_3d.direct_space_state
			var stand := Vector3.ZERO
			for i in 16:
				var dir := Vector3(cos(i * TAU / 16.0), 0, sin(i * TAU / 16.0))
				var level := true
				var spot := Vector3.ZERO
				for dist in [3.5, 7.0]:
					var at: Vector3 = bug.global_position + dir * dist
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 30.0, 1))
					if hit.is_empty() or absf(hit["position"].y - bug.global_position.y) > 1.5:
						level = false
						break
					spot = hit["position"]
				if level:
					stand = spot
					break
			check("level ground 7 m from the bug", stand != Vector3.ZERO)
			p.global_position = stand + Vector3.UP * 0.5
			p.reset_physics_interpolation()
			seen.clear()
			until = TK.wait_secs(4.0)
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
			until = TK.wait_secs(0.4)
		2:
			check("hitstun is brief", bug.state != 7)
			var hit := HitData.new(); hit.damage = 5.0; hit.knockback_force = 9.0; hit.knockdown = true
			bug.hurtbox.take_hit(hit, p)
			check("heavy hit -> ragdoll", bug.state == 8 and bug._rag != null)
			t0 = TK.wait_secs(9.0)
			step += 1
			return false
		3:
			if bug.state != 8 or not TK.ticking(t0):
				print("   down for ", snappedf(9.0 - (t0 - Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second), 0.01), " s, flips tried ", bug._flip_tries)
				check("gets back up", bug.state != 8)
				check("ragdoll freed", bug._rag == null)
				check("upright again", bug.body_node.global_basis.orthonormalized().y.y > 0.9 or bug._settle_t < 1.0)
				step += 1
			return false
		4:
			until = TK.wait_secs(0.5)
		5:
			check("upright after settle", bug.body_node.global_basis.orthonormalized().y.y > 0.9)
			var hit := HitData.new(); hit.damage = 99.0; hit.knockback_force = 6.0
			p.global_position = bug.global_position + Vector3(1.5, 0.5, 0)
			bug.hurtbox.take_hit(hit, p)
			check("dies", bug.state == 9)
			check("death ragdoll", bug._rag != null)
			# (1.22: 60% of kills pay coins; the rates are t/economy/drop_rates')
			until = TK.wait_secs(1.5)
		6:
			var left := root.get_tree().current_scene.find_children("Coin*", "", false, false)
			if not left.is_empty():
				p.global_position = (left[0] as Node3D).global_position + Vector3(1.5, 0.5, 0)
				p.reset_physics_interpolation()
			until = TK.wait_secs(2.0)
		7:
			print("   gold ", gold0, " -> ", p.inventory_component.count("gold"))
			check("coins fly to the player", p.inventory_component.count("gold") > gold0)
			until = TK.wait_secs(2.5)
		8:
			check("dead bug sinks away", not is_instance_valid(bug))
			check("the rest still alive", nest.alive_count() == nest.spots.size() - 1)
			# respawn once far away
			nest.respawn_time = 0.5
			p.global_position = p.global_position + Vector3(60, 5, 0)
			until = TK.wait_secs(1.5)
		9:
			check("respawns when you're away", nest.alive_count() == nest.spots.size())
			print("RESULT ", "OK" if fails == 0 else "%d FAILED" % fails)
			return true
	step += 1
	return false

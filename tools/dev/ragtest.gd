extends SceneTree
## Player ragdoll: knockdown -> get up, death -> stays down -> respawn.
var t := 0.0
var step := 0
var wait := 0.0
var p
var fails := 0
var t0 := 0.0
var max_sep := 0.0
var err_max := 0.0
var slide_sum := 0.0
var late_n := 0
var err_at := 0.0
var world_parts := false
var rest_at := -1.0
var fold_max := -99.0
var fold_min := 99.0
var err_sum := 0.0
var err_n := 0
var spins := []
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func st() -> String: return p.current_state_name()
func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.0: return false
			p = root.get_tree().get_first_node_in_group("player")
			p.knock_down(Vector3(0, 3.5, 6))
			wait = 0.05
		1:
			check("knockdown enters Downed", st() == "Downed")
			check("ragdoll exists", p.body_model.ragdoll != null)
			check("hurtbox off while down", not p.hurtbox.monitorable)
			t0 = t
			step += 1
			return false
		2:
			var hips: Vector3 = p.body_model.hips.global_position
			var sep := Vector2(hips.x - p.global_position.x, hips.z - p.global_position.z).length()
			if t - t0 > 0.6: max_sep = maxf(max_sep, sep)
			var rag = p.body_model.ragdoll
			if rag != null and not p.state_machine.current_state.getting_up:
				# what's drawn vs where the physics body is (interpolation mismatch = shimmer);
				# (this runs before the nodes' _process, so pose this frame first)
				rag.drive()
				var hn: Node3D = p.body_model.hips
				world_parts = hn.top_level and hn.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF
				var part: Dictionary = rag.parts[0]
				var want: Vector3 = ((part["body"] as RigidBody3D).get_global_transform_interpolated() * (part["offset"] as Transform3D)).origin
				var drawn: Vector3 = p.body_model.hips.get_global_transform_interpolated().origin
				var e := drawn.distance_to(want) if t - t0 > 0.1 else 0.0
				if e > err_max:
					err_max = e
					err_at = t - t0
				err_sum += e
				err_n += 1
				# once it's down: the bodies shouldn't creep along the ground or twitch
				if t - t0 > 1.4:
					var pb: RigidBody3D = rag.root_body()
					slide_sum += Vector2(pb.linear_velocity.x, pb.linear_velocity.z).length()
					late_n += 1
				# legs vs the pelvis while flying (rig terms: thigh x+ = forward/up)
				if t - t0 < 0.9:
					var hb: Basis = p.body_model.hips.global_basis.orthonormalized()
					for leg in [p.body_model.leg_l, p.body_model.leg_r]:
						var lx: float = (hb.inverse() * (leg as Node3D).global_basis.orthonormalized()).get_euler().x
						fold_max = maxf(fold_max, lx)
						fold_min = minf(fold_min, lx)
				var spin := 0.0
				for q in rag.parts:
					spin += (q["body"] as RigidBody3D).angular_velocity.length()
				spins.append(spin / rag.parts.size())
				if rag._rested and rest_at < 0.0:
					rest_at = t - t0
			if st() == "Idle" or t - t0 > 7.0:
				print("   got up after ", snappedf(t - t0, 0.01), " s  (max root/hips gap after 0.6s: ", snappedf(max_sep, 0.01), ")")
				var slide := slide_sum / maxf(late_n, 1)
				# limb spin over the last ~0.25 s before the get-up (at rest)
				var tail := spins.slice(maxi(spins.size() - 15, 0))
				var twitch := 0.0
				for s in tail:
					twitch += s
				twitch /= maxf(tail.size(), 1)
				print("   drawn-vs-body worst %.3f m at %.2f s, mean %.4f m; once down: pelvis slide %.3f m/s; at rest mean limb spin %.3f rad/s" % [err_max, err_at, err_sum / maxf(err_n, 1), slide, twitch])
				check("braced legs: the knees come up (thighs reach %.2f rad)" % fold_max, fold_max > 0.65)
				check("...and the legs don't fold back behind the body (%.2f rad)" % fold_min, fold_min > -0.6)
				check("the body's parts are placed in world space, uninterpolated, while down (no shimmer against the chasing root)", world_parts)
				check("...it comes to rest and is pinned there (at %.2f s)" % rest_at, rest_at > 0.5 and rest_at < 2.6)
				var hn: Node3D = p.body_model.hips
				check("...and handed back to the rig after the get-up", not hn.top_level and hn.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_INHERIT)
				check("once down it doesn't creep along the ground (%.3f m/s)" % slide, slide < 0.08)
				check("...or twitch at rest (mean limb spin %.3f rad/s)" % twitch, twitch < 0.3)
				check("gets back up (Idle)", st() == "Idle")
				check("ragdoll gone", p.body_model.ragdoll == null)
				check("root followed the body", max_sep < 1.0)
				var hp: Vector3 = p.body_model.hips.global_position - p.global_position
				check("standing again (hips ~0.9 above feet)", hp.y > 0.6 and hp.y < 1.3)
				print("   hips offset ", hp)
				step += 1
			return false
		3:
			p.health_component.take_damage(9999.0)
			wait = 0.1
		4:
			check("death ragdolls", st() == "Downed" and p.body_model.ragdoll != null)
			wait = 2.0
		5:
			check("dead body stays down", st() == "Downed" and p.body_model.ragdoll != null)
			wait = 1.6
		6:
			check("respawn -> Idle", st() == "Idle")
			check("ragdoll cleared on respawn", p.body_model.ragdoll == null)
			check("health restored", p.health_component.current_health > 0.0)
			var hp: Vector3 = p.body_model.hips.global_position - p.global_position
			check("respawned standing", hp.y > 0.6)
			# light hit -> short flinch
			var hit := HitData.new(); hit.damage = 5.0; hit.knockback_force = 4.0; hit.stagger_duration = 0.3
			wait = 0.5
		7:
			var hit := HitData.new(); hit.damage = 5.0; hit.knockback_force = 4.0; hit.stagger_duration = 0.3
			var hp0: float = p.health_component.current_health
			p.hurtbox.take_hit(hit, null)
			check("light hit -> Stagger (hitstun)", st() == "Stagger")
			check("took damage", p.health_component.current_health < hp0)
			wait = 0.3
		8:
			check("hitstun is short (<0.3 s)", st() != "Stagger")
			var hit := HitData.new(); hit.damage = 5.0; hit.knockdown = true; hit.knockback_force = 7.0
			p.hurtbox.take_hit(hit, null)
			check("knockdown hit -> Downed", st() == "Downed")
			wait = 0.1
		9:
			print("RESULT ", "OK" if fails == 0 else "%d FAILED" % fails)
			return true
	step += 1
	return false

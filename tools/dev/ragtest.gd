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
var knee_gap := 99.0
var err_sum := 0.0
var err_n := 0
var spins := []
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func st() -> String: return p.current_state_name()
## Tightest hip fold right now: angle between the chest's up and a thigh's down
## (standing ~PI; legs folded flat onto the torso ~0).
func fold_angle(rag) -> float:
	var up: Vector3 = rag.body("chest").global_basis.y
	var a := PI
	for sn in ["thigh_l", "thigh_r"]:
		a = minf(a, up.angle_to(-(rag.body(sn) as RigidBody3D).global_basis.y))
	return a
var knocks := [Vector3(0, 3.5, -6), Vector3(6, 3.5, 0), Vector3(0, 7, 5)]
var ki := 0
var min_fold := PI
var knee_all := 99.0
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
			var rg0 = p.body_model.ragdoll
			var chest_b: RigidBody3D = rg0.body("chest")
			var ex := chest_b.get_collision_exceptions()
			check("ragdoll parts collide with each other, thighs vs chest included (%d exempt pairs on the chest)" % ex.size(),
				chest_b.collision_mask & Ragdoll.LAYER != 0 and not ex.has(rg0.body("thigh_l")) and not ex.has(rg0.body("thigh_r")))
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
				# knees vs the chest (self-collision): never inside it
				var cb: RigidBody3D = rag.body("chest")
				var csg: Array = rag._by_name["chest"]["seg"]
				var c0: Vector3 = cb.global_transform * (csg[0] as Vector3)
				var c1: Vector3 = cb.global_transform * (csg[1] as Vector3)
				for sn in ["shin_l", "shin_r"]:
					var knee: Vector3 = rag.body(sn).global_position
					knee_gap = minf(knee_gap, knee.distance_to(Geometry3D.get_closest_point_to_segment(knee, c0, c1)))
				min_fold = minf(min_fold, fold_angle(rag))
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
				check("the knees never sink into the chest (closest %.2f m from its axis, chest radius 0.14)" % knee_gap, knee_gap > 0.15)
				check("braced legs: the knees come up (thighs reach %.2f rad)" % fold_max, fold_max > 0.65)
				check("...and the legs don't fold back behind the body (%.2f rad)" % fold_min, fold_min > -0.6)
				check("the body's parts are placed in world space, uninterpolated, while down (no shimmer against the chasing root)", world_parts)
				# (the get-up waits for rest; a forced one after MAX_DOWN would start ~3.9 s in)
				check("...it comes to rest by itself (pinned at %.2f s, up at %.2f s)" % [rest_at, t - t0], t - t0 < 3.6)
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
			t0 = t
			wait = 0.1
		9:
			# more falls (forward, sideways, a high backflip): the legs never fold flat onto the torso
			if st() != "Idle" and t - t0 < 8.0:
				var rg = p.body_model.ragdoll
				if rg != null:
					min_fold = minf(min_fold, fold_angle(rg))
					var cb2: RigidBody3D = rg.body("chest")
					var cs2: Array = rg._by_name["chest"]["seg"]
					var a0: Vector3 = cb2.global_transform * (cs2[0] as Vector3)
					var a1: Vector3 = cb2.global_transform * (cs2[1] as Vector3)
					for sn in ["shin_l", "shin_r"]:
						var kp: Vector3 = rg.body(sn).global_position
						knee_all = minf(knee_all, kp.distance_to(Geometry3D.get_closest_point_to_segment(kp, a0, a1)))
				return false
			if ki >= knocks.size():
				print("   tightest hip fold over the falls %.0f deg" % rad_to_deg(min_fold))
				check("in any fall the knees stay out of the chest (closest %.2f m from its axis; chest r 0.14 + shin r 0.06)" % knee_all, knee_all > 0.17)
				print("RESULT ", "OK" if fails == 0 else "%d FAILED" % fails)
				return true
			p.knock_down(knocks[ki])
			ki += 1
			t0 = t
			wait = 0.2
			if ki == knocks.size():
				# the last fall: fling both shins straight at the chest; only the
				# joint limits and self-collision can stop them
				step = 10
				return false
			return false
		10:
			var rg = p.body_model.ragdoll
			if rg != null:
				var cpos: Vector3 = rg.body("chest").global_position
				for sn in ["shin_l", "shin_r"]:
					var sb: RigidBody3D = rg.body(sn)
					sb.linear_velocity = (cpos - sb.global_position).normalized() * 12.0
			step = 9
			return false
	step += 1
	return false

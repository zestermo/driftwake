extends SceneTree
## Player ragdoll: knockdown -> get up, death -> stays down -> respawn.
var t := 0.0
var step := 0
var wait := 0.0
var p
var fails := 0
var t0 := 0.0
var max_sep := 0.0
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
			if st() == "Idle" or t - t0 > 7.0:
				print("   got up after ", snappedf(t - t0, 0.01), " s  (max root/hips gap after 0.6s: ", snappedf(max_sep, 0.01), ")")
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

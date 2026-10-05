extends SceneTree
## Grunt firearms: rifle shots on a line (hit when standing on it, miss when dodging/sidestepping),
## reposition, shove, pistol swap, heavy-attack glow, wider parry window.
const AIM := 15; const KEEP := 16; const REPOSITION := 17; const SHOVE := 18; const STAGGER := 9; const CIRCLE := 3; const DEAD := 14
var t := 0.0
var step := 0
var wait := 0.0
var p
var camp
var rifle
var fails := 0
var hp0 := 0.0
var seen := {}
var t0 := 0.0
var sword
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func _process(d: float) -> bool:
	t += d
	if rifle: seen[rifle.state] = true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			var riflemen: Array = camp.grunts.filter(func(x): return x.role == "rifle")
			check("two riflemen in the crew", riflemen.size() == 2)
			rifle = camp.grunts[2]
			check("sentry carries a rifle", rifle.role == "rifle" and rifle.humanoid.carry == "rifle")
			# keep the sword crew out of it for now
			for x in camp.grunts:
				if x != rifle: x.process_mode = Node.PROCESS_MODE_DISABLED
			p.global_position = rifle.global_position + rifle._fwd() * 12.0 + Vector3.UP * 0.5
			p.reset_physics_interpolation()
			hp0 = p.health_component.current_health
			t0 = t
			step += 1
			return false
		1:
			if rifle.state == AIM:
				check("aims at you, line visible", rifle._aim_line.visible)
				step += 1
			elif t - t0 > 8.0:
				check("rifleman takes aim", false); step = 99
			return false
		2:
			if rifle._fired:
				wait = 0.1
				step += 1
			return false
		3:
			print("   hp lost to the rifle: ", hp0 - p.health_component.current_health)
			check("standing on the line: hit (15 before armor)", hp0 - p.health_component.current_health >= 10.0)
			t0 = t
			step += 1
			return false
		4:
			if rifle.state == REPOSITION or t - t0 > 2.0:
				check("moves to a new firing spot after the shot", seen.has(REPOSITION))
				rifle._shot_cd = 0.0
				t0 = t
				step += 1
			return false
		5:
			# next shot: sidestep out of the line once it locks
			if rifle.state == AIM and rifle.st_t >= rifle._aim_len - rifle._lock_len + 0.05 and not has_meta("moved"):
				set_meta("moved", true)
				var side: Vector3 = Vector3.UP.cross((p.global_position - rifle.global_position).normalized())
				var isl = root.get_node("World/Islands/Brinehollow")
				var c1: Vector3 = p.global_position + side * 2.2
				var c2: Vector3 = p.global_position - side * 2.2
				var l1: Vector3 = isl.to_local(c1); var l2: Vector3 = isl.to_local(c2)
				var pick: Vector3 = c1 if isl.height_at(l1.x, l1.z) > isl.height_at(l2.x, l2.z) else c2
				var lp: Vector3 = isl.to_local(pick)
				p.global_position = isl.to_global(Vector3(lp.x, isl.height_at(lp.x, lp.z) + 0.3, lp.z))
				p.reset_physics_interpolation()
				hp0 = p.health_component.current_health
			if has_meta("moved") and rifle._fired:
				wait = 0.1; step += 1
			elif t - t0 > 14.0:
				check("second shot happened", false); step = 99
			return false
		6:
			check("sidestepped after the lock: missed", is_equal_approx(hp0, p.health_component.current_health))
			wait = 0.6
		7:
			# third shot: dodge i-frames through it
			rifle._shot_cd = 0.0
			t0 = t
			step += 1
			return false
		8:
			if rifle.state == AIM and rifle.st_t > rifle._aim_len - 0.05 and not has_meta("dodged"):
				set_meta("dodged", true)
				p.hurtbox.monitorable = false
				hp0 = p.health_component.current_health
			if has_meta("dodged") and rifle._fired:
				p.hurtbox.monitorable = true
				check("dodging through the shot: no damage", is_equal_approx(hp0, p.health_component.current_health))
				step += 1
			elif t - t0 > 14.0:
				var q := PhysicsRayQueryParameters3D.create(rifle.global_position + Vector3(0, 1.5, 0), p.global_position + Vector3(0, 1.1, 0), 1)
				q.exclude = [rifle.get_rid()]
				var h: Dictionary = rifle.get_world_3d().direct_space_state.intersect_ray(q)
				print("   ray hit ", h.get("collider"), " at ", h.get("position"), " player ", p.global_position, " rifle ", rifle.global_position)
				print("   rifle state ", rifle.state, " dist ", rifle.global_position.distance_to(p.global_position), " shot_cd ", rifle._shot_cd, " los ", rifle._los(p), " st_t ", rifle.st_t)
				check("third shot", false); step = 99
			return false
		9:
			wait = 0.6
		10:
			# get in close: shove
			rifle._shove_cd = 0.0
			rifle._shot_cd = 99.0
			p.global_position = rifle.global_position + rifle._fwd() * 1.8
			p.reset_physics_interpolation()
			hp0 = p.health_component.current_health
			t0 = t
			step += 1
			return false
		11:
			if rifle.state == SHOVE and rifle._shoved:
				wait = 0.05; step += 1
			elif t - t0 > 3.0:
				check("shoves when you're too close", false); step = 99
			return false
		12:
			print("   after shove: state ", p.current_state_name(), " hp lost ", hp0 - p.health_component.current_health, " dist ", p.global_position.distance_to(rifle.global_position))
			check("shove: small damage + knocked down", hp0 - p.health_component.current_health > 0.0 and p.current_state_name() == "Downed")
			wait = 1.0
		13:
			check("shove has a cooldown", rifle._shove_cd > 2.0)
			# pistol: a swordsman out of reach
			for x in camp.grunts: x.process_mode = Node.PROCESS_MODE_INHERIT
			rifle.process_mode = Node.PROCESS_MODE_DISABLED
			sword = camp.grunts[3]
			sword.alert()
			wait = 0.8
		14:
			p.global_position = sword.global_position + Vector3(12, 0.5, 0)
			p.reset_physics_interpolation()
			sword._start_aim("pistol")
			wait = 0.2
		15:
			check("pistol drawn (weapon swapped)", sword.state == AIM and sword._gun == "pistol")
			wait = 1.3
		16:
			check("cutlass back after the pistol shot", sword.state != AIM and sword._pistol_cd > 8.0)
			# heavy attack glow
			sword._attack = "lunge"
			sword._start_wind()
			check("lunge = heavy: blade glows", sword.humanoid.weapon.material_override != null)
			check("heavy hits harder", sword.hitbox.hit_data.damage > 12.0)
			wait = 1.2
		17:
			check("glow lasts about a second", sword.humanoid.weapon.material_override == null)
			var ps = p.state_machine.states["parry"]
			check("parry window widened (0.26 s)", is_equal_approx(ps.parry_window, 0.26))
			print("RESULT ", "OK" if fails == 0 else "%d FAILED" % fails)
			return true
		99:
			print("RESULT %d FAILED" % fails)
			return true
	step += 1
	return false

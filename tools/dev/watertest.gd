extends SceneTree
## Water for grunts and ragdolls: grunts avoid the sea, swim back to shore when
## they end up in it, ragdolls plunge under then float, knocked-down swimmers
## (grunt and player) bob up and swim on, dead bodies float.
const IDLE := 0; const DOWN := 11; const GETUP := 12; const RETURN := 13; const DEAD := 14; const SWIM := 19
var t := 0.0
var step := 0
var wait := 0.0
var p
var camp
var isl
var ocean
var fails := 0
var g
var g2
var t0 := 0.0
var deep := Vector3.INF
var edge := Vector3.INF
var max_d := -INF
var min_hip := INF
var saw := {}
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func surf(at: Vector3) -> float: return ocean.get_wave_height(at)
func feet_depth(x) -> float: return surf(x.global_position) - x.global_position.y
func hip_depth(h) -> float:
	var hp: Vector3 = h.hips.global_position
	return surf(hp) - hp.y
func _process(d: float) -> bool:
	t += d
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
			isl = root.get_node("World/Islands/Brinehollow")
			ocean = root.get_node("Ocean")
			# park the player far away so nobody gets alerted
			var ship = root.get_tree().get_first_node_in_group("ship")
			p.global_position = ship.global_transform * Vector3(0, 2.0, 0)
			p.reset_physics_interpolation()
			var c := Vector2(46, 110)
			var to_sea := Vector2(1, 0.15).normalized()
			for f in range(4, 90):
				var l: Vector2 = c + to_sea * float(f)
				var gp: Vector3 = isl.to_global(Vector3(l.x, 0, l.y))
				var dd: float = ocean.depth_at(gp)
				if edge == Vector3.INF and dd > 0.25:
					edge = gp
				if dd > 3.0 and dd < 30.0:
					deep = gp
					break
			print("   edge ", edge, " deep ", deep)
			check("found shore edge and deep water by the camp", edge != Vector3.INF and deep != Vector3.INF)
			for x in camp.grunts:
				var pd: float = ocean.depth_at(x.post, [], true)
				print("   post calm depth ", snappedf(pd, 0.01))
				if x.patrol.size() > 0:
					for q in x.patrol: print("     patrol pt ", snappedf(ocean.depth_at(q, [], true), 0.01))
			check("all posts on dry land", camp.grunts.all(func(x): return ocean.depth_at(x.post, [], true) <= 0.0))
			g = camp.grunts[0]
			g.humanoid.seated = false
			g.global_position = Vector3(deep.x, surf(deep) - 1.4, deep.z)
			g.reset_physics_interpolation()
			wait = 0.8
			step += 1
		1:
			print("   grunt state ", g.state, " feet depth ", snappedf(feet_depth(g), 0.01))
			check("grunt in deep water swims", g.state == SWIM and g.humanoid.swimming)
			var head_y: float = g.humanoid.head.global_position.y - surf(g.humanoid.head.global_position)
			print("   head above water ", snappedf(head_y, 0.01))
			check("grunt keeps his head above water", head_y > -0.05 and head_y < 0.9)
			t0 = t
			set_meta("d0", Vector2(g.global_position.x - edge.x, g.global_position.z - edge.z).length())
			step += 1
		2:
			if g.state == SWIM and t - t0 < 30.0: return false
			var dt := t - t0
			print("   out of the water after ", snappedf(dt, 0.1), " s, state ", g.state, " depth ", snappedf(feet_depth(g), 0.01))
			check("grunt swims back to shore", g.state != SWIM and dt < 30.0)
			check("standing in shallow water / on the beach", feet_depth(g) < 0.95)
			check("heads home after", g.state in [RETURN, IDLE])
			wait = 0.5
			step += 1
		3:
			# water avoidance: send a grunt home to a post out at sea
			g2 = camp.grunts[3]
			g2.humanoid.seated = false
			set_meta("post", g2.post)
			g2.global_position = edge + (edge - deep).normalized() * 4.0 + Vector3.UP * 1.0
			g2.reset_physics_interpolation()
			g2.post = deep
			g2._set_state(RETURN)
			max_d = -INF
			t0 = t
			step += 1
		4:
			max_d = maxf(max_d, feet_depth(g2))
			saw[g2.state] = true
			if t - t0 < 6.0: return false
			print("   deepest wade ", snappedf(max_d, 0.01), " states ", saw.keys())
			check("grunt won't walk into the sea", max_d < 1.0 and not saw.has(SWIM))
			g2.post = get_meta("post")
			# knocked into the sea: plunge under, float up, swim
			g2.global_position = Vector3(deep.x, surf(deep) + 1.0, deep.z)
			g2.reset_physics_interpolation()
			g2._knock_down(Vector3(1.0, -7.0, 0.0))
			min_hip = -INF
			saw.clear()
			t0 = t
			step += 1
		5:
			min_hip = maxf(min_hip, hip_depth(g2.humanoid))
			saw[g2.state] = true
			if g2.state == DOWN and t - t0 < 8.0: return false
			print("   sank to ", snappedf(min_hip, 0.01), " m under, recovered after ", snappedf(t - t0, 0.1), " s state ", g2.state)
			check("knocked-in body submerges", min_hip > 0.5)
			check("then floats up and swims (no get-up on the sea floor)", g2.state == SWIM and not saw.has(GETUP))
			wait = 0.5
			step += 1
		6:
			var hd := hip_depth(g2.humanoid)
			print("   swimming hip depth ", snappedf(hd, 0.01))
			check("swimming at the surface after", hd > -0.2 and hd < 0.8)
			# killed in the water: the body floats
			g2.health.take_damage(99999.0)
			wait = 4.0
			step += 1
		7:
			var hd := hip_depth(g2.humanoid)
			print("   dead body hip depth ", snappedf(hd, 0.01))
			check("dead body floats", g2.state == DEAD and hd > -0.4 and hd < 0.85)
			# the player: swimming, knocked under, floats back up and swims
			p.global_position = Vector3(deep.x + 3.0, surf(deep) - 0.5, deep.z + 3.0)
			p.reset_physics_interpolation()
			t0 = t
			wait = 1.0
			step += 1
		8:
			if p.current_state_name() != "Swim" and t - t0 < 4.0: return false
			check("player swimming", p.current_state_name() == "Swim")
			p.knock_down(Vector3(0.5, -6.0, 0.0))
			min_hip = -INF
			saw.clear()
			t0 = t
			step += 1
		9:
			min_hip = maxf(min_hip, hip_depth(p.body_model))
			saw[p.current_state_name()] = true
			if p.current_state_name() == "Downed" and t - t0 < 8.0: return false
			print("   player sank to ", snappedf(min_hip, 0.01), " m, state ", p.current_state_name(), " after ", snappedf(t - t0, 0.1), " s")
			check("player submerges as a ragdoll", min_hip > 0.5)
			check("player floats up and swims", p.current_state_name() == "Swim" and p.body_model.ragdoll == null)
			wait = 1.0
			step += 1
		10:
			var head_y: float = p.body_model.head.global_position.y - p.water_surface()
			print("   player head above water ", snappedf(head_y, 0.01))
			check("player treading water, head up", head_y > -0.05 and head_y < 0.9 and p.current_state_name() == "Swim")
			# knocked down on the deck (dry) still gets up normally
			var ship = root.get_tree().get_first_node_in_group("ship")
			p.global_position = ship.global_transform * Vector3(0, 2.0, 0)
			p.reset_physics_interpolation()
			wait = 2.0
			step += 1
		11:
			p.knock_down(Vector3(1.0, 3.0, 0.0))
			t0 = t
			saw.clear()
			step += 1
		12:
			saw[p.current_state_name()] = true
			if t - t0 < 5.0: return false
			print("   on land: ", saw.keys(), " now ", p.current_state_name())
			check("on land: get up as before", p.current_state_name() in ["Idle", "Move"] and not saw.has("Swim"))
			print("RESULT ", "OK" if fails == 0 else "FAILED %d" % fails)
			quit(1 if fails else 0)
	return false

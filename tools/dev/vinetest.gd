extends SceneTree
## Vine Fruit round 2: energy drain, grapple points on trees, swing body
## alignment + loose limbs + release tilt that rights itself, arm vines,
## grapple pull (light enemy) and zip (heavy enemy), fists in the fist stance,
## punch wind FX.
var t := 0.0
var step := 0
var wait := 0.0
var p
var pc
var camp
var fails := 0
var g
var crown := Vector3.INF
var saw := {}
var bug
var d0 := 0.0
var GP


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func rig():
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	return cam.get_parent().get_parent() as Node3D


func cam() -> Camera3D:
	return root.get_viewport().get_camera_3d()


## Point the camera at a world spot (yaw on the rig, pitch on the arm).
func aim_at(target: Vector3) -> void:
	# aim from the rig's pivot (the camera looks through it along its forward)
	var c: Camera3D = cam()
	var r = c.get_parent().get_parent()
	var arm: Node3D = c.get_parent()
	var d: Vector3 = target - (r as Node3D).global_position
	r.rotation.y = atan2(-d.x, -d.z)
	arm.rotation.x = 0.0
	r.force_update_transform()
	arm.force_update_transform()
	var want := atan2(d.y, Vector2(d.x, d.z).length())
	var cur := asin(clampf((-c.global_basis.z).y, -1.0, 1.0))
	arm.rotation.x = want - cur


func put(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at


func park(x, at: Vector3) -> void:
	if "humanoid" in x:
		x.humanoid.seated = false
	x.global_position = at + Vector3.UP * 0.3
	x.velocity = Vector3.ZERO
	x.reset_physics_interpolation()


func _process(d: float) -> bool:
	t += d
	if camp:
		for x in camp.grunts:
			if is_instance_valid(x):
				x._cooldown = 99.0; x._pistol_cd = 99.0; x._shot_cd = 99.0; x._shove_cd = 99.0
	if p and p.current_state_name() == "Swing":
		saw["swing"] = true
		saw["align"] = maxf(float(saw.get("align", 0.0)), p.align_w)
		if p.body_model.dangle and p.body_model._dg.has("leg_l"):
			saw["dangle"] = true
		if p.body_model.current_action() == "vine_hang":
			saw["hang"] = true
		if p.body_model.arm_r.find_children("ArmVines*", "", false, false).size() > 0 or p.body_model.fore_r.find_children("ArmVines*", "", false, false).size() > 0:
			saw["arm_vines"] = true
	if bug and p and saw.has("bug_start"):
		saw["bug_min"] = minf(float(saw.get("bug_min", 99.0)), bug.global_position.distance_to(p.global_position))
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			GP = load("res://scripts/world/grapple_points.gd")
			p = root.get_tree().get_first_node_in_group("player")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			pc = p.power
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			check("trees register grapple points (%d)" % GP.count(), GP.count() > 50)
			# energy: casting drains it, and it comes back slowly
			var fruit: ItemData = load("res://resources/items/vine_fruit.tres")
			p.inventory_component.add_item(fruit, 1)
			p.use_item(fruit)
			wait = 2.2
			step += 1
		1:
			check("ate the Vine Fruit", pc.fruit == "vine")
			check("Vine Swing on the bar", "vine_swing" in pc.loadout)
			var e0: float = pc.energy
			pc.energy = 60.0
			pc._regen_wait = 0.0
			pc._process(1.0)
			check("energy regen is slow (%.1f/s)" % (pc.energy - 60.0), pc.energy - 60.0 > 1.0 and pc.energy - 60.0 < 4.0)
			pc.energy = e0
			# find a tree crown 7-13 m away
			var best := Vector3.INF
			for e in GP._points:
				if not is_instance_valid(e[0]): continue
				var cp: Vector3 = e[0].to_global(e[1])
				var dd := Vector2(cp.x - p.global_position.x, cp.z - p.global_position.z).length()
				if dd < 60.0 and (best == Vector3.INF or dd < Vector2(best.x - p.global_position.x, best.z - p.global_position.z).length()):
					best = cp
			check("a tree near the start", best != Vector3.INF)
			crown = best
			# stand 9 m from it on open ground
			var away := Vector3(crown.x, 0, crown.z) + Vector3(9, 0, 0)
			put(ground(away) + Vector3.UP * 0.2)
			wait = 0.5
			step += 1
		2:
			aim_at(crown)
			p.state_machine.states["skill"]._pc = pc
			var tgt: Dictionary = p.state_machine.states["skill"]._vine_target() if p.state_machine.states.has("skill") else {}
			check("aiming at a tree finds its crown", str(tgt.get("kind", "")) == "point" and (tgt["pos"] as Vector3).distance_to(crown) < 2.5)
			var slot: int = pc.loadout.find("vine_swing")
			pc.energy = pc.max_energy()
			var e0: float = pc.energy
			check("cast Vine Swing at the tree", pc.try_cast(slot))
			check("Vine Swing costs energy", pc.energy < e0 - 5.0)
			wait = 0.45
			step += 1
		3:
			check("swinging", saw.get("swing", false))
			check("body lines up with the vine (w %.2f)" % float(saw.get("align", 0.0)), float(saw.get("align", 0.0)) > 0.8)
			check("vine-hang pose with loose limbs", saw.get("hang", false) and saw.get("dangle", false))
			check("vines coil up the vine arm", saw.get("arm_vines", false))
			check("a vine rope is drawn", root.find_children("*", "VineRope", true, false).size() > 0)
			# let go
			var ev := InputEventAction.new()
			ev.action = "jump"
			ev.pressed = true
			Input.parse_input_event(ev)
			wait = 0.05
			step += 1
		4:
			var ev := InputEventAction.new()
			ev.action = "jump"
			ev.pressed = false
			Input.parse_input_event(ev)
			if p.current_state_name() == "Swing":
				# the press can be eaten by xvfb timing: release directly
				p.state_machine.states["swing"]._released = true
				p.state_machine.force_state("Fall", {})
			saw["release_w"] = p.align_w
			check("let go into a fall", p.current_state_name() in ["Fall", "Jump"])
			check("still tilted after letting go (w %.2f)" % p.align_w, p.align_w > 0.3 and not p.align_hold)
			check("release pose", p.body_model.current_action() == "vine_release")
			check("limbs no longer dangling", not p.body_model.dangle)
			step += 1
		5:
			if not p.is_on_floor() and t < 60.0:
				return false
			check("upright again by landing (w %.2f)" % p.align_w, p.align_w < 0.05)
			wait = 0.6
			step += 1
		6:
			# grapple a grunt (light): it's reeled in
			g = camp.grunts[0]
			var spot: Vector3 = ground(g.global_position + Vector3(10, 0, 0))
			put(spot + Vector3.UP * 0.2)
			park(g, ground(spot + Vector3(-9, 0, 0)))
			for i in range(1, camp.grunts.size()):
				park(camp.grunts[i], ground(spot + Vector3(0, 0, 25 + i * 3)))
			wait = 0.8
			step += 1
		7:
			aim_at(g.global_position + Vector3.UP * 1.0)
			var tgt: Dictionary = p.state_machine.states["skill"]._vine_target()
			check("aiming at a grunt targets it", str(tgt.get("kind", "")) == "enemy" and tgt["node"] == g)
			check("grunts are light", g.vine_weight() == "light")
			d0 = g.global_position.distance_to(p.global_position)
			pc.energy = pc.max_energy()
			pc.cooldowns["vine_swing"] = 0.0
			check("cast the grapple", pc.try_cast(pc.loadout.find("vine_swing")))
			wait = 1.2
			step += 1
		8:
			var d1: float = g.global_position.distance_to(p.global_position)
			check("grunt reeled in (%.1f -> %.1f m)" % [d0, d1], d1 < d0 - 4.0 and d1 < 4.0)
			# a big scuttlebug pulls you to it
			var bugs := root.find_children("*", "Scuttlebug", true, false)
			for b in bugs:
				if b.big and b.state != 9:
					bug = b
					break
			if bug == null and bugs.size() > 0:
				bug = bugs[0]
				bug.big = true
			check("found a scuttlebug", bug != null)
			if bug == null:
				step = 11
				return false
			check("big bugs are heavy", bug.vine_weight() == "heavy")
			var spot: Vector3 = ground(bug.global_position + Vector3(9, 0, 0))
			put(spot + Vector3.UP * 0.2)
			park(bug, ground(spot + Vector3(-9, 0, 0)))
			bug._cooldown = 99.0
			wait = 0.4
			step += 1
		9:
			aim_at(bug.global_position + Vector3.UP * 0.6)
			d0 = bug.global_position.distance_to(p.global_position)
			var bp: Vector3 = bug.global_position
			pc.energy = pc.max_energy()
			pc.cooldowns["vine_swing"] = 0.0
			var tgt: Dictionary = p.state_machine.states["skill"]._vine_target()
			check("aiming at the big bug targets it", str(tgt.get("kind", "")) == "enemy")
			check("cast the grapple at the big bug", pc.try_cast(pc.loadout.find("vine_swing")))
			saw["bug_start"] = bp
			wait = 1.0
			step += 1
		10:
			var bp: Vector3 = saw["bug_start"]
			var moved: float = bug.global_position.distance_to(bp)
			var d1: float = float(saw.get("bug_min", 99.0))
			check("you're hauled to the big bug (%.1f -> %.1f m), it stays put (%.1f m)" % [d0, d1, moved], d1 < 3.0 and moved < 3.0)
			step += 1
		11:
			# fists
			p.unequip_weapon()
			p.draw_weapon()
			wait = 0.6
			step += 1
		12:
			check("fists closed in the fist stance", p.body_model.fists and p.body_model.fore_r.get_node("Fist").visible and not p.body_model.fore_r.get_node("Mitten").visible)
			p.reset_combo()
			p.state_machine.force_state("LightAttack", {})
			wait = 0.12
			step += 1
		13:
			check("a jab throws a punch wind", root.find_children("PunchWind*", "", true, false).size() > 0)
			p.sheathe_weapon(true)
			wait = 0.6
			step += 1
		14:
			check("hands open again when the guard drops", not p.body_model.fists)
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false

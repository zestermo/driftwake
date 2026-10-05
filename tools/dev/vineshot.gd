extends SceneTree
## Renders: vine swing from a tree (+ release), grapple pull on a grunt,
## punches with wind, flying kick. Args: <out_prefix>
var t := 0.0
var step := 0
var wait := 0.0
var p
var pc
var camp
var out := ""
var shot_cam: Camera3D
var r2: Node3D
var GP
var crown := Vector3.INF
var g
var frames := 0
var follow := true
var side := Vector3(4.5, 1.2, 0)
var look_off := Vector3(0, 1.0, 0)


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func cam() -> Camera3D:
	return p.get_viewport().get_camera_3d() if shot_cam == null or not shot_cam.current else p.get_node("CameraRig").get_node_or_null("SpringArm3D/Camera3D")


func player_cam() -> Camera3D:
	return root.get_node("World/CameraRig/SpringArm3D/Camera3D") as Camera3D


func aim_at(target: Vector3) -> void:
	# aim from the rig's pivot (the camera looks through it along its forward)
	var c: Camera3D = player_cam()
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


func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at


func put(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])


func use_shot_cam(on: bool) -> void:
	shot_cam.current = on
	if not on:
		player_cam().current = true


func _process(d: float) -> bool:
	t += d
	if camp:
		for x in camp.grunts:
			if is_instance_valid(x):
				x._cooldown = 99.0; x._pistol_cd = 99.0; x._shot_cd = 99.0; x._shove_cd = 99.0
	if p and shot_cam and follow:
		var foc: Vector3 = p.global_position + look_off
		r2.global_position = foc
		shot_cam.global_position = foc + side
		shot_cam.look_at(foc, Vector3.UP)
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 2.0: return false
			for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
			GP = load("res://scripts/world/grapple_points.gd")
			p = root.get_tree().get_first_node_in_group("player")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			pc = p.power
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			r2 = Node3D.new(); var a2 := Node3D.new()
			root.add_child(r2); r2.add_child(a2)
			shot_cam = Camera3D.new(); shot_cam.fov = 55; shot_cam.far = 500
			a2.add_child(shot_cam)
			var fruit: ItemData = load("res://resources/items/vine_fruit.tres")
			p.inventory_component.add_item(fruit, 1)
			p.use_item(fruit)
			wait = 2.5
			step += 1
		1:
			# a crown away from buildings, 9 m off
			var best := Vector3.INF
			var bd := INF
			for e in GP._points:
				if not is_instance_valid(e[0]): continue
				var cp: Vector3 = e[0].to_global(e[1])
				var dd := Vector2(cp.x - p.global_position.x, cp.z - p.global_position.z).length()
				if dd > 15.0 and dd < bd:
					bd = dd
					best = cp
			crown = best
			put(ground(Vector3(crown.x + 9.0, 0, crown.z)) + Vector3.UP * 0.2)
			wait = 0.6
			step += 1
		2:
			aim_at(crown)
			var sk = p.state_machine.states["skill"]
			sk._pc = pc
			var c = p.get_viewport().get_camera_3d()
			print("cam ", c, " ", c.get_path(), " fwd ", -c.global_basis.z, " to crown ", (crown - c.global_position).normalized(), " crown ", crown, " p ", p.global_position)
			print("target ", sk._vine_target())
			pc.energy = pc.max_energy()
			print("cast swing ", pc.try_cast(pc.loadout.find("vine_swing")), " ", p.current_state_name())
			side = Vector3(0.5, 1.0, 7.5)
			look_off = Vector3(0, 0.6, 0)
			use_shot_cam(true)
			frames = 0
			step += 1
		3:
			frames += 1
			if frames < 8:
				print("f", frames, " ", p.current_state_name(), " pos ", p.global_position, " v ", p.velocity, " floor ", p.is_on_floor(), " d ", Engine.get_frames_drawn())
			if frames in [3, 6, 9, 12]:
				shot("swing_%02d" % frames)
				print(frames, " state ", p.current_state_name(), " align ", p.align_w)
			if frames == 13:
				if p.current_state_name() == "Swing":
					p.state_machine.states["swing"]._released = true
					p.velocity.y += 5.0
					p.state_machine.force_state("Fall", {})
			if frames in [15, 18]:
				shot("release_%02d" % frames)
			if frames >= 18:
				use_shot_cam(false)
				step += 1
		4:
			# grapple a grunt
			g = camp.grunts[0]
			var spot: Vector3 = ground(g.global_position + Vector3(10, 0, 0))
			put(spot + Vector3.UP * 0.2)
			g.humanoid.seated = false
			g.global_position = ground(spot + Vector3(-9, 0, 0)) + Vector3.UP * 0.3
			g.reset_physics_interpolation()
			for i in range(1, camp.grunts.size()):
				camp.grunts[i].global_position = ground(spot + Vector3(0, 0, 25 + i * 3)) + Vector3.UP * 0.3
			wait = 0.8
			step += 1
		5:
			aim_at(g.global_position + Vector3.UP)
			pc.energy = pc.max_energy()
			pc.cooldowns["vine_swing"] = 0.0
			print("cast grapple ", pc.try_cast(pc.loadout.find("vine_swing")))
			side = Vector3(-1.5, 1.2, 6.5)
			look_off = Vector3(-4.0, 1.0, 0)
			use_shot_cam(true)
			frames = 0
			step += 1
		6:
			frames += 1
			if frames in [2, 4, 6]:
				shot("pull_%02d" % frames)
			if frames >= 6:
				step += 1
				wait = 1.0
		7:
			# punches
			p.unequip_weapon()
			p.draw_weapon()
			look_off = Vector3(0, 1.0, 0)
			side = Vector3(-3.2, 1.0, -2.6)
			p.player_model.rotation.y = 0.0
			aim_at(p.global_position + Vector3(0, 1.2, -12))
			wait = 0.8
			step += 1
		8:
			shot("guard")
			p.reset_combo()
			p.state_machine.force_state("LightAttack", {})
			frames = 0
			step += 1
		9:
			frames += 1
			if frames == 2:
				shot("jab")
			if frames == 6:
				p.state_machine.force_state("LightAttack", {"combo_index": 1, "chain": true})
			if frames == 8:
				shot("cross")
			if frames == 12:
				p.state_machine.force_state("LightAttack", {"combo_index": 2, "chain": true})
			if frames == 14:
				shot("hook")
			if frames == 18:
				p.state_machine.force_state("LightAttack", {"combo_index": 3, "chain": true})
			if frames == 21:
				shot("roundhouse")
			if frames == 28:
				p.state_machine.force_state("HeavyAttack", {})
			if frames == 32:
				shot("flying_kick")
			if frames >= 33:
				quit()
	return false

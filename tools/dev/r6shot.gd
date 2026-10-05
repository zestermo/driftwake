extends SceneTree
## Round 6 renders. Args: <out_prefix>
var t := 0.0
var step := 0
var wait := 0.0
var p
var pc
var camp
var g
var out := ""
var shot_cam: Camera3D
var r2: Node3D
var frames := 0
var side := Vector3(-2.6, 0.9, -2.2)
var look_off := Vector3(0, 1.1, 0)
var follow := true


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func player_cam() -> Camera3D:
	return root.get_node("World/CameraRig/SpringArm3D/Camera3D") as Camera3D


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
	print("shot ", n, " state ", p.current_state_name(), " act ", p.body_model.current_action())


func face_rig(dir: Vector3) -> void:
	var r = player_cam().get_parent().get_parent()
	r.rotation.y = atan2(-dir.x, -dir.z)
	p.player_model.rotation.y = atan2(-dir.x, -dir.z)


func _process(d: float) -> bool:
	t += d
	if camp:
		for x in camp.grunts:
			if is_instance_valid(x):
				x._cooldown = 99.0; x._pistol_cd = 99.0; x._shot_cd = 99.0; x._shove_cd = 99.0; x._peril_cd = 99.0
	if p and shot_cam and follow:
		var b: Basis = p.player_model.global_basis
		var foc: Vector3 = p.global_position + look_off
		r2.global_position = foc
		shot_cam.global_position = foc + b * side
		shot_cam.look_at(foc, Vector3.UP)
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 2.0: return false
			for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
			p = root.get_tree().get_first_node_in_group("player")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			pc = p.power
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			r2 = Node3D.new(); var a2 := Node3D.new()
			root.add_child(r2); r2.add_child(a2)
			shot_cam = Camera3D.new(); shot_cam.fov = 50; shot_cam.far = 500
			a2.add_child(shot_cam)
			var fruit: ItemData = load("res://resources/items/vine_fruit.tres")
			p.inventory_component.add_item(fruit, 1)
			p.use_item(fruit)
			p.progression.level = 12
			p.progression.skill_points = 30
			for nid in ["c_spirit", "h_arm", "h_coat"]:
				p.progression.learn(nid)
			wait = 2.5
			step += 1
		1:
			# open ground near the camp
			var spot: Vector3 = ground(camp.grunts[0].global_position + Vector3(10, 0, 0))
			put(spot + Vector3.UP * 0.2)
			for i in range(camp.grunts.size()):
				camp.grunts[i].global_position = ground(spot + Vector3(0, 0, 25 + i * 3)) + Vector3.UP * 0.3
			face_rig(Vector3(-1, 0, 0))
			wait = 0.6
			step += 1
		2:
			shot_cam.current = true
			# vine aura after Vine Snare
			pc.energy = pc.max_energy()
			pc.try_cast(pc.loadout.find("vine_snare"))
			wait = 0.9
			step += 1
		3:
			side = Vector3(-1.4, 0.4, -2.0)
			wait = 0.15
			step += 1
		4:
			shot("vine_aura")
			# dash with vines on the ground
			side = Vector3(-3.5, 2.2, 1.5)
			look_off = Vector3(0, 0.3, 0)
			Input.action_press("move_left")
			p.state_machine.force_state("Dodge", {})
			wait = 0.28
			step += 1
		5:
			Input.action_release("move_left")
			shot("vine_dash")
			wait = 2.0
			step += 1
		6:
			# Armament: Coat with the cutlass
			look_off = Vector3(0, 1.1, 0)
			side = Vector3(-1.6, 0.5, -1.9)
			p.draw_weapon()
			pc.equip("armament_coat", 3)
			pc.energy = pc.max_energy()
			pc.try_cast(3)
			wait = 0.8
			step += 1
		7:
			shot("haki_arm")
			p.reset_combo()
			p.state_machine.force_state("LightAttack", {})
			frames = 0
			step += 1
		8:
			frames += 1
			if frames == 2:
				shot("haki_slash")
			if frames >= 3:
				p.power.buffs["coat"] = 0.0
				wait = 0.8
				step += 1
		9:
			# blocking: sword, then fists
			Input.action_press("parry")
			p.state_machine.force_state("Block", {})
			wait = 0.5
			step += 1
		10:
			shot("block_sword")
			Input.action_release("parry")
			p.unequip_weapon()
			p.draw_weapon()
			wait = 0.6
			step += 1
		11:
			side = Vector3(-0.9, 0.25, -1.3)
			look_off = Vector3(0, 1.35, 0)
			wait = 0.3
			step += 1
		12:
			shot("fist_guard_close")
			Input.action_press("parry")
			p.state_machine.force_state("Block", {})
			side = Vector3(-1.6, 0.4, -2.0)
			look_off = Vector3(0, 1.1, 0)
			wait = 0.5
			step += 1
		13:
			shot("block_fists")
			Input.action_release("parry")
			p.state_machine.force_state("Idle", {})
			# a grunt's red wind-up
			g = camp.grunts[0]
			g.humanoid.seated = false
			var fw: Vector3 = -p.player_model.global_basis.z
			g.global_position = ground(p.global_position + fw * 3.0) + Vector3.UP * 0.3
			g.reset_physics_interpolation()
			g._yaw = atan2(fw.x, fw.z)
			g.facing.rotation.y = g._yaw
			g._attack = "peril"
			g._start_wind()
			side = Vector3(-3.0, 0.9, -1.0)
			look_off = Vector3(0, 1.0, -1.5)
			wait = 0.6
			step += 1
		14:
			shot("grunt_peril")
			# skill map tabs
			shot_cam.current = false
			player_cam().current = true
			root.get_node("GameMenu").open("skills")
			wait = 0.4
			step += 1
		15:
			shot("map_main")
			root.get_node("GameMenu")._skills.set_tab(1)
			wait = 0.3
			step += 1
		16:
			shot("map_fruit")
			root.get_node("GameMenu").close()
			wait = 0.4
			step += 1
		17:
			shot("hud")
			quit()
	return false

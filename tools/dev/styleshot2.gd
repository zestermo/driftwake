extends SceneTree
## Fighting styles, fruit forms and the skill map. Args: <out_prefix>
var t := 0.0
var p
var cam: Camera3D
var r2: Node3D
var out := ""
var phase := 0
var t0 := 0.0
var camp
var shots := []
var yaw := 0.0
var side := true
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n, " act ", p.body_model.current_action(), " state ", p.current_state_name(), " style ", p.style())
func item(id: String):
	return load("res://resources/items/%s.tres" % id)
func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at
func act(a: String) -> void:
	# xvfb frames are slow (the input buffer would expire): enter the state directly
	match a:
		"light_attack":
			p.state_machine.force_state("Shoot" if p.weapon_class() == "gun" else "LightAttack", {})
		"heavy_attack":
			p.state_machine.force_state("HeavyAttack", {})
## queue: [delay, label, callable-or-null]
func run(seq: Array) -> void:
	shots = seq
	t0 = t
func _process(d: float) -> bool:
	t += d
	if camp:
		for x in camp.grunts:
			if is_instance_valid(x):
				x._cooldown = 99.0; x._pistol_cd = 99.0; x._shot_cd = 99.0; x._shove_cd = 99.0
	if t < 1.5: return false
	if p == null:
		for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
		p = root.get_tree().get_first_node_in_group("player")
		camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
		p.health_component.max_health = 99999.0
		p.health_component.current_health = 99999.0
		var isl = root.get_node("World/Islands/Brinehollow")
		var spot := ground(isl.to_global(Vector3(30, 0, 92)))
		p.global_position = spot + Vector3.UP * 0.2
		p.reset_physics_interpolation()
		cam = Camera3D.new(); cam.fov = 50; cam.far = 600
		r2 = Node3D.new(); var a2 := Node3D.new()
		root.add_child(r2); r2.add_child(a2); a2.add_child(cam)
		return false
	# camera: side view of the player (the rig's yaw keeps "forward" = -Z)
	r2.global_position = p.global_position
	r2.rotation.y = 0.0
	var foc: Vector3 = p.global_position + Vector3(0, 1.0, 0)
	cam.global_position = foc + (Vector3(3.6, 0.5, -0.6) if side else Vector3(0.8, 0.5, -3.6))
	cam.look_at(foc, Vector3.UP)
	match phase:
		0:
			if t < 4.0: return false
			cam.current = true
			var hud = root.get_tree().get_first_node_in_group("hud")
			if hud: hud.visible = true
			p.player_model.rotation.y = PI
			p.inventory_component.add_item(item("pistol"), 2)
			p.equip_weapon(item("pistol"), false)
			p.set_offhand(item("pistol"))
			p.draw_weapon()
			side = true
			phase = 1; t0 = t
		1:
			if t - t0 < 0.8: return false
			shot("a_dual_pistols")
			act("light_attack")
			phase = 2; t0 = t
		2:
			if t - t0 < 0.06: return false
			shot("b_pistol_fire")
			phase = 3; t0 = t
		3:
			if t - t0 < 0.8: return false
			p.inventory_component.add_item(item("wolf_fruit"), 1)
			p.state_machine.force_state("Idle", {})
			p.use_item(item("wolf_fruit"))
			phase = 4; t0 = t
		4:
			if t - t0 < 2.2: return false
			p.toggle_hybrid()
			side = false
			phase = 5; t0 = t
		5:
			if t - t0 < 1.5: return false
			shot("c_wolf_front")
			side = true
			phase = 6; t0 = t
		6:
			if t - t0 < 0.3: return false
			shot("d_wolf_side")
			p.toggle_hybrid()
			p.power.fruit = "ember"
			phase = 7; t0 = t
		7:
			if t - t0 < 1.0: return false
			p.state_machine.force_state("Dodge", {})
			phase = 8; t0 = t
		8:
			if t - t0 < 0.12: return false
			shot("e_logia_dodge")
			p.power.fruit = "vine"
			phase = 9; t0 = t
		9:
			if t - t0 < 1.0: return false
			p.state_machine.force_state("Swing", {"anchor": p.global_position + Vector3(3, 7, -2)})
			phase = 10; t0 = t
		10:
			if t - t0 < 0.5: return false
			shot("f_vine_swing")
			phase = 11; t0 = t
		11:
			if t - t0 < 2.5: return false
			p.progression.add_xp(p.progression.xp_to_next(1))
			phase = 12; t0 = t
		12:
			if t - t0 < 1.6: return false
			shot("g_level_up")
			quit()
	return false

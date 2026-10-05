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
	cam.global_position = foc + (Vector3(3.6, 0.5, -0.6) if side else Vector3(1.2, 1.4, 4.0))
	cam.look_at(foc, Vector3.UP)
	match phase:
		0:
			if t < 4.0: return false
			cam.current = true
			var hud = root.get_tree().get_first_node_in_group("hud")
			if hud: hud.visible = true
			p.player_model.rotation.y = 0.0
			# fists
			p.unequip_weapon()
			p.draw_weapon()
			phase = 1; t0 = t
		1:
			if t - t0 < 0.6: return false
			shot("01_fist_stance")
			p.reset_combo(); act("light_attack")
			phase = 2; t0 = t
		2:
			if t - t0 < 0.1: return false
			shot("02_jab")
			phase = 3; t0 = t
		3:
			if t - t0 < 0.5: return false
			p.state_machine.force_state("LightAttack", {"combo_index": 3, "chain": true})
			phase = 4; t0 = t
		4:
			if t - t0 < 0.22: return false
			shot("03_roundhouse")
			phase = 5; t0 = t
		5:
			if t - t0 < 0.8: return false
			act("heavy_attack")
			phase = 6; t0 = t
		6:
			if t - t0 < 0.3: return false
			shot("04_flying_kick")
			phase = 7; t0 = t
		7:
			if t - t0 < 1.0: return false
			p.inventory_component.add_item(item("cutlass"), 1)
			p.equip_weapon(p.inventory_component.find_item("cutlass"), false)
			if p.offhand_weapon == null:
				p.set_offhand(item("cutlass"))
			p.sheathe_weapon(true)
			p.draw_weapon()
			phase = 8; t0 = t
		8:
			if t - t0 < 0.8: return false
			shot("05_dual_stance")
			p.reset_combo(); act("light_attack")
			phase = 9; t0 = t
		9:
			if t - t0 < 0.17: return false
			shot("06_dual_slash")
			phase = 10; t0 = t
		10:
			if t - t0 < 0.4: return false
			p.state_machine.force_state("LightAttack", {"combo_index": 2, "chain": true})
			phase = 11; t0 = t
		11:
			if t - t0 < 0.2: return false
			shot("07_dual_cross")
			phase = 12; t0 = t
		12:
			if t - t0 < 0.8: return false
			act("heavy_attack")
			phase = 13; t0 = t
		13:
			if t - t0 < 0.27: return false
			shot("08_dual_heavy")
			phase = 14; t0 = t
		14:
			if t - t0 < 1.2: return false
			p.inventory_component.add_item(item("pistol"), 2)
			p.equip_weapon(item("pistol"), false)
			p.set_offhand(null)
			p.sheathe_weapon(true)
			p.draw_weapon()
			phase = 15; t0 = t
		15:
			if t - t0 < 0.6: return false
			shot("09_pistol_stance")
			act("light_attack")
			phase = 16; t0 = t
		16:
			if t - t0 < 0.05: return false
			shot("10_pistol_shot")
			phase = 17; t0 = t
		17:
			if t - t0 < 0.8: return false
			p.set_offhand(item("pistol"))
			p.sheathe_weapon(true)
			p.draw_weapon()
			phase = 18; t0 = t
		18:
			if t - t0 < 0.6: return false
			shot("11_dual_pistols")
			act("heavy_attack")
			phase = 19; t0 = t
		19:
			if t - t0 < 0.35: return false
			shot("12_gun_kata")
			phase = 20; t0 = t
		20:
			if t - t0 < 1.0: return false
			# wolf hybrid
			p.inventory_component.add_item(item("wolf_fruit"), 1)
			p.state_machine.force_state("Idle", {})
			p.use_item(item("wolf_fruit"))
			phase = 21; t0 = t
		21:
			if t - t0 < 2.0: return false
			side = false
			p.toggle_hybrid()
			phase = 22; t0 = t
		22:
			if t - t0 < 1.2: return false
			shot("13_wolf_hybrid")
			side = true
			p.reset_combo(); act("light_attack")
			phase = 23; t0 = t
		23:
			if t - t0 < 0.15: return false
			shot("14_claw")
			phase = 24; t0 = t
		24:
			if t - t0 < 0.8: return false
			p.progression.level = 10
			p.progression.skill_points = 9
			for nid in ["c_agility", "m_geppo", "m_soru", "c_strength", "w_blade", "w_flying", "c_vitality", "v_hardy"]:
				p.progression.learn(nid)
			p.progression.xp = 600
			var gm = root.get_node("GameMenu")
			gm.open("skills")
			phase = 25; t0 = t
		25:
			if t - t0 < 0.5: return false
			shot("15_skill_map")
			var gm = root.get_node("GameMenu")
			gm._skills._zoom = 0.9
			gm._skills._pan = Vector2(-120, -150)
			gm._skills._sel = "m_soru"
			phase = 26; t0 = t
		26:
			if t - t0 < 0.3: return false
			shot("16_skill_map_zoom")
			quit()
	return false

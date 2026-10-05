extends SceneTree
## Ember Fruit + skill bar shots. Args: <out_prefix>
var t := 0.0
var p
var pc
var cam: Camera3D
var r2: Node3D
var out := ""
var phase := 0
var t0 := 0.0
var camp
var isl
var g
var g2
var g3
var yaw := 0.0
var cam_off := Vector3(1.1, 2.0, 4.6)
var follow := true
var shots := []
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n, " state ", p.current_state_name(), " e ", snappedf(pc.energy, 1), " ult ", snappedf(pc.ult, 1))
func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at
func park(x, at: Vector3, face_to: Vector3) -> void:
	x.humanoid.seated = false
	x.global_position = at + Vector3.UP * 0.2
	x.velocity = Vector3.ZERO
	x.reset_physics_interpolation()
	var d := face_to - at
	x._yaw = atan2(-d.x, -d.z)
	x.facing.rotation.y = x._yaw
func put(at: Vector3, y_: float) -> void:
	p.global_position = at + Vector3.UP * 0.2
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	yaw = y_
	p.player_model.rotation.y = y_
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
		pc = p.power
		p.health_component.max_health = 140.0
		p.health_component.current_health = 140.0
		camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
		isl = root.get_node("World/Islands/Brinehollow")
		g = camp.grunts[0]; g2 = camp.grunts[3]; g3 = camp.grunts[1]
		cam = Camera3D.new(); cam.fov = 60; cam.far = 600
		r2 = Node3D.new(); var a2 := Node3D.new()
		root.add_child(r2); r2.add_child(a2); a2.add_child(cam)
		var c: Vector3 = isl.to_global(Vector3(30, 0, 92))
		var spot := ground(c)
		put(spot, 0.0)
		return false
	if follow and r2:
		r2.global_position = p.global_position
		r2.rotation.y = yaw
		cam.position = cam_off
		cam.look_at(p.global_position + Vector3(0, 1.3, 0) - Vector3(sin(yaw), 0, cos(yaw)) * 4.0, Vector3.UP)
	var e := t - t0
	match phase:
		0:
			if t < 4.0: return false
			cam.current = true
			var hud = root.get_tree().get_first_node_in_group("hud")
			if hud: hud.visible = true
			phase = 1; t0 = t
		1:
			if e < 0.6: return false
			shot("01_hud_nofruit")
			var fruit: ItemData = load("res://resources/items/ember_fruit.tres")
			p.inventory_component.add_item(fruit, 1)
			p.use_item(fruit)
			cam_off = Vector3(0.6, 1.7, -2.4)
			phase = 2; t0 = t
		2:
			if e < 0.7: return false
			shot("02_eating")
			phase = 3; t0 = t
		3:
			if e < 1.4: return false
			shot("03_eaten")
			cam_off = Vector3(1.1, 2.0, 4.6)
			# a grunt ahead for the fire fist
			var fwd := -Vector3(sin(yaw), 0, cos(yaw))
			park(g, ground(p.global_position + fwd * 9.0), p.global_position)
			park(g2, ground(p.global_position + fwd * 30.0 + Vector3(30, 0, 0)), p.global_position)
			park(g3, ground(p.global_position + fwd * 30.0 + Vector3(-30, 0, 0)), p.global_position)
			phase = 4; t0 = t
		4:
			if e < 0.8: return false
			pc.try_cast(0)
			phase = 5; t0 = t
		5:
			if e < 0.24: return false
			shot("04_fire_fist")
			phase = 6; t0 = t
		6:
			if e < 0.25: return false
			shot("05_fireball_hit")
			phase = 7; t0 = t
		7:
			if e < 1.4: return false
			shot("06_burning_hud_cooldown")
			# blazing ring with two grunts close
			park(g, ground(p.global_position + Vector3(2.2, 0, -1.0)), p.global_position)
			park(g3, ground(p.global_position + Vector3(-2.0, 0, -1.5)), p.global_position)
			g.health.current_health = 110.0
			phase = 8; t0 = t
		8:
			if e < 1.0: return false
			pc.energy = 100.0
			pc.try_cast(2)
			phase = 9; t0 = t
		9:
			if e < 0.32: return false
			shot("07_blazing_ring")
			phase = 10; t0 = t
		10:
			if e < 0.6: return false
			shot("08_ring_after")
			phase = 11; t0 = t
		11:
			if e < 3.5: return false
			pc.energy = 100.0
			pc.try_cast(3)
			phase = 12; t0 = t
		12:
			if e < 1.4: return false
			shot("09_ember_field")
			phase = 13; t0 = t
		13:
			if e < 2.0: return false
			for z in root.get_tree().get_nodes_in_group("fire_zones"): z.queue_free()
			pc.energy = 100.0
			cam_off = Vector3(3.5, 2.2, 1.5)
			phase = 14; t0 = t
		14:
			if e < 0.5: return false
			pc.try_cast(1)
			phase = 15; t0 = t
		15:
			if e < 0.25: return false
			shot("10_flame_dash")
			phase = 16; t0 = t
		16:
			if e < 0.5: return false
			shot("11_dash_trail")
			phase = 17; t0 = t
		17:
			if e < 3.0: return false
			for z in root.get_tree().get_nodes_in_group("fire_zones"): z.queue_free()
			var here: Vector3 = p.global_position
			park(g, ground(here + Vector3(3.5, 0, -1.0)), here)
			park(g3, ground(here + Vector3(-3.0, 0, -2.5)), here)
			g.health.current_health = 110.0
			g3.health.current_health = 110.0
			cam_off = Vector3(2.0, 3.5, 8.0)
			pc.ult = pc.ULT_MAX
			phase = 18; t0 = t
		18:
			if e < 1.2: return false
			shot("12_ult_ready")
			pc.try_cast(4)
			phase = 19; t0 = t
		19:
			if e < 0.3: return false
			shot("13_inferno_rise")
			phase = 20; t0 = t
		20:
			if p.current_state_name() == "Skill" and p.state_machine.current_state.get("_slammed") != true and e < 1.0: return false
			phase = 21; t0 = t
		21:
			if e < 0.12: return false
			shot("14_inferno_slam")
			phase = 22; t0 = t
		22:
			if e < 0.9: return false
			shot("15_inferno_after")
			phase = 23; t0 = t
		23:
			if e < 2.0: return false
			# parry sparks: a grunt swings into a parry
			for z in root.get_tree().get_nodes_in_group("fire_zones"): z.queue_free()
			var here: Vector3 = p.global_position
			var gg = camp.grunts[2]
			park(gg, ground(here - Vector3(sin(yaw), 0, cos(yaw)) * 1.6), here)
			cam_off = Vector3(2.4, 1.8, 0.6)
			phase = 24; t0 = t
		24:
			if e < 0.8: return false
			p.state_machine.force_state("Parry", {})
			var hd := HitData.new(); hd.damage = 10.0
			p.hurtbox.take_hit(hd, camp.grunts[2])
			phase = 25; t0 = t
		25:
			if e < 0.05: return false
			shot("16_parry")
			phase = 26; t0 = t
		26:
			if e < 0.6: return false
			# thornbrush around the jungle stash
			var thorn = isl.get_node("Thornbrush0")
			var tp: Vector3 = thorn.global_position
			var stash: Vector3 = isl.to_global(Vector3(-92, 0, 14))
			var away := (tp - stash); away.y = 0; away = away.normalized()
			var at := ground(tp + away * 5.0)
			put(at, atan2(away.x, away.z))
			cam_off = Vector3(1.5, 2.2, 4.0)
			phase = 27; t0 = t
		27:
			if e < 1.2: return false
			shot("17_thornbrush")
			pc.energy = 100.0
			pc.cooldowns[0] = 0.0
			pc.try_cast(0)
			phase = 28; t0 = t
		28:
			if e < 1.0: return false
			shot("18_thorn_burning")
			phase = 29; t0 = t
		29:
			if e < 3.5: return false
			shot("19_thorn_burned")
			# the curse
			var ship = root.get_tree().get_first_node_in_group("ship")
			p.global_position = ship.global_transform * Vector3(7.0, 2.0, 0.6)
			p.reset_physics_interpolation()
			cam_off = Vector3(2.5, 1.0, 3.5)
			phase = 30; t0 = t
		30:
			if e < 1.8: return false
			shot("20_sinking")
			quit()
	return false

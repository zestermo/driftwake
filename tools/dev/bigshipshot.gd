extends SceneTree
## The bigger ship: from outside (side, three-quarter stern, bow), the main
## deck toward the quarterdeck and stairs, inside the cabin (bunk, galley,
## storage), up on the quarterdeck at the helm, the crow's nest, and an enemy
## ship alongside for scale. Args: <out_prefix> [psx]
var t := 0.0
var out := ""
var cam: Camera3D
var ship
var p
var shots: Array = []
var i := -1
var t0 := 0.0


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func L(v: Vector3) -> Vector3:
	return ship.global_transform * v


func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if cam == null:
		if OS.get_cmdline_user_args().has("psx"): root.get_node("Settings").set_value("video", "psx_preset", 4, false)
		else: root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		ship = get_first_node_in_group("ship")
		p = get_first_node_in_group("player")
		var w = root.get_node("Weather")
		w.forced = 0
		w.forced_at = w.world_time() - 100.0
		w.world_offset += fposmod(11.0 - float(w.hour()), 24.0) / 24.0 * float(w.DAY_LEN)
		cam = Camera3D.new(); cam.fov = 60; cam.far = 1500
		root.add_child(cam); cam.current = true
		var HB = load("res://scripts/ship/hull_builder.gd")
		# (the refit's third pair of guns, up on the quarterdeck)
		ship._add_gun_pair(2)
		shots = [
			["side", Vector3(-26, 6, -1), Vector3(0, 4, -1), Vector3(0, 0.5, -4)],
			["stern", Vector3(-15, 9, 22), Vector3(0, 3, 4), Vector3(0, 0.5, -4)],
			["bow", Vector3(9, 5, -24), Vector3(0, 3, -4), Vector3(0, 0.5, -4)],
			["deck_aft", Vector3(0.5, 2.3, -5), Vector3(0, 2.2, 6), Vector3(1.0, 0.5, 0.0)],
			["cabin_bunk", Vector3(1.2, 1.9, 5.6), Vector3(-3.0, 0.6, 8.6), Vector3(0.0, 0.5, 6.2)],
			["cabin_galley", Vector3(-1.4, 1.9, 5.6), Vector3(3.2, 0.8, 8.2), Vector3(0.0, 0.5, 6.2)],
			["cabin_door", Vector3(0.0, 1.9, 9.3), Vector3(-1.0, 0.8, 5.0), Vector3(-1.0, 0.5, 7.0)],
			["quarterdeck", Vector3(-2.6, 4.6, 9.4), Vector3(0, 3.0, 4.0), Vector3(0, HB.QD_Y + 0.05, HB.HELM_Z)],
			["nest", Vector3(-2.2, HB.NEST_Y + 2.2, HB.MAST_Z + 3.0), Vector3(0, HB.NEST_Y - 3.0, -8.0), Vector3(0.4, HB.NEST_Y + 0.1, HB.MAST_Z + 0.4)],
			["rigging", Vector3(-9.0, 7.0, -6.0), Vector3(3.0, 8.0, -1.8), Vector3(0, 0.5, -4)],
			["with_enemy", Vector3(-30, 12, 22), Vector3(6, 3, -2), Vector3(0, 0.5, -4)],
			["bow_deck", Vector3(0.3, 2.6, -4.5), Vector3(0, 1.0, -12.6), Vector3(-1.5, 0.5, -3)],
			["stairs", Vector3(-0.8, 2.2, -1.8), Vector3(3.3, 1.2, 3.6), Vector3(-1.5, 0.5, -3)],
			["climb_ladder", Vector3(7.0, 0.6, -0.4), Vector3(4.4, -0.2, -2.9), Vector3(0, 0.5, -4), "ladder"],
			["climb_rig", Vector3(9.0, 6.5, 2.6), Vector3(3.4, 4.6, -1.8), Vector3(0, 0.5, -4), "rig"],
			["climb_armed", Vector3(9.0, 6.5, -6.0), Vector3(3.4, 4.6, -1.8), Vector3(0, 0.5, -4), "rig_armed"],
		]
		return false
	if i < 0 or t - t0 > 1.3:
		if i >= 0:
			root.get_texture().get_image().save_png("%s_%s.png" % [out, shots[i][0]])
			print("shot ", shots[i][0])
		i += 1
		if i >= shots.size():
			quit()
			return false
		var s: Array = shots[i]
		p.global_position = L(s[3])
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		if s[0] == "with_enemy":
			var es = get_nodes_in_group("enemy_ships")[0]
			es.global_transform = Transform3D(ship.global_basis, L(Vector3(12.5, 0, 0)) + Vector3(0, es.global_position.y - ship.global_position.y, 0))
			es._pos = Vector3(es.global_position.x, 0, es.global_position.z)
			es._heading = ship.global_rotation.y
			es.speed = 0.0
			es.set_physics_process(false)
		if s.size() > 4:
			# hanging on part way up (the climb state placed at s metres)
			var cs = p.state_machine.states["climb"]
			if s[4] == "ladder":
				var lad = ship.ship_model.get_node("LadderStarboard")
				p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
				p.global_position = lad.global_transform * Vector3(0, -2.6, 0.6)
				p.start_climb({"kind": "ladder", "ladder": lad})
				cs.keys.clear()
				cs.s = 1.6
			else:
				if s[4] == "rig_armed":
					p.equip_weapon(load("res://resources/items/cutlass.tres"), false)
					p.draw_weapon(true)
				p.start_climb({"kind": "rig", "rig": ship.ship_model.get_node("RiggingS"), "up": true})
				cs.keys.clear()
				cs.s = 4.5
		cam.global_position = L(s[1])
		cam.look_at(L(s[2]), Vector3.UP)
		t0 = t
	return false

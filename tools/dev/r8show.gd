extends SceneTree
## Round 8 showcase: a broadside, boarders, a sinking pirate ship, Morrow's
## slam and Red Tide whirl, a crew marker, the kneel. Args: <out_prefix>
var t := 0.0
var p
var ship
var es
var fort
var boss
var out := ""
var cam: Camera3D
var phase := 0
var t0 := 0.0
var hud


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, name])
	print("shot ", name)


func look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


func _process(d: float) -> bool:
	t += d
	if t < 1.5:
		return false
	if p == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for n in root.find_children("*", "CharacterCreator", true, false):
			n._finish(true)
		p = get_first_node_in_group("player")
		p.health_component.max_health = 99999.0
		p.health_component.current_health = 99999.0
		ship = get_first_node_in_group("ship")
		es = get_nodes_in_group("enemy_ships")[0]
		fort = root.find_children("*", "RedtideFort", true, false)[0]
		boss = fort.boss
		hud = get_first_node_in_group("hud")
		cam = Camera3D.new()
		cam.fov = 55
		cam.far = 1500
		root.add_child(cam)
		return false
	var e := t - t0
	match phase:
		0:
			# the crew's ship out past the harbour, a pirate abeam
			p.global_position = Vector3(150, 3, 100)
			p.reset_physics_interpolation()
			var spot: Vector3 = es.global_position + es._right() * 36.0
			ship.place(Vector3(spot.x, 0.5, spot.z), es.global_rotation.y + 0.4)
			phase = 1
			t0 = t
		1:
			if e < 0.4:
				return false
			p.global_position = ship.global_position + Vector3(0, 1.4, 1.0)
			p.reset_physics_interpolation()
			hud.visible = false
			cam.current = true
			phase = 2
			t0 = t
		2:
			look(ship.global_transform * Vector3(-3, 4.5, 9), es.global_position + Vector3(0, 2, 0))
			if es._warn_t > 1.1 or e > 14.0:
				shot("broadside")
				phase = 3
				t0 = t
		3:
			look(ship.global_transform * Vector3(-3, 4.5, 9), es.global_position + Vector3(0, 2, 0))
			if e < 0.7:
				return false
			shot("broadside_impact")
			var bp: Vector3 = ship.global_position + ship.global_basis.x * 8.0
			es._pos = Vector3(bp.x, 0, bp.z)
			es._heading = ship.global_rotation.y
			es._set_state(4)
			phase = 4
			t0 = t
		4:
			if e < 0.4:
				return false
			es._board(ship)
			phase = 5
			t0 = t
		5:
			look(ship.global_transform * Vector3(-7, 4, 6), ship.global_transform * Vector3(4, 1.5, 0))
			if e < 0.55:
				return false
			shot("boarders")
			phase = 6
			t0 = t
		6:
			look(ship.global_transform * Vector3(-7, 4, 6), ship.global_transform * Vector3(2, 1.0, 0))
			if e < 1.6:
				return false
			shot("boarders_landed")
			for g in es.boarders:
				if is_instance_valid(g):
					g.health.take_damage(99999.0)
			var h := HitData.new()
			h.damage = 99999.0
			h.siege = true
			es.hurtbox.take_hit(h, p)
			phase = 7
			t0 = t
		7:
			look(es.global_position + es._right() * -18.0 + Vector3(0, 6, 8), es.global_position + Vector3(0, 1, 0))
			if e < 3.2:
				return false
			shot("sinking")
			# the boss: inside the fort
			p.global_position = fort.to_global(Vector3(0, 6.4, 3.0))
			p.reset_physics_interpolation()
			ship.place(Vector3(150, 0.5, 40), 0.0)
			p.global_position = fort.to_global(Vector3(0, 6.4, 3.0))
			p.reset_physics_interpolation()
			phase = 8
			t0 = t
		8:
			if e < 2.0:
				return false
			boss.health.current_health = boss.health.max_health * 0.5
			phase = 9
			t0 = t
		9:
			if e < 2.4:
				return false
			for g in fort.crew:
				if is_instance_valid(g):
					g.queue_free()
			if p.current_state_name() == "Downed":
				p.body_model.end_ragdoll()
				p.body_model.reset_pose()
			p.state_machine.force_state("Idle", {})
			p.global_position = boss.global_position + boss._fwd() * 7.0
			p.reset_physics_interpolation()
			boss._special = ""
			boss._set_state(3)
			boss._attack = "slam"
			boss._begin_special("slam")
			phase = 10
			t0 = t
		10:
			var mid: Vector3 = (boss.global_position + p.global_position) * 0.5
			look(mid + boss.facing.global_basis * Vector3(8, 4.5, 0), mid + Vector3(0, 1.2, 0))
			if e < 1.15:
				return false
			shot("slam")
			phase = 11
			t0 = t
		11:
			if e < 2.0:
				return false
			boss.health.current_health = boss.health.max_health * 0.25
			phase = 12
			t0 = t
		12:
			if e < 2.5:
				return false
			if p.current_state_name() == "Downed":
				p.body_model.end_ragdoll()
				p.body_model.reset_pose()
			p.state_machine.force_state("Idle", {})
			p.global_position = boss.global_position + boss._fwd() * 4.0
			p.reset_physics_interpolation()
			boss._special = ""
			boss._set_state(3)
			boss._attack = "whirl"
			boss._begin_special("whirl")
			phase = 13
			t0 = t
		13:
			look(boss.global_position + Vector3(4.5, 2.6, 4.5), boss.global_position + Vector3(0, 1.2, 0))
			if e < 0.7:
				return false
			shot("redtide_whirl")
			# HUD: the boss bar and a crew marker
			hud.visible = true
			cam.current = false
			p.state_machine.force_state("Idle", {})
			phase = 14
			t0 = t
		14:
			if e < 1.0:
				return false
			p.place_marker()
			phase = 15
			t0 = t
		15:
			if e < 0.5:
				return false
			shot("hud")
			# the kneel (a pose check)
			hud.visible = false
			cam.current = true
			p.global_position = fort.to_global(Vector3(-4, 6.4, 8.0))
			p.reset_physics_interpolation()
			boss.queue_free()
			phase = 16
			t0 = t
		16:
			if e < 0.5:
				return false
			p.set_physics_process(false)
			p.body_model.kneeling = true
			phase = 17
			t0 = t
		17:
			look(p.global_position + p.player_model.global_basis * Vector3(2.2, 1.3, -1.6), p.global_position + Vector3(0, 0.6, 0))
			if e < 0.8:
				return false
			shot("kneel")
			quit()
	return false

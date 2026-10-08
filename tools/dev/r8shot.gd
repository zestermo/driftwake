extends SceneTree
## Round 8 renders: Redtide Rock, an enemy ship, Captain Morrow, the boss bar.
## Args: <out_prefix>
var t := 0.0
var p
var out := ""
var cam: Camera3D
var phase := 0
var t0 := 0.0
var fort
var es
var boss
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, name])
	print("shot ", name)
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if p == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
		p = root.get_tree().get_first_node_in_group("player")
		fort = root.find_children("*", "RedtideFort", true, false)[0]
		cam = Camera3D.new(); cam.fov = 55; cam.far = 1500
		root.add_child(cam)
		return false
	var e := t - t0
	match phase:
		0:
			var hud = root.get_tree().get_first_node_in_group("hud")
			if hud: hud.visible = false
			cam.current = true
			# from the sea, south-east of the rock
			cam.global_position = fort.to_global(Vector3(38, 14, 62))
			cam.look_at(fort.to_global(Vector3(0, 6, 0)), Vector3.UP)
			# park the player in the fort so things stream/animate near it
			p.global_position = fort.to_global(Vector3(0, 6.3, 12))
			p.reset_physics_interpolation()
			phase = 1; t0 = t
		1:
			if e < 1.5: return false
			shot("fort")
			cam.global_position = fort.to_global(Vector3(-6, 13, 22))
			cam.look_at(fort.to_global(Vector3(0, 6, -6)), Vector3.UP)
			phase = 2; t0 = t
		2:
			if e < 0.6: return false
			shot("arena")
			boss = root.find_children("*", "RedtideFort", true, false)[0].boss
			cam.global_position = boss.global_position + boss.facing.global_basis * Vector3(1.2, 2.0, -3.6)
			cam.look_at(boss.global_position + Vector3(0, 1.6, 0), Vector3.UP)
			phase = 3; t0 = t
		3:
			if e < 0.6: return false
			shot("morrow")
			es = root.get_tree().get_nodes_in_group("enemy_ships")[0]
			phase = 4; t0 = t
		4:
			cam.global_position = es.global_transform * Vector3(16, 7, -10)
			cam.look_at(es.global_transform * Vector3(0, 3, -1), Vector3.UP)
			if e < 0.8: return false
			shot("enemy_ship")
			cam.global_position = es.global_transform * Vector3(-14, 4, 6)
			cam.look_at(es.global_transform * Vector3(0, 4, -1), Vector3.UP)
			phase = 5; t0 = t
		5:
			if e < 0.4: return false
			shot("enemy_ship2")
			phase = 50; t0 = t
		50:
			# its crew on deck, close up
			cam.global_position = es.global_transform * Vector3(7.5, 4.5, 3.0)
			cam.look_at(es.global_transform * Vector3(0, 1.2, -0.8), Vector3.UP)
			if e < 0.4: return false
			shot("enemy_crew")
			# start the boss fight: HUD back, player inside the gate
			var hud = root.get_tree().get_first_node_in_group("hud")
			if hud: hud.visible = true
			p.global_position = fort.to_global(Vector3(0, 6.3, -2))
			p.reset_physics_interpolation()
			boss.alert()
			cam.current = false
			phase = 6; t0 = t
		6:
			if e < 2.0: return false
			shot("bossbar")
			quit()
	return false

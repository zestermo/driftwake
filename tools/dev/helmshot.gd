extends SceneTree
## Captain at the helm. Args: <out_prefix>
var t := 0.0
var p
var ship
var out := ""
var idx := 0
var cam: Camera3D
var phase := 0
var t0 := 0.0
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
		var hud = root.get_tree().get_first_node_in_group("hud")
		if hud: hud.visible = false
		p = root.get_tree().get_first_node_in_group("player")
		ship = root.get_tree().get_first_node_in_group("ship")
		cam = Camera3D.new(); cam.fov = 50; cam.far = 800
		root.add_child(cam)
		return false
	var e := t - t0
	match phase:
		0:
			if t < 2.5: return false
			# moored, from the dock side
			cam.current = true
			cam.global_position = ship.global_transform * Vector3(-16, 7, 6)
			cam.look_at(ship.global_transform * Vector3(0, 4.5, 0), Vector3.UP)
			phase = 1; t0 = t
		1:
			if e < 0.4: return false
			shot("moored")
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
			Input.action_press("move_forward")
			ship.sail = 1.0
			phase = 2; t0 = t
		2:
			if e < 4.0: return false
			Input.action_press("move_right")
			phase = 3; t0 = t
		3:
			if e < 1.2: return false
			cam.current = false
			var hud = root.get_tree().get_first_node_in_group("hud")
			if hud: hud.visible = true
			phase = 31; t0 = t
		31:
			if e < 0.15: return false
			shot("helmcam")
			var hud = root.get_tree().get_first_node_in_group("hud")
			if hud: hud.visible = false
			cam.current = true
			phase = 4; t0 = t
		4:
			cam.global_position = ship.global_transform * Vector3(2.4, 2.3, 1.6)
			cam.look_at(p.global_position + Vector3(0, 1.0, -0.3), Vector3.UP)
			if e < 0.3: return false
			shot("captain")
			phase = 5; t0 = t
		5:
			cam.global_position = ship.global_transform * Vector3(-1.8, 2.0, 1.4)
			cam.look_at(p.global_position + Vector3(0, 1.0, -0.4), Vector3.UP)
			if e < 0.3: return false
			shot("captain2")
			Input.action_release("move_right")
			phase = 6; t0 = t
		6:
			cam.global_position = ship.global_transform * Vector3(16, 7, -10)
			cam.look_at(ship.global_transform * Vector3(0, 1, -2), Vector3.UP)
			if e < 0.4: return false
			shot("sailing")
			quit()
	return false

extends SceneTree
## Cannons on the sloop: overview, manning pose, gun camera with the arc,
## a shot in flight. Args: <out_prefix>
var t := 0.0
var p
var ship
var out := ""
var cam: Camera3D
var phase := 0
var t0 := 0.0
var c
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
		ship = root.get_tree().get_first_node_in_group("ship")
		cam = Camera3D.new(); cam.fov = 50; cam.far = 800
		root.add_child(cam)
		return false
	var e := t - t0
	match phase:
		0:
			if t < 2.5: return false
			var hud = root.get_tree().get_first_node_in_group("hud")
			if hud: hud.visible = false
			cam.current = true
			cam.global_position = ship.global_transform * Vector3(9, 7, -9)
			cam.look_at(ship.global_transform * Vector3(0, 1, -1), Vector3.UP)
			phase = 1; t0 = t
		1:
			if e < 0.5: return false
			shot("deck")
			c = ship.cannons[3]
			p.global_position = c.global_position + Vector3(0, 0.3, 0)
			p.reset_physics_interpolation()
			p.man_cannon(c)
			phase = 2; t0 = t
		2:
			if e < 0.8: return false
			cam.global_position = c.global_transform * Vector3(-2.2, 1.8, 2.4)
			cam.look_at(c.global_position + Vector3(0, 0.9, 0.3), Vector3.UP)
			if e < 1.0: return false
			shot("manning")
			var hud = root.get_tree().get_first_node_in_group("hud")
			if hud: hud.visible = true
			c.pitch = 0.12
			c.yaw = 0.2
			cam.current = false
			c.camera.current = true
			phase = 3; t0 = t
		3:
			if e < 0.6: return false
			shot("guncam")
			c.fire(p)
			phase = 4; t0 = t
		4:
			if e < 0.35: return false
			shot("fire")
			phase = 5; t0 = t
		5:
			if e < 0.9: return false
			shot("flight")
			quit()
	return false

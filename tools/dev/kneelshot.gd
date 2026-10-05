extends SceneTree
## The kneel pose and a crew marker on the HUD. Args: <out_prefix>
var t := 0.0
var p
var out := ""
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
	if t < 2.0:
		return false
	var e := t - t0
	match phase:
		0:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			for n in root.find_children("*", "CharacterCreator", true, false):
				n._finish(true)
			p = get_first_node_in_group("player")
			# a marker out on the water, ahead of the camera
			var c3 := get_root().get_viewport().get_camera_3d()
			phase = 1
			t0 = t
		1:
			if e < 1.0:
				return false
			p.place_marker()
			phase = 2
			t0 = t
		2:
			if e < 0.6:
				return false
			shot("marker")
			get_first_node_in_group("hud").visible = false
			p.set_physics_process(false)
			p.body_model.kneeling = true
			cam = Camera3D.new()
			cam.fov = 45
			root.add_child(cam)
			cam.current = true
			phase = 3
			t0 = t
		3:
			cam.global_position = p.global_position + p.player_model.global_basis * Vector3(2.0, 1.2, -1.8)
			cam.look_at(p.global_position + Vector3(0, 0.6, 0), Vector3.UP)
			if e < 0.8:
				return false
			shot("kneel")
			quit()
	return false

extends SceneTree
## Swimmer vs waves, side view, several moments. Args: <out_prefix>
var t := 0.0
var p
var cam: Camera3D
var out := ""
var n := 0
var t0 := 0.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if p == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		p = get_first_node_in_group("player")
		var ship = get_first_node_in_group("ship")
		p.global_position = ship.global_transform * Vector3(14.0, 2.0, 4.0)
		p.reset_physics_interpolation()
		cam = Camera3D.new(); cam.fov = 40
		root.add_child(cam); cam.current = true
		t0 = t
		return false
	var f := Vector3(1, 0, 0.3).normalized()
	var hd: Vector3 = p.body_model.head.global_position
	cam.global_position = hd + Vector3(-f.z, 0, f.x) * 6.0 + Vector3(0, 2.2, 0)
	cam.look_at(hd, Vector3.UP)
	if t - t0 > 2.0 + n * 0.7:
		root.get_texture().get_image().save_png("%s_%d.png" % [out, n])
		var oc = root.get_node("Ocean")
		print("shot ", n, " state ", p.current_state_name(), " head-surf ", snappedf(p.body_model.head.global_position.y - oc.get_wave_height(p.body_model.head.global_position), 0.01))
		n += 1
		if n >= 4: quit()
	return false

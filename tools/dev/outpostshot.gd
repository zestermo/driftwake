extends SceneTree
## A Marine outpost (MarineOutpost) stood up in front of the captain in Brinehollow, filmed from two sides. Args: <out_dir>
var t := 0.0
var step := 0
var o


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "res://tools/dev/out/outpost"
	var p = root.get_tree().get_first_node_in_group("player")
	if step == 0 and t > 3.0:
		step = 1
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var scene: Node3D = root.get_tree().current_scene
		o = load("res://scripts/island/marine_outpost.gd").make(scene, Vector2.ZERO, 0.0, "shot_outpost", 1, 2, rng)
		o.global_position = p.global_position + Vector3(0, 0, -12.0)
		o.rotation.y = 0.0
		var cam := Camera3D.new()
		cam.name = "ShotCam"
		scene.add_child(cam)
		cam.global_position = o.global_position + Vector3(7.0, 4.0, 11.0)
		cam.look_at(o.global_position + Vector3(1.0, 1.6, 0.0))
		cam.make_current()
	if step == 1 and t > 5.0:
		step = 2
		root.get_texture().get_image().save_png(out + "/front.png")
		var cam: Camera3D = root.get_tree().current_scene.get_node("ShotCam")
		cam.global_position = o.global_position + Vector3(-9.0, 6.0, -8.0)
		cam.look_at(o.global_position + Vector3(0.0, 1.5, 0.0))
	if step == 2 and t > 6.0:
		root.get_texture().get_image().save_png(out + "/back.png")
		print("SAVED")
		quit()
	return false

extends SceneTree
var t := 0.0
var step := 0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if step == 0 and t > 1.5:
		var p = root.get_tree().get_first_node_in_group("player")
		var isl = root.get_node("World/Islands/Brinehollow")
		var v = isl.VILLAGE + Vector2(-2, 10)
		p.global_position = Vector3(150 + v.x, isl.hv(v) + 0.3, 150 + v.y); p.reset_physics_interpolation()
		p.player_model.rotation.y = PI
		var rig = root.get_node("World/CameraRig"); rig.rotation.y = PI + 0.3
		step = 1; t = 0
	elif step == 1 and t > 2.5:
		root.get_texture().get_image().save_png("res://tools/dev/out/village.png"); print("SAVED"); quit()
	return false

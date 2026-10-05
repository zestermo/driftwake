extends SceneTree
## PSX renderer comparison: a far view of the village from the beach.
## Args: <out_prefix>
var t := 0.0
var step := 0
var wait := 0.0
var p
var out := ""


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func cam() -> Camera3D:
	return root.get_node("World/CameraRig/SpringArm3D/Camera3D") as Camera3D


func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)


func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 2.0:
				return false
			for n in root.find_children("*", "CharacterCreator", true, false):
				n._finish(true)
			p = get_first_node_in_group("player")
			var rig = cam().get_parent().get_parent()
			rig.rotation.y = deg_to_rad(205)
			cam().get_parent().rotation.x = deg_to_rad(-6)
			wait = 2.0
			step += 1
		1:
			shot("default")
			var vars: Array = OS.get_cmdline_user_args().slice(1)
			for v in vars:
				var kv: PackedStringArray = str(v).split("=")
				root.get_node("Settings").set_value("video", kv[0], float(kv[1]) if kv[1].is_valid_float() else kv[1])
			wait = 1.0
			step += 1
		2:
			shot("variant")
			quit()
	return false

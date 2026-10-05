extends SceneTree
var t := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t > 2.0:
		var all := root.find_children("*", "MeshInstance3D", true, false)
		var hum := 0
		for n in all:
			var p = n.get_parent()
			while p and not (p is Humanoid): p = p.get_parent()
			if p: hum += 1
		print("mesh instances: ", all.size(), " in humanoids: ", hum, " humanoids: ", root.find_children("*", "Humanoid", true, false).size())
		quit()
	return false

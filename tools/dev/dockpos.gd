extends SceneTree
var t := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 1.0: return false
	var isl = root.get_node("World/Islands/Brinehollow")
	var side := Vector2(-isl.dock_dir.y, isl.dock_dir.x)
	var p: Vector2 = isl.dock_shore - isl.dock_dir * 3.0 + side * 17.0
	print("SHACK ", p, " dir ", isl.dock_dir, " h ", isl.height_at(p.x, p.y))
	return true

extends SceneTree
var f := 0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	f += 1
	var ship = root.get_tree().get_first_node_in_group("ship")
	if ship and f < 8: print(f, " ", ship.global_position, " rotY ", ship.global_rotation.y)
	return f > 8

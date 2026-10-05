extends SceneTree
var frames := 0
func _initialize() -> void:
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(_d: float) -> bool:
	frames += 1
	if frames in [2, 10, 60, 150]:
		var p = root.get_tree().get_first_node_in_group("player")
		var s = root.get_tree().get_first_node_in_group("ship")
		var cam = root.get_viewport().get_camera_3d()
		var isl = root.get_node_or_null("World/Islands/Brinehollow")
		print("F", frames, " player=", p.global_position if p else null, " ship=", s.global_position if s else null,
			" cam=", cam.global_position if cam else null, " island=", isl != null,
			" children=", isl.get_child_count() if isl else -1)
		if isl and frames == 2:
			print("  dock_shore=", isl.dock_shore, " spawn=", isl.player_spawn_local, " h(village)=", isl.hv(isl.VILLAGE), " h(0,0)=", isl.height_at(0,0))
	if frames == 151:
		quit()
	return false

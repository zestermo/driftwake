extends SceneTree
var f := 0
func _initialize() -> void:
	change_scene_to_file("res://scenes/world/world.tscn")
func _physics_process(_d: float) -> bool:
	f += 1
	if f in [300]:
		var isl = root.get_node("World/Islands/Brinehollow")
		var s = root.get_tree().get_first_node_in_group("ship")
		var p = root.get_tree().get_first_node_in_group("player")
		var t = isl.get_node("Tilly"); var b = isl.get_node("Bram")
		print("F", f, " ship=", s.global_position, " rotY=", snappedf(s.rotation.y, 0.01), " player=", p.global_position,
			" tilly_dy=", snappedf(t.position.y - isl.height_at(t.position.x, t.position.z), 0.01),
			" bram_dy=", snappedf(b.position.y - isl.height_at(b.position.x, b.position.z), 0.01))
	if f == 300:
		var isl = root.get_node("World/Islands/Brinehollow")
		var n_cols = isl.get_node("VegetationColliders").get_child_count()
		var veg = isl.get_node("Vegetation")
		var total = 0
		for mmi in veg.get_children(): total += mmi.multimesh.instance_count
		print("colliders=", n_cols, " veg instances=", total, " multimeshes=", veg.get_child_count(), " island children=", isl.get_child_count())
	if f == 301:
		quit()
	return false

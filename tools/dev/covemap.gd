extends SceneTree
var t := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 1.0: return false
	var isl = root.get_node("World/Islands/Brinehollow")
	var line := ""
	for z in range(40, 150, 5):
		line = "%4d " % z
		for x in range(30, 150, 5):
			var h: float = isl.height_at(x, z)
			var c := "~"
			if h > -0.3: c = "."
			if h > 1.0: c = "-"
			if h > 3.0: c = "+"
			if h > 8.0: c = "^"
			if Vector2(x, z).distance_to(Vector2(80, 94)) < 3: c = "C"
			if Vector2(x, z).distance_to(Vector2(65, 76)) < 3: c = "K"
			line += c
		print(line)
	print("     x=30.. step 5")
	return true

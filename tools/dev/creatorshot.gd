extends SceneTree
var t := 0.0
var step := 0
var out := ""
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
func _process(d: float) -> bool:
	t += d
	match step:
		0:
			if t < 1.5: return false
			root.get_texture().get_image().save_png(out + "_title.png")
			change_scene_to_file("res://scenes/world/world.tscn")
			step = 1; t = 0.0
		1:
			if t < 3.0: return false
			for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
			var p = root.get_tree().get_first_node_in_group("player")
			p.open_creator(false)
			step = 2; t = 0.0
		2:
			if t < 1.5: return false
			root.get_texture().get_image().save_png(out + "_creator.png")
			quit()
	return false

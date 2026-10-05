extends SceneTree
var t := 0.0
var p
var out := ""
var phase := 0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if p == null:
		for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
		p = root.get_tree().get_first_node_in_group("player")
		return false
	match phase:
		0:
			if t < 4.0: return false
			root.get_node("GameMenu").open("skills")
			phase = 1
		1:
			if t < 5.0: return false
			root.get_texture().get_image().save_png(out + "_lv1.png")
			print("size ", root.get_node("GameMenu")._skills.size, " vis ", root.get_node("GameMenu")._skills.visible)
			quit()
	return false

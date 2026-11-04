extends SceneTree
var t := 0.0
## Args: <out_prefix> [WxH] (e.g. 1920x1080, the 960x540 canvas at 2x).
var win := Vector2i.ZERO
var step := 0
var out := ""
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	if OS.get_cmdline_user_args().size() > 1:
		var wh := OS.get_cmdline_user_args()[1].split("x")
		win = Vector2i(int(wh[0]), int(wh[1]))
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
func _process(d: float) -> bool:
	t += d
	match step:
		0:
			if win != Vector2i.ZERO and root.size != win:
				DisplayServer.window_set_size(win)
				root.size = win
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

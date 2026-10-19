extends SceneTree
## The skill map's Seamanship tab: fresh, then with a few nodes learned and one selected. Args: <out_prefix>
var t := 0.0
var out := ""
var step := 0
var t0 := 0.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	var gm = root.get_node("GameMenu")
	match step:
		0:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			gm.open("skills")
			gm._skills.set_tab("life")
			t0 = t
			step = 1
		1:
			if t - t0 < 1.0: return false
			root.get_texture().get_image().save_png("%s_fresh.png" % out)
			var pr = get_first_node_in_group("player").progression
			while pr.mastery_level("sea") < 7:
				pr.add_mastery("sea", pr.mastery_to_next(pr.mastery_level("sea")))
			gm._skills._sel = "sea_gunner"
			gm._skills.queue_redraw()
			t0 = t
			step = 2
		2:
			if t - t0 < 1.0: return false
			root.get_texture().get_image().save_png("%s_learned.png" % out)
			print("shot seamap")
			quit()
	return false

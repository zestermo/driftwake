extends SceneTree
var t := 0.0
var out := ""
var step := 0
var SG
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	SG = load("res://scripts/game/save_game.gd")
	SG.use_test_dir("user://shot_slots")
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	match step:
		0:
			if t < 3.0: return false
			for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
			var p = root.get_tree().get_first_node_in_group("player")
			p.progression.add_xp(900)
			p.power.eat("ember")
			SG.slot = 1
			root.get_node("GameManager").play_time = 4210.0
			SG.save(p)
			SG.slot = 3
			p.progression.add_xp(3000)
			root.get_node("GameManager").play_time = 400.0
			SG.save(p)
			root.get_node("GameMenu")._quit_to_title()
			step = 1; t = 0.0
		1:
			if t < 2.5: return false
			root.get_texture().get_image().save_png(out + "_title.png")
			root.get_tree().get_first_node_in_group("title_screen")._open_slots("load")
			step = 2; t = 0.0
		2:
			if t < 0.5: return false
			root.get_texture().get_image().save_png(out + "_slots.png")
			var ts = root.get_tree().get_first_node_in_group("title_screen")
			ts._slots.mode = "new"
			ts._slots._pick(1, SG.slot_info(1))
			step = 3; t = 0.0
		3:
			if t < 0.4: return false
			root.get_texture().get_image().save_png(out + "_confirm.png")
			for i in range(1, 4): SG.delete_slot(i)
			quit()
	return false

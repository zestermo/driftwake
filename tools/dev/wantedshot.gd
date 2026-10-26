extends SceneTree
## The new-poster moment (WantedCard) over Brinehollow, and the portrait alone. Args: <out_dir>
var t := 0.0
var step := 0


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "res://tools/dev/out/wanted"
	if step == 0 and t > 3.0:
		step = 1
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
		var p = root.get_tree().get_first_node_in_group("player")
		p.bounty = 26000
		WantedCard.show_for(p, 4000, 26000, Bounty.WHY["boss"])
	if step == 1 and t > 6.0:
		step = 2
		root.get_texture().get_image().save_png(out + "/card.png")
		var c = root.get_tree().get_first_node_in_group("wanted_card")
		var face: TextureRect = c.find_children("*", "TextureRect", true, false)[0] if c else null
		if face and face.texture:
			face.texture.get_image().save_png(out + "/portrait.png")
		print("SAVED")
		quit()
	return false

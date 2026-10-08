extends SceneTree
## The title screen's version ribbon and what's-new pop-up: first launch of the
## version (pops up by itself), then closed (the menu with the ribbon).
## Args: <out_prefix>
var t := 0.0
var out := ""
var step := 0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	# (as if this version had never been opened)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://whats_new_seen.txt"))
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
func _process(d: float) -> bool:
	t += d
	match step:
		0:
			if t < 1.5: return false
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			step = 1; t = 0.0
		1:
			if t < 0.5: return false
			root.get_texture().get_image().save_png(out + "_popup.png")
			var ts = root.get_tree().get_first_node_in_group("title_screen")
			print("popped up by itself: ", ts._whats_new.visible)
			ts._whats_new._close.pressed.emit()
			step = 2; t = 0.0
		2:
			if t < 0.5: return false
			root.get_texture().get_image().save_png(out + "_menu.png")
			var ts = root.get_tree().get_first_node_in_group("title_screen")
			print("seen now: ", not ts.WHATS_NEW.unseen(), "  menu back: ", ts._menu.visible)
			quit()
	return false

extends SceneTree
var t := 0.0
var done := false
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t > 1.0 and not has_meta("x"):
		set_meta("x", 1)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		var p = root.get_tree().get_first_node_in_group("player")
		p.spend_stamina(45.0)
	if t > 1.6 and not done:
		done = true
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]); print("SAVED"); quit()
	return false

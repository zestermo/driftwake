extends SceneTree
var f := 0
func _initialize() -> void:
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(_d: float) -> bool:
	f += 1
	if f == 20:
		print("before: mode=", DisplayServer.window_get_mode(), " size=", DisplayServer.window_get_size(), " embedded=", Engine.is_embedded_in_editor())
		var ev := InputEventKey.new(); ev.keycode = KEY_F11; ev.pressed = true
		Input.parse_input_event(ev)
	if f == 40:
		print("after: mode=", DisplayServer.window_get_mode(), " size=", DisplayServer.window_get_size(), " viewport=", root.get_visible_rect().size, " snap=", RenderingServer.global_shader_parameter_get("psx_snap_res"))
		root.get_texture().get_image().save_png("res://tools/dev/out/fs.png")
		print("SAVED")
	if f == 42:
		quit()
	return false

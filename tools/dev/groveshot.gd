extends SceneTree
## Tackett's grove on Brinehollow (StoryGrove): shots of it standing, then with every marked ironwood felled (as a
## captain who has felled them sees it). Args: <out_prefix>. Writes <out>_standing.png, <out>_felled.png and
## <out>_felled_low.png.
var t := 0.0
var n := 0
var cam: Camera3D
var isl
var out := ""


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func _aim(from: Vector2, fy: float, to: Vector2, ty: float) -> void:
	cam.global_position = isl.to_global(Vector3(from.x, isl.hv(from) + fy, from.y))
	cam.look_at(isl.to_global(Vector3(to.x, isl.hv(to) + ty, to.y)), Vector3.UP)


func _process(d: float) -> bool:
	t += d
	if t < 1.5:
		return false
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false):
			c._finish(true)
		isl = root.get_node("World/Islands/Brinehollow")
		var hud = get_first_node_in_group("hud")
		if hud:
			hud.visible = false
		cam = Camera3D.new()
		cam.fov = 60
		cam.far = 2000
		root.add_child(cam)
		cam.current = true
		_aim(isl.GROVE + Vector2(6, -9), 2.6, isl.GROVE + Vector2(-1, 2), 2.0)
		return false
	n += 1
	if n == 6:
		root.get_texture().get_image().save_png(out + "_standing.png")
		for i in range(isl.grove.trees.size()):
			isl.grove._set_down(i, true, false)
	elif n == 12:
		root.get_texture().get_image().save_png(out + "_felled.png")
		_aim(isl.GROVE + Vector2(-9, -6), 1.6, isl.GROVE + Vector2(3, 3), 0.5)
	elif n == 18:
		root.get_texture().get_image().save_png(out + "_felled_low.png")
		print("SAVED")
		quit()
	return false

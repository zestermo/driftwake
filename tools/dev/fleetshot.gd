extends SceneTree
## The enemy ship kinds side by side at sea (sloop, gunboat, brig, Marines). Args: <out_prefix>
var t := 0.0
var out := ""
var cam: Camera3D
var ships: Array = []
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if cam == null:
		# ("psx": the game's sharper preset, for the README; not saved)
		if OS.get_cmdline_user_args().has("psx"): root.get_node("Settings").set_value("video", "psx_preset", 4, false)
		else: root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		var by := {}
		for s in get_nodes_in_group("enemy_ships"):
			by[s.kind] = s
		var base := Vector3(560, 0, 150)
		var i := 0
		for k in ["sloop", "gunboat", "brig", "marine"]:
			if not by.has(k):
				continue
			var s = by[k]
			s.set_physics_process(false)
			s._pos = base + Vector3(i * 16.0, 0, 0)
			s._heading = -0.5
			s.global_transform = Transform3D(Basis(Vector3.UP, s._heading), s._pos + Vector3(0, 0.85, 0))
			ships.append(s)
			i += 1
		var p = get_first_node_in_group("player")
		p.global_position = base + Vector3(24, 0.8, 60)
		cam = Camera3D.new(); cam.fov = 50; cam.far = 800; root.add_child(cam); cam.current = true
		cam.global_position = base + Vector3(24, 14, 52)
		cam.look_at(base + Vector3(24, 3, 0), Vector3.UP)
		return false
	if t > 4.0:
		root.get_texture().get_image().save_png(out + "_fleet.png")
		cam.global_position = ships[3].global_position + Vector3(8, 6, 12) if ships.size() > 3 else cam.global_position
		cam.look_at(ships[3].global_position + Vector3(0, 3, 0) if ships.size() > 3 else Vector3.ZERO, Vector3.UP)
		await process_frame
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png(out + "_marine.png")
		quit()
	return false

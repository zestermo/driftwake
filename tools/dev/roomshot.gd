extends SceneTree
## Brinehollow's walk-in rooms (the chapel close's BrinehollowRooms, the lighthouse's keeper's cottage and lamp room
## once built): for each, a shot from inside its front corner across the room and one from outside its door, the HUD
## hidden, the keepers in place. Args: <out_prefix>. Writes <out>_<room>_in.png and <out>_<room>_door.png.
var t := 0.0
var n := 0
var cam: Camera3D
var isl
var out := ""
var shots: Array = []


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


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
		var p = get_first_node_in_group("player")
		if p:
			p.visible = false
		cam = Camera3D.new()
		cam.fov = 70
		cam.far = 2000
		root.add_child(cam)
		cam.current = true
		var rooms: Dictionary = isl.close_rooms.duplicate()
		rooms["cottage"] = isl._keeper_hut
		for k in rooms.keys():
			var r: Node3D = rooms[k]
			var door: Vector3 = (r.get_node("Door") as Node3D).position
			var w: float = absf(door.x) + 2.0
			var dz: float = door.z - 1.4
			shots.append([k + "_in", r.to_global(Vector3(signf(-door.x + 0.01) * (w - 1.0) * 0.6, 1.75, dz - 0.6)), r.to_global(Vector3(-signf(-door.x + 0.01) * 1.0, 1.0, -dz + 0.4))])
			shots.append([k + "_door", r.to_global(door + Vector3(1.5, 1.6, 4.5)), r.to_global(Vector3(door.x, 1.2, 0.0))])
		_aim()
		return false
	n += 1
	if n % 6 == 0:
		root.get_texture().get_image().save_png("%s_%s.png" % [out, shots[0][0]])
		shots.pop_front()
		if shots.is_empty():
			print("SAVED")
			quit()
			return false
		_aim()
	return false


func _aim() -> void:
	cam.global_position = shots[0][1]
	cam.look_at(shots[0][2], Vector3.UP)

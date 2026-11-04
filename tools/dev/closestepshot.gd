extends SceneTree
## The 1.30 opening steps on screen at 1920x1080 (the smallest supported display): the farm step's objective after the
## smugglers, Wick's talk in his shop, the tinkering banner with the marker on his bench, Aldous's talk and the
## reading banner. The captain stands in each place; the HUD shows. Args: <out_prefix>.
var out := ""
var t := 0.0
var n := 0
var isl
var p
var story
var dlg
var cam_set := false


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func _snap(name_: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, name_])
	print("shot ", name_)


func _stand(room: Node3D, back: float) -> void:
	var door: Vector3 = (room.get_node("Door") as Node3D).position
	p.global_position = room.to_global(Vector3(door.x * 0.4, 0.6, door.z - 1.4 - back))
	p.rotation.y = room.global_rotation.y + PI
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _process(d: float) -> bool:
	t += d
	if t < 1.5:
		return false
	if isl == null:
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		root.size = Vector2i(1920, 1080)
		for c in root.find_children("*", "CharacterCreator", true, false):
			c._finish(true)
		isl = root.get_node("World/Islands/Brinehollow")
		p = get_first_node_in_group("player")
		story = root.get_node("Story")
		dlg = root.get_node("Dialogue")
		story.begin()
		story.step = "smugglers"
		return false
	n += 1
	match n:
		10:
			story.complete("smugglers")
		90:
			_snap("farm_objective")
			story.step = "tinker"
			story.changed.emit()
			_stand(isl.close_rooms["tinker"], 0.0)
		150:
			dlg._cooldown = 0.0
			dlg.start("wick")
		200:
			if str(dlg._node.get("next", "end")) != "end":
				dlg._goto(str(dlg._node["next"]))
		230:
			_snap("wick_talk")
			dlg._close()
			story.gift("tinker")
		290:
			_snap("tinker_banner")
			story.step = "read"
			story.changed.emit()
			_stand(isl.close_rooms["scribe"], 0.0)
		350:
			dlg._cooldown = 0.0
			dlg.start("aldous")
		400:
			_snap("aldous_talk")
			dlg._close()
			story.gift("read")
		460:
			_snap("read_banner")
			print("SAVED")
			quit()
	return false

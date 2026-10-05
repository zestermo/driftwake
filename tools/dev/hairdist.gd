extends SceneTree
## Hair at a distance (scalp poking through?). Args: <out_prefix>
var t := 0.0
var p
var cam: Camera3D
var out := ""
var n := 0
const D := [5.0, 8.0, 12.0]
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if cam == null:
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		p = get_first_node_in_group("player")
		var lk: Dictionary = p.body_model.look.duplicate(true)
		lk["hat"] = "none"
		lk["hair"] = "long"
		p.body_model.apply_look(lk)
		var args := OS.get_cmdline_user_args()
		if args.size() > 1:
			root.get_node("Settings").set_value("video", "psx_preset", int(args[1]))
		cam = Camera3D.new(); cam.fov = 40; root.add_child(cam); cam.current = true
		return false
	var dist: float = D[mini(n, D.size() - 1)]
	var hd: Vector3 = p.body_model.head.global_position
	var back: Vector3 = p.player_model.global_basis.z
	cam.global_position = hd + back * dist * 0.8 + Vector3(0, dist * 0.6, 0) + p.player_model.global_basis.x * dist * 0.2
	cam.look_at(hd, Vector3.UP)
	if t > 3.0 + n * 0.8:
		var img := root.get_texture().get_image()
		# crop around the head (centre)
		var s := int(clampf(360.0 / dist, 40.0, 200.0))
		var c := Vector2i(img.get_width() / 2, img.get_height() / 2)
		var cr := img.get_region(Rect2i(c - Vector2i(s, s), Vector2i(s * 2, s * 2)))
		cr.resize(240, 240, Image.INTERPOLATE_NEAREST)
		cr.save_png("%s_%d.png" % [out, n])
		n += 1
		if n >= D.size(): quit()
	return false

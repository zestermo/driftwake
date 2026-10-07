extends SceneTree
## The sea from Brinehollow's dock at a run of hours, clear weather (the
## view of the capture where the sea went pale and opaque). Args: <out_prefix>
var t := 0.0
var out := ""
var p
var w
var cam: Camera3D
var i := -1
var t0 := 0.0
const HOURS := [7.0, 8.5, 9.5, 10.75, 11.5, 13.0, 15.0, 16.5, 17.5]
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func set_hour(h: float) -> void:
	var dh := fposmod(h - float(w.hour()), 24.0)
	w.world_offset += dh / 24.0 * float(w.DAY_LEN)
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		var args := OS.get_cmdline_user_args()
		if args.size() > 1:
			var wh := args[1].split("x")
			root.size = Vector2i(int(wh[0]), int(wh[1]))
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		p = get_first_node_in_group("player")
		w = root.get_node("Weather")
		w.forced = 0
		w.forced_at = w.world_time() - 100.0
		cam = Camera3D.new(); cam.fov = 85; cam.far = 3000; root.add_child(cam); cam.current = true
		# (the capture: standing on the dock, looking out along it)
		p.global_position = Vector3(149.5, 1.8, 19.44)
		p.reset_physics_interpolation()
		cam.global_position = Vector3(147.36, 5.4, 23.2)
		cam.look_at(cam.global_position + Vector3(0.43, -0.5, -0.75), Vector3.UP)
		t0 = t
		return false
	if i < 0 or t - t0 > 1.5:
		if i >= 0:
			root.get_texture().get_image().save_png("%s_%s.png" % [out, str(HOURS[i]).replace(".", "_")])
			print("shot hour ", HOURS[i], " sun ", w.sun_dir)
		i += 1
		if i >= HOURS.size():
			quit()
			return false
		set_hour(float(HOURS[i]))
		t0 = t
	return false

extends SceneTree
## Close look at the 3D clouds at a pixelated PSX preset. Args: <out_png> [preset]
var t := 0.0
var cam: Camera3D
var out := ""
var done := false
var t0 := 0.0
func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	change_scene_to_file("res://scenes/world/world.tscn")
	if a.size() > 1:
		root.get_node("Settings").set_value("video", "psx_preset", int(a[1]), false)
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	var w = root.get_node("Weather")
	if cam == null:
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		var dh := fposmod(10.5 - float(w.hour()), 24.0)
		w.world_offset += dh / 24.0 * float(w.DAY_LEN)
		w.forced = 1
		w.forced_at = w.world_time() - 100.0
		cam = Camera3D.new(); cam.fov = 60; cam.far = 3000; root.add_child(cam); cam.current = true
		t0 = t
		return false
	var cl = current_scene.get_node("Clouds")
	var p = get_first_node_in_group("player")
	# a big visible cloud ~70 m off, seen slightly from below
	var best = null
	for c in cl.clouds:
		if cl._vis(c) > 0.95 and (best == null or float(c["radii"].x) > float(best["radii"].x)):
			best = c
	if best:
		var cc: Vector3 = cl.center_of(best, p.global_position)
		cam.global_position = cc + Vector3(-150, -55, 40)
		cam.look_at(cc, Vector3.UP)
	if t - t0 > 3.0 and not done:
		done = true
		root.get_texture().get_image().save_png(out)
		quit()
	return false

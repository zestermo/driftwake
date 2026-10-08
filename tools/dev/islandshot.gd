extends SceneTree
## Shots of the starter island from given local (island-space) camera positions.
## Args: <out_prefix> then repeated "name:cx,cy,cz:tx,ty,tz" (y "~3": 3 m above the
## ground there). Env ISHOT_HOUR=21: at that hour of the day.
var t := 0.0
var shots: Array = []
var idx := 0
var cam: Camera3D
var isl: Node3D
var out := ""
var settle := 0
func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	for i in range(1, a.size()):
		var parts: PackedStringArray = a[i].split(":")
		shots.append([parts[0], parts[1].split(","), parts[2].split(",")])
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
		isl = root.get_node("World/Islands/Brinehollow")
		var hud = root.get_tree().get_first_node_in_group("hud")
		if hud: hud.visible = false
		cam = Camera3D.new(); cam.fov = 60; cam.far = 2000
		root.add_child(cam); cam.current = true
		# ISHOT_HOUR=21 renders at that hour
		if OS.get_environment("ISHOT_HOUR") != "":
			var wx = root.get_node("Weather")
			var k: Dictionary = (wx.get_script() as GDScript).get_script_constant_map()
			var want := float(OS.get_environment("ISHOT_HOUR"))
			wx.set_world_time(fposmod(want - float(k["START_HOUR"]), 24.0) / 24.0 * float(k["DAY_LEN"]))
			settle = -120  # (lamps check the hour once a second)
		_aim()
		return false
	settle += 1
	if settle < 4: return false
	root.get_texture().get_image().save_png("%s_%s.png" % [out, shots[idx][0]])
	idx += 1; settle = 0
	if idx >= shots.size():
		print("SAVED"); quit(); return false
	_aim()
	return false
func _v(c: PackedStringArray) -> Vector3:
	var x := float(c[0]); var z := float(c[2])
	var ys := c[1]
	var y: float = (float(ys.substr(1)) + float(isl.height_at(x, z))) if ys.begins_with("~") else float(ys)
	return Vector3(x, y, z)
func _aim():
	var s: Array = shots[idx]
	cam.global_position = isl.to_global(_v(s[1])); cam.look_at(isl.to_global(_v(s[2])), Vector3.UP)

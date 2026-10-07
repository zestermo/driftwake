extends SceneTree
## The open sea's features from a passing ship: a reef, a whirlpool, a fog
## bank, a storm cell (later: a wreck, a bottle). Args: <out_prefix>
var t := 0.0
var out := ""
var cam: Camera3D
var sf
var shots: Array = []
var i := -1
var t0 := 0.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		sf = get_first_node_in_group("sea_features")
		cam = Camera3D.new(); cam.fov = 60; cam.far = 1500; root.add_child(cam); cam.current = true
		var r = sf.reefs[0]
		shots.append(["reef", Vector3(r[0].x, 0, r[0].y), 45.0, 12.0])
		var w = sf.whirls[0]
		shots.append(["whirlpool", Vector3(w[0].x, 0, w[0].y), 70.0, 30.0])
		var f = sf.fogs[0]
		shots.append(["fogbank", Vector3(f[0].x, 0, f[0].y), 330.0, 18.0])
		var s = sf.storm_at(0)
		shots.append(["storm", Vector3(s.x, 0, s.y), 60.0, 8.0])
		for extra in ["wrecks", "bottles"]:
			var arr = sf.get(extra)
			if arr != null and arr.size() > 0:
				var e = arr[0]
				shots.append([extra.trim_suffix("s"), Vector3(e[0].x, 0, e[0].y), 22.0, 7.0])
		t0 = t
		return false
	if i < 0 or t - t0 > 2.5:
		if i >= 0:
			root.get_texture().get_image().save_png("%s_%s.png" % [out, shots[i][0]])
			print("shot ", shots[i][0])
		i += 1
		if i >= shots.size():
			quit()
			return false
		var s: Array = shots[i]
		var at: Vector3 = s[1]
		# the player stands in for the camera (the weather follows the player's camera)
		var p = get_first_node_in_group("player")
		var eye := at + Vector3(float(s[2]), float(s[3]), float(s[2]) * 0.4)
		p.global_position = eye + Vector3(0, 30, 0)
		cam.global_position = eye
		cam.look_at(at, Vector3.UP)
		t0 = t
	return false

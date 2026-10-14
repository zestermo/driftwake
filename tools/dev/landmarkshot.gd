extends SceneTree
## A chain island's landmarks and set piece (Island.places): a map with each
## place marked, then each place close up and from the sea, captioned; a contact
## sheet of them all (<out>_sheet.png). Prints the places as data.
## Args: <out_prefix> [chain seed | -] [node id | -]
## Env: LSHOT_PIECE forces the set piece, LSHOT_MARKS the landmarks' order
## (comma list, e.g. "waterfall,great_tree"), LSHOT_HOUR the hour (11).
var t := 0.0
var out := ""
var cam: Camera3D
var isl
var want := -1
var shots: Array = []
var idx := 0
var settle := 0
var frames: Array = []
var caption: Label
var rebuilt := false


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1 and a[1] != "-":
		root.get_node("GameManager").chain_seed = int(a[1])
	if a.size() > 2 and a[2] != "-":
		want = int(a[2])
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var w = root.get_node_or_null("World/Islands")
	if w == null:
		return false
	var gm = root.get_node("GameManager")
	if want < 0:
		want = int(w.chain().start_next[0])
	if gm.chain_at != want:
		gm.apply_chain(want, false, root.get_node("Weather").world_time())
		var wx = root.get_node("Weather")
		var hour := float(OS.get_environment("LSHOT_HOUR")) if OS.get_environment("LSHOT_HOUR") != "" else 11.0
		wx.set_world_time(wx.time_at(hour))
		gm.chain_since = wx.world_time()
	if t < 1.5:
		return false
	if isl == null:
		if not w.chain_ready() or not w.chain_islands.has(want):
			return false
		# rebuilt with the forced set piece and landmarks
		if not rebuilt and (OS.get_environment("LSHOT_PIECE") != "" or OS.get_environment("LSHOT_MARKS") != ""):
			rebuilt = true
			var n: Dictionary = w.chain().node(want)
			if OS.get_environment("LSHOT_PIECE") != "":
				n["setpiece"] = OS.get_environment("LSHOT_PIECE")
			if OS.get_environment("LSHOT_MARKS") != "":
				n["landmarks"] = Array(OS.get_environment("LSHOT_MARKS").split(","))
				n["landmark_count"] = (n["landmarks"] as Array).size()
			w._free_chain_island(want)
			w.sync_chain_islands()
			return false
		_setup(w.chain_islands[want])
		return false
	settle += 1
	if settle < 10:
		return false
	var img := root.get_texture().get_image()
	img.save_png("%s_%s.png" % [out, shots[idx][0]])
	frames.append(img)
	idx += 1
	settle = 0
	if idx >= shots.size():
		_sheet()
		print("SAVED")
		quit()
		return false
	_aim()
	return false


func _setup(island) -> void:
	isl = island
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
	print("island %d %s (seed %d): r %.0f, built %s" % [int(isl.node["id"]), isl.island_name, int(root.get_node("GameManager").chain_seed), isl.radius, isl.build_ms])
	for pl in isl.places:
		print("PLACE %s %s at %s r %.0f y %.1f door %s" % [pl["role"], pl["kind"], pl["at"], pl["r"], pl["y"], pl.get("door", "-")])
	var hud = get_first_node_in_group("hud")
	if hud: hud.visible = false
	root.get_node("Settings").set_value("video", "perf_overlay", false, false)
	cam = Camera3D.new(); cam.fov = 60; cam.far = 3000
	root.add_child(cam); cam.current = true
	var cl := CanvasLayer.new()
	cl.layer = 100
	root.add_child(cl)
	caption = Label.new()
	caption.position = Vector2(12, 8)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	caption.add_theme_constant_override("outline_size", 6)
	cl.add_child(caption)
	var top := 0.0
	for h in isl.heights:
		top = maxf(top, h)
	shots = [["map", "the whole island, north up (places marked)", Vector3(0, top + 30.0, 0), Vector3(0, 0, -0.001), (isl.radius + 50.0) * 2.0]]
	for pl in isl.places:
		var at: Vector2 = pl["at"]
		var y0: float = pl["y"]
		var r: float = pl["r"]
		var k: String = pl["kind"]
		var door: Vector2 = pl.get("door", at + Vector2(r, 0))
		var d := (door - at).normalized()
		var side := d.orthogonal()
		var look_h: float = {"waterfall": float(pl.get("lip", 10.0)) * 0.45, "great_tree": float(pl.get("top", 30.0)) * 0.5, "temple": 9.0, "wreck": 1.5,
			"sea_arch": 7.0, "giant_nest": 9.0, "volcano_vent": 5.0, "cenote": -4.0, "watchtower": float(pl.get("h", 16.0)) * 0.5,
			"aqueduct": float(pl.get("top", 8.0)) * 0.6, "sky_wreck": 3.0, "gorge_bridge": -3.0, "mine": 2.5}.get(k, 3.0)
		var near := r * 0.95 + 3.0
		var cq := Vector2(at.x + d.x * near + side.x * near * 0.35, at.y + d.y * near + side.y * near * 0.35)
		var cy := maxf(y0 + r * 0.55 + 5.0, maxf(isl.height_at(cq.x, cq.y), 0.0) + 6.0)
		shots.append(["%s_close" % k, "%s, close" % k, Vector3(cq.x, cy, cq.y), Vector3(at.x, y0 + look_h, at.y), 0.0])
		var outw := at.normalized()
		var sea: Vector2 = outw * (float(isl.radius) + 150.0) + outw.orthogonal() * 60.0
		shots.append(["%s_sea" % k, "%s, from the sea" % k, Vector3(sea.x, 12.0, sea.y), Vector3(at.x, y0 + look_h, at.y), 0.0])
		match k:
			"great_tree":
				var dk: Array = load("res://scripts/island/kit/kit_landmarks.gd").deck_heights(pl)
				shots.append(["great_tree_deck", "great_tree, on its middle deck", Vector3(at.x + d.x * 4.3, y0 + float(dk[1]) + 1.7, at.y + d.y * 4.3), Vector3(at.x + d.x * 18.0, y0 + float(dk[1]) - 2.0, at.y + d.y * 18.0), 0.0])
			"waterfall":
				shots.append(["waterfall_pool", "waterfall, from the pool's edge", Vector3(at.x + d.x * 7.5, y0 + 1.2, at.y + d.y * 7.5), Vector3(at.x - d.x * 6.0, y0 + 5.0, at.y - d.y * 6.0), 0.0])
			"wreck":
				shots.append(["wreck_low", "wreck, by her breach", Vector3(at.x + side.x * 9.0 + d.x * 3.0, y0 + 1.7, at.y + side.y * 9.0 + d.y * 3.0), Vector3(at.x, y0 + 0.5, at.y), 0.0])
				shots.append(["wreck_low2", "wreck, the other side", Vector3(at.x - side.x * 9.0 + d.x * 3.0, y0 + 1.7, at.y - side.y * 9.0 + d.y * 3.0), Vector3(at.x, y0 + 0.5, at.y), 0.0])
	_aim()


func _aim():
	var s: Array = shots[idx]
	var map: bool = float(s[4]) > 0.0
	for we in root.find_children("*", "WorldEnvironment", true, false):
		we.environment.fog_enabled = not map
	var clouds = root.get_node_or_null("World/Clouds")
	if clouds:
		clouds.visible = not map
	caption.text = "%s  -  %s" % [isl.island_name, s[1]]
	if map:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(s[4])
		cam.global_position = isl.to_global(s[2])
		cam.global_rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	else:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.global_position = isl.to_global(s[2])
		cam.look_at(isl.to_global(s[3]), Vector3.UP)


func _sheet() -> void:
	var w: int = frames[0].get_width() / 2
	var h: int = frames[0].get_height() / 2
	var cols := 3
	var rows := ceili(frames.size() / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.08))
	for i in range(frames.size()):
		var f: Image = frames[i]
		f.convert(Image.FORMAT_RGB8)
		f.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(f, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png("%s_sheet.png" % out)

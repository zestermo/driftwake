extends SceneTree
## The canal city (CanalIsland, 1.21): sailing in, from high above, the riva, the piazza, the Grand Canal, the market
## bridge, a lane, a campo, the arsenal, a cross canal; each captioned, then a contact
## sheet (<out>_sheet.png). Prints its build times.
## Args: <out_prefix> [chain seed | -]
## (CSHOT_HOUR=18.4 renders at that hour, 11 by default; CSHOT_ONLY=approach,plaza renders just those shots)
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


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1 and a[1] != "-":
		root.get_node("GameManager").chain_seed = int(a[1])
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var w = root.get_node_or_null("World/Islands")
	if w == null:
		return false
	var gm = root.get_node("GameManager")
	if want < 0:
		for nn in w.chain().nodes:
			if nn.get("canal", false):
				want = int(nn["id"])
	if gm.chain_at != want:
		var wx = root.get_node("Weather")
		gm.apply_chain(want, false, wx.world_time())
		var hour := float(OS.get_environment("CSHOT_HOUR")) if OS.get_environment("CSHOT_HOUR") != "" else 11.0
		wx.set_world_time(wx.time_at(hour))
		gm.chain_since = wx.world_time()
	if t < 1.5:
		return false
	if isl == null:
		if not w.chain_ready() or not w.chain_islands.has(want):
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
	print("canal city %d %s (Lv %d, chain seed %d): built %s" % [int(isl.node["id"]), isl.island_name, int(isl.node["level"]),
		int(root.get_node("GameManager").chain_seed), isl.build_ms])
	var tris := 0
	var draws := 0
	var by_piece := {}
	for mi in isl.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			draws += mi.mesh.get_surface_count()
			var key := str(mi.get_parent().name).get_slice("_", 0)
			for s in range(mi.mesh.get_surface_count()):
				var arr = mi.mesh.surface_get_arrays(s)
				var n: int = (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] else arr[Mesh.ARRAY_VERTEX].size()) / 3
				tris += n
				by_piece[key] = int(by_piece.get(key, 0)) + n
	print("canal city: triangles by piece %s" % by_piece)
	print("canal city: %d mesh instances, %d surfaces, %d triangles, %d collision shapes, %d nodes" % [isl.find_children("*", "MeshInstance3D", true, false).size(),
		draws, tris, isl.find_children("*", "CollisionShape3D", true, false).size(), isl.find_children("*", "", true, false).size()])
	var hud = get_first_node_in_group("hud")
	if hud: hud.visible = false
	root.get_node("Settings").set_value("video", "perf_overlay", false, false)
	cam = Camera3D.new(); cam.fov = 60; cam.far = 4000
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
	var ship = get_first_node_in_group("ship")
	var moor: Array = isl.mooring()
	ship.place(moor[0], moor[1])
	# (the captain in the plaza, unseen: its people and the toughs wake for a captain nearby, and people hide past 230 m
	# from every captain: the plaza is within that of the throne hall, the docks and the slum alike)
	var me = get_first_node_in_group("player")
	me.global_position = isl.city_global(Vector2(14, 0), CanalPlan.QUAY_Y + 0.3)
	me.reset_physics_interpolation()
	me.visible = false
	shots = [
		["approach", "sailing in from the lagoon", Vector2(40, 520), 20.0, Vector2(0, -40), 16.0],
		["aerial", "from high above", Vector2(240, 300), 210.0, Vector2(0, -40), 0.0],
		["riva", "on the riva", Vector2(-40, 104), 1.7, Vector2(60, 100), 3.0],
		["piazza", "the piazza", Vector2(100, 92), 1.8, Vector2(50, 50), 6.0],
		["grand", "along the Grand Canal", Vector2(-14, 60), 2.0, Vector2(0, -60), 3.0],
		["bridge", "the market bridge", Vector2(-14, -8), 1.8, Vector2(8, -30), 3.0],
		["lane", "a lane through the houses", Vector2(-106, 14), 1.7, Vector2(-106, -30), 3.0],
		["campo", "a campo", Vector2(-100, -22), 1.7, Vector2(-112, -34), 1.5],
		["arsenal", "the arsenal", Vector2(134, 4), 2.2, Vector2(150, -66), 1.0],
		["canal", "a cross canal at eye height", Vector2(-180, 18), 1.7, Vector2(-40, 24), 1.0],
		["plan", "the city from straight above", Vector2(0, -38), 320.0, Vector2(0, -40), 0.0],
	]
	# (1.27) the rolled campo, a roof, a room: wherever this world put them
	var campi: Array = CanalPlan.floors().filter(func(f): return str(f[0]).ends_with("_campo"))
	if not campi.is_empty():
		var cr: Rect2 = campi[1 % campi.size()][1]
		shots.append(["campo2", "a rolled campo", cr.get_center() + Vector2(6.5, 6.5), 1.7, cr.get_center() - Vector2(8, 8), 1.6])
	var flats: Array = CanalPlan.lots().filter(func(l): return l.has("top_y") and str(l["roof"]) == "flat")
	if not flats.is_empty():
		var l: Dictionary = flats[flats.size() / 3]
		var c: Vector2 = l["c"]
		var h: float = float(l["top_y"]) - CanalPlan.QUAY_Y
		shots.append(["roofs", "the rooftops", c - (l["face"] as Vector2) * 12.0, h + 12.0, c + (l["face"] as Vector2) * 6.0, h])
	var rooms: Array = isl.doors.filter(func(dd): return dd.get("inside", Vector3.INF) != Vector3.INF)
	if not rooms.is_empty():
		var dd: Dictionary = rooms[0]
		var iv: Vector3 = dd["inside"]
		var fc: Vector2 = dd["face"]
		shots.append(["room", "inside a canal house", Vector2(iv.x, iv.z) - fc * 1.4, 1.9, Vector2(iv.x, iv.z) + fc * 4.0, 1.0])
	var only := OS.get_environment("CSHOT_ONLY")
	if only != "":
		shots = shots.filter(func(e): return e[0] in only.split(","))
	_aim()


func _aim():
	var s: Array = shots[idx]
	caption.text = "%s  -  %s" % [isl.island_name, s[1]]
	var from: Vector2 = s[2]
	var to: Vector2 = s[4]
	cam.global_position = isl.city_global(from, CanalPlan.ground(from) + float(s[3]) if CanalPlan.land_t(from) < 0.0 else float(s[3]))
	cam.look_at(isl.city_global(to, CanalPlan.ground(to) + float(s[5])), Vector3.UP)


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

extends SceneTree
## The royal capital (CapitalIsland): sailing in from the sea, the harbour mouth, from high above, on the quay, up
## the market street, the plaza, the palace on its hill, the arena, the slum alley, the docks, the wharf, the terrace; each captioned, then a contact
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
		want = int(w.chain().capital_id())
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
	print("capital %d %s (Lv %d, chain seed %d): built %s" % [int(isl.node["id"]), isl.island_name, int(isl.node["level"]),
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
	print("capital: triangles by piece %s" % by_piece)
	print("capital: %d mesh instances, %d surfaces, %d triangles, %d collision shapes, %d nodes" % [isl.find_children("*", "MeshInstance3D", true, false).size(),
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
	me.global_position = isl.city_global(Vector2(0, 10), CapitalPlan.ground(Vector2(0, 10)) + 0.3)
	me.reset_physics_interpolation()
	me.visible = false
	shots = [
		["approach", "sailing in from the sea", Vector2(70, 720), 26.0, Vector2(0, -40), 22.0],
		["approach2", "closer in", Vector2(40, 420), 16.0, Vector2(0, -40), 24.0],
		["mouth", "the harbour mouth", Vector2(-30, 250), 9.0, Vector2(0, 40), 12.0],
		["aerial", "from high above", Vector2(260, 330), 230.0, Vector2(0, -40), 0.0],
		["quay", "on the quay", Vector2(46, 116), 3.6, Vector2(0, 80), 7.0],
		["gate", "the sea gate", Vector2(0, 104), 3.6, Vector2(0, 80), 6.0],
		["street", "up the market street", Vector2(1.5, 72), 4.0, Vector2(0, 0), 6.0],
		["plaza", "the plaza", Vector2(-20, 18), 6.8, Vector2(12, -24), 8.0],
		["palace", "the palace on its hill", Vector2(0, -20), 6.8, Vector2(0, -165), 40.0],
		["arena", "the arena's walls", Vector2(30, 0), 6.8, Vector2(108, 0), 12.0],
		["slum", "the slum alley", Vector2(-8, 52), 4.0, Vector2(-62, 50), 4.0],
		["docks", "the docks' warehouse row", Vector2(10, 57), 4.0, Vector2(126, 58), 5.0],
		["wharf", "the wharf and Coyle's yard", Vector2(128, 72), 4.5, Vector2(156, 50), 4.0],
		["terrace", "the noble quarter's terrace", Vector2(12, -56), 4.0, Vector2(100, -58), 5.0],
		["court", "the palace court", Vector2(0, -122), 3.0, Vector2(0, -165), 10.0],
		["throne", "the throne hall", Vector2(0, -162.5), 3.0, Vector2(0, -180), 3.5],
		["queen", "the Queen on her dais", Vector2(3, -172), 2.0, Vector2(0, -179.5), 2.4],
		["yard", "Gallows Row's yard and its toughs", Vector2(-50.0, 45.0), 2.6, Vector2(-63, 53), 1.0],
		["inn", "the Crown and Compass", Vector2(-12, 2), 2.4, Vector2(-30, 3), 3.5],
		["crowd", "the market street at eye height", Vector2(-1.0, 62), 1.7, Vector2(0, 28), 2.0],
		["halls", "the guild hall and the counting house", Vector2(0, 12), 2.5, Vector2(0, -30), 7.0],
		["hill", "the town from the palace", Vector2(0, -112), 40.0, Vector2(0, 60), 0.0],
	]
	var only := OS.get_environment("CSHOT_ONLY")
	if only != "":
		shots = shots.filter(func(e): return e[0] in only.split(","))
	_aim()


func _aim():
	var s: Array = shots[idx]
	caption.text = "%s  -  %s" % [isl.island_name, s[1]]
	var from: Vector2 = s[2]
	var to: Vector2 = s[4]
	cam.global_position = isl.city_global(from, CapitalPlan.ground(from) + float(s[3]) if CapitalPlan.land_t(from) < 0.0 else float(s[3]))
	cam.look_at(isl.city_global(to, CapitalPlan.ground(to) + float(s[5])), Vector3.UP)


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

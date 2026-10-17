extends SceneTree
## A forest island's own things (docs/forest_island_plan.md): its woods at eye height, its rivers, the
## falls and their pool from below and the gorge from above, a bridge, the town on its river, then each
## theme place on it (the sawmill, camps and lodges, the set pieces) and its wildlife when built; each
## captioned, then a contact sheet (<out>_sheet.png). The chain's first island unless a node id is given;
## it is made forest whatever it rolled.
## Args: <out_prefix> [chain seed | -] [node id | -]   Env FSHOT_HOUR (11 by default), FSHOT_ONLY=a,b (shot names).
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
		w.chain().node(want)["theme"] = "forest"
	if gm.chain_at != want:
		w.chain().node(want)["theme"] = "forest"
		gm.apply_chain(want, false, root.get_node("Weather").world_time())
		var wx = root.get_node("Weather")
		var hour := float(OS.get_environment("FSHOT_HOUR")) if OS.get_environment("FSHOT_HOUR") != "" else 11.0
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
	print("island %d %s (%s, %s, Lv %d): r %.0f, built %s" % [int(isl.node["id"]), isl.island_name, isl.theme, isl.forest, int(isl.node["level"]), isl.radius, isl.build_ms])
	print("places %s" % [isl.places.map(func(pl): return "%s:%s" % [pl["role"], pl["kind"]])])
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
	var FL = load("res://scripts/island/themes/forest_land.gd")
	var L: Dictionary = isl.land_plan
	var s: Dictionary = isl.sites
	var dd: Vector2 = isl.dock_dir
	shots = []
	# the woods at eye height, two places in the thick of it
	for k in [3, 2]:
		if isl.forest_crowns.size() > k:
			var fc: Vector3 = isl.forest_crowns[isl.forest_crowns.size() / k]
			var at := Vector2(fc.x, fc.z) + Vector2(2.0, 1.0)
			shots.append(["woods%d" % k, "in the woods (%s)" % isl.forest, _g(at, 1.7), _g(at + Vector2.from_angle(k * 1.7) * 20.0, 3.0)])
	shots.append(["canopy", "over the canopy from the summit", _g(s["summit"] + dd * 4.0, 18.0), _g(s["summit"] + dd * 160.0, -10.0)])
	# the rivers: a reach of each, the falls from their pool and the gorge from above
	for i in range((L["rivers"] as Array).size()):
		var pts: PackedVector2Array = L["rivers"][i]["pts"]
		var k := int(pts.size() * 0.6)
		var along := (pts[k + 1] - pts[k - 1]).normalized()
		var side := Vector2(-along.y, along.x)
		shots.append(["river%d" % i, "a river's reach", _g(pts[k] + side * 9.0 - along * 6.0, 2.4), _g(pts[k] + along * 26.0, 0.0)])
	for fl in FL.falls_of(L):
		var foot: Vector2 = fl["foot"]
		var dir: Vector2 = fl["dir"]
		shots.append(["falls", "the falls from their pool", _g(foot + dir * 11.0 + Vector2(-dir.y, dir.x) * 3.0, 2.0), _g(fl["top"], float(fl["drop"]) * 0.5)])
		shots.append(["gorge", "the gorge from above", _g(foot + dir * 30.0 + Vector2(-dir.y, dir.x) * 14.0, 26.0), _g(foot + dir * 10.0, 0.0)])
		break
	var br = isl.get_node_or_null("ForestBridges")
	if br != null and br.get_child_count() > 1:
		var c: Vector3 = (br.get_child(0) as CollisionShape3D).position
		shots.append(["bridge", "a bridge on a path", Vector3(c.x + 7.0, c.y + 2.5, c.z + 6.0), c])
	var v: Vector2 = s["village"]
	var rv := Vector2.ZERO
	var bd := INF
	for r in L["rivers"]:
		for q in r["pts"]:
			if (q as Vector2).distance_to(v) < bd:
				bd = (q as Vector2).distance_to(v)
				rv = q
	shots.append(["town_river", "the town on its river", _g(rv + (rv - v).normalized() * 18.0, 9.0), _g(v, 2.0)])
	shots.append(["town", "the town's square", _g(v + dd * 24.0, 3.0), _g(v, 2.0)])
	shots.append(["town_high", "the town from above", _g(v + dd * 40.0 + Vector2(-dd.y, dd.x) * 20.0, 30.0), _g(v, 0.0)])
	for pl in isl.places:
		if str(pl["role"]) != "theme":
			continue
		var at: Vector2 = pl["at"]
		var face: Vector2 = pl["face"]
		var r: float = pl["r"]
		shots.append([str(pl["kind"]), str(pl["kind"]).replace("_", " "), _g(at + face * (r + 8.0) + Vector2(-face.y, face.x) * r * 0.5, r * 0.4 + 3.0), _g(at, 2.0)])
	var only := OS.get_environment("FSHOT_ONLY")
	if only != "":
		shots = shots.filter(func(e): return only.split(",").has(e[0]))
	_aim()


func _g(p: Vector2, up: float) -> Vector3:
	return Vector3(p.x, maxf(isl.height_at(p.x, p.y), 0.0) + up, p.y)


func _aim():
	var s: Array = shots[idx]
	caption.text = "%s  (forest: %s)  -  %s" % [isl.island_name, isl.forest, s[1]]
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

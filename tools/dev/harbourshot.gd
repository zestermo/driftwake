extends SceneTree
## Generated harbours (GenHarbour), each kind on several chain seeds: every island
## is built far out to sea (its chain node, the kind forced), timed step by step,
## shot from four cameras (from the sea, from above, on the pier, along the beach)
## and freed. A sheet per kind (<out>_<kind>_sheet.png: a row per seed) and one
## frame per shot. Prints each harbour's buildings, props, lights and build ms.
## Args: <out_prefix> [seeds, comma separated] [kinds, comma separated | all]
## (env HSHOT_HOUR=21: at that hour, 11 by default)
const VIEWS := ["sea", "above", "pier", "beach"]

var t := 0.0
var out := ""
var seeds: Array = [777, 31337, 4242]
var kinds: Array = ["stilts", "cove", "wharf", "ruins", "landing"]
var jobs: Array = []
var job := 0
var view := 0
var settle := -1
var isl
var cam: Camera3D
var caption: Label
var frames := {}
var gh


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1 and a[1] != "-":
		seeds = Array(a[1].split(",")).map(func(s): return int(s))
	if a.size() > 2 and a[2] != "all":
		kinds = Array(a[2].split(","))
	for k in kinds:
		for s in seeds:
			jobs.append([k, s])
	gh = load("res://scripts/island/kit/kit_harbour_gen.gd")
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var w = root.get_node_or_null("World/Islands")
	if w == null or t < 1.5:
		return false
	if cam == null:
		if not w.chain_ready():
			return false
		_setup(w)
		return false
	if isl == null:
		if job >= jobs.size():
			for k in kinds:
				_sheet(k)
			print("SAVED")
			quit()
			return false
		_build(w, jobs[job])
		view = 0
		settle = 0
		_aim()
		return false
	settle += 1
	if settle < 8:
		return false
	var img := root.get_texture().get_image()
	var nm := "%s_%s_%d_%s" % [out, jobs[job][0], jobs[job][1], VIEWS[view]]
	img.save_png(nm + ".png")
	frames["%s|%d|%d" % [jobs[job][0], jobs[job][1], view]] = img
	view += 1
	settle = 0
	if view >= VIEWS.size():
		isl.queue_free()
		isl = null
		job += 1
		return false
	_aim()
	return false


func _setup(w) -> void:
	w.set_process(false)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for n in root.find_children("*", "CharacterCreator", true, false):
		n._finish(true)
	var hud = get_first_node_in_group("hud")
	if hud:
		hud.visible = false
	root.get_node("Settings").set_value("video", "perf_overlay", false, false)
	for g in ["player", "ship"]:
		var n = get_first_node_in_group(g)
		if n:
			n.visible = false
			n.process_mode = Node.PROCESS_MODE_DISABLED
	root.get_node("Weather").force(0)
	var wx = root.get_node("Weather")
	var k: Dictionary = (wx.get_script() as GDScript).get_script_constant_map()
	var hour := float(OS.get_environment("HSHOT_HOUR")) if OS.get_environment("HSHOT_HOUR") != "" else 11.0
	wx.set_world_time(fposmod(hour - float(k["START_HOUR"]), 24.0) / 24.0 * float(k["DAY_LEN"]) + float(k["DAY_LEN"]))
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 3000
	root.add_child(cam)
	cam.current = true
	var cl := CanvasLayer.new()
	cl.layer = 100
	root.add_child(cl)
	caption = Label.new()
	caption.position = Vector2(12, 8)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	caption.add_theme_constant_override("outline_size", 6)
	cl.add_child(caption)


func _build(w, jb: Array) -> void:
	var gm = root.get_node("GameManager")
	gm.chain_seed = int(jb[1])
	var c = w.chain()
	var n: Dictionary = c.node(int(c.start_next[0]))
	gh.force = str(jb[0])
	isl = load("res://scripts/island/gen_island.gd").new()
	isl.name = "HarbourShotIsle"
	isl.position = Vector3(40000.0, 0.0, 40000.0 + job * 3000.0)
	w.add_child(isl)
	load("res://scripts/island/island_theme.gd").meshes(str(n["theme"]))
	isl.prepare(n)
	var worst := 0
	var total := 0
	for s in isl.finish_steps():
		var ms: int = isl.run_step(s)
		if s[0] == "harbour":
			worst = maxi(worst, ms)
			total += ms
	gh.force = ""
	var hb = isl.harbour
	var site: Node3D = isl.get_node("Site_harbour")
	var what := {}
	for ch in site.get_children():
		var nm := str(ch.name).replace("@", " ").strip_edges().split(" ")[0].rstrip("0123456789")
		if nm == "StaticBody3D" or nm == "Node3D" or nm == "MeshInstance3D":
			var m := ch.find_child("*", false, false)
			nm = "%s(%s)" % [nm, m.name if m else ""]
		what[nm] = int(what.get(nm, 0)) + 1
	print("HARBOUR %s seed %d (%s): kind %s, shore %.0f..%.0f, %d nodes, lights left %d, plan %d ms, build %d ms in %d steps (worst %d ms), spots %d\n   %s" % [
		n["name"], int(jb[1]), str(n["theme"]), hb.kind, hb.f.s0, hb.f.s1, site.get_child_count(), int(hb.ctx.budget["lights"]),
		int(isl.build_ms.get("harbour plan", 0)), total, hb.steps().size(), worst, hb.spots.size(), what])


func _g(p: Vector2, up: float) -> Vector3:
	return isl.to_global(Vector3(p.x, maxf(isl.hv(p), 0.0) + up, p.y))


func _aim() -> void:
	var hb = isl.harbour
	var dock: Vector2 = isl.dock_shore
	var dd: Vector2 = isl.dock_dir
	var side := Vector2(-dd.y, dd.x)
	var de: Vector2 = isl.sites["dock_end"]
	var from: Vector3
	var to: Vector3
	match VIEWS[view]:
		"sea":
			from = _g(de + dd * 55.0 - side * 30.0, 13.0)
			to = _g(dock - dd * 10.0, 2.0)
		"above":
			from = _g(dock + dd * 32.0 + side * 6.0, 58.0)
			to = _g(dock - dd * 14.0, 0.0)
		"pier":
			from = isl.to_global(Vector3(de.x - dd.x * 4.0, 1.7 + 1.7, de.y - dd.y * 4.0))
			to = _g(dock - dd * 22.0, 2.5)
		"beach":
			from = _g(hb.at(-34.0, 6.0), 2.2)
			to = _g(hb.at(14.0, -2.0), 1.5)
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	caption.text = "%s (seed %d)  -  %s harbour  -  %s" % [isl.island_name, int(jobs[job][1]), hb.kind, VIEWS[view]]


## A kind's sheet: a row per seed, its four views across, each at half size.
func _sheet(k: String) -> void:
	var any: Image = frames.values()[0]
	var w: int = any.get_width() / 2
	var h: int = any.get_height() / 2
	var sheet := Image.create((w + 6) * VIEWS.size(), (h + 6) * seeds.size(), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.08))
	for r in range(seeds.size()):
		for v in range(VIEWS.size()):
			var f: Image = frames.get("%s|%d|%d" % [k, seeds[r], v])
			if f == null:
				continue
			f.convert(Image.FORMAT_RGB8)
			f.resize(w, h, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(f, Rect2i(0, 0, w, h), Vector2i(v * (w + 6), r * (h + 6)))
	sheet.save_png("%s_%s_sheet.png" % [out, k])

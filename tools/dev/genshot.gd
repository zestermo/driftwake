extends SceneTree
## A generated chain island (GenIsland): a top-down map of the whole island
## with its sites marked, from high above (fog off), the ship sailing in to the
## pier, on the pier, the village, the camp, the lair, the ruins, the summit
## and its tower, the beast's ground and the beast; each captioned, then a
## contact sheet of them all (<out>_sheet.png). Prints its build times.
## Args: <out_prefix> [chain seed | -] [node id | -] [psx]
## (env GSHOT_SEED / GSHOT_ID still work; GSHOT_HOUR=21 renders at that hour, 11 by default)
const SITE_COLS := {"dock": Color(1, 1, 1), "village": Color(1.0, 0.85, 0.2), "boss": Color(1.0, 0.25, 0.2), "camp": Color(1.0, 0.55, 0.15),
	"lair": Color(0.75, 0.4, 1.0), "ruins": Color(0.6, 0.75, 0.9), "summit": Color(0.3, 0.95, 1.0)}
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
var marks: Node3D


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	var seed_s := a[1] if a.size() > 1 and a[1] != "-" else OS.get_environment("GSHOT_SEED")
	if seed_s != "":
		root.get_node("GameManager").chain_seed = int(seed_s)
	var id_s := a[2] if a.size() > 2 and a[2] != "-" else OS.get_environment("GSHOT_ID")
	if id_s != "":
		want = int(id_s)
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var w = root.get_node_or_null("World/Islands")
	if w == null:
		return false
	var gm = root.get_node("GameManager")
	if want < 0:
		want = int(w.chain().start_next[0])
	# (the crew "at" the island wanted: it's built, nothing else)
	if gm.chain_at != want:
		gm.apply_chain(want, false, root.get_node("Weather").world_time())
		var wx = root.get_node("Weather")
		var k: Dictionary = (wx.get_script() as GDScript).get_script_constant_map()
		var hour := float(OS.get_environment("GSHOT_HOUR")) if OS.get_environment("GSHOT_HOUR") != "" else 11.0
		wx.set_world_time(fposmod(hour - float(k["START_HOUR"]), 24.0) / 24.0 * float(k["DAY_LEN"]))
		gm.chain_since = wx.world_time()
		if OS.get_cmdline_user_args().has("psx"):
			root.get_node("Settings").set_value("video", "psx_preset", 4, false)
	if t < 1.5:
		return false
	if isl == null:
		if not w.chain_ready() or not w.chain_islands.has(want):
			return false
		_setup(w.chain_islands[want])
		return false
	settle += 1
	if settle < 8:
		return false
	var img := root.get_texture().get_image()
	img.save_png("%s_%s.png" % [out, shots[idx][0]])
	frames.append(img)
	if shots[idx][0] == "map" and marks:
		marks.queue_free()
		marks = null
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
	print("island %d %s (%s, Lv %d, seed %d): r %.0f, built %s" % [int(isl.node["id"]), isl.island_name, isl.theme, int(isl.node["level"]),
		int(root.get_node("GameManager").chain_seed), isl.radius, isl.build_ms])
	print("sites %s" % isl.sites)
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
	_mark_sites()
	var r: float = isl.radius
	var dd: Vector2 = isl.dock_dir
	var side := Vector2(-dd.y, dd.x)
	var s: Dictionary = isl.sites
	var top := 0.0
	for h in isl.heights:
		top = maxf(top, h)
	# the ship sailing in to the pier, bow on
	var ship = get_first_node_in_group("ship")
	var ship_at: Vector2 = s["dock_end"] + dd * 50.0
	ship.place(isl.to_global(Vector3(ship_at.x, 0.0, ship_at.y)), atan2(dd.x, dd.y))
	ship.sail = 0.5
	# [name, caption, camera, target, fog off, ortho size]
	shots = [
		["map", "the whole island, north up", Vector3(0, top + 30.0, 0), Vector3(0, 0, -0.001), true, (r + 50.0) * 2.0],
		["aerial", "from high above", Vector3(dd.x * r * 0.9, r * 1.5, dd.y * r * 0.9), Vector3.ZERO, true, 0.0],
		["arrive", "sailing in to the pier", _g(ship_at + dd * 26.0 + side * 7.0, 10.0), _g(s["dock"], 3.0), false, 0.0],
		["sea", "from the sea off the dock", _g(s["dock_end"] + dd * 160.0 + side * 60.0, 14.0), _g(s["dock"], 6.0), false, 0.0],
		["pier", "on the pier", _g(s["dock_end"] - dd * 2.0, 3.4), _g(s["village"], 4.0), false, 0.0],
		["village", "the village", _g(s["village"] + dd * 30.0, 4.0), _g(s["village"] - dd * 40.0, 2.0), false, 0.0],
		["village_high", "the village from above", _g(s["village"] + dd * 28.0 + side * 18.0, 22.0), _g(s["village"], 0.0), false, 0.0],
		["camp", "the pirate camp", _g(s["camp"] + (s["village"] - s["camp"]).normalized() * 22.0, 6.0), _g(s["camp"], 1.0), false, 0.0],
		["lair", "the bug lair", _g(s["lair"] + dd * 18.0 + side * 6.0, 6.0), _g(s["lair"], 0.5), false, 0.0],
		["ruins", "the ruins", _g(s["ruins"] + dd * 14.0, 4.0), _g(s["ruins"], 1.0), false, 0.0],
		["summit", "from the summit's lookout", _g(s["summit"] + dd * 3.0, 8.5), _g(s["dock"], 0.0), false, 0.0],
		["tower", "the summit's tower", _g(s["summit"] - dd * 12.0 + side * 6.0, 16.0), _g(s["summit"], 6.0), false, 0.0],
		["boss", "the beast's ground", _g(s["boss"] + dd * 30.0, 9.0), _g(s["boss"], 1.0), false, 0.0],
		["ape", "the beast", _g(s["boss"] + (s["village"] - s["boss"]).normalized() * 8.0 + side * 3.0, 2.2), _g(s["boss"], 1.6), false, 0.0],
	]
	_aim()


## A disc and a name over each site, seen from above (for the map only).
func _mark_sites() -> void:
	marks = Node3D.new()
	marks.name = "ShotMarks"
	isl.add_child(marks)
	for k in isl.sites.keys():
		var col: Color = SITE_COLS.get(k, Color(0.8, 0.8, 0.8))
		var p: Vector2 = isl.sites[k]
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = col
		mat.no_depth_test = true
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 5.0 if k != "dock_end" else 2.5
		cm.bottom_radius = cm.top_radius
		cm.height = 0.5
		cm.material = mat
		disc.mesh = cm
		disc.position = Vector3(p.x, maxf(isl.height_at(p.x, p.y), 0.0) + 2.0, p.y)
		marks.add_child(disc)
		if k == "dock_end":
			continue
		var lb := Label3D.new()
		lb.text = k
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.pixel_size = 0.6
		lb.font_size = 40
		lb.outline_size = 14
		lb.modulate = col
		lb.position = disc.position + Vector3(0, 30.0, 18.0)
		marks.add_child(lb)


## Island-space p, `up` m above the ground there (or the sea), in island space.
func _g(p: Vector2, up: float) -> Vector3:
	return Vector3(p.x, maxf(isl.height_at(p.x, p.y), 0.0) + up, p.y)


func _aim():
	var s: Array = shots[idx]
	var env: Environment = root.get_viewport().world_3d.environment if root.get_viewport().world_3d.environment else null
	for we in root.find_children("*", "WorldEnvironment", true, false):
		env = we.environment
	if env:
		env.fog_enabled = not s[4]
	var clouds = root.get_node_or_null("World/Clouds")
	if clouds:
		clouds.visible = not s[4]
	caption.text = "%s  (%s, Lv %d)  -  %s" % [isl.island_name, isl.theme, int(isl.node["level"]), s[1]]
	if float(s[5]) > 0.0:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(s[5])
		cam.global_position = isl.to_global(s[2])
		cam.global_rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	else:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.global_position = isl.to_global(s[2])
		cam.look_at(isl.to_global(s[3]), Vector3.UP)


## Every shot at half size on one sheet, three across.
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

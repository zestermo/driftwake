extends SceneTree
## The weather on a themed chain island: the same two views (eye height on the way into the village, and
## from 14 m up over it) in a light fall, a heavy one, the worst (blizzard / sandstorm) and at night;
## then a contact sheet (<out>_sheet.png). Prints Weather's numbers for each.
## Args: <out_prefix> <chain seed> [node id | -] [shot,shot...]   (seed 1 node 1: Hoarfell Atoll, snow; seed 2: a desert)
## Shots: clear (11:00 cloudy), heavy (13:00 rain slot), worst (15:00 storm), night (22:00 cloudy), dusk (18:30 storm).
const SHOTS := {"clear": [11.0, 1], "heavy": [13.0, 2], "worst": [15.0, 3], "night": [22.0, 1], "dusk": [18.4, 3]}
var t := 0.0
var out := ""
var want := -1
var isl
var cam: Camera3D
var shots: Array = []
var idx := 0
var view := 0
var settle := 0.0
var frames: Array = []
var caption: Label
var spot := Vector2.ZERO
var look := Vector2.ZERO


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	root.get_node("GameManager").chain_seed = int(a[1])
	if a.size() > 2 and a[2] != "-":
		want = int(a[2])
	var names := ["clear", "heavy", "worst", "night"]
	if a.size() > 3:
		names = Array(a[3].split(","))
	for n in names:
		shots.append([n, SHOTS[n][0], SHOTS[n][1]])
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
		gm.chain_since = root.get_node("Weather").world_time()
	if t < 1.5:
		return false
	if isl == null:
		if not w.chain_ready() or not w.chain_islands.has(want):
			return false
		_setup(w.chain_islands[want])
		_shot()
		return false
	settle += d
	if settle < 4.0:
		return false
	var img := root.get_texture().get_image()
	var nm := "%s_%s" % [shots[idx][0], ["eye", "wide"][view]]
	img.save_png("%s_%s.png" % [out, nm])
	frames.append(img)
	var wx = root.get_node("Weather")
	print("shot %s: hour %.1f state %s snow %.2f sand %.2f murk %.2f rain %.2f fog %.2f fog_end %.0f fog_color %s zone %s" % [nm, wx.hour(),
		wx.state_name(wx.state), wx.snow, wx.sand, wx.murk, wx.rain, wx.fog, wx.fog_end, wx.fog_color, wx._zone])
	view += 1
	if view > 1:
		view = 0
		idx += 1
		if idx >= shots.size():
			_sheet()
			print("SAVED")
			quit()
			return false
		_shot()
	_aim()
	settle = 0.0
	return false


func _setup(island) -> void:
	isl = island
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
	print("island %d %s (%s), r %.0f" % [int(isl.node["id"]), isl.island_name, isl.theme, isl.radius])
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
	var s: Dictionary = isl.sites
	var v: Vector2 = s["village"]
	var dd: Vector2 = (s["dock"] - v).normalized()
	# open ground on the way in from the dock, off the road
	spot = v + dd * 34.0 + Vector2(-dd.y, dd.x) * 9.0
	look = v
	var p = get_first_node_in_group("player")
	p.global_position = isl.to_global(Vector3(spot.x, isl.hv(spot) + 0.3, spot.y))
	p.reset_physics_interpolation()


func _shot() -> void:
	var wx = root.get_node("Weather")
	wx.skip_to(float(shots[idx][1]))
	wx.forced = int(shots[idx][2])
	wx.forced_at = wx.world_time() - 100.0
	settle = 0.0
	_aim()


func _aim() -> void:
	var s: Array = shots[idx]
	caption.text = "%s (%s)  -  %s, %s" % [isl.island_name, isl.theme, s[0], ["eye height", "from 14 m up"][view]]
	var to_look := (look - spot).normalized()
	if view == 0:
		var side := Vector2(-to_look.y, to_look.x)
		var at := spot - to_look * 4.0 - side * 2.0
		cam.global_position = isl.to_global(Vector3(at.x, isl.hv(at) + 1.8, at.y))
		cam.look_at(isl.to_global(Vector3(look.x, isl.hv(look) + 2.0, look.y)), Vector3.UP)
	else:
		var at := spot - to_look * 10.0
		cam.global_position = isl.to_global(Vector3(at.x, isl.hv(at) + 14.0, at.y))
		cam.look_at(isl.to_global(Vector3(look.x, isl.hv(look), look.y)), Vector3.UP)


func _sheet() -> void:
	var w: int = frames[0].get_width() / 2
	var h: int = frames[0].get_height() / 2
	var cols := 2
	var rows := ceili(frames.size() / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	for i in range(frames.size()):
		var f: Image = frames[i]
		f.convert(Image.FORMAT_RGB8)
		f.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(f, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png("%s_sheet.png" % out)

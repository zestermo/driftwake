extends SceneTree
## The fog isle's graveyard (fog_places.gd, 1.30) in the real world: the first fog island of the chain seeds from
## <seed> up, its graveyard from the way in, from above and inside, by day (11:00) and by night (22:00), then a captain
## walks in and its zombies claw up out of their graves (three frames of the nearest rising). Captioned; a sheet.
## Args: <out_prefix> [first chain seed]. Out: <out>_<shot>.png, <out>_sheet.png.
## `& $env:GODOT --path . --script res://tools/dev/graveshot.gd -- res://tools/dev/out/grave`
var out := "res://tools/dev/out/grave"
var seed_v := 1
var t := 0.0
var isl
var pl: Dictionary
var cam: Camera3D
var caption: Label
var shots: Array = []
var idx := 0
var settle := 0
var frames: Array = []
var phase := "find"
var z
var rise_t := 0.0
var rise_i := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else out
	seed_v = int(a[1]) if a.size() > 1 else 1
	_load()


func _load() -> void:
	root.get_node("GameManager").chain_seed = seed_v
	t = 0.0
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	for n in root.find_children("*", "CharacterCreator", true, false):
		n._finish(true)
	var w = root.get_node_or_null("World/Islands")
	if w == null or t < 1.0:
		return false
	var gm = root.get_node("GameManager")
	var wx = root.get_node("Weather")
	match phase:
		"find":
			if not w.chain_ready():
				return false
			var want := -1
			for n in w.chain().nodes:
				if str(n["theme"]) == "fog":
					want = int(n["id"])
					break
			if want < 0:
				seed_v += 1
				_load()
				return false
			print("GS chain seed %d, fog island %d" % [seed_v, want])
			gm.apply_chain(want, false, wx.world_time())
			wx.set_world_time(wx.time_at(11.0))
			gm.chain_since = wx.world_time()
			phase = "build"
			t = 0.0
		"build":
			var want := int(gm.chain_at)
			if t < 1.5 or not w.chain_islands.has(want):
				return false
			isl = w.chain_islands[want]
			var g := (isl.places as Array).filter(func(e): return str(e.get("kind", "")) == "fog_graveyard")
			if g.is_empty():
				print("GS FAILED: no graveyard on %s" % isl.island_name)
				quit(1)
				return false
			pl = g[0]
			_setup()
			phase = "shoot"
		"shoot":
			settle += 1
			if settle < 10:
				return false
			_grab()
			idx += 1
			settle = 0
			if idx >= shots.size():
				_start_rise()
				return false
			_aim()
		"rise":
			rise_t += d
			if z == null:
				return false
			var c: Vector3 = z.global_position
			var p = get_first_node_in_group("player")
			cam.global_position = c + (p.global_position - c).normalized() * 4.0 + Vector3.UP * 1.6
			cam.look_at(c + Vector3.UP * 0.6, Vector3.UP)
			var ats := [0.45, 0.9, 1.5, 2.6]
			if rise_i < ats.size() and rise_t >= float(ats[rise_i]):
				caption.text = "%s - a zombie claws up out of its grave (%.1f s, %s)" % [isl.island_name, ats[rise_i], z.state]
				_grab_named("rise_%d" % rise_i)
				rise_i += 1
			if rise_t > 3.0:
				_sheet()
				print("GS done")
				quit()
	return false


func _setup() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var hud = get_first_node_in_group("hud")
	if hud:
		hud.visible = false
	root.get_node("Settings").set_value("video", "perf_overlay", false, false)
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 2000
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
	# the captain far off, so nothing rises yet
	var p = get_first_node_in_group("player")
	p.global_position = isl.to_global(Vector3(isl.sites["dock"].x, 5.0, isl.sites["dock"].y))
	p.reset_physics_interpolation()
	var r := float(pl["r"])
	var pa: Vector2 = pl["at"]
	var pf: Vector2 = pl["face"]
	var side := pf.orthogonal()
	for hour in [11.0, 22.0]:
		var tag := "day" if hour < 12.0 else "night"
		shots.append([tag + "_gate", "the graveyard from its way in (%s)" % tag, hour, _g(pa + pf * (r + 7.0) + side * 4.0, 2.2), _g(pa, 1.2)])
		shots.append([tag + "_above", "from above (%s)" % tag, hour, _g(pa + pf * (r * 0.9) - side * (r * 0.9), r * 1.1), _g(pa, 0.0)])
		shots.append([tag + "_inside", "inside, looking to the crypt (%s)" % tag, hour, _g(pa + pf * (r * 0.5) + side * 1.5, 1.7), _g(pa - pf * r, 2.5)])
	_aim()


func _g(p: Vector2, up: float) -> Vector3:
	return isl.to_global(Vector3(p.x, maxf(isl.height_at(p.x, p.y), 0.0) + up, p.y))


func _aim() -> void:
	var s: Array = shots[idx]
	var wx = root.get_node("Weather")
	wx.set_world_time(wx.time_at(float(s[2])))
	caption.text = "%s (fog, Lv %d) - %s" % [isl.island_name, int(isl.node["level"]), s[1]]
	cam.global_position = s[3]
	cam.look_at(s[4], Vector3.UP)
	wx.set("_zone_t", 0.0)


## Dusk: the captain walks in at the gate; the nearest zombie's grave is watched.
func _start_rise() -> void:
	var wx = root.get_node("Weather")
	wx.set_world_time(wx.time_at(16.5))
	var fauna = isl.get_node("Fauna")
	var zs: Array = fauna.groups_of("zombie")
	var pa: Vector2 = pl["at"]
	var gate: Vector3 = _g(pa + (pl["face"] as Vector2) * float(pl["r"]) * 0.45, 0.3)
	var best := INF
	for si in zs[0]["spots"]:
		var n = fauna.spots[si]["node"]
		if n.global_position.distance_to(gate) < best:
			best = n.global_position.distance_to(gate)
			z = n
	var p = get_first_node_in_group("player")
	p.global_position = z.global_position + (gate - z.global_position).normalized() * 7.0 + Vector3.UP * 0.5
	p.reset_physics_interpolation()
	p.health_component.max_health = 99999.0
	p.health_component.current_health = 99999.0
	phase = "rise"


func _grab() -> void:
	_grab_named(shots[idx][0])


func _grab_named(n: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("%s_%s.png" % [out, n]))
	frames.append(img)
	print("GS shot ", n)


func _sheet() -> void:
	var w := 640
	var h := 360
	var rows := ceili(frames.size() / 3.0)
	var sheet := Image.create(w * 3, h * rows, false, Image.FORMAT_RGB8)
	for i in range(frames.size()):
		var f: Image = frames[i].duplicate()
		f.convert(Image.FORMAT_RGB8)
		f.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(f, Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
	sheet.save_png(ProjectSettings.globalize_path("%s_sheet.png" % out))

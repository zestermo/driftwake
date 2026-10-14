extends SceneTree
## Render sheets of the generated islands' interiors (KitDungeons, KitTemple): for
## each chain seed its first island's caves and temple, from outside (the mouth,
## from above), each room from its doorway, the end room and its reward; the temple
## with its gate shut, then both levers pulled and the sanctum open. PSX grid on,
## HUD off. Saves <out>/<seed>_<name>.png and <out>/sheet_<seed>.png.
## Args: <out_dir> <seed,seed,...>        (env DSHOT_HOUR: hour, default 12)
##       <out_dir> list <from> <to>       (headless is fine: which interiors each seed rolls)
const W := 1280
const H := 720
const GRID := Vector2(640, 360)
## (loaded once the world is up, not named: a tool compiles before the autoloads exist)
var KD
var KT
var DG

var out := ""
var seeds: Array = []
var listing := false
var t := 0.0
var started := false
var cam: Camera3D
var frames: Array = []
var p
var gm
var wg
var w
var settings


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	if a[1] == "list":
		listing = true
		for s in range(int(a[2]), int(a[3]) + 1):
			seeds.append(s)
	else:
		seeds = Array(a[1].split(",")).map(func(s): return int(s))
	DisplayServer.window_set_size(Vector2i(W, H))
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	if cam and not cam.current:
		cam.current = true
	if t > 2.0 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	KD = load("res://scripts/island/kit/kit_dungeons.gd")
	KT = load("res://scripts/island/kit/kit_temple.gd")
	DG = load("res://scripts/island/dungeon.gd")
	gm = root.get_node("GameManager")
	wg = root.get_node("World/Islands")
	w = root.get_node("Weather")
	p = get_first_node_in_group("player")
	if listing:
		_list()
		quit()
		return
	settings = root.get_node("Settings")
	settings.set_value("video", "perf_overlay", false, false)
	get_first_node_in_group("hud").visible = false
	p.health_component.max_health = 99999.0
	p.health_component.current_health = 99999.0
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 2000.0
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(cam)
	cam.current = true
	var hour_s := OS.get_environment("DSHOT_HOUR")
	_time(float(hour_s) if hour_s != "" else 12.0)
	for s in seeds:
		await _seed(int(s))
	print("SAVED")
	quit()


func _list() -> void:
	for s in seeds:
		gm.chain_seed = s
		var c = wg.chain()
		var n: Dictionary = c.node(int(c.start_next[0]))
		load("res://scripts/island/island_theme.gd").meshes(str(n["theme"]))
		var g = load("res://scripts/island/gen_island.gd").new()
		g.prepare(n)
		var kinds: Array = g.interiors.map(func(e): return "%s (%d rooms, r %.0f)" % [e["kind"], e["rooms"].size(), e["radius"]])
		print("seed %d: %s, plan %d ms: %s" % [s, n["name"], int(g.build_ms["dungeon_plan"]), ", ".join(kinds)])
		g.free()


func _wait(secs: float) -> void:
	await create_timer(secs, true, false, true).timeout


func _time(h: float) -> void:
	w.world_offset += fposmod(h - float(w.hour()), 24.0) / 24.0 * float(w.DAY_LEN)
	w.forced = 0
	w.forced_at = w.world_time() - 100.0


func _seed(s: int) -> void:
	frames.clear()
	for id in wg.chain_islands.keys():
		wg._free_chain_island(id)
	gm.chain_seed = s
	var id := int(wg.chain().start_next[0])
	gm.apply_chain(id, false, w.world_time())
	var t0 := t
	while (not wg.chain_ready() or not wg.chain_islands.has(id)) and t - t0 < 120.0:
		await process_frame
	var isl = wg.chain_islands[id]
	print("seed %d: %s, interiors %s" % [s, isl.island_name, isl.interiors.map(func(e): return e["kind"])])
	for e in isl.interiors:
		var d = isl.get_node(str(e["name"]))
		if e["kind"] == "temple":
			await _temple(s, isl, d, e)
		else:
			await _cave(s, isl, d, e)
	_sheet(s)


func _snap(s: int, name: String) -> void:
	settings.set_value("video", "pixelate", true, false)
	settings.set_value("video", "dither", true, false)
	var psx = root.get_node("PSX")
	psx._post_rect.material.set_shader_parameter("pixel_res", GRID)
	psx._post_rect.material.set_shader_parameter("pixelate", true)
	root.scaling_3d_scale = GRID.y / float(maxi(root.size.y, 1))
	for l in current_scene.find_children("*", "Label3D", true, false):
		(l as Label3D).visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png("%s/%d_%s.png" % [out, s, name])
	frames.append([name, img])
	print("shot ", name)


func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


## The captain parked well off (the dungeon awake, its enemies not alerted).
func _park(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _cave(s: int, isl, d, e: Dictionary) -> void:
	var tag: String = "%s_%s" % [e["name"], e["kind"]]
	var out_dir: Vector2 = e["mouth_dir"]
	var o3 := Vector3(out_dir.x, 0.0, out_dir.y)
	var side := o3.cross(Vector3.UP)
	var m: Vector3 = d.to_global(KD.loc(e, e["mouth"], e["mouth_y"]))
	var c: Vector3 = d.global_position + Vector3(0, e["rooms"][0]["y"], 0)
	_park(m + o3 * 45.0 + Vector3.UP * 30.0)
	await _wait(1.0)
	_look(m + o3 * 14.0 + side * 5.0 + Vector3.UP * 4.0, m + Vector3.UP * 2.0)
	await _wait(0.4)
	await _snap(s, tag + "_mouth")
	_look(c + o3 * (float(e["radius"]) + 25.0) + side * 20.0 + Vector3.UP * 38.0, c)
	await _wait(0.4)
	await _snap(s, tag + "_above")
	for r in e["rooms"]:
		var rc: Vector3 = d.to_global(KD.loc(e, r["c"], r["y"]))
		var door: Vector3 = d.to_global(KD.loc(e, r["doors"][0], r["y"]))
		var back := (door - rc).normalized()
		_look(door + back * 0.5 + Vector3.UP * 2.2, rc + Vector3.UP * 0.8 - back * float(r["r"]) * 0.4)
		await _wait(0.3)
		await _snap(s, "%s_%s" % [tag, r["role"]])
	var end: Dictionary = KD.room_of(e, "end")
	var rp: Vector3 = d.to_global(DG.reward_point(e, end))
	var ec: Vector3 = d.to_global(KD.loc(e, end["c"], end["y"]))
	_look(ec + (ec - rp).normalized() * 3.0 + Vector3.UP * 3.0, rp + Vector3.UP * 0.6)
	await _wait(0.3)
	await _snap(s, tag + "_reward")


func _temple(s: int, isl, d, e: Dictionary) -> void:
	var tag: String = e["name"]
	_park(d.to_global(Vector3(0, 30, 70)))
	await _wait(1.0)
	_look(d.to_global(Vector3(9, 4, float(KT.PLINTH[3]) + float(e["stair_len"]) + 16)), d.to_global(Vector3(0, 3.5, 4)))
	await _wait(0.4)
	await _snap(s, tag + "_front")
	_look(d.to_global(Vector3(-40, 34, 30)), d.to_global(Vector3(0, 2, -6)))
	await _wait(0.4)
	await _snap(s, tag + "_above")
	_look(d.to_global(Vector3(0.5, 2.0, 7.0)), d.to_global(Vector3(0, 1.5, -8)))
	await _wait(0.3)
	await _snap(s, tag + "_hall")
	_look(d.to_global(Vector3(-4.5, 2.0, 0.0)), d.to_global(Vector3(-13, 1.2, 0)))
	await _wait(0.3)
	await _snap(s, tag + "_shrine")
	_look(d.to_global(Vector3(0.0, 1.8, -3.0)), d.to_global(Vector3(0, 1.8, -12)))
	await _wait(0.3)
	await _snap(s, tag + "_gate_shut")
	d.net_pull(0)
	d.net_pull(1)
	await _wait(2.8)
	_look(d.to_global(Vector3(0.0, 2.0, -7.0)), d.to_global(Vector3(0, 0.8, -18)))
	await _wait(0.3)
	await _snap(s, tag + "_sanctum")
	_look(d.to_global(Vector3(2.5, 2.4, -14.5)), d.to_global(Vector3(0, 0.8, -18)))
	await _wait(0.3)
	await _snap(s, tag + "_altar")


func _sheet(s: int) -> void:
	if frames.is_empty():
		return
	var tw := W / 3
	var th := H / 3
	var cols := 4
	var rows := ceili(frames.size() / float(cols))
	var sheet := Image.create(tw * cols + (cols - 1) * 4, th * rows + (rows - 1) * 4, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.08))
	for i in range(frames.size()):
		var f: Image = (frames[i][1] as Image).duplicate()
		f.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(f, Rect2i(0, 0, tw, th), Vector2i((i % cols) * (tw + 4), (i / cols) * (th + 4)))
	sheet.save_png("%s/sheet_%d.png" % [out, s])
	print("sheet %d: %s" % [s, ", ".join(frames.map(func(e): return str(e[0])))])

extends SceneTree
## Performance benchmark: fixed views at 1920x1080, vsync off, the "960x540
## (sharper)" preset (not saved). For each view: average frame ms, process /
## physics ms, render CPU / GPU ms, draw calls, primitives, nodes. Compare runs
## before and after a change. Args: [label] [WxH]
const VIEWS := [
	["village", Vector3(149.0, 5.0, 33.0), Vector3(150.0, 4.0, 80.0)],
	["camp", Vector3(0, 0, 0), Vector3(0, 0, 0)],
	["dock_sea", Vector3(147.36, 5.4, 23.2), Vector3(160.0, 0.0, -40.0)],
	["open_sea", Vector3(420.0, 9.0, -330.0), Vector3(150.0, 5.0, 20.0)],
	["overview", Vector3(40.0, 90.0, 220.0), Vector3(150.0, 0.0, 0.0)],
]
const SETTLE := 2.0
const SAMPLE := 3.0
var t := 0.0
var label := ""
var p
var perf
var cam: Camera3D
var i := -1
var t0 := 0.0
var acc := {}
var n := 0


var size := Vector2i(1920, 1080)
## "probe": at the village, switch whole systems off one at a time and print
## how much process / physics / GPU time each one was costing.
var probe := false


func _initialize():
	var args := OS.get_cmdline_user_args()
	label = args[0] if args.size() > 0 else "run"
	probe = label.begins_with("probe")
	# ("probe:camp" etc. probes at that view)
	_probe_view = label.get_slice(":", 1) if label.contains(":") else "village"
	if args.size() > 1:
		var wh := args[1].split("x")
		size = Vector2i(int(wh[0]), int(wh[1]))
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	if t < 2.5: return false
	if p == null:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_size(size)
		root.size = size
		root.get_node("Settings").set_value("video", "psx_preset", 4, false)
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		p = get_first_node_in_group("player")
		perf = root.get_node("Perf")
		var w = root.get_node("Weather")
		w.forced = 0
		w.forced_at = w.world_time() - 100.0
		cam = Camera3D.new(); cam.fov = 75; cam.far = 4000
		var r := Node3D.new(); var a := Node3D.new()
		root.add_child(r); r.add_child(a); a.add_child(cam)
		print("perfbench %s  window %s  %s" % [label, str(root.size), RenderingServer.get_video_adapter_name()])
		if probe:
			i = -1
			_next()
			while VIEWS[i][0] != _probe_view:
				_next()
			_probe_setup()
			return false
		print("3D scale %.2f" % root.scaling_3d_scale)
		print("%-10s %7s %7s %7s %7s %7s %7s %8s %7s %6s %4s" % ["view", "frame", "process", "physics", "rcpu", "gpu", "draws", "prims", "nodes", "worst", ">33"])
		_next()
		return false
	if probe:
		_probe_step(d)
		return false
	var e := t - t0
	if e < SETTLE:
		return false
	if e < SETTLE + SAMPLE:
		acc["frame"] = acc.get("frame", 0.0) + d * 1000.0
		acc["worst"] = maxf(acc.get("worst", 0.0), d * 1000.0)
		if d * 1000.0 > 33.0:
			acc["hitches"] = acc.get("hitches", 0.0) + 1.0
		acc["process"] = acc.get("process", 0.0) + Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		acc["physics"] = acc.get("physics", 0.0) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		acc["rcpu"] = acc.get("rcpu", 0.0) + RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		acc["gpu"] = acc.get("gpu", 0.0) + perf.gpu_ms()
		var c: Dictionary = perf.counts()
		acc["draws"] = acc.get("draws", 0.0) + c["draws"]
		acc["prims"] = acc.get("prims", 0.0) + c["prims"]
		acc["nodes"] = c["nodes"]
		n += 1
		return false
	var k := float(maxi(n, 1))
	print("%-10s %7.2f %7.2f %7.2f %7.2f %7.2f %7.0f %8.0f %7d %6.1f %4d   active bodies %d  pairs %d" % [VIEWS[i][0], acc["frame"] / k, acc["process"] / k, acc["physics"] / k,
		acc["rcpu"] / k, acc["gpu"] / k, acc["draws"] / k, acc["prims"] / k, acc["nodes"], acc.get("worst", 0.0), int(acc.get("hitches", 0.0)),
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)), int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))])
	_next()
	return false


var groups: Array = []    # [script path, nodes]
var g_i := -2             # -2 settling, -1 baseline, then each group
var base := Vector2.ZERO
var results: Array = []


func _probe_setup() -> void:
	var by := {}
	for node in root.find_children("*", "", true, false):
		var s = node.get_script()
		if s == null or not (node.is_processing() or node.is_physics_processing()):
			continue
		var key: String = s.resource_path if s.resource_path != "" else "(built-in)"
		if not by.has(key):
			by[key] = []
		by[key].append([node, node.is_processing(), node.is_physics_processing()])
	for k in by:
		groups.append([k, by[k]])
	t0 = t


var _proc := PackedFloat32Array()
var _phys := PackedFloat32Array()


## (run it --headless: with no rendering, frame time is script + physics)
func _probe_sample(d: float) -> void:
	_proc.append(d * 1000.0)
	_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	n += 1


func _median(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var total := 0.0
	for v in a:
		total += v
	return total / a.size()


func _set_group(gi: int, on: bool) -> void:
	for e in groups[gi][1]:
		if is_instance_valid(e[0]):
			e[0].set_process(e[1] if on else false)
			e[0].set_physics_process(e[2] if on else false)


## Each script in turn: its nodes stop processing on their own and the probe
## calls their _process / _physics_process itself, timed (per frame, ms).
func _probe_step(d: float) -> void:
	var e := t - t0
	if g_i == -2:
		if e > 3.0:
			g_i = 0; t0 = t; _proc.clear(); _phys.clear()
			_set_group(0, false)
		return
	var nodes: Array = groups[g_i][1]
	var us := Time.get_ticks_usec()
	for en in nodes:
		if is_instance_valid(en[0]) and en[1] and en[0].has_method("_process"):
			en[0]._process(d)
	var us2 := Time.get_ticks_usec()
	for en in nodes:
		if is_instance_valid(en[0]) and en[2] and en[0].has_method("_physics_process"):
			en[0]._physics_process(1.0 / 60.0)
	var us3 := Time.get_ticks_usec()
	if e > 0.3:
		_proc.append((us2 - us) / 1000.0)
		_phys.append((us3 - us2) / 1000.0)
	if e < 1.8:
		return
	_set_group(g_i, true)
	results.append([groups[g_i][0], nodes.size(), _median(_proc), _median(_phys)])
	g_i += 1
	if g_i >= groups.size():
		results.sort_custom(func(a, b): return a[2] + a[3] > b[2] + b[3])
		var tp := 0.0
		var tf := 0.0
		print("%-58s %5s %8s %8s" % ["script", "nodes", "process", "physics"])
		for r in results:
			tp += r[2]; tf += r[3]
			if r[2] + r[3] > 0.02:
				print("%-58s %5d %8.3f %8.3f" % [r[0].replace("res://", ""), r[1], r[2], r[3]])
		print("total: process %.2f ms/frame, physics %.2f ms/tick" % [tp, tf])
		quit()
		return
	_set_group(g_i, false)
	t0 = t; _proc.clear(); _phys.clear()


var _probe_view := "village"


func _next() -> void:
	i += 1
	if i >= VIEWS.size():
		quit()
		return
	acc = {}
	n = 0
	t0 = t
	var v: Array = VIEWS[i]
	var from: Vector3 = v[1]
	var at: Vector3 = v[2]
	if v[0] == "camp":
		var camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
		at = camp.grunts[1].global_position + Vector3(0, 1, 0)
		from = at + Vector3(14, 8, 12)
	# the player stands near the view so its nearby systems (IK, cloth) run
	p.global_position = from.lerp(at, 0.3) if from.y < 20.0 else at + Vector3.UP * 2.0
	p.reset_physics_interpolation()
	cam.current = true
	cam.global_position = from
	cam.look_at(at, Vector3.UP)

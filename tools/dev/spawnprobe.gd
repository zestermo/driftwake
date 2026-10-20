extends SceneTree
## What one enemy or creature costs to put in the world (an island's build spawns dozens): each kind made three times
## in the world, far out at sea, timing new + setup + add_child and the frame after it. Scuttlebugs, spitters, every
## theme's creatures and beasts. A window (the server's work counts) or --headless. Args: [kind filter]
var t := 0.0
var w
var jobs: Array = []
var ji := 0
var phase := 0
var last_us := 0
var made: Node3D
var step_us := 0
var rows := {}
var filter := ""
const AT := Vector3(0, 2, 7000)


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		filter = a[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func _jobs() -> Array:
	var out: Array = []
	out.append(["scuttlebug", func(): return load("res://scripts/enemies/scuttlebug.gd").new().setup(false, AT)])
	out.append(["scuttlebug big", func(): return load("res://scripts/enemies/scuttlebug.gd").new().setup(true, AT)])
	out.append(["spitter", func(): return load("res://scripts/enemies/canopy_spitter.gd").new().roost(AT + Vector3(0, 8, 0), AT)])
	var themes = load("res://scripts/island/themes/island_themes.gd")
	for th in themes.all():
		for k in th.creatures.keys():
			var path: String = th.creatures[k]
			out.append(["%s %s" % [th.name, k], func(): return load(path).new().setup(AT, {})])
		for k in th.beasts.keys():
			var info: Dictionary = th.beasts[k]
			if info.has("script") and not info.get("camp", false):
				var path: String = info["script"]
				out.append(["%s beast %s" % [th.name, k], func(): return load(path).new().setup({"post": AT, "yaw": 0.0, "level": 6, "name": "Probe"})])
	return out.filter(func(j): return filter == "" or str(j[0]).contains(filter))


func _process(d: float) -> bool:
	t += d
	if w == null:
		w = root.get_node_or_null("World/Islands")
		if w != null and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		return false
	if t < 3.0 or not w.chain_ready():
		return false
	if jobs.is_empty():
		jobs = _jobs()
	var now := Time.get_ticks_usec()
	if made != null:
		var key: String = jobs[ji][0]
		if not rows.has(key):
			rows[key] = []
		rows[key].append([step_us, now - last_us])
		made.queue_free()
		made = null
		phase += 1
		if phase >= 3:
			phase = 0
			ji += 1
		return false
	if ji >= jobs.size():
		for k in rows.keys():
			var r: Array = rows[k]
			print("SPAWN %-32s new+add %6.1f %6.1f %6.1f ms   frames %6.1f %6.1f %6.1f ms" % [k, r[0][0] / 1000.0, r[1][0] / 1000.0, r[2][0] / 1000.0,
				r[0][1] / 1000.0, r[1][1] / 1000.0, r[2][1] / 1000.0])
		quit()
		return true
	var t0 := Time.get_ticks_usec()
	made = (jobs[ji][1] as Callable).call()
	made.name = "Probe%d" % phase
	w.add_child(made)
	made.global_position = AT
	step_us = Time.get_ticks_usec() - t0
	last_us = t0
	return false

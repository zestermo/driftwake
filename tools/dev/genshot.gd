extends SceneTree
## A generated chain island (GenIsland): from high above (fog off), from the
## sea off its dock, on the pier, at the village's ground, at the boss's ground
## and from the summit. Builds the first island the log pose points at (or
## GSHOT_ID's node; GSHOT_SEED picks the chain). Prints its build times. Args: <out_prefix>
var t := 0.0
var out := ""
var cam: Camera3D
var isl
var shots: Array = []
var idx := 0
var settle := 0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	if OS.get_environment("GSHOT_SEED") != "":
		root.get_node("GameManager").chain_seed = int(OS.get_environment("GSHOT_SEED"))
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if isl == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
		var w = root.get_node("World/Islands")
		var want := int(OS.get_environment("GSHOT_ID")) if OS.get_environment("GSHOT_ID") != "" else int(w.chain().start_next[0])
		if not w.chain_islands.has(want):
			if OS.get_environment("GSHOT_ID") != "" and not w._pending.has(want):
				w._start_chain_island(w.chain().node(want))
			return false
		isl = w.chain_islands[want]
		print("island %s: r %.0f, sites %s" % [isl.island_name, isl.radius, isl.sites])
		var hud = get_first_node_in_group("hud")
		if hud: hud.visible = false
		cam = Camera3D.new(); cam.fov = 60; cam.far = 3000
		root.add_child(cam); cam.current = true
		var r: float = isl.radius
		var dd: Vector2 = isl.dock_dir
		var side := Vector2(-dd.y, dd.x)
		var s: Dictionary = isl.sites
		shots = [
			["aerial", Vector3(dd.x * r * 0.9, r * 1.5, dd.y * r * 0.9) , Vector3.ZERO, true],
			["sea", _g(s["dock_end"] + dd * 160.0 + side * 60.0, 14.0), _g(s["dock"], 6.0), false],
			["pier", _g(s["dock_end"] - dd * 2.0, 3.4), _g(s["village"], 4.0), false],
			["village", _g(s["village"] + dd * 30.0, 4.0), _g(s["village"] - dd * 40.0, 2.0), false],
			["boss", _g(s["boss"] + dd * 30.0, 5.0), _g(s["boss"], 1.0), false],
			["summit", _g(s["summit"] + dd * 6.0, 4.0), _g(s["dock"], 0.0), false],
			["camp", _g(s["camp"] + (s["village"] - s["camp"]).normalized() * 22.0, 6.0), _g(s["camp"], 1.0), false],
			["lair", _g(s["lair"] + dd * 18.0 + side * 6.0, 6.0), _g(s["lair"], 0.5), false],
			["ruins", _g(s["ruins"] + dd * 14.0, 4.0), _g(s["ruins"], 1.0), false],
			["tower", _g(s["summit"] - dd * 12.0 + side * 6.0, 16.0), _g(s["summit"], 6.0), false],
		]
		_aim()
		return false
	settle += 1
	if settle < 6: return false
	root.get_texture().get_image().save_png("%s_%s.png" % [out, shots[idx][0]])
	idx += 1; settle = 0
	if idx >= shots.size():
		print("SAVED"); quit(); return false
	_aim()
	return false
## Island-space p, `up` m above the ground there, in world space.
func _g(p: Vector2, up: float) -> Vector3:
	return Vector3(p.x, maxf(isl.height_at(p.x, p.y), 0.0) + up, p.y)
func _aim():
	var s: Array = shots[idx]
	var env: Environment = root.get_viewport().world_3d.environment if root.get_viewport().world_3d.environment else null
	for we in root.find_children("*", "WorldEnvironment", true, false):
		env = we.environment
	if env:
		env.fog_enabled = not s[3]
	cam.global_position = isl.to_global(s[1]); cam.look_at(isl.to_global(s[2]), Vector3.UP)

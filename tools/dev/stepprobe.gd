extends SceneTree
## A chain island's build steps one a frame, as the world puts it in: each step's ms and its whole frame's
## (deferred spawns and the tail land in the frame), the island built twice (cold caches, then warm).
## Prints the steps over 4 ms (step or frame) and the totals. Args: [chain seed] [node id]; a window
## (the server's mesh and texture work counts) or --headless (scripts only).
var chain_seed := 4242
var node_id := -1
var t := 0.0
var w
var isl
var steps: Array = []
var si := 0
var round_n := 0
var last_us := 0
var step_us := 0
var rows: Array = []
var idle: Array = []


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		chain_seed = int(a[0])
	if a.size() > 1:
		node_id = int(a[1])
	load("res://tools/dev/test_kit.gd").use_seed(self, chain_seed)
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	if w == null:
		w = root.get_node_or_null("World/Islands")
		if w != null and DisplayServer.get_name() != "headless":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		return false
	# (the world's own chain islands built first: they'd share the frames)
	if t < 3.0 or (isl == null and round_n == 0 and not w.chain_ready()):
		return false
	var now := Time.get_ticks_usec()
	if idle.size() < 90:
		if last_us > 0:
			idle.append(now - last_us)
		last_us = now
		if idle.size() == 90:
			idle.sort()
			print("PROBE idle frame median %.1f ms" % (idle[45] / 1000.0))
			last_us = 0
		return false
	if isl != null and si > 0 and last_us > 0:
		rows.append([steps[si - 1][0], step_us, now - last_us])
	if isl == null:
		var c = w.chain()
		var n: Dictionary = c.node(node_id if node_id >= 0 else int(c.start_next[0]))
		var t0 := Time.get_ticks_usec()
		load("res://scripts/island/island_theme.gd").meshes(str(n["theme"]))
		isl = load("res://scripts/island/gen_island.gd").new()
		isl.name = "ProbeIsle"
		isl.position = Vector3(n["pos"].x, 0.0, n["pos"].y) + Vector3(0, 0, 6000.0)
		isl.prepare(n.duplicate(true))
		print("PROBE round %d: %s prepared in %d ms (here on the main thread)" % [round_n, n["name"], (Time.get_ticks_usec() - t0) / 1000])
		w.add_child(isl)
		steps = isl.finish_steps()
		si = 0
		rows = []
		last_us = Time.get_ticks_usec()
		return false
	if si < steps.size():
		var t1 := Time.get_ticks_usec()
		last_us = t1
		isl.run_step(steps[si])
		step_us = Time.get_ticks_usec() - t1
		si += 1
		return false
	_report()
	isl.queue_free()
	isl = null
	round_n += 1
	if round_n >= 2:
		quit()
		return true
	return false


func _report() -> void:
	var tot_step := 0
	var tot_frame := 0
	var n := {}
	for r in rows:
		tot_step += int(r[1])
		tot_frame += int(r[2])
		n[r[0]] = int(n.get(r[0], 0)) + 1
		if int(r[1]) >= 4000 or int(r[2]) >= 20000:
			print("PROBE %d  %-22s #%-3d step %6.1f ms  frame %6.1f ms" % [round_n, r[0], n[r[0]], int(r[1]) / 1000.0, int(r[2]) / 1000.0])
	print("PROBE round %d: %d steps, steps %d ms, frames %d ms; slowest %s" % [round_n, rows.size(), tot_step / 1000, tot_frame / 1000, isl.slowest(12)])

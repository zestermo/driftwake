extends SceneTree
## The cape lab: the captain in a cape over a tunic runs one fixed script on physics ticks (idle, walk, run, a sharp
## 180 turn, a dead stop, a jump, the cutlass combo's spin, idle) for every cape mode x look (BodyBuilder.cape_mode,
## cape_thick) on the light stage, filmed at the PSX pixel grid. Each run goes twice (stills and metrics, then the
## frame sequences), so run it at a fixed frame rate: the runs then line up frame for frame and the jitter measured
## is the one a 144 Hz screen shows against 60 Hz physics:
##   & $env:GODOT --path . --fixed-fps 144 --script res://tools/dev/capelab.gd
## Args: [out_dir=res://tools/dev/out/capelab] [modes=a0,a,b,bg,c] [looks=thin,thick] ["stills": no sequences, no GIFs].
## Env CAPE_TRACE="t0,t1": each film run prints the hem per frame between those seconds (speed, jitter).
## Writes strip_<mode>_<look>.png (behind over back three-quarter at the key moments), sheet_<look>.png (every mode
## top to bottom, from behind at the run, the turn, the stop and the spin), seq/<mode>_<look>_<turn|stop>/f###.png
## and <turn|stop>_<look>.gif (the modes side by side in mode order, 4x slow), metrics.txt (also printed).
const TK := preload("res://tools/dev/test_kit.gd")
const CROP := Vector2i(190, 250)
const FPS_GIF := 36
# the script, in seconds from a run's start
const EVENTS := [[2.0, "walk"], [3.2, "run"], [4.4, "turn"], [5.3, "stop"], [7.3, "jump"], [8.6, "draw"],
	[9.3, "attack"], [9.75, "attack"], [10.35, "attack"], [12.5, "end"]]
const SEQ_END := 6.7
const MOMENTS := [["idle", 1.9], ["walk", 2.9], ["run", 4.2], ["turn1", 4.55], ["turn2", 4.8], ["stop1", 5.4], ["stop2", 5.8],
	["jump", 7.65], ["land", 8.2], ["spin1", 10.6], ["spin2", 10.85], ["end", 12.4]]
const SHEET := ["run", "turn1", "turn2", "stop1", "stop2", "spin1", "spin2"]
const SEQS := [["turn", 4.3, 5.5, "q3"], ["stop", 5.2, 6.6, "behind"]]
const MOVING := [2.0, 11.8]
const SETTLE := [5.3, 7.3]
const MARGIN := {"thigh_l": 0.03, "thigh_r": 0.03, "shin_l": 0.025, "shin_r": 0.025, "hips": 0.03}

var stage
var p
var out_dir := "res://tools/dev/out/capelab"
var modes: Array = ["a0", "a", "b", "bg", "c"]
var looks: Array = ["thin", "thick"]
var runs: Array = []
var seqs := true
var run := -1
var t0 := 0
var ft := 0.0
var ev := 0
var mo := 0
var cam: Camera3D
var want := {}
var shots := {}
var sheet_shots := {}
var seq_yaw := {}
var seq_n := {}
var deltas := PackedFloat32Array()
var report: Array = []
# the current run's cape
var sim: SpringChains
var cape_chains: Array = []
var poses: Array = []
var verts: Array = []
var binds: Dictionary = {}
var rec := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		modes = Array(args[1].split(","))
	if args.size() > 2:
		looks = Array(args[2].split(","))
	seqs = not (args.size() > 3 and args[3] == "stills")
	for lk in looks:
		for m in modes:
			runs.append([m, lk, "film"])
			if seqs:
				runs.append([m, lk, "seq"])
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})
	RenderingServer.frame_pre_draw.connect(_sample)
	RenderingServer.frame_post_draw.connect(_grab)


func _look() -> Dictionary:
	var lk: Dictionary = CharacterLook.default_look()
	lk["coat"] = "none"
	lk["belt"] = "belt"
	lk["cape"] = true
	lk["cape_color"] = Color(0.6, 0.12, 0.1)
	return lk


func _process(d: float) -> bool:
	if not stage.up:
		return false
	if run < 0:
		var st = root.get_node("Settings")
		st.set_value("video", "pixelate", true, false)
		st.set_value("video", "dither", true, false)
		p = stage.player
		p.health_component.max_health = 99999.0
		p.health_component.current_health = 99999.0
		var rig := Node3D.new()
		var arm := Node3D.new()
		cam = Camera3D.new()
		cam.fov = 50.0
		cam.far = 300.0
		cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		# (in a rig and an arm at yaw 0: the player's states read the move direction off the camera's grandparent)
		rig.add_child(arm)
		arm.add_child(cam)
		stage.add_child(rig)
		cam.current = true
		_next()
		return false
	deltas.append(d)
	ft += d
	var r: Array = runs[run]
	var t := (Engine.get_physics_frames() - t0) / float(Engine.physics_ticks_per_second)
	var cur := run
	while ev < EVENTS.size() and t >= float(EVENTS[ev][0]) and run == cur:
		ev += 1
		_event(str(EVENTS[ev - 1][1]))
	if run == cur and r[2] == "seq" and t >= SEQ_END:
		_event("end")
	if run >= runs.size():
		return true
	if run != cur:
		return false
	want = {}
	if r[2] == "seq":
		for s in SEQS:
			if t >= float(s[1]) and t < float(s[2]):
				if not seq_yaw.has(s[0]):
					seq_yaw[s[0]] = _facing_yaw()
					seq_n[s[0]] = 0
				want = {"kind": "seq", "name": s[0], "view": s[3]}
	elif mo < MOMENTS.size() and t >= float(MOMENTS[mo][1]):
		var have: Array = shots.get(MOMENTS[mo][0], [])
		want = {"kind": "moment", "name": MOMENTS[mo][0], "view": "behind" if have.is_empty() else "q3"}
		if have.size() >= 1:
			mo += 1
	_place(want.get("view", "behind"), seq_yaw.get(want.get("name", ""), INF) if want.get("kind", "") == "seq" else INF)
	return false


func _facing_yaw() -> float:
	var f: Vector3 = -p.player_model.get_global_transform_interpolated().basis.z
	return atan2(-f.x, -f.z)


func _place(view: String, fixed_yaw: float) -> void:
	var at: Vector3 = p.get_global_transform_interpolated().origin
	var yaw := fixed_yaw if fixed_yaw != INF else _facing_yaw()
	var back := Vector3(sin(yaw), 0, cos(yaw))
	var aim := at + Vector3(0, 0.95, 0)
	if view == "q3":
		cam.look_at_from_position(at + back.rotated(Vector3.UP, 0.87) * 4.0 + Vector3(0, 1.7, 0), aim, Vector3.UP)
	else:
		cam.look_at_from_position(at + back * 4.2 + Vector3(0, 1.9, 0), aim, Vector3.UP)


func _event(e: String) -> void:
	match e:
		"walk":
			TK.press("move_forward")
		"run":
			TK.press("sprint")
		"turn":
			TK.release("move_forward")
			TK.press("move_back")
		"stop":
			TK.release("move_back")
			TK.release("sprint")
		"jump":
			TK.act("jump")
		"draw":
			p.draw_weapon(true)
		"attack":
			TK.act("light_attack")
		"end":
			TK.release("move_forward")
			TK.release("move_back")
			TK.release("sprint")
			if runs[run][2] == "film":
				_finish()
			_next()


func _next() -> void:
	run += 1
	if run >= runs.size():
		_write_report()
		if seqs:
			_gifs()
		return
	var r: Array = runs[run]
	BodyBuilder.cape_mode = r[0]
	BodyBuilder.cape_thick = r[1] == "thick"
	p.sheathe_weapon(true)
	p.state_machine.force_state("Idle", {})
	p.global_position = Vector3(0, 3.05, 0)
	p.velocity = Vector3.ZERO
	p.player_model.rotation.y = 0.0
	p.body_model.apply_look(_look())
	p.reset_physics_interpolation()
	_find_cape()
	t0 = Engine.get_physics_frames()
	ft = 0.0
	ev = 0
	mo = 0
	shots = {}
	seq_yaw = {}
	seq_n = {}
	if r[2] == "seq":
		for s in SEQS:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/seq/%s_%s_%s" % [out_dir, r[0], r[1], s[0]]))
	rec = {"t": [], "hem": [], "pen_n": 0, "pen_frames": 0, "pen_worst": 0.0, "pen_at": 0.0, "swing": 0.0, "frames": 0}
	print("RUN %s %s %s" % r)


## The cape's chains, skeleton and (deduplicated) vertices with their skin weights.
func _find_cape() -> void:
	var torso: Node3D = p.body_model.torso
	var c = torso.get_node_or_null("Cape")
	sim = c if c != null else torso.get_node("SpringChains")
	var n := 3 if BodyBuilder.cape_thick else 1
	cape_chains = []
	var bones := {}
	for i in range(sim.chain_count() - n, sim.chain_count()):
		cape_chains.append(sim.chain(i))
		for b in sim.chain(i)["bones"]:
			bones[b] = true
	var sk := sim.skel
	poses = []
	for b in range(sk.get_bone_count()):
		poses.append(sk.get_bone_global_pose(b))
	sk.skeleton_updated.connect(_on_skel.bind(sk))
	var mi: MeshInstance3D = sk.get_node("Mesh")
	binds = {}
	for i in range(mi.skin.get_bind_count()):
		binds[i] = [mi.skin.get_bind_bone(i), mi.skin.get_bind_pose(i)]
	var seen := {}
	verts = []
	for s in range(mi.mesh.get_surface_count()):
		var arr := mi.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bb: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ww: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for i in range(v.size()):
			if not bones.has(int(binds[bb[i * 4]][0])):
				continue
			var key := "%.4f,%.4f,%.4f" % [v[i].x, v[i].y, v[i].z]
			if seen.has(key):
				continue
			seen[key] = true
			var bw := []
			for k in range(4):
				if ww[i * 4 + k] > 0.0:
					bw.append([bb[i * 4 + k], ww[i * 4 + k]])
			verts.append([v[i], bw])


func _on_skel(sk: Skeleton3D) -> void:
	if not is_instance_valid(sim) or sk != sim.skel:
		return
	for b in range(sk.get_bone_count()):
		poses[b] = sk.get_bone_global_pose(b)


## Every drawn frame of a film run: the hem in the torso's space, the swing, and cape vertices inside the body.
func _sample() -> void:
	if run < 0 or run >= runs.size() or runs[run][2] != "film" or not is_instance_valid(sim):
		return
	var c: Dictionary = cape_chains[0]
	var pts: PackedVector3Array = c["p"]
	var bones: PackedInt32Array = c["bones"]
	var last: int = bones[bones.size() - 1]
	var hem: Vector3 = (poses[last] as Transform3D) * (pts[pts.size() - 1] - pts[pts.size() - 2])
	var top: Vector3 = (poses[bones[0]] as Transform3D).origin
	(rec["t"] as Array).append(ft)
	(rec["hem"] as Array).append(hem)
	rec["swing"] = maxf(rec["swing"], (hem - top).angle_to(pts[pts.size() - 1] - pts[0]))
	rec["frames"] += 1
	var inv := sim.get_global_transform_interpolated().affine_inverse()
	var caps := []
	for key in MARGIN.keys():
		var cd: Dictionary = sim.colliders[key]
		var tt := inv * (cd["node"] as Node3D).get_global_transform_interpolated()
		caps.append([tt * (cd["a"] as Vector3), tt * (cd["b"] as Vector3), float(cd["r"]) - float(MARGIN[key])])
	# (the body's deepest back: the cape hangs 4 cm off it, over a tunic)
	var back := pts[0].z - 0.04
	var hits := 0
	for v in verts:
		var q := Vector3.ZERO
		for e in v[1]:
			var bd: Array = binds[e[0]]
			q += ((poses[bd[0]] as Transform3D) * (bd[1] as Transform3D) * (v[0] as Vector3)) * float(e[1])
		var depth := 0.0
		if absf(q.x) < 0.1 and q.y < pts[0].y - 0.02 and q.y > -0.1:
			depth = back - q.z
		for cap in caps:
			var a: Vector3 = cap[0]
			var ab: Vector3 = (cap[1] as Vector3) - a
			var k := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			depth = maxf(depth, float(cap[2]) - q.distance_to(a + ab * k))
		if depth > 0.0:
			hits += 1
			if depth > rec["pen_worst"]:
				rec["pen_worst"] = depth
				rec["pen_at"] = ft
	rec["pen_n"] += hits
	if hits > 0:
		rec["pen_frames"] += 1


func _grab() -> void:
	if want.is_empty() or run < 0 or run >= runs.size():
		return
	var w := want
	want = {}
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var grid: Vector2 = root.get_node("PSX").pixel_res()
	img.resize(int(grid.x), int(grid.y), Image.INTERPOLATE_NEAREST)
	var at: Vector2 = cam.unproject_position(p.get_global_transform_interpolated().origin + Vector3(0, 0.85, 0)) * (grid / root.get_visible_rect().size)
	var r := Rect2i(Vector2i(at) - CROP / 2, CROP)
	r.position = r.position.clamp(Vector2i.ZERO, Vector2i(grid) - CROP)
	var crop := img.get_region(r)
	var c: Array = runs[run]
	if w["kind"] == "seq":
		crop.save_png(ProjectSettings.globalize_path("%s/seq/%s_%s_%s/f%03d.png" % [out_dir, c[0], c[1], w["name"], seq_n[w["name"]]]))
		seq_n[w["name"]] += 1
		return
	if not shots.has(w["name"]):
		shots[w["name"]] = []
	(shots[w["name"]] as Array).append(crop)
	if w["view"] == "behind" and w["name"] in SHEET:
		sheet_shots["%s|%s|%s" % [c[1], c[0], w["name"]]] = crop


func _finish() -> void:
	var c: Array = runs[run]
	var strip := Image.create(MOMENTS.size() * (CROP.x + 2), 2 * (CROP.y + 2), false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.08, 0.08, 0.08))
	for i in range(MOMENTS.size()):
		var list: Array = shots.get(MOMENTS[i][0], [])
		for row in range(list.size()):
			strip.blit_rect(list[row], Rect2i(Vector2i.ZERO, CROP), Vector2i(i * (CROP.x + 2), row * (CROP.y + 2)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	strip.save_png(ProjectSettings.globalize_path("%s/strip_%s_%s.png" % [out_dir, c[0], c[1]]))
	report.append(_metrics(c))
	print("METRIC ", report[report.size() - 1])


func _metrics(c: Array) -> String:
	var ts := PackedFloat32Array(rec["t"])
	var hem := PackedVector3Array(rec["hem"])
	var jit := PackedFloat32Array()
	var settle := 0.0
	var worst_at := 0.0
	var worst := 0.0
	var trace := OS.get_environment("CAPE_TRACE").split(",")
	for i in range(1, hem.size() - 1):
		var j2 := (hem[i + 1] - hem[i] * 2.0 + hem[i - 1]).length() * 1000.0
		var sp := hem[i].distance_to(hem[i - 1]) / maxf(ts[i] - ts[i - 1], 1e-4)
		if ts[i] >= MOVING[0] and ts[i] < MOVING[1]:
			jit.append(j2)
			if j2 > worst:
				worst = j2
				worst_at = ts[i]
		# (over the last six frames: a one-frame twitch isn't a cape still swinging)
		if ts[i] >= SETTLE[0] and ts[i] < SETTLE[1] and i >= 6 and hem[i].distance_to(hem[i - 6]) / maxf(ts[i] - ts[i - 6], 1e-4) > 0.1:
			settle = ts[i] - SETTLE[0]
		if trace.size() == 2 and ts[i] >= float(trace[0]) and ts[i] <= float(trace[1]):
			print("TRACE %s %.4f hem %.3f %.3f %.3f speed %.2f jitter %.1f" % [c[0], ts[i], hem[i].x, hem[i].y, hem[i].z, sp, j2])
	jit.sort()
	var mean := 0.0
	for j in jit:
		mean += j
	mean /= maxf(jit.size(), 1)
	var p95 := jit[int(jit.size() * 0.95)] if jit.size() > 0 else 0.0
	var mx := jit[jit.size() - 1] if jit.size() > 0 else 0.0
	return "%-3s %-5s | pen %5d vert-frames in %4d/%d frames, worst %.3f m (%.2f s) | jitter mean %.2f p95 %.2f max %.1f mm (%.2f s) | settle %.2f s | swing max %3.0f deg | %.3f ms/frame" % [
		c[0], c[1], rec["pen_n"], rec["pen_frames"], rec["frames"], rec["pen_worst"], rec["pen_at"], mean, p95, mx, worst_at, settle, rad_to_deg(rec["swing"]), _cost()]


## The cape's cost per character per frame: its simulate() back to back at a 144 Hz frame's delta (Godot's spring
## bones: plus the skeleton's update with them on, less with them off).
func _cost() -> float:
	var n := 2000
	var own := _time_sim(n)
	if sim.motion == null or sim.motion.mode != "bg":
		return own
	var sk := sim.skel
	var gb: SkeletonModifier3D = sk.get_node("SpringBones")
	var t1 := Time.get_ticks_usec()
	for i in range(n):
		sk.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
	var on := Time.get_ticks_usec() - t1
	gb.active = false
	t1 = Time.get_ticks_usec()
	for i in range(n):
		sk.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)
	var off := Time.get_ticks_usec() - t1
	gb.active = true
	return own + (on - off) / float(n) / 1000.0


func _time_sim(n: int) -> float:
	var t1 := Time.get_ticks_usec()
	for i in range(n):
		sim.simulate(1.0 / 144.0)
	return (Time.get_ticks_usec() - t1) / float(n) / 1000.0


func _write_report() -> void:
	var lo := 1e9
	var hi := 0.0
	for d in deltas:
		lo = minf(lo, d)
		hi = maxf(hi, d)
	var timing := "fixed %.1f fps" % (1.0 / lo) if hi - lo < 1e-5 else "REAL TIME (frames %.1f-%.1f ms): rerun with --fixed-fps 144 for comparable numbers" % [lo * 1000.0, hi * 1000.0]
	var lines := ["cape lab %s, physics %d Hz, %s" % [Time.get_date_string_from_system(), Engine.physics_ticks_per_second, timing],
		"pen: cape vertices inside the body (the legs' and hips' capsules less their clearance; the back's plane across the middle)",
		"jitter: the hem's frame-to-frame second difference in the torso's space, walk to the spin's end; settle: until the hem stays under 0.1 m/s after the stop"]
	lines.append_array(report)
	var f := FileAccess.open(ProjectSettings.globalize_path(out_dir + "/metrics.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	for l in lines:
		print("METRIC ", l)
	for lk in looks:
		var sheet := Image.create(SHEET.size() * (CROP.x + 2), modes.size() * (CROP.y + 2), false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.08, 0.08, 0.08))
		for r in range(modes.size()):
			for i in range(SHEET.size()):
				var key := "%s|%s|%s" % [lk, modes[r], SHEET[i]]
				if sheet_shots.has(key):
					sheet.blit_rect(sheet_shots[key], Rect2i(Vector2i.ZERO, CROP), Vector2i(i * (CROP.x + 2), r * (CROP.y + 2)))
		sheet.save_png(ProjectSettings.globalize_path("%s/sheet_%s.png" % [out_dir, lk]))
	print("SAVED ", ProjectSettings.globalize_path(out_dir))


## The sequences as GIFs, the modes side by side (ffmpeg on PATH).
func _gifs() -> void:
	for lk in looks:
		for s in SEQS:
			var args := ["-y", "-loglevel", "error"]
			var pads := ""
			for i in range(modes.size()):
				args.append_array(["-framerate", str(FPS_GIF), "-i", ProjectSettings.globalize_path("%s/seq/%s_%s_%s/f%%03d.png" % [out_dir, modes[i], lk, s[0]])])
				pads += "[%d:v]" % i
			var stack := "%shstack=inputs=%d," % [pads, modes.size()] if modes.size() > 1 else ""
			args.append_array(["-filter_complex", stack + "scale=iw*2:ih*2:flags=neighbor,split[a][b];[a]palettegen[pl];[b][pl]paletteuse",
				ProjectSettings.globalize_path("%s/%s_%s.gif" % [out_dir, s[0], lk])])
			var o := []
			var code := OS.execute("ffmpeg", args, o, true)
			print("GIF %s_%s: %s" % [s[0], lk, "ok" if code == 0 else "ffmpeg failed (%d) %s" % [code, "".join(PackedStringArray(o))]])

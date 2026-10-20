extends SceneTree
## Brinehollow benchmark (v1.14; the route grown in v1.19). A real window, vsync off. Waits until the chain
## islands ahead are built and manned (plus `warm` seconds), then walks the captain
## through fixed stops, in ROUTE's order. The old eight (v1.14's, group "old"): the beach you wake on, the plaza,
## the market, the quay, the dock, the foot of Grell's den, the training yard, aboard the moored ship. The new ones
## (group "new"): Brinehollow's shrine terrace and the windmill hamlet, a fight at the smugglers' camp (its five
## grunts alerted, the captain kept alive), at sea under full sail on open water, the same in a storm, a chain
## island's village (the crew arrives there, freeing the other island ahead), then the royal capital's plaza and market street (reached the way Alt+F10 does, after the chain
## islands are put up again round it: `cwarm` s more). Groups: old, new, town (terrace farm village cplaza cmarket),
## atsea (sea storm), capital (cplaza cmarket), all (the default; `quick` alone runs old). At each
## stop the gameplay camera pans a full turn per phase:
##   base: frame mean/p95/worst, process/physics/render CPU/GPU ms, draws, shadow pass, nodes, physics;
##   probe: every script's _process/_physics_process timed (by script, by distance from the captain), rigs posed;
##   far: the frame again with every enemy, villager and enemy ship past FAR m disabled;
##   sun / lshadow / lights: the frame again with the sun's shadows, local shadows, local lights off.
## Each frame is split by timeline marks: physics scripts (the scene's physics pass), physics engine
## (Jolt's step and sync), process scripts (the scene's process pass), rest (tweens, transforms, the draw, present).
## Args (after --): label=<name> hour=13 wx=clear|cloudy|rain|storm pix=1|0 size=1920x1080
## warm=20 cwarm=10 seed=4242 stops=beach,dock|old|new|atsea,fight quick (base only) gate (base + probe: the summary and
## the scripts, no ablations; perf_gate.ps1) nosleep (ActorSleep off: far actors stay awake) crowd (Brinehollow's
## market crowd on: BrinehollowCast.CROWD, off as the game ships). Writes tools/dev/out/bench/brinehollow_<label>.txt
## (the summary has h33 / h50: base frames over 33 / 50 ms, and ALL_OLD / ALL_NEW rows when both groups ran) and a
## screenshot per stop (brinehollow_<label>_<stop>.png, after its base sample); bench.ps1 keeps the whole log beside them.
## Prints "bench: <stop> <phase>" as it goes, and a watchdog thread names the stop, phase and island build step if a frame stalls.
## Run it through tools/dev/bench.ps1 (a quiet machine); compare two with bench_compare.ps1.
const OLD := ["beach", "plaza", "market", "quay", "dock", "den", "yard", "aboard"]
const NEW := ["terrace", "farm", "fight", "sea", "storm", "village", "cplaza", "cmarket"]
## Stops where something happens instead of a pan (group "act"): walks through Brinehollow and the capital at a
## sprint, a brawl at the smugglers' camp, a broadside duel at sea that ends in a boarding and her sinking.
## isles: standing in Brinehollow's plaza while a chain island ahead is let go and built again (what a captain
## plays through when the log pose sets: the build's steps a frame each, the old island freed).
const ACT := ["bwalk", "brawl", "naval", "isles", "cwalk"]
## (the village late: standing on a chain island makes the crew arrive there, which frees the other one ahead)
const ROUTE := ["beach", "plaza", "market", "quay", "dock", "den", "yard", "aboard", "terrace", "farm", "bwalk", "fight",
	"brawl", "sea", "storm", "naval", "isles", "village", "cplaza", "cmarket", "cwalk"]
const GROUPS := {"old": OLD, "new": NEW, "act": ACT, "all": ROUTE, "town": ["terrace", "farm", "village", "cplaza", "cmarket"],
	"atsea": ["sea", "storm"], "capital": ["cplaza", "cmarket", "cwalk"], "walk": ["bwalk", "cwalk"], "fights": ["brawl", "naval"]}
## The isles stop ends this long after the island is standing again (at most ISLES_MAX s).
const ISLES_MAX := 45.0
const CAPITAL := ["cplaza", "cmarket", "cwalk"]
const ACT_DUR := {"brawl": 20.0, "naval": 26.0}
const WALK_V := 9.0
## The walks, in each island's frame: Brinehollow's (beach, plaza, market, up to the terrace, back down to the quay)
## and the capital's (city frame: along the quay, through the sea gate, up the market street, the plaza, the arena
## street and back, up the avenue).
const CWALK := [Vector2(60, 100), Vector2(0, 100), Vector2(0, 78), Vector2(0, 50), Vector2(0, 22), Vector2(0, 0),
	Vector2(40, 0), Vector2(0, 0), Vector2(0, -60)]
const HITCH_MS := 33.3
const WX := ["clear", "cloudy", "rain", "storm"]
const PHASES := ["settle", "base", "probe", "far", "sun", "lshadow", "lights", "base2"]
const DUR := {"settle": 4.0, "base": 5.0, "probe": 4.0, "far": 3.0, "sun": 3.0, "lshadow": 3.0, "lights": 3.0, "base2": 4.0}
const ABLATIONS := ["far", "sun", "lshadow", "lights"]
const LEAD := 0.5
const FAR := 120.0
const BANDS := [30.0, 60.0, 120.0, 250.0]
const BAND_NAMES := ["<30", "30-60", "60-120", "120-250", ">250"]
const PITCH := -0.25
const COLS := ["frame", "p95", "worst", "h33", "h50", "frame1t", "phys_scr", "phys_eng", "proc_scr", "tail", "draw", "present", "ticks", "tick_scr", "tick_eng",
	"rcpu", "gpu", "procmax", "physmax", "draws", "objects", "prims_k", "sh_draws", "sh_objects", "tot_draws", "tot_prims_k", "nodes", "active", "pairs"]
const SPLIT := ["frame", "frame1t", "tick_scr", "tick_eng", "proc_scr", "tail", "draw", "present", "rcpu", "gpu", "draws", "sh_draws"]
const TK := preload("res://tools/dev/test_kit.gd")

var args := {}
var label := "run"
var t := 0.0
var started := false
var done := false
var ready_at := -1.0
var p
var rig
var sun: DirectionalLight3D
var wx
var late: Node
var hold := 0.0
var stops: Array = []
var si := -1
var phases: Array = []
var ph_i := 0
var phase := ""
var t0 := 0.0
var ticks := 0
var rec := {}
var results := {}
var census_text := ""
var calib_ms := 0.0
var scene_asked := false
## Waiting for the capital to stand (the jump to it asked at travel_t; up and manned since cap_ready).
var traveling := false
var travel_t := 0.0
var cap_ready := -1.0
var sea_at := Vector3.INF
var sea_yaw := 0.0
## Results and screenshots (res://tools/dev/out/bench/, or out=<folder> for an exported build).
var out_dir := "res://tools/dev/out/bench/"
## An action stop: seconds since its base began, the walk's island and points (its frame), the enemy ship.
var act_t := 0.0
var walk_isl
var walk_pts: Array = []
var walk_len := 0.0
var es
var _beat := -1
var _cast_slot := -1
var _cast_until := 0.0
## The isles stop: when (act_t) the island stood again (-1 not yet).
var isles_done := -1.0
## Hitches (base frames over HITCH_MS): each with its split, pipelines compiled and Perf's marks.
var hitches: Array = []
var pipes_at := PackedInt64Array()
var nodes_at := 0
var base_pipes := 0
var last_us := 0
var real_ms := 0.0

var lights: Array = []
var toggled: Array = []
var frozen: Array = []

## (loaded once the autoloads exist: the scripts use them)
var humanoid_gd
var creature_gd

var mk := ""
var mk_t := 0
const STALL_S := 10.0
var watchdog: Thread
## The chain island step about to run this frame (named by the watchdog if the frame never ends).
var building := ""
var acc_phys_scr := 0.0
var acc_phys_eng := 0.0
var last_proc_scr := 0.0
var last_tail := 0.0
var last_draw := 0.0
var last_present := 0.0

var pe: Array = []
var us_p := PackedFloat64Array()
var us_f := PackedFloat64Array()
## Each node's longest single _process / _physics_process call in the probe (us): the spikes, not the mean.
var us_max := PackedFloat64Array()
var posed := PackedInt32Array()
var proc_order: Array = []
var phys_order: Array = []
var pr_frames := 0
var pr_ticks := 0
var pr_posed := 0
var pr_lights := 0
var pr_lights_sh := 0
var pr_counts := {}
var geo := {}
var phys_geo := {}


func _initialize():
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	label = args.get("label", "run")
	if args.has("out"):
		out_dir = (args["out"] as String).replace("\\", "/").trim_suffix("/") + "/"
	load("res://scripts/world/actor_sleep.gd").enabled = not args.has("nosleep")
	stops = _pick_stops(args.get("stops", "old" if args.has("quick") else "all"))
	TK.use_seed(self, int(args.get("seed", str(TK.DEFAULT_SEED))))
	RenderingServer.frame_pre_draw.connect(_mark.bind("pre_draw"))
	RenderingServer.frame_post_draw.connect(_mark.bind("post_draw"))
	watchdog = Thread.new()
	watchdog.start(_watch)
	# (the crowd's flag is a const: its script is recompiled once the autoloads are up, before the world loads)
	if not args.has("crowd"):
		scene_asked = true
		change_scene_to_file("res://scenes/world/world.tscn")


## Stop names and group names (GROUPS) to the stops, in ROUTE's order (the capital last: going there frees the
## chain islands round Brinehollow).
func _pick_stops(spec: String) -> Array:
	var want := {}
	# (PowerShell hands `stops=a,b` on as "a b")
	for s in spec.replace(" ", ",").split(",", false):
		for x in GROUPS.get(s, [s]):
			if not x in ROUTE:
				push_error("bench: no stop or group '%s' (stops: %s; groups: %s)" % [x, ", ".join(ROUTE), ", ".join(GROUPS.keys())])
				quit(1)
			want[x] = true
	return ROUTE.filter(func(x): return want.has(x))


func _crowd_on() -> void:
	var gs: GDScript = load("res://scripts/island/brinehollow_cast.gd")
	var off := "const CROWD := false"
	if gs.source_code.find(off) < 0:
		push_error("bench: crowd: '%s' isn't in brinehollow_cast.gd any more" % off)
		quit(1)
		return
	gs.source_code = gs.source_code.replace(off, "const CROWD := true")
	var err := gs.reload()
	if err != OK:
		push_error("bench: crowd: brinehollow_cast.gd didn't recompile (%s)" % error_string(err))
		quit(1)
		return
	print("bench: Brinehollow's market crowd on (BrinehollowCast.CROWD)")


## A stalled main thread (no timeline mark for STALL_S) is named: the stop, the phase and the last mark.
func _watch() -> void:
	var told := false
	while not done:
		OS.delay_msec(1000)
		var quiet := (Time.get_ticks_usec() - mk_t) / 1000000.0
		if quiet > STALL_S and not told:
			told = true
			print("bench: STALL main thread quiet %.0f s after mark '%s' (t %.1f s, stop %s, phase %s; islands: %s)" % [quiet, mk, t, stops[si] if si >= 0 and si < stops.size() else "-", phase, building])
		elif quiet < 1.0:
			told = false


func _process(d: float) -> bool:
	if done:
		return false
	_mark("proc")
	t += d
	# (frames in real time: d runs at Engine.time_scale, 0.05 in a hit-stop)
	var now := Time.get_ticks_usec()
	real_ms = (now - last_us) / 1000.0 if last_us > 0 else d * 1000.0
	last_us = now
	_frame_counts()
	if not scene_asked:
		scene_asked = true
		_crowd_on()
		change_scene_to_file("res://scenes/world/world.tscn")
		return false
	var w = root.get_node_or_null("World/Islands")
	if w != null and not w._finishing.is_empty():
		var e: Array = w._finishing[w._finishing.keys()[0]]
		building = "Isle%d step %d/%d '%s', %d preparing" % [w._finishing.keys()[0], e[2], e[1].size(), e[1][e[2]][0], w._pending.size()]
	else:
		building = "" if w == null else "nothing building, %d preparing" % w._pending.size()
	if w == null or t < 2.5:
		return false
	if not started:
		_setup()
		return false
	wx.set_world_time(hold)
	if si < 0:
		if not w.chain_ready():
			if t > 240.0:
				# (seen with a stale import cache: the islands' worker tasks never finish and quitting waits on them forever)
				push_error("bench: the chain islands never finished building (SCRIPT ERRORs above? the log is beside the results)")
				done = true
				quit(1)
			return false
		if ready_at < 0.0:
			ready_at = t
			print("bench: chain islands ready at %.1f s" % t)
		if t - ready_at < float(args.get("warm", "20")):
			return false
		census_text = _census()
		print(census_text)
		calib_ms = _calib()
		print("bench: calib %.2f ms" % calib_ms)
		_next_stop()
		return false
	if traveling:
		_travel(w)
		return false
	_step(d)
	return false


## Pipelines compiled and nodes made since the last frame; a frame over HITCH_MS once the route has begun is kept
## (any phase, the settle after a jump and the capital's travel too) with its split and what Perf was told about it.
func _frame_counts() -> void:
	var perf := root.get_node_or_null("Perf")
	if perf == null:
		return
	var pipes: PackedInt64Array = perf._pipe_counts()
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if pipes_at.size() != pipes.size():
		pipes_at = pipes
	var pd := PackedInt64Array()
	var sum := 0
	for i in range(pipes.size()):
		pd.append(pipes[i] - pipes_at[i])
		sum += pd[i]
	if phase == "base":
		base_pipes += sum
	if si >= 0 and phase != "" and real_ms > HITCH_MS:
		var what: Array = perf._marks_prev + perf._marks
		var line := "%-8s %-8s t %6.1f  %6.1f ms  phys_scr %5.1f  phys_eng %5.1f  ticks %d  proc_scr %5.1f  tail %5.1f  draw %5.1f  present %5.1f  pipes %s  nodes %+d%s" % [
			stops[si] if si < stops.size() else "-", phase, t, real_ms, acc_phys_scr, acc_phys_eng, ticks, last_proc_scr, last_tail, last_draw,
			last_present, "/".join(Array(pd).map(func(x): return str(x))), nodes - nodes_at,
			("  marks: " + "; ".join(what)) if not what.is_empty() else ""]
		hitches.append(line)
		print("bench: hitch " + line)
	pipes_at = pipes
	nodes_at = nodes


## Alt+F10's jump asked: wait for the capital (and whatever the log pose points on to) to be up and manned, then cwarm s.
func _travel(w) -> void:
	if t - travel_t > 240.0:
		push_error("bench: the capital never finished building (SCRIPT ERRORs above? the log is beside the results)")
		done = true
		quit(1)
		return
	if not (w.chain_islands.has(w.chain().capital_id()) and w.chain_ready()):
		return
	if cap_ready < 0.0:
		cap_ready = t
		print("bench: the capital and its neighbours ready at %.1f s (%.1f s after the jump)" % [t, t - travel_t])
	if t - cap_ready >= float(args.get("cwarm", "10")):
		traveling = false
		_go()


func _physics_process(delta: float) -> bool:
	_mark("phys")
	ticks += 1
	if phase == "probe" and not done:
		var count := t - t0 > LEAD
		_dispatch(true, delta, count)
		if count:
			pr_ticks += 1
	return false


func _setup() -> void:
	started = true
	humanoid_gd = load("res://scripts/npc/humanoid.gd")
	creature_gd = load("res://scripts/enemies/fauna/creature.gd")
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	var size := Vector2i(1920, 1080)
	if args.has("size"):
		var wh: PackedStringArray = (args["size"] as String).split("x")
		size = Vector2i(int(wh[0]), int(wh[1]))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(size)
	root.size = size
	var st = root.get_node("Settings")
	st.set_value("video", "pixelate", args.get("pix", "1") != "0", false)
	st.set_value("video", "perf_overlay", false, false)
	p = get_first_node_in_group("player")
	rig = root.get_node("World/CameraRig")
	# (as the loading screen does before the game is shown)
	root.get_node("FX").warm_up()
	sun = root.get_node("World/DirectionalLight3D")
	wx = root.get_node("Weather")
	hold = wx.time_at(float(args.get("hour", "13")), 1)
	wx.set_world_time(hold)
	wx.forced = WX.find(args.get("wx", "clear"))
	wx.forced_at = hold - 100.0
	var gs := GDScript.new()
	gs.source_code = "extends Node\nvar bench\nfunc _process(_d):\n\tbench._late()\nfunc _physics_process(_d):\n\tbench._mark(\"late_phys\")\n"
	gs.reload()
	late = Node.new()
	late.set_script(gs)
	late.set("bench", self)
	late.name = "BenchLate"
	late.process_priority = 1000000
	late.process_physics_priority = 1000000
	root.add_child(late)


## Timeline marks: the start of the scene's physics pass and process pass (this
## script, called first) and their ends (BenchLate, processed last).
func _mark(kind: String) -> void:
	var now := Time.get_ticks_usec()
	var dt := (now - mk_t) / 1000.0
	match kind:
		"phys", "proc":
			if mk == "late_phys":
				acc_phys_eng += dt
			elif mk == "late_proc":
				last_tail = dt
				last_draw = 0.0
				last_present = 0.0
			elif mk == "post_draw":
				last_present = dt
		"pre_draw":
			last_tail = dt
		"post_draw":
			last_draw = dt
		"late_phys":
			acc_phys_scr += dt
		"late_proc":
			last_proc_scr = dt
	mk = kind
	mk_t = now


func _spot(s: String) -> Vector3:
	var isl = root.get_node("World/Islands/Brinehollow")
	var h = isl.harbour
	var v: Vector2 = isl.VILLAGE
	var to_dock: Vector2 = (h.dock - v).normalized()
	match s:
		"beach":
			return isl.wake_spot()[0]
		"plaza":
			return _g(isl, v + to_dock * 10.0)
		"market":
			return _g(isl, isl.MARKET)
		"quay":
			return _g(isl, h.quay_pt(lerpf(h.s0, h.dock_s, 0.5), 6.0))
		"dock":
			var dp: Vector2 = h.dock_point(16.0)
			return isl.to_global(Vector3(dp.x, h.deck_y, dp.y))
		"den":
			return _g(isl, isl.den_plan["start"])
		"yard":
			return _g(isl, isl.TRAINING + Vector2(7, 3))
		"aboard":
			return get_first_node_in_group("ship").global_transform * Vector3(0, 0.6, 1.0)
		"terrace":
			return _g(isl, Vector2(isl.UP_X, 11.0))
		"farm":
			return _g(isl, isl.FARM + Vector2(4.5, -1.5))
		"village":
			var gi = _chain_isle()
			return _g(gi, gi.sites["village"] + Vector2(3, 3))
		"fight":
			# inland of the smugglers' fire, the five of them alerted
			for g in isl.smugglers.grunts:
				if is_instance_valid(g):
					g.alert(randf_range(0.1, 0.4))
			return _g(isl, isl.SMUGGLERS - Vector2(1, 0.15).normalized() * 6.0)
		"sea", "storm":
			# (the same water both times: the ship put back at the start, under full sail)
			if sea_at == Vector3.INF:
				_find_sea()
				# (the naval stop's enemy crew built ahead on a worker, as the fleet does)
				if "naval" in stops:
					humanoid_gd.prebuild(load("res://scripts/ship/enemy_ship.gd").crew_plan(7, "sloop").map(func(c): return c[0]))
			var ship = get_first_node_in_group("ship")
			ship.place(sea_at, sea_yaw)
			ship.set_anchored(false)
			ship.sail = 1.0
			# (the deck from where she's put: her transform reads back the old one until her next tick)
			return Transform3D(Basis(Vector3.UP, sea_yaw), Vector3(sea_at.x, ship.global_position.y, sea_at.z)) * Vector3(0, 0.6, 1.0)
		"cplaza", "cmarket":
			var ci = root.get_node("World/Islands").chain_islands[root.get_node("World/Islands").chain().capital_id()]
			var q: Vector2 = ci.from_city(Vector2(0, 9.5) if s == "cplaza" else Vector2(0, 46))
			return _g(ci, q)
		"bwalk":
			var to_v := func(g: Vector3) -> Vector2:
				var l: Vector3 = isl.to_local(g)
				return Vector2(l.x, l.z)
			_walk_on(isl, [to_v.call(isl.wake_spot()[0]), v + to_dock * 10.0, isl.MARKET, Vector2(isl.UP_X, 11.0),
				v + to_dock * 10.0, h.quay_pt(lerpf(h.s0, h.dock_s, 0.5), 6.0)])
			return _g(isl, walk_pts[0])
		"cwalk":
			var ci = root.get_node("World/Islands").chain_islands[root.get_node("World/Islands").chain().capital_id()]
			_walk_on(ci, CWALK.map(func(q): return ci.from_city(q)))
			return _g(ci, walk_pts[0])
		"brawl":
			_arm()
			for g in isl.smugglers.grunts:
				if is_instance_valid(g) and not g.is_dead():
					g.alert(randf_range(0.1, 0.4))
			return _g(isl, isl.SMUGGLERS - Vector2(1, 0.15).normalized() * 6.0)
		"isles":
			isles_done = -1.0
			return _g(isl, v + to_dock * 10.0)
		"naval":
			_arm()
			var deck := _spot("sea")
			es = load("res://scripts/ship/enemy_ship.gd").new().setup(sea_at, 90.0, 0.0, 7, "sloop")
			es.set_meta("no_sleep", true)
			root.get_node("World").add_child(es)
			return deck
	push_error("bench: no stop " + s)
	return Vector3.ZERO


func _walk_on(isl, pts: Array) -> void:
	walk_isl = isl
	walk_pts = pts
	walk_len = 0.0
	for i in range(1, pts.size()):
		walk_len += (pts[i] as Vector2).distance_to(pts[i - 1])


func _along(dist: float) -> Vector2:
	var left := dist
	for i in range(1, walk_pts.size()):
		var seg: float = (walk_pts[i] as Vector2).distance_to(walk_pts[i - 1])
		if left <= seg:
			return (walk_pts[i - 1] as Vector2).lerp(walk_pts[i], left / maxf(seg, 0.001))
		left -= seg
	return walk_pts[-1]


## A cutlass drawn, and the cutlass's technique and ultimate on their slots (no learning: the loadout is set).
func _arm() -> void:
	if p.current_state_name() != "Idle":
		p.state_machine.force_state("Idle", {})
	p.unequip_weapon()
	p.equip_weapon(load("res://resources/items/cutlass.tres"), false)
	p.sheathe_weapon(true)
	p.draw_weapon(true)
	p.power.loadout[0] = "swordfish"
	p.power.loadout[p.power.ULT] = "kraken_wake"


func _g(isl, q: Vector2) -> Vector3:
	return isl.to_global(Vector3(q.x, isl.hv(q), q.y))


## The first generated chain island standing (one the log pose points at from Brinehollow).
func _chain_isle():
	var w = root.get_node("World/Islands")
	var ids: Array = w.chain_islands.keys()
	ids.sort()
	for id in ids:
		if w.chain_islands[id].theme != "capital":
			return w.chain_islands[id]
	push_error("bench: no generated chain island standing")
	return null


## Open water clear of every island and Redtide, out from Brinehollow; the ship sails straight out from it.
func _find_sea() -> void:
	var w = root.get_node("World/Islands")
	var home: Vector2 = w.starter_center + Vector2(-20, 110)
	var rt := Vector2(w.redtide.position.x, w.redtide.position.z)
	for r: float in [750.0, 900.0, 1050.0]:
		for k in range(24):
			var a := (rt - home).angle() + PI + floori((k + 1) * 0.5) * (TAU / 24.0) * (1.0 if k % 2 == 0 else -1.0)
			var c := home + Vector2.from_angle(a) * r
			var out := Vector2.from_angle(a)
			if w._deep_enough(c, 150.0) and w._deep_enough(c + out * 400.0, 150.0) and c.distance_to(rt) > 450.0:
				sea_at = Vector3(c.x, 0.0, c.y)
				sea_yaw = atan2(-out.x, -out.y)
				print("bench: open sea at %s, %.0f m out, sailing %.0f deg" % [str(sea_at), r, rad_to_deg(sea_yaw)])
				return
	push_error("bench: no open sea round Brinehollow")


func _next_stop() -> void:
	si += 1
	if si >= stops.size():
		_finish()
		return
	_go()


func _go() -> void:
	var w = root.get_node("World/Islands")
	if stops[si] in CAPITAL and not (int(root.get_node("GameManager").chain_at) == w.chain().capital_id() and w.chain_islands.has(w.chain().capital_id())):
		traveling = true
		travel_t = t
		cap_ready = -1.0
		phase = "travel"
		print("bench: to the capital (Alt+F10's jump; t %.1f s)" % t)
		p.debug_to_capital()
		return
	wx.forced = WX.find("storm" if stops[si] == "storm" else args.get("wx", "clear"))
	wx.forced_at = hold - 100.0
	var at := _spot(stops[si])
	if p.current_state_name() != "Idle":
		p.state_machine.force_state("Idle", {})
	p.global_position = at + Vector3.UP * 0.3
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	rig.global_position = p.global_position + Vector3(0, 1.2, 0)
	phases = ["settle", "base"] if args.has("quick") else ["settle", "base", "probe"] if args.has("gate") or stops[si] in ACT else PHASES.duplicate()
	act_t = 0.0
	_beat = -1
	_cast_slot = -1
	ticks = 0
	acc_phys_scr = 0.0
	acc_phys_eng = 0.0
	results[stops[si]] = {"at": at, "enemies": _enemy_line(at)}
	print("bench: %s at %s" % [stops[si], str(at)])
	_begin(0)


func _begin(i: int) -> void:
	ph_i = i
	phase = phases[i]
	t0 = t
	rec = {}
	toggled = []
	print("bench: %s %s (t %.1f s)" % [stops[si], phase, t])
	base_pipes = 0
	if phase == "probe":
		_probe_begin()
	elif phase == "far":
		_freeze_far()


func _freeze_far() -> void:
	frozen = []
	var pos: Vector3 = p.global_position
	var actors: Array = get_nodes_in_group("enemies")
	for e in pe:
		if is_instance_valid(e[0]) and e[1] in ["npc.gd", "villager.gd", "enemy_ship.gd"]:
			actors.append(e[0])
	for n in actors:
		if is_instance_valid(n) and (n as Node3D).global_position.distance_to(pos) > FAR and n.process_mode != Node.PROCESS_MODE_DISABLED:
			frozen.append([n, n.process_mode])
			n.process_mode = Node.PROCESS_MODE_DISABLED


func _step(d: float) -> void:
	var e := t - t0
	var dur := _dur()
	rig.spring_arm.rotation.x = PITCH
	if stops[si] in ACT:
		_act(d)
	else:
		rig.rotation.y = TAU * clampf(e / dur, 0.0, 1.0)
	if stops[si] in ["fight", "brawl", "naval"]:
		var hc = p.health_component
		if hc.current_health < hc.max_health:
			hc.current_health = hc.max_health
	if phase == "probe":
		var count := e > LEAD
		_dispatch(false, d, count)
		if count:
			pr_frames += 1
			_count_lights()
	elif phase != "settle" and e > (0.0 if phase == "base" else LEAD):
		_sample(d)
	ticks = 0
	acc_phys_scr = 0.0
	acc_phys_eng = 0.0
	if e < dur:
		return
	var r: Dictionary = results[stops[si]]
	match phase:
		"base":
			r["base"] = _summarise()
			r["frames"] = rec["frame"].duplicate()
			r["pipes"] = base_pipes
			base_pipes = 0
			# (after the sample: its save was ~65 ms in the base's first frame; the next phase's LEAD or settle skips it)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
			root.get_node("Perf").mark("bench: the stop's screenshot")
			root.get_texture().get_image().save_png(out_dir + "brinehollow_%s_%s.png" % [label, stops[si]])
		"base2":
			r["base2"] = _summarise()
		"probe":
			r["probe"] = _probe_end()
		"far":
			r[phase] = _summarise()
			r["frozen"] = frozen.size()
			for f in frozen:
				if is_instance_valid(f[0]):
					f[0].process_mode = f[1]
			frozen = []
		"sun", "lshadow", "lights":
			r[phase] = _summarise()
			_untoggle()
	if ph_i + 1 < phases.size():
		_begin(ph_i + 1)
	else:
		_next_stop()


func _dur() -> float:
	var s: String = stops[si]
	if not s in ACT:
		return DUR[phase]
	if phase == "settle":
		return 3.0
	if phase == "probe":
		return DUR["probe"]
	if s == "isles":
		return minf(isles_done + 1.0, ISLES_MAX) if isles_done >= 0.0 else ISLES_MAX
	return walk_len / WALK_V if s in ["bwalk", "cwalk"] else ACT_DUR[s]


## An action stop's frame: from its base on (through the probe after it), the walk or the fight goes on.
func _act(d: float) -> void:
	var s: String = stops[si]
	if phase == "settle":
		if s == "naval":
			_beside()
		return
	var was := act_t
	act_t += d
	match s:
		"bwalk", "cwalk":
			var dist := minf(act_t * WALK_V, walk_len)
			var q := _along(dist)
			var at := _g(walk_isl, q)
			p.global_position = at + Vector3.UP * 0.1
			p.velocity = Vector3.ZERO
			var dir := _g(walk_isl, _along(minf(dist + 4.0, walk_len + 4.0))) - at
			if dist >= walk_len:
				return
			dir.y = 0.0
			if dir.length() > 0.1:
				var yaw := atan2(-dir.x, -dir.z)
				rig.rotation.y = lerp_angle(rig.rotation.y, yaw, clampf(5.0 * d, 0.0, 1.0))
				p.player_model.global_rotation.y = yaw
		"brawl":
			_fight(root.get_node("World/Islands/Brinehollow").smugglers.grunts, was, d)
		"naval":
			_naval(was, d)
		"isles":
			var w = root.get_node("World/Islands")
			if was == 0.0:
				var id: int = w.chain_islands.keys().filter(func(k): return w.chain_islands[k].theme != "capital")[0]
				print("bench: isles: %s let go at %.1f s" % [w.chain_islands[id].name, act_t])
				w._free_chain_island(id)
				w.sync_chain_islands()
			elif isles_done < 0.0 and act_t > 1.0 and w.chain_ready():
				isles_done = act_t
				print("bench: isles: standing again at %.1f s" % act_t)


## Hold the enemy ship alongside to starboard, 34 m off (the settle: her own steering takes over at the base).
func _beside() -> void:
	var ship = get_first_node_in_group("ship")
	var right: Vector3 = ship.global_basis.x
	es._pos = ship.global_position + right * 34.0
	es._heading = ship.global_rotation.y
	es.speed = ship.speed
	es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), es._pos + Vector3(0, 1.45, 0))


func _crossed(was: float, at: float) -> bool:
	return was < at and act_t >= at


## The captain fights the nearest of `targets`: closes in, a click every 0.2 s within reach, the cutlass's technique
## at 3 and 13 s, a heavy at 7 and 16, the ultimate at 10.
func _fight(targets: Array, was: float, d: float) -> void:
	p.stamina = p.max_stamina
	var pc = p.power
	pc.energy = pc.max_energy()
	var tgt: Node3D = null
	var best := INF
	for g in targets:
		if is_instance_valid(g) and g.is_inside_tree() and not g.is_dead():
			var dd: float = (g as Node3D).global_position.distance_to(p.global_position)
			if dd < best:
				best = dd
				tgt = g
	if tgt == null:
		return
	var to: Vector3 = tgt.global_position - p.global_position
	to.y = 0.0
	var dist := to.length()
	var yaw := atan2(-to.x, -to.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, yaw, clampf(4.0 * d, 0.0, 1.0))
	if p.current_state_name() in ["Idle", "Move"]:
		p.player_model.global_rotation.y = yaw
		if dist > 1.8:
			p.global_position += to.normalized() * minf(6.0 * d, dist - 1.6)
	var beat := int(act_t / 0.2)
	if beat != _beat:
		_beat = beat
		if dist < 3.0:
			p.input_buffer.buffer_action("light_attack")
	for b in [[3.0, "tech"], [7.0, "heavy"], [10.0, "ult"], [13.0, "tech"], [16.0, "heavy"]]:
		if _crossed(was, b[0]):
			if b[1] == "heavy":
				p.state_machine.force_state("HeavyAttack", {})
			else:
				_cast_slot = 0 if b[1] == "tech" else pc.ULT
				_cast_until = act_t + 1.5
	# (a cast waits for the captain to be free of a hit or a stagger, up to 1.5 s)
	if _cast_slot >= 0:
		pc.cooldowns.clear()
		pc.ult = pc.ULT_MAX if _cast_slot == pc.ULT else pc.ult
		var why: String = pc.can_cast(_cast_slot)
		if why == "" or act_t > _cast_until:
			print("bench: %s %s at %.1f s: %s %s" % [stops[si], "ultimate" if _cast_slot == pc.ULT else "technique", act_t,
				pc.try_cast(_cast_slot), "" if why == "" else "(%s in %s)" % [why, p.current_state_name()]])
			_cast_slot = -1


## The duel: her broadsides at us (her own AI), ours at her every 4 s; at 12 s she boards and the captain fights her
## men on deck; at 20 s she goes down.
func _naval(was: float, d: float) -> void:
	var ship = get_first_node_in_group("ship")
	ship.sail = 1.0
	if was == 0.0 and is_instance_valid(es):
		es._set_state(es.S.BROADSIDE)
		es._volley_cd = 0.5
	if not is_instance_valid(es):
		return
	var to: Vector3 = es.global_position - ship.global_position
	if act_t < 12.0:
		var yaw := atan2(-to.x, -to.z)
		rig.rotation.y = lerp_angle(rig.rotation.y, yaw, clampf(3.0 * d, 0.0, 1.0))
	for k in range(3):
		if _crossed(was, 1.0 + 4.0 * k):
			var side := 1.0 if ship.global_basis.x.dot(to) > 0.0 else -1.0
			print("bench: naval broadside at %.1f s: %d guns" % [act_t, ship.broadside(side, es.global_position, p)])
	if _crossed(was, 12.0) and not es.is_dead():
		es._board(ship)
		print("bench: naval boarders at %.1f s: %d" % [act_t, es.boarders.size()])
	if act_t >= 12.0:
		_fight(es.boarders, was, d)
	if _crossed(was, 20.0) and not es.is_dead():
		es._start_sink()


## (the last node processed each frame: overrides Weather's sun and NightLight's own toggles)
func _late() -> void:
	_mark("late_proc")
	match phase:
		"sun":
			sun.shadow_enabled = false
		"lshadow":
			for l in lights:
				if is_instance_valid(l) and l.shadow_enabled:
					l.shadow_enabled = false
					toggled.append(l)
		"lights":
			for l in lights:
				if is_instance_valid(l) and l.visible:
					l.visible = false
					toggled.append(l)


func _untoggle() -> void:
	for l in toggled:
		if is_instance_valid(l):
			if phase == "lshadow":
				l.shadow_enabled = true
			else:
				l.visible = true
	toggled = []


func _rec(k: String, v: float) -> void:
	if not rec.has(k):
		rec[k] = PackedFloat32Array()
	rec[k].append(v)


func _sample(d: float) -> void:
	var vp := root.get_viewport_rid()
	_rec("frame", real_ms)
	_rec("phys_scr", acc_phys_scr)
	_rec("phys_eng", acc_phys_eng)
	_rec("proc_scr", last_proc_scr)
	_rec("tail", last_tail)
	_rec("draw", last_draw)
	_rec("present", last_present)
	_rec("procmax", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_rec("physmax", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_rec("tot_draws", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_rec("tot_prims_k", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0)
	_rec("ticks", ticks)
	_rec("rcpu", RenderingServer.viewport_get_measured_render_time_cpu(vp))
	_rec("gpu", RenderingServer.viewport_get_measured_render_time_gpu(vp))
	_rec("draws", RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	_rec("objects", RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME))
	_rec("prims_k", RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) / 1000.0)
	_rec("sh_draws", RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	_rec("sh_objects", RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME))
	_rec("nodes", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_rec("active", Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	_rec("pairs", Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))


func _mean(a: PackedFloat32Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1.0)


func _pct(a: PackedFloat32Array, q: float) -> float:
	var s := a.duplicate()
	s.sort()
	return s[mini(int(s.size() * q), s.size() - 1)]


func _over(a: PackedFloat32Array, ms: float) -> int:
	var n := 0
	for v in a:
		if v > ms:
			n += 1
	return n


func _summarise() -> Dictionary:
	var out := {}
	for k in rec:
		out[k] = _mean(rec[k])
	out["p95"] = _pct(rec["frame"], 0.95)
	out["worst"] = _pct(rec["frame"], 1.0)
	out["n"] = rec["frame"].size()
	out["h33"] = _over(rec["frame"], 33.3)
	out["h50"] = _over(rec["frame"], 50.0)
	out["tick_scr"] = out["phys_scr"] / maxf(out["ticks"], 0.01)
	out["tick_eng"] = out["phys_eng"] / maxf(out["ticks"], 0.01)
	out["frame1t"] = out["proc_scr"] + out["tail"] + out["draw"] + out["present"] + out["tick_scr"] + out["tick_eng"]
	return out


## base and base2 (before and after the ablations) averaged: drift during a stop cancels out.
func _base_of(r: Dictionary) -> Dictionary:
	var out := {}
	for k in r["base"]:
		out[k] = (float(r["base"][k]) + float(r["base2"][k])) * 0.5
	return out


# --------------------------------------------------------------------------
# Script timing: every processing script's node stops being processed by the engine
# and is called here instead, in the engine's order (priority, then tree order).
# --------------------------------------------------------------------------
func _probe_begin() -> void:
	pe = []
	lights = []
	geo = {}
	phys_geo = {}
	pr_counts = {"static": 0, "character": 0, "rigid": 0, "area": 0, "area_monitoring": 0, "shapes": 0, "lights": 0, "humanoids": 0}
	var all := root.find_children("*", "", true, false)
	var pos: Vector3 = p.global_position
	for i in range(all.size()):
		var n: Node = all[i]
		if n is StaticBody3D:
			pr_counts["static"] += 1
		elif n is CharacterBody3D:
			pr_counts["character"] += 1
		elif n is RigidBody3D:
			pr_counts["rigid"] += 1
		elif n is Area3D:
			pr_counts["area"] += 1
			if (n as Area3D).monitoring:
				pr_counts["area_monitoring"] += 1
				_count_phys(n, 2)
			else:
				_count_phys(n, 1)
		elif n is CollisionShape3D:
			pr_counts["shapes"] += 1
			_count_phys(n.get_parent(), 0)
		elif n is OmniLight3D or n is SpotLight3D:
			lights.append(n)
		elif is_instance_of(n, humanoid_gd):
			pr_counts["humanoids"] += 1
		elif n is GeometryInstance3D and (n as GeometryInstance3D).is_visible_in_tree():
			_count_geometry(n, pos)
		if n == late or n.get_script() == null or not n.can_process():
			continue
		var wp: bool = n.is_processing() and n.has_method("_process")
		var wf: bool = n.is_physics_processing() and n.has_method("_physics_process")
		if not (wp or wf):
			continue
		pe.append([n, _key(n), _band(n, pos), wp, wf, n.process_priority, n.process_physics_priority, i, is_instance_of(n, humanoid_gd), is_instance_of(n, creature_gd)])
	pr_counts["lights"] = lights.size()
	us_p = PackedFloat64Array()
	us_f = PackedFloat64Array()
	posed = PackedInt32Array()
	us_max = PackedFloat64Array()
	us_p.resize(pe.size())
	us_f.resize(pe.size())
	us_max.resize(pe.size())
	posed.resize(pe.size())
	proc_order = []
	phys_order = []
	for j in range(pe.size()):
		if pe[j][3]:
			proc_order.append(j)
		if pe[j][4]:
			phys_order.append(j)
	proc_order.sort_custom(func(a, b): return pe[a][5] < pe[b][5] or (pe[a][5] == pe[b][5] and pe[a][7] < pe[b][7]))
	phys_order.sort_custom(func(a, b): return pe[a][6] < pe[b][6] or (pe[a][6] == pe[b][6] and pe[a][7] < pe[b][7]))
	_sweep()
	pr_frames = 0
	pr_ticks = 0
	pr_posed = 0
	pr_lights = 0
	pr_lights_sh = 0


## Visible geometry by the piece it belongs to (the island's child, digits dropped):
## [nodes, surfaces, surfaces within 60 m, within 150 m, surfaces with no visibility range, shadow-casting surfaces].
func _count_geometry(g: GeometryInstance3D, pos: Vector3) -> void:
	var a: Node = g
	while a.get_parent() != null and a.get_parent().get_parent() != null and a.get_parent().get_parent().name != "Islands" and a.get_parent().name != "World":
		a = a.get_parent()
	var key := str(a.name).rstrip("0123456789_@")
	if a.get_parent() != null and a.get_parent().get_parent() != null and a.get_parent().get_parent().name == "Islands":
		key = "%s/%s" % [a.get_parent().name, key]
	var surf := 1
	if g is MeshInstance3D:
		var m: Mesh = (g as MeshInstance3D).mesh
		surf = m.get_surface_count() if m else 0
	var d := g.global_position.distance_to(pos)
	if not geo.has(key):
		geo[key] = [0, 0, 0, 0, 0, 0]
	var e: Array = geo[key]
	e[0] += 1
	e[1] += surf
	if d < 60.0:
		e[2] += surf
	if d < 150.0:
		e[3] += surf
	if g.visibility_range_end <= 0.0:
		e[4] += surf
	if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		e[5] += surf


## Collision by what owns it (the body's script, else its class and name, digits dropped):
## [shapes, areas not monitoring, areas monitoring].
func _count_phys(owner: Node, slot: int) -> void:
	var key := owner.get_class()
	if owner.get_script() != null:
		key = owner.get_script().resource_path.get_file()
	else:
		var host := owner.get_parent()
		var hk := ""
		if host != null and host.get_script() != null:
			hk = " in " + host.get_script().resource_path.get_file()
		key = "%s %s%s" % [owner.get_class(), str(owner.name).rstrip("0123456789_@"), hk]
	if not phys_geo.has(key):
		phys_geo[key] = [0, 0, 0]
	phys_geo[key][slot] += 1


## Creatures asleep in their distance LOD aren't processed (FaunaSpawner wakes them).
func _awake(n) -> bool:
	return n.lod <= creature_gd.LOD_LOW or n.state in [creature_gd.S.DEAD, creature_gd.S.DOWN]


func _dispatch(phys: bool, delta: float, count: bool) -> void:
	for idx in (phys_order if phys else proc_order):
		var e: Array = pe[idx]
		var n = e[0]
		if not is_instance_valid(n) or not n.is_inside_tree() or not n.can_process():
			continue
		if e[9] and not _awake(n):
			continue
		var pf := -1
		if e[8] and not phys:
			pf = n.pose_frame
		var us := Time.get_ticks_usec()
		if phys:
			n._physics_process(delta)
		else:
			n._process(delta)
		var dt := Time.get_ticks_usec() - us
		if count:
			us_max[idx] = maxf(us_max[idx], dt)
			if phys:
				us_f[idx] += dt
			else:
				us_p[idx] += dt
				if e[8] and n.pose_frame != pf:
					posed[idx] += 1
					pr_posed += 1
	_sweep()


## Anything a script switched back on (a creature waking, a LOD) is taken over again.
func _sweep() -> void:
	for e in pe:
		var n = e[0]
		if not is_instance_valid(n):
			continue
		if n.is_processing():
			n.set_process(false)
		if n.is_physics_processing():
			n.set_physics_process(false)


func _count_lights() -> void:
	var cam := root.get_viewport().get_camera_3d()
	var planes := cam.get_frustum()
	var cp := cam.global_position
	for l in lights:
		if not is_instance_valid(l) or not l.is_visible_in_tree():
			continue
		var c: Vector3 = l.global_position
		var r: float = l.omni_range if l is OmniLight3D else l.spot_range
		if l.distance_fade_enabled and cp.distance_to(c) > l.distance_fade_begin + l.distance_fade_length:
			continue
		var inside := true
		for pl in planes:
			if pl.distance_to(c) > r:
				inside = false
				break
		if inside:
			pr_lights += 1
			if l.shadow_enabled:
				pr_lights_sh += 1


func _probe_end() -> Dictionary:
	var mine := {}
	for e in pe:
		if is_instance_valid(e[0]):
			mine[e[0]] = true
	var untimed := 0
	for n in root.find_children("*", "", true, false):
		if n.get_script() != null and n != late and not mine.has(n) and n.can_process() and ((n.is_processing() and n.has_method("_process")) or (n.is_physics_processing() and n.has_method("_physics_process"))):
			untimed += 1
	for e in pe:
		var n = e[0]
		if not is_instance_valid(n):
			continue
		if e[9]:
			var on := _awake(n)
			n.set_process(on)
			n.set_physics_process(on)
		else:
			n.set_process(e[3])
			n.set_physics_process(e[4])
	var fr := maxf(pr_frames, 1.0)
	var tk := maxf(pr_ticks, 1.0)
	var by := {}
	for j in range(pe.size()):
		var k: String = pe[j][1]
		if not by.has(k):
			by[k] = {"nodes": 0, "proc": 0.0, "phys": 0.0, "posed": 0.0, "bands": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "band_nodes": [0, 0, 0, 0, 0, 0]}
		var b: Dictionary = by[k]
		var pm := us_p[j] / 1000.0 / fr
		var fm := us_f[j] / 1000.0 / tk
		b["nodes"] += 1
		b["max"] = maxf(float(b.get("max", 0.0)), us_max[j] / 1000.0)
		b["proc"] += pm
		b["phys"] += fm
		b["posed"] += posed[j] / fr
		b["bands"][pe[j][2] + 1] += pm + fm
		b["band_nodes"][pe[j][2] + 1] += 1
	return {"scripts": by, "frames": pr_frames, "ticks_per_frame": pr_ticks / fr, "posed": pr_posed / fr,
		"lights": pr_lights / fr, "lights_shadowed": pr_lights_sh / fr, "counts": pr_counts.duplicate(), "entries": pe.size(), "untimed": untimed,
		"geo": geo.duplicate(), "phys": phys_geo.duplicate()}


func _key(n: Node) -> String:
	var k: String = n.get_script().resource_path.get_file()
	if k == "":
		k = "(built-in)"
	if k == "humanoid.gd":
		var a := n.get_parent()
		while a != null and (a.get_script() == null or a.get_script().resource_path.get_file() == "humanoid.gd"):
			a = a.get_parent()
		k = "humanoid.gd<-%s" % (a.get_script().resource_path.get_file() if a else "?")
	return k


## -1 not in 3D, else the BANDS index of its distance from `pos`.
func _band(n: Node, pos: Vector3) -> int:
	if not n is Node3D:
		return -1
	var dd: float = (n as Node3D).global_position.distance_to(pos)
	for i in range(BANDS.size()):
		if dd < BANDS[i]:
			return i
	return BANDS.size()


# --------------------------------------------------------------------------
# Who's in the world
# --------------------------------------------------------------------------
func _place_of(n: Node) -> String:
	var a := n
	while a != null and a.get_parent() != null:
		var par := a.get_parent()
		if par.name == "Islands" or par.name == "World":
			return str(a.name)
		a = par
	return "?"


## A fixed script workload (ms, the best of 5): how fast this machine runs GDScript right now (power plan,
## heat), so perf_gate.ps1 can tell a slower machine from slower code.
func _calib() -> float:
	var best := INF
	for r in range(5):
		var t0 := Time.get_ticks_usec()
		var acc := 0.0
		var d := {}
		for i in range(200000):
			acc += sin(i * 0.001) * 1.0001
			d[i & 1023] = acc
		best = minf(best, (Time.get_ticks_usec() - t0) / 1000.0)
	return best


func _census() -> String:
	var pos: Vector3 = p.global_position
	var groups := {}
	for e in get_nodes_in_group("enemies"):
		var k := "%s @ %s" % [e.get_script().resource_path.get_file(), _place_of(e)]
		if not groups.has(k):
			groups[k] = [0, 0, 0, INF, 0.0]
		var g: Array = groups[k]
		var dd: float = (e as Node3D).global_position.distance_to(pos)
		g[0] += 1
		if e.is_physics_processing() and e.can_process():
			g[1] += 1
		var h = e.get("humanoid")
		if h != null and h.is_processing():
			g[2] += 1
		g[3] = minf(g[3], dd)
		g[4] = maxf(g[4], dd)
	var s := "== census (enemies group, from the beach where you wake, after the chain islands are ready + %s s)\n" % args.get("warm", "20")
	s += "%-44s %5s %8s %8s %8s %8s\n" % ["script @ place", "count", "phys_on", "rig_on", "near_m", "far_m"]
	var keys := groups.keys()
	keys.sort()
	var tot := 0
	for k in keys:
		var g: Array = groups[k]
		tot += g[0]
		s += "%-44s %5d %8d %8d %8.0f %8.0f\n" % [k, g[0], g[1], g[2], g[3], g[4]]
	s += "total enemies %d\n" % tot
	var isl := root.get_node("World/Islands")
	for c in isl.get_children():
		if c is Node3D:
			s += "  island %s at %.0f m\n" % [c.name, (c as Node3D).global_position.distance_to(pos)]
	return s


func _enemy_line(at: Vector3) -> String:
	var n := 0
	var near := 0
	var on := 0
	for e in get_nodes_in_group("enemies"):
		n += 1
		if (e as Node3D).global_position.distance_to(at) < 60.0:
			near += 1
		if e.is_physics_processing() and e.can_process():
			on += 1
	return "enemies %d, within 60 m %d, physics on %d" % [n, near, on]


# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------
func _finish() -> void:
	done = true
	phase = ""
	var L: Array = []
	L.append("Driftwake Brinehollow bench  label %s  %s" % [label, Time.get_datetime_string_from_system()])
	L.append("version %s  Godot %s  driver %s  %s  CPU %s (%d threads)" % [str(ProjectSettings.get_setting("application/config/version", "")),
		Engine.get_version_info()["string"], RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name(),
		OS.get_processor_name(), OS.get_processor_count()])
	L.append("window %s  3D scale %.3f  pixelate %s  hour %s  weather %s  vsync off  physics %d Hz  calib %.2f ms  crowd %s  sleep %s  build %s" % [str(root.size), root.scaling_3d_scale,
		args.get("pix", "1"), args.get("hour", "13"), args.get("wx", "clear"), Engine.physics_ticks_per_second, calib_ms, "on" if args.has("crowd") else "off",
		"off" if args.has("nosleep") else "on", ("export" if OS.has_feature("template") else "editor") + (" debug" if OS.is_debug_build() else " release")])
	L.append("")
	L.append(census_text)
	L.append("== summary")
	var hdr := "%-8s" % "stop"
	for c in COLS:
		hdr += " %8s" % c
	L.append(hdr)
	for s in stops:
		L.append(_row(s, results[s]["base"]))
	L.append(_row("ALL", _total(stops)))
	for g in [["ALL_OLD", OLD], ["ALL_NEW", NEW], ["ALL_ACT", ACT]]:
		var some := stops.filter(func(s): return s in g[1])
		if some.size() > 0 and some.size() < stops.size():
			L.append(_row(g[0], _total(some)))
	L.append("")
	L.append("(ms; frame/p95/worst = frame time, h33/h50 = base frames over 33 / 50 ms (a count; ALL: the sum), split into phys_scr")
	L.append(" (the scene's physics pass, all ticks: scripts, move_and_slide), ALL_OLD = v1.14's eight stops, ALL_NEW the rest;")
	L.append(" phys_eng (Jolt's step + sync, all ticks), proc_scr (the scene's process pass), tail (timers, tweens, transform")
	L.append(" notifications, deferred calls, until the draw), draw (RenderingServer.draw on the main thread), present (after it);")
	L.append(" frame1t = the frame with exactly one physics tick; tick_scr / tick_eng = phys_scr / phys_eng per tick;")
	L.append(" ticks = physics ticks per frame; rcpu/gpu = the viewport's measured render CPU/GPU; procmax/physmax = Godot's")
	L.append(" TIME_PROCESS / TIME_PHYSICS_PROCESS (the F8 overlay's numbers: the worst in the last second, process including the draw);")
	L.append(" draws/objects/prims_k = the visible pass, sh_* the shadow pass, tot_* both (the F8 overlay's DRAWS / PRIMS))")
	for s in stops:
		L.append("  %-8s %s; pipelines compiled in base %d" % [s, results[s]["enemies"], results[s]["pipes"]])
	L.append("")
	L.append("== hitches (frames over %.0f ms in any phase once the route began: the split of that frame, pipelines compiled" % HITCH_MS)
	L.append("  canvas/mesh/surface/draw/specialization, nodes made, Perf's marks; settle = just after the jump to the stop)")
	L.append_array(hitches if not hitches.is_empty() else ["  (none)"])
	if not args.has("quick"):
		if not args.has("gate"):
			_report_ablations(L)
		_report_scripts(L)
	var text := "\n".join(L) + "\n"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var path := out_dir + "brinehollow_%s.txt" % label
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print(text)
	print("bench: wrote " + ProjectSettings.globalize_path(path))
	watchdog.wait_to_finish()
	quit()


## Stops' base summaries as one: the mean of the stops, but frame / p95 / worst over all their frames and hitches summed.
func _total(list: Array) -> Dictionary:
	var tot := {}
	var frames := PackedFloat32Array()
	for s in list:
		var b: Dictionary = results[s]["base"]
		frames.append_array(results[s]["frames"])
		for c in COLS:
			tot[c] = float(tot.get(c, 0.0)) + float(b.get(c, 0.0)) / list.size()
	tot["frame"] = _mean(frames)
	tot["p95"] = _pct(frames, 0.95)
	tot["worst"] = _pct(frames, 1.0)
	tot["h33"] = _over(frames, 33.3)
	tot["h50"] = _over(frames, 50.0)
	return tot


func _row(name: String, b: Dictionary) -> String:
	var s := "%-8s" % name
	for c in COLS:
		var v := float(b.get(c, 0.0))
		s += (" %8.0f" % v) if c in ["h33", "h50", "draws", "objects", "sh_draws", "sh_objects", "tot_draws", "nodes", "active", "pairs"] else (" %8.2f" % v)
	return s


func _report_ablations(L: Array) -> void:
	L.append("")
	L.append("== ablations (ms, change from base = the mean of base and base2, measured before and after them;")
	L.append("  far: enemies, villagers and enemy ships past %d m disabled; frame1t = the frame with exactly one physics tick," % int(FAR))
	L.append("  tick_scr / tick_eng = the physics pass's scripts / Jolt per tick)")
	var hdr := "%-8s %-8s" % ["stop", "what"]
	for c in SPLIT:
		hdr += " %8s" % c
	L.append(hdr)
	var abl := stops.filter(func(s): return not s in ACT)
	if abl.is_empty():
		return
	for s in abl:
		var r: Dictionary = results[s]
		var b := _base_of(r)
		var line := ""
		for k in ["base", "base2"]:
			line = "%-8s %-8s" % [s if k == "base" else "", k]
			for c in SPLIT:
				line += " %8.2f" % r[k][c]
			L.append(line)
		for k in ABLATIONS:
			var a: Dictionary = r[k]
			line = "%-8s %-8s" % ["", k]
			for c in SPLIT:
				line += " %+8.2f" % (a[c] - b[c])
			L.append(line)
		var pr: Dictionary = r["probe"]
		L.append("         (far froze %d; sun shadow draws %d -> %d; lights in view %.1f (%.1f shadowed) of %d)" % [r["frozen"], b["sh_draws"], r["sun"]["sh_draws"],
			pr["lights"], pr["lights_shadowed"], pr["counts"]["lights"]])
	L.append("")
	L.append("== ablations, mean over stops (ms, change from base)")
	L.append(hdr)
	for k in ABLATIONS:
		var line := "%-8s %-8s" % ["ALL", k]
		for c in SPLIT:
			var dsum := 0.0
			for s in abl:
				dsum += (results[s][k][c] - _base_of(results[s])[c]) / abl.size()
			line += " %+8.2f" % dsum
		L.append(line)


## Each script's probe costs, the mean over these stops.
func _agg(list: Array) -> Dictionary:
	var agg := {}
	for s in list:
		var by: Dictionary = results[s]["probe"]["scripts"]
		for k in by:
			if not agg.has(k):
				agg[k] = {"nodes": 0.0, "proc": 0.0, "phys": 0.0, "posed": 0.0, "bands": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], "band_nodes": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}
			var a: Dictionary = agg[k]
			a["nodes"] += float(by[k]["nodes"]) / list.size()
			a["proc"] += by[k]["proc"] / list.size()
			a["phys"] += by[k]["phys"] / list.size()
			a["posed"] += by[k]["posed"] / list.size()
			for i in range(6):
				a["bands"][i] += by[k]["bands"][i] / list.size()
				a["band_nodes"][i] += float(by[k]["band_nodes"][i]) / list.size()
	return agg


## A scripts table (`title`: "scripts", or "scripts_old" for the old eight alone; perf_gate.ps1 reads them).
func _scripts_table(L: Array, title: String, what: String, agg: Dictionary) -> Array:
	L.append("")
	L.append("== " + title)
	L.append("  (mean over %s; proc = ms/frame, phys = ms/physics tick, cost = proc + phys; by band: cost of the nodes that far from the captain)" % what)
	var hdr := "%-48s %7s %7s %7s %7s %7s" % ["script", "nodes", "proc", "phys", "cost", "posed"]
	for bn in ["n/a"] + BAND_NAMES:
		hdr += " %8s" % bn
	L.append(hdr)
	var keys := agg.keys()
	keys.sort_custom(func(x, y): return agg[x]["proc"] + agg[x]["phys"] > agg[y]["proc"] + agg[y]["phys"])
	var tp := 0.0
	var tf := 0.0
	for k in keys:
		var a: Dictionary = agg[k]
		tp += a["proc"]
		tf += a["phys"]
		if a["proc"] + a["phys"] < 0.01:
			continue
		var line := "%-48s %7.1f %7.3f %7.3f %7.3f %7.1f" % [k, a["nodes"], a["proc"], a["phys"], a["proc"] + a["phys"], a["posed"]]
		for i in range(6):
			line += " %8.3f" % a["bands"][i]
		L.append(line)
	L.append("")
	L.append("total scripts: process %.2f ms/frame, physics %.2f ms/tick" % [tp, tf])
	return keys


func _report_scripts(L: Array) -> void:
	L.append("")
	L.append("== per stop (probe): scripts' ms, rigs, physics")
	var agg := _agg(stops)
	for s in stops:
		var pr: Dictionary = results[s]["probe"]
		var by: Dictionary = pr["scripts"]
		var sp := 0.0
		var sf := 0.0
		var rigs := 0
		for k in by:
			sp += by[k]["proc"]
			sf += by[k]["phys"]
			if k.begins_with("humanoid.gd"):
				rigs += by[k]["nodes"]
		var c: Dictionary = pr["counts"]
		L.append("%-8s scripts: process %.2f ms/frame, physics %.2f ms/tick (%.2f ticks/frame); %d timed nodes, %d untimed; rigs %d processing of %d, posed %.1f/frame" % [
			s, sp, sf, pr["ticks_per_frame"], pr["entries"], pr["untimed"], rigs, c["humanoids"], pr["posed"]])
		L.append("         bodies: static %d, character %d, rigid %d, areas %d (%d monitoring), shapes %d" % [c["static"], c["character"], c["rigid"], c["area"], c["area_monitoring"], c["shapes"]])
		var keys := by.keys()
		keys.sort_custom(func(x, y): return by[x]["proc"] + by[x]["phys"] > by[y]["proc"] + by[y]["phys"])
		for k in keys.slice(0, 8):
			L.append("           %-44s %5d  %6.2f + %6.2f" % [k, by[k]["nodes"], by[k]["proc"], by[k]["phys"]])
		var spiky := by.keys()
		spiky.sort_custom(func(x, y): return float(by[x].get("max", 0.0)) > float(by[y].get("max", 0.0)))
		L.append("         longest single calls (ms): " + ", ".join(spiky.slice(0, 6).map(func(k): return "%s %.1f" % [k, float(by[k].get("max", 0.0))])))
		var geo_s: Dictionary = pr["geo"]
		var gk := geo_s.keys()
		gk.sort_custom(func(x, y): return geo_s[x][3] > geo_s[y][3])
		var gt := [0, 0, 0, 0, 0, 0]
		for k in gk:
			for i in range(6):
				gt[i] += geo_s[k][i]
		L.append("         visible geometry: %d nodes, %d surfaces, %d within 60 m, %d within 150 m, %d with no visibility range, %d casting shadows; most within 150 m:" % gt)
		for k in gk.slice(0, 10):
			L.append("           %-44s %5d nodes %6d surf %6d <60m %6d <150m %6d no-range %6d shadow" % ([k] + geo_s[k]))
	L.append("")
	L.append("== collision in the world (at the first stop): shapes and areas by owner")
	var ph: Dictionary = results[stops[0]]["probe"]["phys"]
	var pk := ph.keys()
	pk.sort_custom(func(x, y): return ph[x][0] + ph[x][2] * 10 > ph[y][0] + ph[y][2] * 10)
	L.append("%-60s %7s %7s %7s" % ["owner", "shapes", "areas", "monitor"])
	for k in pk.slice(0, 25):
		L.append("%-60s %7d %7d %7d" % [k, ph[k][0], ph[k][1], ph[k][2]])
	var keys := _scripts_table(L, "scripts", "stops", agg)
	var olds := stops.filter(func(s): return s in OLD)
	if olds.size() > 0 and olds.size() < stops.size():
		_scripts_table(L, "scripts_old", "the old route's stops", _agg(olds))
	L.append("")
	L.append("== nodes by band (mean over stops; processing nodes of each script that far from the captain)")
	var nh := "%-48s %7s" % ["script", "nodes"]
	for bn in ["n/a"] + BAND_NAMES:
		nh += " %8s" % bn
	L.append(nh)
	for k in keys.slice(0, 25):
		var a: Dictionary = agg[k]
		var line := "%-48s %7.1f" % [k, a["nodes"]]
		for i in range(6):
			line += " %8.1f" % a["band_nodes"][i]
		L.append(line)

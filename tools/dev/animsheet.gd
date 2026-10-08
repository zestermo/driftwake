extends SceneTree
## Contact sheets of every Humanoid action in ActionSpecs at its length: 8 frames each
## (u 0 -> 0.98), three rows to a sheet, saved as <out_prefix>_NN_<a>+<b>+<c>.png.
## A red bar under a frame = inside the action's hitbox window. Each spec "variant"
## (another dash direction, another way a blow shoves) is a row of its own.
## Args: <out_prefix> [only: names or stances, comma separated] [yaw_deg = 125: front
## three-quarter, sword side; 90 = side]. Moves that travel play in place.
## Lab mode, `lab:<action>` as the second arg: the live animation and each AnimLab variant
## as rows (tag colours: live white, A red, B green, C blue, D yellow), 12 frames, one sheet
## per view (front3, side, back3, top) saved as <out_prefix>_<action>_<view>.png, and each
## row's range of motion per axis printed (pivot, hips, torso, head, lift, squash, smear).
const N := 8
const N_LAB := 12
const ROWS := 3
const FW := 230
const FH := 300
const GAP := 4
const BAR := 6
const TAG := 16
const TAGS := [Color(1, 1, 1), Color(0.95, 0.2, 0.15), Color(0.2, 0.85, 0.3), Color(0.25, 0.5, 1.0), Color(1.0, 0.85, 0.15)]
const VIEWS := {"front3": 125.0, "side": 90.0, "back3": 305.0, "top": 180.0}
const AXES := ["pivot", "hips", "torso", "head"]

var _world: Node3D
var _cam: Camera3D
var _frames := N


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_build_stage()
	if a.size() > 1 and a[1].begins_with("lab:"):
		await _lab(out, a[1].trim_prefix("lab:"))
		quit()
		return
	var only: Array = Array(a[1].split(",", false)) if a.size() > 1 else []
	var yaw := float(a[2]) if a.size() > 2 else 125.0
	var rows: Array = []
	var names: Array = []
	var sheet := 0
	for n in ActionSpecs.SPECS.keys():
		var s: Dictionary = ActionSpecs.SPECS[n]
		if not only.is_empty() and not (n in only) and not (s["stance"] in only):
			continue
		var base: Dictionary = s.get("extras", {})
		for ex in [base] + Array(s.get("variants", [])):
			rows.append(await _strip(n, s, base.merged(ex, true), yaw))
			names.append(n)
			if rows.size() == ROWS:
				_save("%s_%02d_%s.png" % [out, sheet, "+".join(names)], rows)
				sheet += 1
				rows = []
				names = []
	if not rows.is_empty():
		_save("%s_%02d_%s.png" % [out, sheet, "+".join(names)], rows)
	quit()


func _lab(out: String, n: String) -> void:
	_frames = N_LAB
	var picks: Array = [""] + (AnimLab.VARIANTS.get(n, {}) as Dictionary).keys()
	for view in VIEWS.keys():
		_aim(view)
		var rows: Array = []
		for p in picks:
			AnimLab.pick = p
			AnimLab.debug = view == "front3" and p != "" and OS.get_environment("AS_DEBUG") == p
			var s := AnimLab.spec(n)
			var row := await _strip(n, s, s.get("extras", {}), VIEWS[view])
			row.append(TAGS[picks.find(p)])
			rows.append(row)
			if view == "front3":
				_print_ranges(n, p, row[2])
		_save("%s_%s_%s.png" % [out, n, view], rows)
	AnimLab.pick = ""


func _build_stage() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.6, 0.75)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.62, 0.68)
	e.ambient_light_energy = 0.8
	env.environment = e
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-30), 0)
	_world.add_child(sun)
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_.mesh = pm
	_world.add_child(floor_)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	_cam.current = true
	_cam.fov = 40
	_aim("front3")


func _aim(view: String) -> void:
	if view == "top":
		_cam.look_at_from_position(Vector3(0, 4.4, 0.01), Vector3(0, 0.9, 0), Vector3.FORWARD)
	else:
		_cam.look_at_from_position(Vector3(0, 1.2, 4.6), Vector3(0, 0.95, 0))


## [frames, hit window (u) or null, ranges {channel: [min Vector3, max Vector3]}]
func _strip(n: String, s: Dictionary, ex: Dictionary, yaw: float) -> Array:
	var h = Humanoid.new()
	h.setup(CharacterLook.default_look())
	_world.add_child(h)
	h.rotation.y = deg_to_rad(yaw)
	h.stance = s["stance"]
	var weapon: String = s["weapon"]
	if weapon != "":
		h.set_weapon(Props.weapon_mesh(weapon))
		if ex.get("dual", false):
			h.set_offhand(Props.weapon_mesh(weapon))
		h._attach_weapon(not ex.get("sheathed", false))
		h.auto_point_guns = true
	h.armed = true
	if ex.get("beast", false):
		h.set_beast(true)
	for k in ex.keys():
		if not k in ["dual", "beast", "sheathed", "push"]:
			h.set(k, ex[k])
	# (switched off after ready: ready turns processing back on; the tool steps it)
	await process_frame
	h.set_process(false)
	for i in 60:
		h._process(1.0 / 60.0)
	var dur: float = s["len"]
	if s.get("hold", false):
		h.hold(n)
	elif s.get("react", false):
		h.react(n, dur, h.global_basis * (ex["push"] as Vector3))
	else:
		h.play(n, dur)
	var ranges := {}
	var imgs: Array = []
	# (lab mode draws the blade's own trail: where the swing really goes)
	var trail: BladeTrail = null
	if _frames == N_LAB:
		trail = BladeTrail.new()
		trail.body = h
		trail.manual = true
		h.add_child(trail)
	for i in _frames:
		var target := dur * float(i) / float(_frames - 1) * 0.98
		while h.is_busy() and float(h._action["t"]) < target:
			h._process(1.0 / 120.0)
			_track(h, ranges)
			if trail:
				trail.sample(1.0 / 120.0)
		# (the skinned legs only follow on frames the rig posed itself: stepped by hand, skin them here)
		h.hips.get_node("LowerBody")._pose()
		# (the viewport image lags a frame behind: wait two draws for this pose)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		imgs.append(_crop(root.get_texture().get_image()))
	h.queue_free()
	await process_frame
	return [imgs, s.get("hit", null), ranges]


func _track(h, ranges: Dictionary) -> void:
	var vals := {"lift": h._lift, "scale": h._scale, "smear": Vector3(h._smear, 0, 0)}
	for j in AXES:
		vals[j] = h._cur[j]
	for c in vals.keys():
		var v: Vector3 = vals[c]
		if not ranges.has(c):
			ranges[c] = [v, v]
		else:
			ranges[c] = [(ranges[c][0] as Vector3).min(v), (ranges[c][1] as Vector3).max(v)]
	# swing checks: edge leading the cut (1 = straight ahead), worst grip angle (blade vs the
	# forearm: > 2.1 rad = pointing back toward the elbow, a reverse grip), worst roll in the fist
	var sc: Dictionary = h.swing_check
	if not sc.is_empty():
		ranges["grip"] = maxf(ranges.get("grip", 0.0), sc["grip"])
		ranges["roll"] = maxf(ranges.get("roll", 0.0), sc["roll"])
		ranges["head_clear"] = minf(ranges.get("head_clear", 1.0), sc["head"])
		if float(sc["head"]) < -0.01:
			ranges["through"] = ranges.get("through", 0) + 1
		if sc.has("edge"):
			ranges["edge_n"] = ranges.get("edge_n", 0) + 1
			ranges["edge_sum"] = ranges.get("edge_sum", 0.0) + float(sc["edge"])
			ranges["edge_min"] = minf(ranges.get("edge_min", 1.0), sc["edge"])
			if float(sc["grip"]) > 2.1:
				ranges["reverse"] = ranges.get("reverse", 0) + 1


func _print_ranges(n: String, p: String, ranges: Dictionary) -> void:
	var parts: Array = []
	for c in AXES + ["lift"]:
		var d: Vector3 = ranges[c][1] - ranges[c][0]
		parts.append("%s %.2f/%.2f/%.2f" % [c, d.x, d.y, d.z])
	var sc: Vector3 = ranges["scale"][1] - ranges["scale"][0]
	parts.append("squash %.2f smear %.2f" % [maxf(sc.x, maxf(sc.y, sc.z)), (ranges["smear"][1] as Vector3).x])
	print("RANGE %s [%s] (x/y/z, rad) %s" % [n, "live" if p == "" else p.to_upper(), " | ".join(parts)])
	if ranges.has("grip"):
		var en := int(ranges.get("edge_n", 0))
		print("BLADE %s [%s] edge leads the cut avg %.2f min %.2f (%d samples) | worst grip %.2f rad%s | worst roll in fist %.2f | head clearance min %.2f m%s" % [
			n, "live" if p == "" else p.to_upper(), float(ranges.get("edge_sum", 0.0)) / maxi(en, 1), float(ranges.get("edge_min", 0.0)), en,
			float(ranges["grip"]), " REVERSE GRIP x%d" % int(ranges["reverse"]) if ranges.has("reverse") else "", float(ranges["roll"]),
			float(ranges["head_clear"]), " THROUGH THE HEAD x%d" % int(ranges["through"]) if ranges.has("through") else ""])


func _crop(im: Image) -> Image:
	var w := im.get_width()
	var hh := im.get_height()
	var cw := int(w * 0.36)
	var ch := int(hh * 0.86)
	var c := im.get_region(Rect2i((w - cw) / 2, int(hh * 0.07), cw, ch))
	c.resize(FW, FH, Image.INTERPOLATE_BILINEAR)
	return c


func _save(path: String, rows: Array) -> void:
	var f0: Image = rows[0][0][0]
	var sheet := Image.create(_frames * (FW + GAP), rows.size() * (FH + GAP), false, f0.get_format())
	sheet.fill(Color(0.1, 0.1, 0.12))
	for r in rows.size():
		var frames: Array = rows[r][0]
		var hit = rows[r][1]
		for c in _frames:
			var at := Vector2i(c * (FW + GAP), r * (FH + GAP))
			sheet.blit_rect(frames[c], Rect2i(0, 0, FW, FH), at)
			var u := float(c) / float(_frames - 1) * 0.98
			if hit != null and u >= float(hit[0]) and u <= float(hit[1]):
				sheet.fill_rect(Rect2i(at.x, at.y + FH - BAR, FW, BAR), Color(0.9, 0.15, 0.1))
		if rows[r].size() > 3:
			sheet.fill_rect(Rect2i(r * 0 + 4, r * (FH + GAP) + 4, TAG, TAG), rows[r][3])
	sheet.save_png(path)
	print("SAVED ", path)

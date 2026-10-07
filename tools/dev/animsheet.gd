extends SceneTree
## Contact sheets of every Humanoid action in ActionSpecs at its length: 8 frames each
## (u 0 -> 0.98), three rows to a sheet, saved as <out_prefix>_NN_<a>+<b>+<c>.png.
## A red bar under a frame = inside the action's hitbox window. Each spec "variant"
## (another dash direction, another way a blow shoves) is a row of its own.
## Args: <out_prefix> [only: names or stances, comma separated] [yaw_deg = 125: front
## three-quarter, sword side; 90 = side]. Moves that travel play in place.
const N := 8
const ROWS := 3
const FW := 230
const FH := 300
const GAP := 4
const BAR := 6

var _world: Node3D


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var only: Array = Array(a[1].split(",", false)) if a.size() > 1 else []
	var yaw := float(a[2]) if a.size() > 2 else 125.0
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_build_stage()
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
				_save(out, sheet, rows, names)
				sheet += 1
				rows = []
				names = []
	if not rows.is_empty():
		_save(out, sheet, rows, names)
	quit()


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
	var cam := Camera3D.new()
	_world.add_child(cam)
	cam.current = true
	cam.fov = 40
	cam.look_at_from_position(Vector3(0, 1.2, 4.6), Vector3(0, 0.95, 0))


## [frames, hit window (u) or null]
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
	var imgs: Array = []
	for i in N:
		var target := dur * float(i) / float(N - 1) * 0.98
		while h.is_busy() and float(h._action["t"]) < target:
			h._process(1.0 / 120.0)
		# (the skinned legs only follow on frames the rig posed itself: stepped by hand, skin them here)
		h.hips.get_node("LowerBody")._pose()
		# (the viewport image lags a frame behind: wait two draws for this pose)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		imgs.append(_crop(root.get_texture().get_image()))
	h.queue_free()
	await process_frame
	return [imgs, s.get("hit", null)]


func _crop(im: Image) -> Image:
	var w := im.get_width()
	var hh := im.get_height()
	var cw := int(w * 0.36)
	var ch := int(hh * 0.86)
	var c := im.get_region(Rect2i((w - cw) / 2, int(hh * 0.07), cw, ch))
	c.resize(FW, FH, Image.INTERPOLATE_BILINEAR)
	return c


func _save(out: String, i: int, rows: Array, names: Array) -> void:
	var f0: Image = rows[0][0][0]
	var sheet := Image.create(N * (FW + GAP), rows.size() * (FH + GAP), false, f0.get_format())
	sheet.fill(Color(0.1, 0.1, 0.12))
	for r in rows.size():
		var frames: Array = rows[r][0]
		var hit = rows[r][1]
		for c in N:
			var at := Vector2i(c * (FW + GAP), r * (FH + GAP))
			sheet.blit_rect(frames[c], Rect2i(0, 0, FW, FH), at)
			var u := float(c) / float(N - 1) * 0.98
			if hit != null and u >= float(hit[0]) and u <= float(hit[1]):
				sheet.fill_rect(Rect2i(at.x, at.y + FH - BAR, FW, BAR), Color(0.9, 0.15, 0.1))
	var path := "%s_%02d_%s.png" % [out, i, "+".join(names)]
	sheet.save_png(path)
	print("SAVED ", path)

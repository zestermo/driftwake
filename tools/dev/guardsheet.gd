extends SceneTree
## Every weapon's stance side by side: one Humanoid per weapon, stepped by hand to a fixed time, shot from
## several views, one sheet per view (five weapons to a row): <out_dir>/sheet_<mode>_<view>.png.
## Args: <out_dir> [mode: guard | walk | run | sprint | after:<action> (played, then shot `GS_AT` s after it
## ends: the settle)] [only: row names, comma separated] [views: three,side,back].
## A row's fifth field (true): the stance's mastered guard (Humanoid.guard2), rows named <weapon>2.
## Env GS_AT: seconds to step before the shot (default 1.5; after:<action>, seconds after its end, default 0.1).
## Env GS_MOVE="x,y": the travel direction relative to the facing (Humanoid.local_move, y+ forward; default 0,1).
## Prints FEET <row> l=<m> r=<m>: each ankle's height off the floor (the sole sits ~0.06 under it).
const ROWS := [
	["cutlass", "sword", "cutlass", ""], ["katana", "katana", "katana", ""], ["axe", "axe", "axe", ""],
	["dagger", "dagger", "dagger", ""], ["fist", "fist", "", ""], ["pistol", "pistol", "pistol", ""],
	["dual_pistol", "dual_pistol", "pistol", "pistol"], ["corsair", "sword_pistol", "cutlass", "pistol"],
	["dual_dagger", "dual_dagger", "dagger", "dagger"], ["dual_sword", "dual_sword", "cutlass", "cutlass"],
	["polearm", "polearm", "polearm", ""], ["hammer", "hammer", "hammer", ""], ["greatsword", "greatsword", "greatsword", ""],
	["dual_axe", "dual_axe", "axe", "axe"], ["unarmed", "", "", ""],
	["axe2", "axe", "axe", "", true], ["katana2", "katana", "katana", "", true], ["cutlass2", "sword", "cutlass", "", true], ["dagger2a", "dagger", "dagger", "", "a"], ["dagger2b", "dagger", "dagger", "", "b"], ["dual2a", "dual_sword", "cutlass", "cutlass", "a"], ["dual2b", "dual_sword", "cutlass", "cutlass", "b"]]
## Env GS_AURA=1: the awakened weapon's aura on it (stance -> its class).
var AURAS := {"sword": BladeWater, "katana": BladePetals, "axe": BladeEmbers}
const COLS := 5
const FW := 300
const FH := 400
const GAP := 4
const SPEED := {"guard": 0.0, "walk": 3.0, "run": 6.0, "sprint": 9.0}

var _world: Node3D
var _cam: Camera3D


func _initialize() -> void:
	_run()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var mode: String = a[1] if a.size() > 1 else "guard"
	var only: Array = Array(a[2].split(",", false)) if a.size() > 2 and a[2] != "all" else []
	var views: Array = Array(a[3].split(",", false)) if a.size() > 3 else ["three", "side", "back"]
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	_build_stage()
	var shots := {}
	for v in views:
		shots[v] = []
	for r in ROWS:
		if not only.is_empty() and not (r[0] in only):
			continue
		var imgs: Dictionary = await _shoot(r, mode, views)
		for v in views:
			shots[v].append(imgs[v])
	var tag := mode.replace(":", "_")
	for v in views:
		_save("%s/sheet_%s_%s.png" % [out, tag, v], shots[v])
	quit()


func _build_stage() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.72)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.75)
	env.environment = e
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	_world.add_child(sun)
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	floor_.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.35, 0.4, 0.33)
	floor_.material_override = fm
	_world.add_child(floor_)
	# the target, 1.3 m ahead (model forward = -Z)
	var tgt := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.03
	cm.height = 1.8
	tgt.mesh = cm
	tgt.position = Vector3(0.9, 0.9, -1.3)
	_world.add_child(tgt)
	_cam = Camera3D.new()
	_world.add_child(_cam)
	_cam.current = true
	_cam.fov = 38


func _aim(v: String) -> void:
	var c := Vector3(0, 1.0, -0.2)
	match v:
		"side":
			_cam.look_at_from_position(c + Vector3(-4.2, 0.3, 0), c)
		"back":   # the game camera's side: behind, above, a little right
			_cam.look_at_from_position(c + Vector3(1.2, 1.6, 3.9), c)
		"front":
			_cam.look_at_from_position(c + Vector3(0, 0.4, -4.2), c)
		_:
			_cam.look_at_from_position(c + Vector3(-3.0, 1.2, -2.8), c)


func _shoot(r: Array, mode: String, views: Array) -> Dictionary:
	var h = Humanoid.new()
	h.setup(CharacterLook.default_look())
	_world.add_child(h)
	h.stance = r[1]
	if r[2] != "":
		h.set_weapon(Props.weapon_mesh(r[2]))
		if r[3] != "":
			h.set_offhand(Props.weapon_mesh(r[3]))
		h._attach_weapon(true)
		h.auto_point_guns = true
	h.armed = r[1] != ""
	if r.size() > 4 and r[4]:
		h.guard2 = true
		if r[4] is String:
			DaggerMoves.preview = r[4]
			WieldMoves.preview = r[4]
	var spd: float = SPEED.get(mode, 0.0)
	h.ground_speed = spd
	h.local_move = Vector2(0, 1)
	if OS.get_environment("GS_MOVE") != "":
		var mv := OS.get_environment("GS_MOVE").split(",")
		h.local_move = Vector2(float(mv[0]), float(mv[1])).normalized()
	h.sprinting = mode == "sprint"
	await process_frame
	if OS.get_environment("GS_AURA") != "" and r[1] in AURAS:
		AURAS[r[1]].keep(h, true)
	h.set_process(false)
	var at := float(OS.get_environment("GS_AT")) if OS.get_environment("GS_AT") != "" else -1.0
	if mode.begins_with("after:"):
		for i in 90:
			h._process(1.0 / 60.0)
		var n := mode.trim_prefix("after:")
		h.play(n, float(ActionSpecs.SPECS[n]["len"]) if ActionSpecs.SPECS.has(n) else 0.6)
		while h.is_busy():
			h._process(1.0 / 120.0)
		for i in int((at if at >= 0.0 else 0.1) * 120.0):
			h._process(1.0 / 120.0)
	else:
		for i in int((at if at >= 0.0 else 1.5) * 60.0):
			h._process(1.0 / 60.0)
	h.hips.get_node("LowerBody")._pose()
	var feet := []
	for s in [h.shin_l, h.shin_r]:
		feet.append((s as Node3D).global_transform * Vector3(0, h.shin_l.position.y, 0))
	print("FEET %s l=%.3f r=%.3f (standing %.3f)" % [r[0], (feet[0] as Vector3).y, (feet[1] as Vector3).y,
		h.hip_y + h.leg_l.position.y + h.shin_l.position.y * 2.0])
	# (the free hand from its shoulder in the chest's frame: a reach path's first key, SwordMoves.OFF_GUARD)
	var tb: Basis = h.torso.global_basis.orthonormalized()
	print("HAND_L %s %s" % [r[0], tb.inverse() * (h.hand_l.global_position - h.arm_l.global_position)])
	var imgs := {}
	for v in views:
		_aim(v)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		imgs[v] = _crop(root.get_texture().get_image())
	h.queue_free()
	await process_frame
	return imgs


func _crop(im: Image) -> Image:
	var w := im.get_width()
	var hh := im.get_height()
	var ch := int(hh * 0.9)
	var cw := int(ch * float(FW) / float(FH))
	var c := im.get_region(Rect2i((w - cw) / 2, int(hh * 0.05), cw, ch))
	c.resize(FW, FH, Image.INTERPOLATE_BILINEAR)
	return c


func _save(path: String, imgs: Array) -> void:
	var rows := ceili(float(imgs.size()) / COLS)
	var sheet := Image.create(COLS * (FW + GAP), rows * (FH + GAP), false, (imgs[0] as Image).get_format())
	sheet.fill(Color(0.1, 0.1, 0.12))
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(0, 0, FW, FH), Vector2i((i % COLS) * (FW + GAP), (i / COLS) * (FH + GAP)))
	sheet.save_png(path)
	print("SAVED ", path)

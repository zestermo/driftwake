extends SceneTree
## Contact sheets of every Humanoid action at the length the game plays it: 8 frames
## each (u 0 -> 0.98), three actions to a sheet, saved as
## <out_prefix>_NN_<a>+<b>+<c>.png. Args: <out_prefix> [only: names or stances, comma
## separated] [yaw_deg = 125: front three-quarter, sword side]. Moves that travel (lunges, dashes, jumps) play in place.
const N := 8
const ROWS := 3
const FW := 230
const FH := 300
const GAP := 4

# [action, length (s, as its caller plays it), stance, weapon ("" = none), extras]
# extras: "dual" (same weapon in the off hand), "beast", "sheathed", any Humanoid property.
# Moves that callers play at several lengths are listed at the player's.
const CAT := [
	["draw", 0.35, "sword", "cutlass", {"sheathed": true}],
	["sheathe", 0.4, "sword", "cutlass", {}],
	["slash_r", 0.48, "sword", "cutlass", {}],
	["slash_l", 0.48, "sword", "cutlass", {}],
	["spin_slash", 0.62, "sword", "cutlass", {}],
	["dash_cut", 0.62, "sword", "cutlass", {}],
	["thrust", 0.75, "sword", "cutlass", {}],
	["flying_slash", 0.5, "sword", "cutlass", {}],
	["heavy", 0.8, "sword", "cutlass", {}],
	["parry", 0.66, "sword", "cutlass", {}],
	["guard_block", 1.0, "sword", "cutlass", {}],
	["guard_block_hit", 0.2, "sword", "cutlass", {}],
	["plunge_air", 0.6, "sword", "cutlass", {}],
	["plunge_land", 0.48, "sword", "cutlass", {}],
	["climb_chop", 0.5, "sword", "cutlass", {}],
	["katana_r", 0.85, "katana", "katana", {}],
	["katana_l", 0.85, "katana", "katana", {}],
	["katana_stab", 0.9, "katana", "katana", {}],
	["quick_draw", 1.3, "katana", "katana", {}],
	["iai_ready", 1.0, "katana", "katana", {}],
	["iai_slash", 0.6, "katana", "katana", {}],
	["air_slash", 0.6, "katana", "katana", {}],
	["axe_hack", 0.62, "axe", "axe", {}],
	["axe_hook", 0.62, "axe", "axe", {}],
	["axe_split", 0.9, "axe", "axe", {}],
	["axe_whirl", 1.24, "axe", "axe", {}],
	["axe_flip", 0.58, "axe", "axe", {}],
	["axe_land", 0.53, "axe", "axe", {}],
	["dual_1", 0.4, "dual_sword", "cutlass", {"dual": true}],
	["dual_2", 0.4, "dual_sword", "cutlass", {"dual": true}],
	["dual_cross", 0.5, "dual_sword", "cutlass", {"dual": true}],
	["dual_spin", 0.6, "dual_sword", "cutlass", {"dual": true}],
	["dual_heavy", 0.88, "dual_sword", "cutlass", {"dual": true}],
	["fists_up", 0.25, "fist", "", {}],
	["jab", 0.34, "fist", "", {}],
	["cross", 0.36, "fist", "", {}],
	["hook", 0.42, "fist", "", {}],
	["roundhouse", 0.56, "fist", "", {}],
	["flying_kick", 0.85, "fist", "", {}],
	["shoot_r", 0.6, "pistol", "pistol", {}],
	["pistol_whip", 0.62, "pistol", "pistol", {}],
	["reload", 1.0, "pistol", "pistol", {}],
	["bullet_storm", 0.75, "pistol", "pistol", {}],
	["shoot_l", 0.6, "dual_pistol", "pistol", {"dual": true}],
	["gun_kata", 0.82, "dual_pistol", "pistol", {"dual": true}],
	["gun_rain", 0.6, "dual_pistol", "pistol", {"dual": true}],
	["claw_r", 0.44, "claw", "", {"beast": true}],
	["claw_l", 0.44, "claw", "", {"beast": true}],
	["claw_double", 0.62, "claw", "", {"beast": true}],
	["maul", 0.82, "claw", "", {"beast": true}],
	["pounce", 1.0, "claw", "", {"beast": true}],
	["howl", 0.9, "claw", "", {"beast": true}],
	["fire_punch", 0.45, "fist", "", {}],
	["flame_dash", 0.5, "fist", "", {}],
	["fire_ring", 0.6, "fist", "", {}],
	["fire_plant", 0.55, "fist", "", {}],
	["inferno", 1.15, "fist", "", {}],
	["soru", 0.24, "fist", "", {}],
	["tekkai", 3.0, "fist", "", {}],
	["coat", 0.45, "fist", "", {}],
	["foresight", 0.4, "fist", "", {}],
	["vine_throw", 0.45, "fist", "", {}],
	["thorn_whip", 0.55, "fist", "", {}],
	["vine_pull", 0.55, "fist", "", {}],
	["vine_zip", 1.9, "fist", "", {}],
	["vine_release", 0.75, "fist", "", {}],
	["vine_shoot", 0.5, "fist", "", {}],
	["dash", 0.3, "sword", "cutlass", {"dash_dir": Vector2(0, 1)}],
	["dash", 0.3, "sword", "cutlass", {"dash_dir": Vector2(1, 0)}],
	["roll", 0.6, "sword", "cutlass", {}],
	["flip", 0.45, "sword", "cutlass", {}],
	["hit", 0.32, "sword", "cutlass", {}],
	["stagger", 1.0, "sword", "cutlass", {}],
	["mantle", 1.0, "sword", "cutlass", {}],
	["drink", 1.0, "sword", "cutlass", {}],
	["eat", 1.0, "sword", "cutlass", {}],
	["wave", 1.5, "sword", "cutlass", {}],
	["wind_r", 0.6, "sword", "cutlass", {}],
	["swing_r", 0.5, "sword", "cutlass", {}],
	["wind_l", 0.32, "sword", "cutlass", {}],
	["swing_l", 0.5, "sword", "cutlass", {}],
	["lunge_wind", 0.8, "sword", "cutlass", {}],
	["lunge", 0.8, "sword", "cutlass", {}],
	["block", 0.4, "sword", "cutlass", {}],
	["peril_chop", 2.6, "sword", "cutlass", {}],
	["slash_down", 0.5, "sword", "cutlass", {}],
	["aim_pistol", 1.3, "pistol", "pistol", {"auto_point_guns": false}],
	["aim_rifle", 1.3, "sword", "rifle", {}],
	["shove", 0.75, "sword", "rifle", {}],
]

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
	for e in CAT:
		if not only.is_empty() and not (e[0] in only) and not (e[2] in only):
			continue
		rows.append(await _strip(e, yaw))
		names.append(e[0])
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


func _strip(e: Array, yaw: float) -> Array:
	var ex: Dictionary = e[4]
	var h = Humanoid.new()
	h.setup(CharacterLook.default_look())
	_world.add_child(h)
	h.rotation.y = deg_to_rad(yaw)
	h.stance = e[2]
	if e[3] != "":
		h.set_weapon(Props.weapon_mesh(e[3]))
		if ex.get("dual", false):
			h.set_offhand(Props.weapon_mesh(e[3]))
		h._attach_weapon(not ex.get("sheathed", false))
		h.auto_point_guns = true
	h.armed = true
	if ex.get("beast", false):
		h.set_beast(true)
	for k in ex.keys():
		if not k in ["dual", "beast", "sheathed"]:
			h.set(k, ex[k])
	# (switched off after ready: ready turns processing back on; the tool steps it)
	await process_frame
	h.set_process(false)
	for i in 60:
		h._process(1.0 / 60.0)
	var dur: float = e[1]
	h.play(e[0], dur)
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
	return imgs


func _crop(im: Image) -> Image:
	var w := im.get_width()
	var hh := im.get_height()
	var cw := int(w * 0.36)
	var ch := int(hh * 0.86)
	var c := im.get_region(Rect2i((w - cw) / 2, int(hh * 0.07), cw, ch))
	c.resize(FW, FH, Image.INTERPOLATE_BILINEAR)
	return c


func _save(out: String, i: int, rows: Array, names: Array) -> void:
	var f0: Image = rows[0][0]
	var sheet := Image.create(N * (FW + GAP), rows.size() * (FH + GAP), false, f0.get_format())
	sheet.fill(Color(0.1, 0.1, 0.12))
	for r in rows.size():
		for c in N:
			sheet.blit_rect(rows[r][c], Rect2i(0, 0, FW, FH), Vector2i(c * (FW + GAP), r * (FH + GAP)))
	var path := "%s_%02d_%s.png" % [out, i, "+".join(names)]
	sheet.save_png(path)
	print("SAVED ", path)

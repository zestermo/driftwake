extends SceneTree
## Key art for the website (web/site/img): each shot staged in the world (hour,
## weather, ships, fights, the first chain island of a fixed chain seed with its
## village layout, harbour kind and temple forced where a shot needs them), HUD and
## labels off, the PSX post pass and dither on the game's own 640x360 grid, saved
## as 1600x900 JPEGs in <out_dir> (and <name>-640.jpg); action shots come in bursts (<name>_<n>).
## Clips (clip_*) are frame runs for GIFs: <out_dir>/clips/<name>/NNN.png on the
## 640x360 grid (nearest) plus <name>_poster.jpg; run with --fixed-fps 30 so game
## time steps evenly while frames are saved. Ends with sheet.png (every still) and
## og.jpg (1200x630 from OG).
## Args: <out_dir> [shot,shot,... | all]   (env SITE_SEED: chain seed, default 11)
## Shots: hero jungle stilts harbour cliffs shelf canopy beasts fauna daggers coop
##   post cove town cave temple seaking; clips: clip_combo clip_fangs clip_ape clip_sail clip_walk;
##   bats by name only (a seed with a roost; the canopy's perches are island-local, so they sit off the island)
## 1.18: fishing dive shark galley (Brinehollow), heldmap camp snow desert (chain islands; snow and desert on the
##   first seed from 1 that opens on one); clips: clip_fish clip_dive clip_map clip_loadout.
##   The held map is the game's own camera (own_cam off), the rest a stand-in camera.
const W := 1600
const H := 900
const GRID := Vector2(640, 360)
const ALL := ["hero", "jungle", "stilts", "harbour", "cliffs", "shelf", "canopy", "beasts", "fauna", "daggers", "coop",
	"clip_combo", "clip_fangs", "clip_ape", "clip_sail", "post", "cove", "town", "cave", "temple", "clip_walk", "seaking",
	"fishing", "dive", "shark", "galley", "clip_fish", "clip_dive", "heldmap", "camp", "clip_map", "clip_loadout", "snow", "desert"]
const OG := "hero_out_c"
const STAGGER := 9
const DECK := HullBuilder.DECK_Y
## The chain island's forced make-up per group of shots (the seed's own roll where left out).
const MAIN := {"village": "stilts", "harbour": "stilts"}
const POST := {"village": "post", "harbour": "cove"}
const TOWN := {"village": "town", "harbour": "wharf", "temple": true}

var out := ""
var want: Array = []
var t := 0.0
var started := false
var base_seed := 11
var p
var pc
var ship
var w
var gm
var wg
var isl
var isl_cfg := {}
var cam: Camera3D
var rig: Node3D
var aim := Callable()
var frames: Array = []
var settings
var pups := {}
var own_cam := true


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	want = Array(a[1].split(",")) if a.size() > 1 and a[1] != "all" else ALL.duplicate()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var seed_s := OS.get_environment("SITE_SEED")
	if seed_s != "":
		base_seed = int(seed_s)
	root.get_node("GameManager").chain_seed = base_seed
	DisplayServer.window_set_size(Vector2i(W, H))
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	# (the helm takes its own camera)
	if cam and own_cam and not cam.current:
		cam.current = true
	if aim.is_valid():
		aim.call()
	_feed()
	if t > 2.0 and not started:
		started = true
		_run()
	return false


func _run() -> void:
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	settings = root.get_node("Settings")
	settings.set_value("video", "perf_overlay", false, false)
	settings.set_value("gameplay", "name_tags", false, false)
	w = root.get_node("Weather")
	gm = root.get_node("GameManager")
	wg = root.get_node("World/Islands")
	ship = get_first_node_in_group("ship")
	p = get_first_node_in_group("player")
	pc = p.power
	get_first_node_in_group("hud").visible = false
	p.health_component.max_health = 99999.0
	p.health_component.current_health = 99999.0
	var lk: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
	lk.merge({"hat": "tricorn", "hat_color": Color(0.16, 0.12, 0.1), "coat": "longcoat", "coat_color": Color(0.55, 0.09, 0.08),
		"vest": "vest", "legs_color": Color(0.22, 0.18, 0.14), "hair": "long"}, true)
	p.appearance = lk
	p._wear_outfit_of(lk)
	_learn_all()
	# (attacks and walking go along the current camera's grandparent: a stand-in rig)
	rig = Node3D.new()
	var arm := Node3D.new()
	root.add_child(rig)
	rig.add_child(arm)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 3000.0
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	arm.add_child(cam)
	cam.current = true
	await _wait(0.5)
	for s in want:
		print("== ", s)
		match s:
			"hero": await _shot_hero()
			"jungle": await _shot_jungle()
			"stilts": await _shot_stilts()
			"harbour": await _shot_harbour("harbour", MAIN, 17.4)
			"cliffs": await _shot_cliffs()
			"shelf": await _shot_shelf()
			"canopy": await _shot_canopy()
			"beasts": await _shot_beasts()
			"fauna": await _shot_fauna()
			"bats": await _shot_bats()
			"daggers": await _shot_daggers()
			"coop": await _shot_coop()
			"post": await _shot_post()
			"cove": await _shot_harbour("cove", POST, 19.2)
			"town": await _shot_town()
			"cave": await _shot_cave()
			"temple": await _shot_temple()
			"seaking": await _shot_seaking()
			"clip_combo": await _clip_combo()
			"clip_fangs": await _clip_fangs()
			"clip_ape": await _clip_ape()
			"clip_sail": await _clip_sail()
			"clip_walk": await _clip_walk()
			"fishing": await _shot_fishing()
			"dive": await _shot_dive()
			"shark": await _shot_shark()
			"galley": await _shot_galley()
			"heldmap": await _shot_heldmap()
			"camp": await _shot_camp()
			"snow": await _shot_theme("snow", [[16.9, 3, "blizzard"], [12.0, 2, "fall"]])
			"desert": await _shot_theme("desert", [[17.3, 0, "gold"], [10.5, 0, "day"]])
			"clip_fish": await _clip_fish()
			"clip_dive": await _clip_dive()
			"clip_map": await _clip_map()
			"clip_loadout": await _clip_loadout()
		aim = Callable()
		for a in ["move_forward", "dodge"]:
			Input.action_release(a)
		_own_cam()
		if p.equipment.get_item("equipment") != null:
			p.unequip_gear("equipment")
	_sheet()
	print("SAVED")
	quit()


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
func _wait(secs: float) -> void:
	await create_timer(secs, true, false, true).timeout


## The 3D on the GRID, dithered, vertices snapped to match (as the game's preset does).
func _grid() -> void:
	settings.set_value("video", "pixelate", true, false)
	settings.set_value("video", "dither", true, false)
	var psx = root.get_node("PSX")
	psx._post_rect.material.set_shader_parameter("pixel_res", GRID)
	psx._post_rect.material.set_shader_parameter("pixelate", true)
	root.scaling_3d_scale = GRID.y / float(maxi(root.size.y, 1))
	var wob := clampf(float(settings.get_value("video", "wobble")), 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("psx_snap_res", GRID / lerpf(0.25, 2.0, wob))


func _frame() -> Image:
	_grid()
	_clean_blood()
	for l in current_scene.find_children("*", "Label3D", true, false):
		(l as Label3D).visible = false
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if img.get_size() != Vector2i(W, H):
		print("  (window is %s: scaled)" % img.get_size())
		img.resize(W, H, Image.INTERPOLATE_NEAREST)
	return img


func _snap(name: String) -> void:
	var img: Image = await _frame()
	img.save_jpg("%s/%s.jpg" % [out, name], 0.86)
	var small: Image = img.duplicate()
	small.resize(640, 360, Image.INTERPOLATE_BILINEAR)
	small.save_jpg("%s/%s-640.jpg" % [out, name], 0.86)
	frames.append([name, img])
	print("shot ", name)


func _burst(name: String, n: int, every: float) -> void:
	for i in range(n):
		await _snap("%s_%d" % [name, i])
		await _wait(every)


## `secs` of game time at `fps` for a GIF: <out>/clips/<name>/NNN.png on the GRID, the first frame also <name>_poster.jpg.
func _clip(name: String, secs: float, fps := 15.0) -> void:
	var dir := "%s/clips/%s" % [out, name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	# (two frames first: the grid and a camera moved this frame show from the next one)
	_grid()
	await process_frame
	await process_frame
	var t0 := t
	var n := 0
	while n < int(secs * fps):
		if t - t0 + 0.001 < n / fps:
			await process_frame
			continue
		var img: Image = await _frame()
		if n == 0:
			img.save_jpg("%s/clips/%s_poster.jpg" % [out, name], 0.86)
		img.resize(int(GRID.x), int(GRID.y), Image.INTERPOLATE_NEAREST)
		img.save_png("%s/%03d.png" % [dir, n])
		n += 1
	print("clip %s: %d frames" % [name, n])


func _time(h: float, state: int) -> void:
	w.skip_to(h)
	w.forced = state
	w.forced_at = w.world_time() - 100.0


func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


func _ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 40.0, at + Vector3.DOWN * 80.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at


## The yaw that faces world direction `d`.
func _yaw(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func _stand(at: Vector3, yaw: float) -> void:
	p.current_ship = null
	p.state_machine.force_state("Idle", {})
	p.global_position = at + Vector3.UP * 0.2
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	p.player_model.rotation.y = yaw
	rig.rotation.y = yaw


func _item(id: String):
	return load("res://resources/items/%s.tres" % id)


func _arm(main: String, off: String = "") -> void:
	p.state_machine.force_state("Idle", {})
	p.unequip_weapon()
	p.inventory_component.add_item(_item(main), 1)
	p.equip_weapon(_item(main), false)
	p.set_offhand(null)
	if off != "":
		p.inventory_component.add_item(_item(off), 1)
		p.set_offhand(_item(off))
	p.sheathe_weapon(true)
	p.draw_weapon(true)


func _learn_all() -> void:
	var pr = p.progression
	pr.level = 30
	pr.skill_points = 999
	pr.master_all()
	var grew := true
	while grew:
		grew = false
		for k in SkillTree.nodes().keys():
			if pr.can_learn(k) == "":
				pr.learn(k)
				grew = true
	pr.owned.erase("h_instinct")
	pr.owned.erase("df_instinct")


func _cast(id: String) -> void:
	if id == "heavy":
		p.state_machine.force_state("HeavyAttack", {})
		return
	var slot := 4 if Skills.is_ult(id) else 0
	pc.equip(id, slot)
	pc.energy = pc.max_energy()
	pc.ult = 100.0
	pc.cooldowns.clear()
	print("cast ", id, ": ", pc.try_cast(slot))


## No enemy ships about.
func _quiet_seas() -> void:
	for e in get_nodes_in_group("enemy_ships"):
		e.queue_free()


## The first island of the chain built for `cfg` (seed, village layout, harbour kind,
## temple; the seed's own roll for what's left out) and manned. Rebuilt only when cfg changes.
func _isle(cfg: Dictionary) -> void:
	var want_cfg := {"seed": base_seed, "village": "", "harbour": "", "temple": false}
	want_cfg.merge(cfg, true)
	if isl and want_cfg == isl_cfg:
		return
	# (the world starts the chain's first islands on load: let them finish before they go)
	while not wg.chain_ready():
		await process_frame
	for id in wg.chain_islands.keys():
		wg._free_chain_island(id)
	isl = null
	isl_cfg = want_cfg
	load("res://scripts/island/village_layouts.gd").force = want_cfg["village"]
	load("res://scripts/island/kit/kit_harbour_gen.gd").force = want_cfg["harbour"]
	load("res://scripts/island/kit/kit_dungeons.gd").force_temple = want_cfg["temple"]
	gm.chain_seed = int(want_cfg["seed"])
	var id := int(wg.chain().start_next[0])
	# (the log pose never sets: the shots jump the clock, and the islands ahead would be built)
	gm.apply_chain(id, false, w.world_time() + 1.0e9)
	await process_frame
	var t0 := t
	while (not wg.chain_ready() or not wg.chain_islands.has(id)) and t - t0 < 300.0:
		await process_frame
	isl = wg.chain_islands[id]
	var vil = _village()
	print("isle %s (seed %d, %s, %s forest, Lv %d) r %.0f: village %s, harbour %s, beast %s, interiors %s" % [isl.island_name, int(want_cfg["seed"]), isl.theme, isl.forest,
		int(isl.node["level"]), isl.radius, vil.layout, isl.harbour.kind, isl.node["beast"], isl.interiors.map(func(e): return e["kind"])])
	_quiet_seas()


## The first chain seed from base_seed whose first island's wildlife has `kind`.
func _seed_with(kind: String) -> int:
	var was: int = gm.chain_seed
	var fs = load("res://scripts/island/fauna_spawner.gd")
	var s := base_seed
	while true:
		gm.chain_seed = s
		var c = wg.chain()
		var first: Dictionary = c.node(int(c.start_next[0]))
		if fs.roll(str(first["theme"]), int(first["seed"])).has(kind):
			break
		s += 1
	gm.chain_seed = was
	wg.chain()
	return s


func _village():
	return isl.get_node("Site_village/Village")


## Island-local p, `up` m over the ground (or the sea) there, in world space.
func _ig(at: Vector2, up: float) -> Vector3:
	return isl.to_global(Vector3(at.x, maxf(isl.height_at(at.x, at.y), 0.0) + up, at.y))


## Island-local p at height y (decks, raised plazas), in world space.
func _iy(at: Vector2, y: float) -> Vector3:
	return isl.to_global(Vector3(at.x, y, at.y))


func _v3(v: Vector2) -> Vector3:
	return isl.global_basis * Vector3(v.x, 0.0, v.y)


## The sloop under full sail from `at` toward `heading`, the captain at the wheel.
func _sail(at: Vector3, heading: float) -> void:
	ship.set_anchored(false)
	ship.place(at, heading)
	ship.sail = 1.0
	ship.sail_shown = 1.0
	ship.speed = 9.0
	p.current_ship = ship
	p.global_position = ship.global_transform * Vector3(0, 2.0, 9.0)
	p.reset_physics_interpolation()
	p.state_machine.force_state("Helm", {})


## The sloop moored at the island's pier, sails furled.
func _moor() -> void:
	var m: Array = isl.mooring()
	ship.place(m[0], m[1])
	ship.set_anchored(true)
	ship.sail = 0.0
	ship.sail_shown = 0.0


## A camera riding with the ship: ship-local position and target, kept level
## (from the sea's surface, or from the hull's height for cameras on deck).
func _ride(from: Vector3, at: Vector3, deck := false) -> void:
	aim = func():
		var xf: Transform3D = ship.get_global_transform_interpolated()
		var flat := Transform3D(Basis(Vector3.UP, xf.basis.get_euler().y), Vector3(xf.origin.x, xf.origin.y if deck else 0.0, xf.origin.z))
		cam.global_position = flat * from
		cam.look_at(flat * at, Vector3.UP)


## A camera following the captain: `back` behind, `side` to the right, `up` over the
## feet, looking `ahead` along the facing at `look_up`.
func _follow(back: float, side: float, up: float, ahead: float, look_up: float) -> void:
	aim = func():
		var me: Vector3 = p.get_global_transform_interpolated().origin
		var yaw: float = p.player_model.global_rotation.y
		var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var r := Vector3(cos(yaw), 0.0, -sin(yaw))
		cam.global_position = me - f * back + r * side + Vector3.UP * up
		cam.look_at(me + f * ahead + Vector3.UP * look_up, Vector3.UP)


## Blood splats off the ground (they read as dark holes in a still).
func _clean_blood() -> void:
	var fx = root.get_node("FX")
	for n in fx._splats.duplicate():
		if is_instance_valid(n):
			fx._splats.erase(n)
			n.free()


## Points on the inland trails (paths past the road) with the thickest jungle either
## side, `n` of them at least 60 m apart: [island point, trail direction].
func _thick_spots(n: int) -> Array:
	var cands: Array = []
	for k in range(1, isl.paths.size()):
		var path: PackedVector2Array = isl.paths[k]
		for i in range(4, path.size() - 4, 3):
			var at: Vector2 = path[i]
			if isl.sites.values().any(func(s): return at.distance_to(s) < 45.0):
				continue
			var dir: Vector2 = (path[i + 3] - path[i - 3]).normalized()
			var side := Vector2(-dir.y, dir.x)
			var thick := 0.0
			for d in [-9.0, -5.0, 5.0, 9.0]:
				var q: Vector2 = at + side * d
				thick += isl.undergrowth_at(isl.to_global(Vector3(q.x, 0.0, q.y)))
			cands.append([thick, at, dir])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var picks: Array = []
	for c in cands:
		if picks.all(func(e): return (e[0] as Vector2).distance_to(c[1]) > 60.0):
			picks.append([c[1], c[2]])
		if picks.size() >= n:
			break
	return picks


## The first of the island's pirate camps' grunts that are standing.
func _grunts() -> Array:
	for camp in isl.find_children("*", "GruntCamp", true, false):
		var gs: Array = camp.grunts.filter(func(g): return is_instance_valid(g) and g.state != 14)
		if gs.size() >= 3:
			return gs
	return []


## Grunts at `spots` round `base`, staggered so they stand and take it, facing it; the rest sent off.
func _line_up(gs: Array, base: Vector3, spots: Array) -> void:
	for k in range(gs.size()):
		var g = gs[k]
		if k < spots.size():
			g.humanoid.seated = false
			g.global_position = _ground(base + spots[k]) + Vector3.UP * 0.3
			g.velocity = Vector3.ZERO
			g.reset_physics_interpolation()
			g._stagger_len = 30.0
			g._set_state(STAGGER)
			g.health.current_health = 900.0
			var to: Vector3 = base - g.global_position
			g._yaw = atan2(-to.x, -to.z)
			g.facing.rotation.y = g._yaw
		else:
			g.global_position = _ground(base + Vector3(60 + k * 3, 0, 60))
			g.reset_physics_interpolation()


## A fight's stage on open ground near the island's pirate camp: [base, facing f, right r].
func _fight_stage() -> Array:
	var cp: Vector2 = isl.sites["camp"]
	var to_v: Vector2 = (isl.sites["village"] - cp).normalized()
	var base := _ground(_ig(cp + to_v * 15.0, 0.0))
	var f := _v3(-to_v.rotated(0.6))
	return [base, f, Vector3.UP.cross(f).normalized() * -1.0]


# --------------------------------------------------------------------------
# Shots
# --------------------------------------------------------------------------
## The sloop under full sail at golden hour, the chain island on the horizon.
func _shot_hero() -> void:
	await _isle(MAIN)
	_time(17.35, 0)
	var c := Vector3(isl.global_position.x, 0.0, isl.global_position.z)
	# the island lies west, under the low sun: she sails into it, then away from it
	var d := Vector3(1, 0, 0.12).normalized()
	_sail(c + d * (isl.radius + 240.0), atan2(d.x, d.z))
	await _wait(7.0)
	var views := [["in_a", Vector3(10, 4.0, 40), Vector3(-5, 5.0, -40)], ["in_b", Vector3(-11, 3.0, 38), Vector3(5, 5.0, -40)],
		["in_c", Vector3(6, 1.8, 24), Vector3(-3, 6.0, -20)], ["in_d", Vector3(22, 12.0, 62), Vector3(-6, 2.0, -60)]]
	for v in views:
		_ride(v[1], v[2])
		await _wait(0.15)
		await _snap("hero_%s" % v[0])
	_sail(c + d * (isl.radius + 120.0), atan2(-d.x, -d.z))
	await _wait(7.0)
	views = [["out_a", Vector3(-14, 3.0, -46), Vector3(2, 5.0, 10)], ["out_b", Vector3(16, 2.2, -40), Vector3(-3, 6.0, 10)],
		["out_c", Vector3(13, 1.6, -30), Vector3(-5, 6.5, 8)]]
	for v in views:
		_ride(v[1], v[2])
		await _wait(0.15)
		await _snap("hero_%s" % v[0])


## The jungle floor under the canopy in the morning: the captain on an overgrown trail, the thick of it either side.
func _shot_jungle() -> void:
	await _isle(MAIN)
	_time(8.6, 0)
	var i := 0
	for e in _thick_spots(3):
		var f := _v3(e[1])
		var r := Vector3.UP.cross(f).normalized() * -1.0
		_stand(_ig(e[0], 0.0), _yaw(f))
		_arm("cutlass")
		p.sheathe_weapon(true)
		await _wait(1.2)
		var me: Vector3 = p.global_position
		_look(me - f * 3.4 + r * 1.2 + Vector3.UP * 1.3, me + f * 7.0 + Vector3.UP * 1.9)
		await _wait(0.3)
		await _snap("jungle_%d_back" % i)
		_look(me + f * 6.5 + r * 1.6 + Vector3.UP * 0.9, me + Vector3.UP * 1.6)
		await _wait(0.3)
		await _snap("jungle_%d_front" % i)
		_look(me + r * 9.0 + f * 2.0 + Vector3.UP * 0.6, me + Vector3.UP * 3.5 - r * 4.0)
		await _wait(0.3)
		await _snap("jungle_%d_up" % i)
		i += 1


## The stilt village at golden hour: from over the road in, from the plaza's deck, under it.
func _shot_stilts() -> void:
	await _isle(MAIN)
	_time(17.2, 0)
	var vil = _village()
	var c: Vector2 = vil.plaza["c"]
	var hy: float = vil.plaza["y"] if vil.plaza["y"] != INF else isl.height_at(c.x, c.y)
	var td: Vector2 = (isl.sites["dock"] - c).normalized()
	var sd := Vector2(-td.y, td.x)
	_stand(_iy(c + td * 4.0 + sd * 2.0, hy), _yaw(_v3(-td)))
	p.sheathe_weapon(true)
	await _wait(2.0)
	_look(_ig(c + td * 55.0 + sd * 20.0, 34.0), _ig(c - td * 10.0, 0.0))
	await _wait(0.6)
	await _snap("stilts_aerial")
	_look(_ig(c + td * 34.0 - sd * 14.0, 9.0), _iy(c, hy + 1.0))
	await _wait(0.4)
	await _snap("stilts_road")
	_look(_iy(c + td * 11.0 + sd * 6.0, hy + 1.7), _iy(c - td * 6.0 - sd * 3.0, hy + 1.6))
	await _wait(0.4)
	await _snap("stilts_deck")
	_look(_ig(c + sd * 13.0 + td * 3.0, 1.6), _ig(c - sd * 4.0, 2.0))
	await _wait(0.4)
	await _snap("stilts_under")


## A harbour from the sea, from above and along the beach at `hour`, the sloop at the pier.
func _shot_harbour(tag: String, cfg: Dictionary, hour: float) -> void:
	await _isle(cfg)
	_time(hour, 0)
	_moor()
	var hb = isl.harbour
	var dock: Vector2 = isl.dock_shore
	var dd: Vector2 = isl.dock_dir
	var side := Vector2(-dd.y, dd.x)
	var de: Vector2 = isl.sites["dock_end"]
	_stand(_iy(de - dd * 6.0, 1.75), _yaw(_v3(-dd)))
	p.sheathe_weapon(true)
	await _wait(2.0)
	_look(_ig(de + dd * 55.0 - side * 30.0, 13.0), _ig(dock - dd * 10.0, 2.0))
	await _wait(0.4)
	await _snap("%s_sea" % tag)
	_look(_ig(de + dd * 40.0 + side * 45.0, 6.0), _ig(dock - dd * 6.0 - side * 10.0, 3.0))
	await _wait(0.4)
	await _snap("%s_sea_low" % tag)
	_look(_ig(dock + dd * 32.0 + side * 6.0, 58.0), _ig(dock - dd * 14.0, 0.0))
	await _wait(0.4)
	await _snap("%s_above" % tag)
	_look(_ig(hb.at(-34.0, 6.0), 2.2), _ig(hb.at(14.0, -2.0), 1.5))
	await _wait(0.4)
	await _snap("%s_beach" % tag)


## The island's tallest sea cliff from the water at mid-morning, the sloop sailing past under it.
func _cliff() -> Array:
	var dock: Vector2 = isl.sites["dock"]
	var best: Array = []
	for c in isl.coast_cols:
		if (c[0] as Vector2).distance_to(dock) > 150.0 and (best.is_empty() or float(c[1]) > float(best[1])):
			best = c
	return best


func _shot_cliffs() -> void:
	await _isle(MAIN)
	_time(10.4, 0)
	var c := _cliff()
	var at: Vector2 = c[0]
	var o: Vector2 = c[2]
	var along := Vector2(-o.y, o.x)
	var start: Vector2 = at + o * 40.0 - along * 50.0
	var go := _v3(along)
	_sail(_iy(start, 0.0), atan2(-go.x, -go.z))
	await _wait(5.5)
	var xw: Vector3 = ship.global_basis.x
	var away := -signf(xw.dot(_v3(-o)))
	_ride(Vector3(away * 26.0, 4.0, 14.0), Vector3(-away * 20.0, 7.0, -10.0))
	await _wait(0.2)
	await _snap("cliffs_ride")
	aim = Callable()
	_look(_ig(at + o * 95.0 + along * 30.0, 9.0), _ig(at + o * 10.0, float(c[1]) * 0.45))
	await _wait(0.3)
	await _snap("cliffs_wide")
	_look(_ig(at + o * 14.0 + along * 12.0, 1.4), Vector3(isl.to_global(Vector3(at.x, float(c[1]) * 0.7, at.y))))
	await _wait(0.3)
	await _snap("cliffs_foot")


## The sandy shelf off a beach at midday: turquoise over the sand, the jungle behind.
func _shot_shelf() -> void:
	await _isle(MAIN)
	_time(11.5, 0)
	var e := _beach(0.0)
	var shore: Vector2 = e[0]
	var dir: Vector2 = e[1]
	var across := Vector2(-dir.y, dir.x)
	_stand(_ig(shore + dir * 6.0, 0.0), _yaw(_v3(-dir)))
	_arm("cutlass")
	p.sheathe_weapon(true)
	await _wait(1.5)
	_look(_ig(shore + dir * 70.0 + across * 30.0, 14.0), _ig(shore - dir * 6.0, 0.0))
	await _wait(0.3)
	await _snap("shelf_out")
	_look(_ig(shore + dir * 16.0 + across * 5.0, 1.5), _ig(shore - dir * 18.0, 3.0))
	await _wait(0.3)
	await _snap("shelf_wade")


## The first beach (no sea cliff near, away from the dock) round the island from bearing `from`: [waterline, out].
func _beach(from: float) -> Array:
	var dock: Vector2 = isl.sites["dock"]
	var r: float = isl.radius
	for k in range(36):
		var dir := Vector2.from_angle(from + k * TAU / 36.0)
		var wl := r * 0.4
		while wl < r + 40.0 and isl.height_at(dir.x * wl, dir.y * wl) > 0.0:
			wl += 1.0
		var shore := dir * wl
		if shore.distance_to(dock) < 120.0 or isl.coast_cols.any(func(c): return (c[0] as Vector2).distance_to(shore) < 70.0):
			continue
		return [shore, dir]
	return []


## The Silverback in its arena, awake and ready to take to the trees, the captain facing it: [ape, way in].
func _ape_up() -> Array:
	var arena = load("res://scripts/island/beast_arena.gd").rebuild(isl, "ape")
	var ape = arena.boss
	var c: Vector3 = arena.global_position
	var to_v: Vector3 = _v3((isl.sites["village"] - isl.sites["boss"]).normalized())
	_arm("katana")
	_stand(_ground(c + to_v * 8.0), _yaw(-to_v))
	await _wait(1.0)
	ape.alert()
	await _wait(0.4)
	ape._special = ""
	ape._set_state(2)
	ape._cd = {"swipe": 99.0, "slam": 99.0, "leap": 99.0, "throw": 99.0, "canopy": 99.0}
	ape.phase = 2
	return [ape, to_v]


## The Silverback bounding up into the canopy over the captain.
func _shot_canopy() -> void:
	await _isle(MAIN)
	_time(15.8, 0)
	var e: Array = await _ape_up()
	var ape = e[0]
	var to_v: Vector3 = e[1]
	var r := Vector3.UP.cross(to_v).normalized()
	var me: Vector3 = p.global_position
	var a0: Vector3 = ape.global_position
	var back := Vector3(me.x - a0.x, 0.0, me.z - a0.z).normalized()
	aim = func():
		cam.global_position = me + back * 4.6 + r * 3.6 + Vector3.UP * 0.35
		cam.look_at(ape.global_position.lerp(me, 0.3) + Vector3.UP * 2.0, Vector3.UP)
	ape._begin_special("climb")
	await _wait(0.6)
	await _burst("canopy_leap", 5, 0.12)


## The other jungle bosses mid-move: the Strangler rising and coiling, the Shade's pounce, the Mantis Queen's display and scythes.
func _shot_beasts() -> void:
	await _isle(MAIN)
	_time(16.6, 0)
	# [kind, move, look (the orchid mantis: the leaf one vanishes into the jungle), wait]
	for e in [["serpent", "rise", 0, 0.5], ["serpent", "coil", 0, 1.0], ["stalker", "pounce", 0, 0.7], ["mantis", "display", 1, 0.6], ["mantis", "scythe", 1, 0.5]]:
		var arena = load("res://scripts/island/beast_arena.gd").rebuild(isl, str(e[0]), int(e[2]))
		var boss = arena.boss
		var c: Vector3 = arena.global_position
		var to_v: Vector3 = _v3((isl.sites["village"] - isl.sites["boss"]).normalized())
		_arm("cutlass" if e[0] != "mantis" else "katana")
		_stand(_ground(c + to_v * 8.5), _yaw(-to_v))
		await _wait(1.0)
		boss.alert()
		await _wait(0.6)
		p.health_component.current_health = 99999.0
		boss.end_move()
		boss._set_state(1)
		boss.film(str(e[1]))
		var me: Vector3 = p.global_position
		aim = func():
			var a: Vector3 = boss.global_position
			var back := Vector3(me.x - a.x, 0.0, me.z - a.z).normalized()
			var side := Vector3.UP.cross(back).normalized()
			cam.global_position = me + back * 4.4 - side * 3.0 + Vector3.UP * 0.7
			cam.look_at(a.lerp(me, 0.35) + Vector3.UP * 1.6, Vector3.UP)
		await _wait(float(e[3]))
		await _burst("beast_%s_%s" % [e[0], e[1]], 4, 0.18)
		aim = Callable()
	load("res://scripts/island/beast_arena.gd").rebuild(isl, "ape")


## Wildlife in the morning: a boar herd, toucans and monkeys in the crowns, crabs on the shore.
func _shot_fauna() -> void:
	await _isle(MAIN)
	_time(9.0, 0)
	var fs = isl.get_node("Fauna")
	print("fauna: ", fs.pool)
	for k in ["boar", "toucan", "monkey", "crab", "snake"]:
		var gs: Array = fs.groups_of(k)
		if gs.is_empty():
			continue
		var g: Dictionary = gs[0]
		var c = fs.spots[int(g["spots"][0])]["node"]
		if c == null or not is_instance_valid(c):
			continue
		var at: Vector3 = c.global_position
		var dir := Vector3(isl.global_position.x - at.x, 0.0, isl.global_position.z - at.z).normalized()
		# under its tree for the canopy's creatures (they come down at you), a few strides off for the rest
		var high: bool = k in ["toucan", "monkey"]
		_arm("cutlass")
		_stand(_ground(Vector3(at.x, 0.0, at.z) + dir * (1.5 if high else 6.0)), _yaw(-dir))
		await _wait(6.0 if high else 2.0)
		print("  %s at %s (captain %s)" % [k, c.global_position if is_instance_valid(c) else at, p.global_position])
		var me: Vector3 = p.global_position
		# over the captain's shoulder (the ground under the camera is the captain's)
		var side := Vector3.UP.cross(dir).normalized()
		aim = func():
			var a: Vector3 = c.global_position if is_instance_valid(c) else at
			var back := Vector3(me.x - a.x, 0.0, me.z - a.z).normalized()
			cam.global_position = me + back * 2.6 + side * 0.9 + Vector3.UP * 1.5
			cam.look_at(a.lerp(me, 0.3) + Vector3.UP * 0.5, Vector3.UP)
		await _wait(0.2)
		await _burst("fauna_%s" % k, 3, 0.4)
		aim = Callable()


## A bat roost at dusk: the colony out round its crown.
func _shot_bats() -> void:
	await _isle({"seed": _seed_with("bat")})
	_time(19.9, 0)
	var fs = isl.get_node("Fauna")
	var gs: Array = fs.groups_of("bat").filter(func(g): return g["zone"] == "canopy")
	if gs.is_empty():
		print("no bat roost on this island")
		return
	var at: Vector3 = fs.to_global(gs[0]["at"])
	var dir := Vector3(isl.global_position.x - at.x, 0.0, isl.global_position.z - at.z).normalized()
	_stand(_ground(Vector3(at.x, 0.0, at.z) + dir * 6.0), _yaw(-dir))
	await _wait(4.0)
	var side := Vector3.UP.cross(dir).normalized()
	_look(_ground(Vector3(at.x, 0.0, at.z) + dir * 12.0 + side * 3.0) + Vector3.UP * 1.2, at + Vector3.DOWN * 2.0)
	await _burst("bats", 3, 0.3)


## Daggers at the pirates' camp in the late afternoon: Hundred Fangs, Red Eclipse, Shadow Lunge.
func _shot_daggers() -> void:
	await _isle(MAIN)
	_time(14.6, 0)
	var st := _fight_stage()
	var base: Vector3 = st[0]
	var f: Vector3 = st[1]
	var r: Vector3 = st[2]
	for e in [["hundred_fangs", "dagger", "dagger", 0.5], ["red_eclipse", "dagger", "", 0.4], ["heavy", "dagger", "", 0.12]]:
		_stand(base, _yaw(f))
		_arm(str(e[1]), str(e[2]))
		_line_up(_grunts(), base, [f * 3.2, f * 4.6 + r * 2.2, f * 5.6 + r * 0.2])
		await _wait(0.8)
		var mid := base + f * 2.6
		_cast(str(e[0]))
		await _wait(float(e[3]))
		for i in range(8):
			var far := i % 2 == 1
			var at: Vector3 = p.global_position.lerp(mid, 0.4)
			at.y = mid.y
			_look(at - r * (7.5 if far else 5.5) + f * (0.6 if far else -1.0) + Vector3.UP * (1.2 if far else 0.7), at + Vector3.UP * 1.1)
			await _snap("daggers_%s_%d" % [e[0], i])
			await _wait(0.12)
		await _wait(2.0)


## A walled trading post: the gate from the road outside, the post from over its wall.
func _shot_post() -> void:
	await _isle(POST)
	_time(16.4, 0)
	var vil = _village()
	var c: Vector2 = vil.plaza["c"]
	var gates: Array = isl.find_children("Gate*", "", true, false)
	var gp: Vector3 = isl.to_local(gates[0].global_position)
	var g2 := Vector2(gp.x, gp.z)
	var away: Vector2 = (g2 - c).normalized()
	var across := Vector2(-away.y, away.x)
	_stand(_ig(g2 + away * 5.0, 0.0), _yaw(_v3(-away)))
	p.sheathe_weapon(true)
	await _wait(2.0)
	_look(_ig(g2 + away * 16.0 + across * 4.0, 1.7), isl.to_global(gp + Vector3(0, 3.0, 0)))
	await _wait(0.4)
	await _snap("post_gate")
	_look(_ig(g2 + away * 34.0 - across * 18.0, 22.0), _ig(c, 0.0))
	await _wait(0.4)
	await _snap("post_aerial")
	_look(_ig(c + across * 9.0 + away * 4.0, 1.7), _ig(c - across * 6.0 - away * 2.0, 1.4))
	await _wait(0.4)
	await _snap("post_market")


## A town by night: the plaza round its fire, a lane of lit windows, the town from over the road.
func _shot_town() -> void:
	await _isle(TOWN)
	_time(21.2, 0)
	var vil = _village()
	var c: Vector2 = vil.plaza["c"]
	var td: Vector2 = (isl.sites["dock"] - c).normalized()
	var sd := Vector2(-td.y, td.x)
	_stand(_ig(c + td * 7.0 + sd * 2.0, 0.0), _yaw(_v3(-td)))
	p.sheathe_weapon(true)
	await _wait(3.0)
	_look(_ig(c + td * 13.0 - sd * 5.0, 1.7), _ig(c - td * 4.0, 1.8))
	await _wait(0.4)
	await _snap("town_plaza")
	_look(_ig(c + td * 6.0 + sd * 8.0, 1.2), _ig(c - td * 3.0 - sd * 3.0, 2.0))
	await _wait(0.4)
	await _snap("town_fire")
	if not vil.lanes.is_empty():
		var l: PackedVector2Array = vil.lanes[0]
		_look(_ig(l[mini(4, l.size() - 1)], 1.7), _ig(l[mini(l.size() - 1, l.size() / 2 + 4)], 1.6))
		await _wait(0.4)
		await _snap("town_lane")
	_look(_ig(c + td * 50.0 + sd * 22.0, 30.0), _ig(c - td * 8.0, 0.0))
	await _wait(0.4)
	await _snap("town_aerial")


## A cave: the captain at its mouth in the afternoon, a room from its doorway, the end room's reward.
func _shot_cave() -> void:
	await _isle(TOWN)
	_time(16.2, 0)
	var KD = load("res://scripts/island/kit/kit_dungeons.gd")
	var caves: Array = isl.interiors.filter(func(e): return e["kind"] != "temple")
	var e: Dictionary = caves[0]
	var d = isl.get_node(str(e["name"]))
	var o: Vector2 = e["mouth_dir"]
	var o3 := Vector3(o.x, 0.0, o.y)
	var side := o3.cross(Vector3.UP)
	var m: Vector3 = d.to_global(KD.loc(e, e["mouth"], e["mouth_y"]))
	_arm("cutlass")
	_stand(_ground(m + o3 * 3.0), _yaw(-o3))
	await _wait(2.5)
	_look(m + o3 * 9.0 + side * 3.5 + Vector3.UP * 2.2, m + Vector3.UP * 1.6)
	await _wait(0.4)
	await _snap("cave_%s_mouth" % e["kind"])
	for rm in e["rooms"]:
		var rc: Vector3 = d.to_global(KD.loc(e, rm["c"], rm["y"]))
		var door: Vector3 = d.to_global(KD.loc(e, rm["doors"][0], rm["y"]))
		var back := (door - rc).normalized()
		_stand(_ground(door - back * 1.5), _yaw(-back))
		await _wait(1.0)
		_look(door + back * 1.5 + Vector3.UP * 2.0, rc + Vector3.UP * 0.8 - back * float(rm["r"]) * 0.4)
		await _wait(0.4)
		await _snap("cave_%s_%s" % [e["kind"], rm["role"]])


## The ruined temple: its stair at golden hour, the hall, the sanctum once both levers are pulled.
func _shot_temple() -> void:
	await _isle(TOWN)
	_time(17.6, 0)
	var KT = load("res://scripts/island/kit/kit_temple.gd")
	var e: Dictionary = isl.interiors.filter(func(x): return x["kind"] == "temple")[0]
	var d = isl.get_node(str(e["name"]))
	var front := float(KT.PLINTH[3]) + float(e["stair_len"])
	_arm("katana")
	_stand(_ground(d.to_global(Vector3(0, 2, front + 3.0))), d.global_rotation.y)
	await _wait(2.5)
	_look(d.to_global(Vector3(8, 3, front + 15)), d.to_global(Vector3(0, 4.0, 2)))
	await _wait(0.4)
	await _snap("temple_front")
	_look(d.to_global(Vector3(-34, 28, front + 22)), d.to_global(Vector3(0, 2, -6)))
	await _wait(0.4)
	await _snap("temple_above")
	_stand(_ground(d.to_global(Vector3(0, 2, 3.0))), d.global_rotation.y)
	await _wait(1.0)
	_look(d.to_global(Vector3(0.8, 1.9, 8.0)), d.to_global(Vector3(0, 1.6, -8)))
	await _wait(0.4)
	await _snap("temple_hall")
	d.net_pull(0)
	d.net_pull(1)
	await _wait(2.8)
	_stand(_ground(d.to_global(Vector3(0, 2, -9.0))), d.global_rotation.y)
	await _wait(1.0)
	_look(d.to_global(Vector3(0.6, 2.0, -5.0)), d.to_global(Vector3(0, 1.0, -18)))
	await _wait(0.4)
	await _snap("temple_sanctum")


## The Sea King rearing over the sloop in a storm, lightning behind it.
func _shot_seaking() -> void:
	_quiet_seas()
	_time(17.0, 3)
	var sk = get_first_node_in_group("sea_kings")
	ship.set_anchored(false)
	ship.place(Vector3(sk.lair.x + 60.0, 0.0, sk.lair.y), 0.0)
	await _wait(0.3)
	p.current_ship = ship
	p.state_machine.force_state("Idle", {})
	p.global_position = ship.global_transform * Vector3(0, 0.8, 2.0)
	p.reset_physics_interpolation()
	var view := Vector3(-26.0, 3.5, 20.0)
	aim = func():
		var at: Vector3 = ship.global_position.lerp(sk.head_position(), 0.6)
		cam.global_position = ship.global_transform * view
		cam.look_at(at + Vector3(0, 3, 0), Vector3.UP)
	await _wait(5.0)
	sk._next = 999.0
	sk._start_rear(ship)
	await _wait(0.75)
	for i in range(6):
		view = Vector3(-26.0, 3.5, 20.0) if i < 3 else Vector3(-15.0, 1.8, 13.0)
		if i % 3 == 1:
			var behind: Vector3 = sk.head_position() + (sk.head_position() - cam.global_position).normalized() * 160.0
			w._strike(Vector3(behind.x, 0, behind.z), 160.0, 7 + i)
			await process_frame
		await _snap("seaking_%d" % i)
		await _wait(0.15)
		if i == 2:
			sk._start_rear(ship)
			await _wait(0.75)


## Three captains on the deck under sail at golden hour (two of them co-op puppets).
func _shot_coop() -> void:
	await _isle(MAIN)
	_time(17.4, 0)
	var net = root.get_node("Net")
	net.my_info = {"name": "Captain"}
	net.host_game(24997)
	var names := ["Mara", "Tobin"]
	for i in range(2):
		var rng := RandomNumberGenerator.new()
		rng.seed = 5 + i * 7
		var lk: Dictionary = load("res://scripts/npc/character_look.gd").random_look(rng)
		lk["name"] = names[i]
		net.roster[i + 2] = {"name": names[i], "look": lk}
		net._spawn_puppet(i + 2, {"name": names[i], "look": lk})
		pups[i + 2] = [net.players[i + 2], [Vector3(-2.2, DECK, -2.0), Vector3(2.2, DECK, -1.6)][i], [-0.25, 0.3][i]]
	# sailing west into the low sun: faces forward lit warm, the sail behind them
	var c := Vector3(isl.global_position.x, 0.0, isl.global_position.z)
	var d := Vector3(1, 0, 0.12).normalized()
	ship.place(c + d * (isl.radius + 420.0), atan2(d.x, d.z))
	ship.set_anchored(true)
	ship.sail = 1.0
	ship.sail_shown = 1.0
	await _wait(0.3)
	p.state_machine.force_state("Idle", {})
	p.current_ship = ship
	p.global_position = ship.global_transform * Vector3(0.0, DECK + 0.3, -3.6)
	p.reset_physics_interpolation()
	p.player_model.rotation.y = ship.global_rotation.y
	_arm("cutlass")
	await _wait(3.0)
	_ride(Vector3(0.9, DECK + 1.25, -8.0), Vector3(0, DECK + 1.5, -1.0), true)
	await _wait(0.5)
	await _snap("coop_a")
	_ride(Vector3(-3.6, DECK + 2.4, -8.2), Vector3(0.5, DECK + 1.2, -1.5), true)
	await _wait(0.3)
	await _snap("coop_b")
	pups.clear()
	net.leave()


## Co-op puppets: a fresh snapshot every frame, standing on the deck, swords out.
func _feed() -> void:
	if pups.is_empty():
		return
	var net = root.get_node("Net")
	for id in pups.keys():
		var e: Array = pups[id]
		var pup = e[0]
		var hum: Array = load("res://scripts/net/humanoid_sync.gd").pack(pup.body_model)
		hum[0] = 0.0
		hum[4] = true
		hum[6] = "sword"
		var n: int = hum.size() - 4
		hum[n] = "cutlass"
		hum[n + 2] = true
		var snap := [e[1], net.key_of(ship), Vector3.ZERO, float(e[2]), Basis(), "Idle", 140.0, 160.0, 4, hum, Vector3.INF, []]
		net._push(net.key_of(pup), net.time() - 0.05, snap)
		net._push(net.key_of(pup), net.time(), snap)


# --------------------------------------------------------------------------
# 1.18: Charted Waters
# --------------------------------------------------------------------------
func _brine():
	return wg.starter_island


## The stand-in camera back in charge (the held map hands it to the game's).
func _own_cam() -> void:
	own_cam = true
	cam.current = true


func _game_cam(yaw: float) -> void:
	own_cam = false
	cam.current = false
	var prig = current_scene.find_child("CameraRig", true, false)
	prig.rotation.y = yaw
	(get_first_node_in_group("player_camera") as Camera3D).current = true


## (by path: the class touches autoloads, and this script compiles before they're up)
func _fishing():
	return load("res://scripts/fishing/fishing.gd")


func _rod(tier: String) -> void:
	var it = ItemDB.get_item(Rods.item_id(tier))
	p.inventory_component.add_item(it, 1)
	p.equip_gear_from_bag(p.inventory_component.find_index(it.id))


func _fish_state():
	return p.state_machine.get_node("Fish")


## The captain at the end of Brinehollow's side pier k, facing out to sea with a rod: [where, out].
func _fish_stand(k: int) -> Array:
	var bi = _brine()
	var piers: Array = load("res://scripts/island/brinehollow_harbour.gd").side_piers(bi)
	var e: Array = piers[k % piers.size()]
	var o: Vector2 = e[1]
	var at := _ground(bi.to_global(Vector3(e[0].x + o.x * (float(e[2]) - 1.1), 0.0, e[0].y + o.y * (float(e[2]) - 1.1))))
	var f: Vector3 = bi.global_basis * Vector3(o.x, 0.0, o.y)
	_stand(at, _yaw(f))
	_rod("driftwood")
	print("pier %d of %d at %s, out %s" % [k, piers.size(), at, f])
	return [at, f]


## Line out: cast, then the float held on the waves with nothing biting.
func _line_out() -> bool:
	var why: String = _fishing().refuse(p)
	if why != "":
		print("  can't cast: ", why)
		return false
	p.fish()
	await _wait(_fishing().CAST_LEN + 0.15)
	_fish_state()._bite_at = 999.0
	_fish_state()._nibbles.clear()
	return true


func _fish_view(v: String, me: Vector3, f: Vector3) -> void:
	var r := Vector3.UP.cross(f).normalized() * -1.0
	match v:
		"back":
			_look(me - f * 3.0 + r * 1.3 + Vector3.UP * 1.9, me + f * 7.0 + Vector3.UP * 0.1)
		"quarter":
			_look(me - f * 2.4 - r * 3.4 + Vector3.UP * 1.5, me + f * 4.0 - r * 0.6 + Vector3.UP * 0.5)
		"face":
			_look(me + f * 2.6 - r * 3.4 + Vector3.UP * 1.1, me + f * 2.2 + Vector3.UP * 0.8)
		"face_wide":
			cam.fov = 60.0
			_look(me + f * 3.5 - r * 6.5 + Vector3.UP * 1.2, me + f * 4.7 + Vector3.UP * 0.5)
		"catch":
			_look(me + f * 2.2 - r * 2.3 + Vector3.UP * 1.3, me + f * 0.6 + Vector3.UP * 1.2)
		"along":
			# from out past the float, looking back along the line at the captain and the harbour
			cam.fov = 42.0
			var c := me + f * 12.5 - r * 2.8
			_look(Vector3(c.x, me.y + 0.2, c.z), me + f * 5.5 + Vector3.DOWN * 0.6)
		"along_low":
			cam.fov = 44.0
			var c := me + f * 8.5 - r * 2.8
			_look(Vector3(c.x, me.y - 0.3, c.z), me + f * 3.0 + Vector3.UP * 0.9)
		"front":
			var c := me + f * 13.0 + r * 2.6
			_look(Vector3(c.x, 1.1, c.z), me + Vector3.UP * 0.9)
		"side":
			cam.fov = 62.0
			_look(me + r * 5.5 - f * 1.0 + Vector3.UP * 1.0, me + f * 5.0 + Vector3.UP * 0.4)


## Fishing off Brinehollow's side piers at golden hour: the line out to the float, then the bite.
func _shot_fishing() -> void:
	_time(17.4, 0)
	for k in [0]:
		var e := _fish_stand(k)
		await _wait(2.0)
		var cast: bool = await _line_out()
		if not cast:
			continue
		await _wait(1.2)
		var me: Vector3 = p.global_position
		for v in ["face", "along", "along_low"]:
			_fish_view(v, me, e[1])
			await _wait(0.2)
			await _snap("fishing_%d_%s" % [k, v])
			cam.fov = 50.0
		_fish_state()._bite_at = _fish_state()._t
		await _wait(0.3)
		for v in ["along", "along_low"]:
			_fish_view(v, me, e[1])
			await _snap("fishing_%d_bite_%s" % [k, v])
			cam.fov = 50.0
		p.state_machine.force_state("Idle", {})
		await _wait(0.5)


## Brinehollow's dive spot whose name starts with `prefix` (null: none).
func _dive_spot(prefix: String):
	var holder = get_first_node_in_group("dive_sites").get_node("Dive_brinehollow")
	for c in holder.get_children():
		if str(c.name).begins_with(prefix):
			return c
	return null


## The captain diving, held at `at` facing `d` (the swim state would drift them up).
func _diver(at: Vector3, d: Vector3) -> void:
	p.current_ship = null
	p.global_position = at
	p.reset_physics_interpolation()
	p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
	var sw = p.state_machine.get_node("Swim")
	sw._diving = true
	p.body_model.diving = true
	p.player_model.rotation.y = _yaw(d)
	rig.rotation.y = _yaw(d)
	aim = func():
		p.global_position = at
		p.velocity = Vector3.ZERO


## A look from `from` (kept under the waves) at `at`, the diver pinned where they are.
func _under_look(from: Vector3, at: Vector3, pin: Vector3) -> void:
	aim = func():
		p.global_position = pin
		p.velocity = Vector3.ZERO
		cam.global_position = Vector3(from.x, minf(from.y, float(p.water_surface(from)) - 0.7), from.z)
		cam.look_at(at, Vector3.UP)


## The captain swimming at the surface `back` m out to sea of `c` (the reef's rocks are on its landward
## side), facing in; returns the way in (toward the island).
func _dive_at_sea(c: Vector3, back: float) -> Vector3:
	var bc: Vector3 = _brine().global_position
	var d := Vector3(bc.x - c.x, 0.0, bc.z - c.z).normalized()
	var start := c - d * back
	p.current_ship = null
	p.global_position = Vector3(start.x, float(p.water_surface(start)) - 1.3, start.z)
	p.reset_physics_interpolation()
	p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
	p.player_model.rotation.y = _yaw(d)
	rig.rotation.y = _yaw(d)
	await _wait(1.0)
	return d


## Ctrl held, the duck dive started by hand (it reads a just-pressed Ctrl in the physics tick, which a press
## from here can miss).
func _duck_dive() -> void:
	Input.action_press("dodge")
	var sw = p.state_machine.get_node("Swim")
	sw._diving = true
	sw._dive_t = 0.0
	sw._vy = -sw.DIVE_KICK


## Under water at midday: swimming in over Brinehollow's reef (a dolphin kick), then held over the reef, its sunken
## chest and the oyster beds.
func _shot_dive() -> void:
	_time(12.0, 0)
	var reef = _dive_spot("Reef_")
	var c: Vector3 = reef.global_position
	var d: Vector3 = await _dive_at_sea(c, 9.0)
	var side := Vector3.UP.cross(d).normalized()
	_duck_dive()
	var t0 := t
	while p.global_position.y > c.y + 1.6 and t - t0 < 5.0:
		p.stamina = p.max_stamina
		await process_frame
	Input.action_release("dodge")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	aim = func():
		var me: Vector3 = p.get_global_transform_interpolated().origin
		var at := me - side * 3.4 + d * 1.6 + Vector3.DOWN * 0.5
		cam.global_position = Vector3(at.x, minf(at.y, float(p.water_surface(at)) - 0.6), at.z)
		cam.look_at(me + d * 0.6 + Vector3.UP * 0.4, Vector3.UP)
	await _wait(0.5)
	for i in range(4):
		p.stamina = p.max_stamina
		await _snap("dive_swim_%d" % i)
		await _wait(0.2)
	for a in ["move_forward", "sprint"]:
		Input.action_release(a)
	aim = Callable()
	for e in [["reef", "Reef_"], ["chest", "Chest_dive_chest"], ["oysters", "Oysters_"]]:
		var spot = _dive_spot(str(e[1]))
		var sc: Vector3 = spot.global_position
		var sd := Vector3(1, 0, 0.3).normalized()
		var ss := Vector3.UP.cross(sd).normalized()
		var at := sc - sd * 1.6 + Vector3.UP * 1.3
		print("%s at %s, %.1f m down" % [e[0], sc, float(p.water_surface(sc)) - sc.y])
		_diver(at, sd)
		await _wait(0.4)
		_under_look(at - sd * 3.4 + ss * 1.6 + Vector3.UP * 1.4, at + sd * 1.6 + Vector3.UP * 0.2, at)
		await _wait(1.4)
		await _snap("dive_%s_back" % e[0])
		_under_look(sc + ss * 3.8 + sd * 1.2 + Vector3.UP * 0.4, at + Vector3.UP * 0.9, at)
		await _wait(0.8)
		await _snap("dive_%s_up" % e[0])
		_under_look(at + sd * 3.6 + ss * 1.2 + Vector3.UP * 1.0, at + Vector3.UP * 0.6, at)
		await _wait(0.8)
		await _snap("dive_%s_front" % e[0])
		aim = Callable()


## The shark at Brinehollow's wreck come up with its fin out round a swimmer, from just over the waves and from under them.
func _shot_shark() -> void:
	_time(17.6, 0)
	var shark = get_first_node_in_group("sea_threats").find_child("Shark0", true, false)
	var to: Vector3 = shark.home + Vector3(9.0, 0.0, 0.0)
	p.current_ship = null
	p.global_position = Vector3(to.x, float(p.water_surface(to)) - 1.3, to.z)
	p.reset_physics_interpolation()
	p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
	shark.global_position = shark.home + Vector3(-8.0, 0.0, 0.0)
	shark.reset_physics_interpolation()
	aim = func():
		var me: Vector3 = p.get_global_transform_interpolated().origin
		var s: Vector3 = shark.get_global_transform_interpolated().origin
		var back := Vector3(me.x - s.x, 0.0, me.z - s.z).normalized()
		var c := me + back * 3.2 + Vector3.UP.cross(back) * 3.4
		cam.global_position = Vector3(c.x, float(p.water_surface(c)) + 1.7, c.z)
		cam.look_at(me.lerp(s, 0.55) + Vector3.UP * 1.1, Vector3.UP)
	var t0 := t
	while int(shark.state) != int(shark.S.NOTICE) and t - t0 < 8.0:
		await process_frame
	await _wait(2.6)
	await _burst("shark_fin", 6, 0.3)
	aim = func():
		var me: Vector3 = p.get_global_transform_interpolated().origin
		var s: Vector3 = shark.get_global_transform_interpolated().origin
		var back := Vector3(me.x - s.x, 0.0, me.z - s.z).normalized()
		var c := me + back * 5.0 + Vector3.DOWN * 3.2
		cam.global_position = c
		cam.look_at(me.lerp(s, 0.6) + Vector3.UP * 0.3, Vector3.UP)
	await _wait(0.6)
	await _burst("shark_under", 3, 0.35)
	aim = Callable()
	p.state_machine.force_state("Idle", {})


## At the galley stove in the sloop's cabin by night, the stove's fire and the lantern.
func _shot_galley() -> void:
	_time(21.0, 0)
	_quiet_seas()
	ship.set_anchored(true)
	ship.sail = 0.0
	ship.sail_shown = 0.0
	p.current_ship = ship
	p.state_machine.force_state("Idle", {})
	var counter: Vector3 = load("res://scripts/ship/ship.gd").COUNTER_AT
	var stove: Vector3 = load("res://scripts/ship/ship.gd").STOVE_AT
	p.global_position = ship.global_transform * (counter + Vector3(-0.85, 0.2, 0.3))
	p.reset_physics_interpolation()
	p.player_model.rotation.y = _yaw(ship.global_basis.x)
	p.unequip_weapon()
	await _wait(1.0)
	var views := [["door", Vector3(-0.8, DECK + 1.6, 5.7), counter + Vector3(0.0, 1.0, 0.8)],
		["stern", Vector3(0.4, DECK + 1.4, 9.4), counter + Vector3(-0.2, 1.0, -0.4)],
		["low", Vector3(0.9, DECK + 1.0, 6.4), stove + Vector3(-0.4, 0.8, -0.4)]]
	for v in views:
		_ride(v[1], v[2], true)
		p.gesture("reach")
		await _wait(0.45)
		await _snap("galley_%s" % v[0])
		await _wait(0.8)
	aim = Callable()


## The held map out on the chain island (the path up from the pier and the village charted, the rest fog and `?`s):
## the game's camera on the page, zoomed in round the captain and out on the chart; then a wider look from behind.
func _map_stage() -> void:
	await _isle(MAIN)
	_time(10.5, 0)
	var vil = _village()
	var c: Vector2 = vil.plaza["c"]
	var hy: float = vil.plaza["y"] if vil.plaza["y"] != INF else isl.height_at(c.x, c.y)
	var td: Vector2 = (isl.sites["dock"] - c).normalized()
	var mf = load("res://scripts/map/map_fog.gd")
	var dd: Dictionary = load("res://scripts/map/map_isles.gd").of(isl)
	var a: Vector2 = isl.sites["dock_end"]
	# from up high (a wider ring): the dock, the road and the village, the rest left to the fog
	for i in range(10):
		var q: Vector2 = a.lerp(c, i / 9.0)
		mf.look(gm, dd, isl.to_global(Vector3(q.x, 24.0, q.y)))
	for k in range(6):
		var q: Vector2 = c + Vector2.from_angle(k * TAU / 6.0) * 45.0
		mf.look(gm, dd, isl.to_global(Vector3(q.x, 24.0, q.y)))
	_stand(_iy(c + td * 5.0, hy), _yaw(_v3(-td)))
	p.unequip_weapon()
	await _wait(1.0)
	_game_cam(_yaw(_v3(-td)))
	await _wait(1.2)


func _shot_heldmap() -> void:
	await _map_stage()
	var hold = p.get_node("MapHold")
	hold.toggle()
	await _wait(1.3)
	await _snap("heldmap_isle")
	hold.page.press(MOUSE_BUTTON_WHEEL_UP, Vector2.ZERO)
	await _wait(1.0)
	await _snap("heldmap_zoom")
	hold.page.press(MOUSE_BUTTON_WHEEL_DOWN, Vector2.ZERO)
	hold.page.press(MOUSE_BUTTON_WHEEL_DOWN, Vector2.ZERO)
	await _wait(1.0)
	await _snap("heldmap_chart")
	hold.page.press(MOUSE_BUTTON_WHEEL_UP, Vector2.ZERO)
	await _wait(0.8)
	var f: Vector3 = -p.player_model.global_basis.z
	var r: Vector3 = p.player_model.global_basis.x
	var me: Vector3 = p.global_position
	_own_cam()
	_look(me - f * 1.5 + r * 0.75 + Vector3.UP * 1.85, me + f * 0.5 + Vector3.UP * 1.1)
	await _wait(0.3)
	await _snap("heldmap_shoulder")
	_look(me + f * 2.4 + r * 1.0 + Vector3.UP * 1.6, me + Vector3.UP * 1.2)
	await _wait(0.3)
	await _snap("heldmap_front")
	hold.toggle()
	await _wait(0.5)


## Camp on a beach at dusk: the fire laid, the captain sat by it.
func _shot_camp() -> void:
	await _isle(MAIN)
	_time(18.3, 0)
	var e := _beach(PI)
	var shore: Vector2 = e[0]
	var dir: Vector2 = e[1]
	var f := _v3(dir)
	var r := Vector3.UP.cross(f).normalized() * -1.0
	_stand(_ig(shore - dir * 9.0 + Vector2(-dir.y, dir.x) * 6.0, 0.0), _yaw(f))
	_arm("cutlass")
	p.sheathe_weapon(true)
	await _wait(1.5)
	var camp_s = load("res://scripts/game/camp.gd")
	var fire := _ground(p.global_position + f * float(camp_s.AHEAD))
	camp_s.place(self, 1, fire, atan2(f.x, f.z))
	p.sit_ground()
	await _wait(6.0)
	var me: Vector3 = p.global_position
	_look(fire + f * 3.6 + r * 1.4 + Vector3.UP * 0.8, me + Vector3.UP * 0.6)
	await _wait(0.3)
	await _snap("camp_sea")
	_look(me - f * 3.0 + r * 1.6 + Vector3.UP * 1.4, fire + f * 30.0 + Vector3.UP * 2.0)
	await _wait(0.3)
	await _snap("camp_behind")
	_look(me + r * 6.0 - f * 1.0 + Vector3.UP * 2.2, me.lerp(fire, 0.5) + Vector3.UP * 0.5)
	await _wait(0.3)
	await _snap("camp_wide")
	_look(me + r * 4.2 - f * 1.2 + Vector3.UP * 1.1, me.lerp(fire, 0.5) + f * 2.5 + Vector3.UP * 0.9)
	await _wait(0.3)
	await _snap("camp_low")
	p.state_machine.force_state("Idle", {})


## The first chain seed from 1 whose first island is `theme`.
func _seed_theme(theme: String) -> int:
	var was: int = gm.chain_seed
	var s := 1
	while true:
		gm.chain_seed = s
		var c = wg.chain()
		if str(c.node(int(c.start_next[0]))["theme"]) == theme:
			break
		s += 1
	gm.chain_seed = was
	wg.chain()
	return s


## A themed island's village from the road in, the captain in front: [hour, weather, label] each.
func _shot_theme(theme: String, looks: Array) -> void:
	await _isle({"seed": _seed_theme(theme)})
	var v: Vector2 = isl.sites["village"]
	var dd: Vector2 = (isl.sites["dock"] - v).normalized()
	var side := Vector2(-dd.y, dd.x)
	var spot: Vector2 = v + dd * 30.0 + side * 6.0
	var to := (v - spot).normalized()
	var ts := Vector2(-to.y, to.x)
	for e in looks:
		_time(float(e[0]), int(e[1]))
		_stand(_ground(_ig(spot, 0.0)), _yaw(_v3(to)))
		_arm("cutlass")
		p.sheathe_weapon(true)
		await _wait(4.0)
		var me: Vector3 = p.global_position
		_look(_ground(_ig(spot - to * 3.0 + ts * 1.2, 0.0)) + Vector3.UP * 1.6, _ig(v, 3.0))
		await _wait(0.3)
		await _snap("%s_%s_eye" % [theme, e[2]])
		_look(_ground(_ig(spot + to * 3.5 - ts * 1.5, 0.0)) + Vector3.UP * 1.3, me + Vector3.UP * 1.3)
		await _wait(0.3)
		await _snap("%s_%s_face" % [theme, e[2]])
		_look(_ground(_ig(spot - to * 12.0, 0.0)) + Vector3.UP * 14.0, _ig(v, 0.0))
		await _wait(0.3)
		await _snap("%s_%s_wide" % [theme, e[2]])


# --------------------------------------------------------------------------
# Clips (GIFs)
# --------------------------------------------------------------------------
## The twin daggers' light combo on three grunts, clicked through.
func _clip_combo() -> void:
	await _isle(MAIN)
	_time(14.6, 0)
	var st := _fight_stage()
	var base: Vector3 = st[0]
	var f: Vector3 = st[1]
	var r: Vector3 = st[2]
	_stand(base, _yaw(f))
	_arm("dagger", "dagger")
	# all of them on the far side of the line from the camera
	_line_up(_grunts(), base, [f * 2.2, f * 3.4 + r * 1.6, f * 4.6 + r * 0.4])
	await _wait(0.8)
	var at := base + f * 1.8
	_look(at - r * 4.6 - f * 0.4 + Vector3.UP * 0.9, at + Vector3.UP * 1.0)
	p.state_machine.force_state("LightAttack", {"combo_index": 0, "chain": true})
	var clicks := func():
		while p.state_machine.current_state.name == "LightAttack" or p.state_machine.current_state.name == "Move":
			p.stamina = p.max_stamina
			p.input_buffer.buffer_action("light_attack")
			await _wait(0.2)
	clicks.call()
	await _clip("combo", 2.6)


## Hundred Fangs: eight blinks round a grunt and the star bursting.
func _clip_fangs() -> void:
	await _isle(MAIN)
	_time(14.6, 0)
	var st := _fight_stage()
	var base: Vector3 = st[0]
	var f: Vector3 = st[1]
	var r: Vector3 = st[2]
	_stand(base, _yaw(f))
	_arm("dagger", "dagger")
	_line_up(_grunts(), base, [f * 3.2, f * 4.6 + r * 2.2, f * 5.6 + r * 0.2])
	await _wait(0.8)
	var at := base + f * 3.0
	_look(at - r * 6.4 - f * 1.2 + Vector3.UP * 1.9, at + Vector3.UP * 0.8)
	_cast("hundred_fangs")
	await _clip("fangs", 3.2)


## The Silverback bounding up into the canopy, filmed side on.
func _clip_ape() -> void:
	await _isle(MAIN)
	_time(16.9, 0)
	var e: Array = await _ape_up()
	var ape = e[0]
	cam.fov = 62.0
	ape._begin_special("climb")
	# low and side on to the bound, close enough that it fills the frame as it takes off, tilted up after it
	var a0: Vector3 = ape._sp_from
	var a1: Vector3 = ape._sp_target
	var across := Vector3(a1.x - a0.x, 0.0, a1.z - a0.z).normalized()
	var side := across.cross(Vector3.UP)
	if side.dot(p.global_position - a0) < 0.0:
		side = -side
	_look(_ground(a0 + side * 7.5 - across * 2.0) + Vector3.UP * 0.8, a0 + across * 3.0 + Vector3.UP * 4.5)
	await _clip("ape", 2.0)
	cam.fov = 50.0


## The sloop running past the sea cliffs under full sail.
func _clip_sail() -> void:
	await _isle(MAIN)
	_time(10.4, 0)
	var c := _cliff()
	var at: Vector2 = c[0]
	var o: Vector2 = c[2]
	var along := Vector2(-o.y, o.x)
	var go := _v3(along)
	_sail(_iy(at + o * 45.0 - along * 40.0, 0.0), atan2(-go.x, -go.z))
	await _wait(3.0)
	var xw: Vector3 = ship.global_basis.x
	var away := -signf(xw.dot(_v3(-o)))
	_ride(Vector3(away * 24.0, 3.2, 10.0), Vector3(-away * 18.0, 6.5, -14.0))
	await _wait(0.2)
	await _clip("sail", 3.5)


## Jogging across the town's plaza at dusk, the villagers out for the evening.
func _clip_walk() -> void:
	await _isle(TOWN)
	_time(18.5, 0)
	var vil = _village()
	var c: Vector2 = vil.plaza["c"]
	var td: Vector2 = (isl.sites["dock"] - c).normalized()
	var sd := Vector2(-td.y, td.x)
	_stand(_ig(c + td * 15.0 + sd * 4.0, 0.0), _yaw(_v3(-td)))
	p.unequip_weapon()
	await _wait(3.0)
	_follow(4.2, 1.5, 1.9, 5.0, 1.3)
	Input.action_press("move_forward")
	await _wait(1.6)
	await _clip("walk", 2.4)
	Input.action_release("move_forward")


## Fishing off a Brinehollow pier at golden hour: the cast, the wait, a nibble, the bite, the strike, the catch held up.
func _clip_fish() -> void:
	_time(17.4, 0)
	var e := _fish_stand(0)
	await _wait(2.0)
	var me: Vector3 = p.global_position
	_fish_view("along", me, e[1])
	var drive := func():
		await _wait(0.15)
		p.fish()
		await _wait(_fishing().CAST_LEN + 0.1)
		var st = _fish_state()
		st._nibbles = [st._t + 0.7]
		st._bite_at = st._t + 1.7
		await _wait(1.95)
		p.input_buffer.buffer_action("light_attack")
		await _wait(0.15)
		st._catch = "fish_parrotfish"
		# the landing close up, the catch held up
		await _wait(1.0)
		cam.fov = 50.0
		_fish_view("catch", me, e[1])
	drive.call()
	await _clip("fish", 6.6)
	cam.fov = 50.0


## Diving down to a reef off Brinehollow and gathering from it.
func _clip_dive() -> void:
	_time(12.0, 0)
	var s = _dive_spot("Reef_")
	var c: Vector3 = s.global_position
	print("reef %.1f m down" % (float(p.water_surface(c)) - c.y))
	var d: Vector3 = await _dive_at_sea(c, 4.5)
	var side := Vector3.UP.cross(d).normalized()
	aim = func():
		var me: Vector3 = p.get_global_transform_interpolated().origin
		var at := me - d * 2.6 + side * 2.6 + Vector3.UP * 0.2
		cam.global_position = Vector3(at.x, minf(at.y, float(p.water_surface(at)) - 0.6), at.z)
		cam.look_at(me + d * 1.2 + Vector3.UP * 0.3, Vector3.UP)
	var drive := func():
		await _wait(0.3)
		_duck_dive()
		var t0 := t
		while t - t0 < 5.0:
			p.stamina = p.max_stamina
			# down first (the kelp's colliders stand tall over the reef), then in
			var me: Vector3 = p.global_position
			var off := Vector2(me.x - c.x, me.z - c.z).length()
			if me.y < c.y + 1.6:
				Input.action_release("dodge")
				Input.action_press("move_forward")
			if off < 2.4:
				Input.action_release("move_forward")
			if off < 2.4 and me.y < c.y + 1.9:
				break
			await process_frame
		Input.action_release("move_forward")
		Input.action_release("dodge")
		var pin: Vector3 = p.global_position
		print("  at the reef after %.1f s: %s (reef %s)" % [t - t0, pin, c])
		var cam_at := pin.lerp(c, 0.5) - side * 4.6 + Vector3.UP * 0.6
		aim = func():
			p.global_position = pin
			p.velocity = Vector3.ZERO
			cam.global_position = cam_at
			cam.look_at(pin.lerp(c, 0.45) + Vector3.UP * 0.3, Vector3.UP)
		await _wait(0.4)
		s.find_children("*", "Interactable", true, false)[0].interacted.emit(p)
	drive.call()
	await _clip("dive", 6.0)
	aim = Callable()
	p.state_machine.force_state("Idle", {})


## The held map coming out on the chain island, then the wheel out to the sea chart.
func _clip_map() -> void:
	await _map_stage()
	var hold = p.get_node("MapHold")
	var drive := func():
		await _wait(0.3)
		hold.toggle()
		await _wait(1.9)
		hold.page.press(MOUSE_BUTTON_WHEEL_UP, Vector2.ZERO)
		await _wait(1.2)
		hold.page.press(MOUSE_BUTTON_WHEEL_DOWN, Vector2.ZERO)
		await _wait(0.9)
		hold.page.press(MOUSE_BUTTON_WHEEL_DOWN, Vector2.ZERO)
	drive.call()
	await _clip("map", 5.8)
	hold.toggle()
	await _wait(0.5)


## Mid-fight at the camp: the cutlass's combo, X held for the loadout wheel (its own canvas layer, so it shows
## with the HUD off), the twin daggers picked, their combo.
func _clip_loadout() -> void:
	await _isle(MAIN)
	_time(14.6, 0)
	var st := _fight_stage()
	var base: Vector3 = st[0]
	var f: Vector3 = st[1]
	var r: Vector3 = st[2]
	_stand(base, _yaw(f))
	p.inventory_component.add_item(_item("dagger"), 2)
	_arm("cutlass")
	p.loadouts = [["cutlass", ""], ["dagger", "dagger"], []]
	p.loadout_at = 0
	_line_up(_grunts(), base, [f * 2.4, f * 3.6 + r * 1.6, f * 4.8 + r * 0.4])
	await _wait(0.8)
	var at := base + f * 1.8
	_look(at - r * 4.8 - f * 0.4 + Vector3.UP * 1.0, at + Vector3.UP * 1.0)
	var clicks := func():
		var t0 := t
		var swapped := false
		while t - t0 < 4.4:
			if not swapped and t - t0 > 1.3:
				swapped = true
				var wh = p.loadout_wheel
				wh._open_now()
				await _wait(0.25)
				wh.point_at(1)
				await _wait(0.7)
				wh._release()
				await _wait(0.4)
			p.stamina = p.max_stamina
			p.input_buffer.buffer_action("light_attack")
			await _wait(0.2)
	clicks.call()
	await _clip("loadout", 4.6)


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------
## Every frame at a quarter size, five across, in the order printed.
func _sheet() -> void:
	if frames.is_empty():
		return
	var tw := W / 4
	var th := H / 4
	var cols := 5
	var rows := ceili(frames.size() / float(cols))
	var sheet := Image.create(tw * cols + (cols - 1) * 4, th * rows + (rows - 1) * 4, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.06, 0.06, 0.08))
	for i in range(frames.size()):
		var f: Image = (frames[i][1] as Image).duplicate()
		f.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(f, Rect2i(0, 0, tw, th), Vector2i((i % cols) * (tw + 4), (i / cols) * (th + 4)))
	sheet.save_png("%s/sheet.png" % out)
	print("sheet: ", ", ".join(frames.map(func(e): return str(e[0]))))
	for e in frames:
		if str(e[0]) == OG:
			_og(e[1])


## 1200x630 for link previews: the frame scaled to 1200 wide, the middle band kept.
func _og(src: Image) -> void:
	var img: Image = src.duplicate()
	img.resize(1200, 675, Image.INTERPOLATE_BILINEAR)
	var og := img.get_region(Rect2i(0, 22, 1200, 630))
	og.save_jpg("%s/og.jpg" % out, 0.86)

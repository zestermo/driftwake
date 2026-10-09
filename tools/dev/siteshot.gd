extends SceneTree
## Key-art screenshots for the website (web/site/img): each shot staged in the
## world (hour, weather, ships, fights, the first chain island), HUD and labels
## off, the PSX post pass and dither on the game's own 640x360 grid, saved as
## 1600x900 JPEGs in <out_dir>; action shots come in bursts (<name>_<n>). Ends
## with sheet.png (every frame) and og.jpg (1200x630 from hero_out_c).
## Args: <out_dir> [shot,shot,... | all]   (env SITE_SEED: chain seed, default 11)
## Shots: hero isle fight ape seaking village broadside logpose coop
const W := 1600
const H := 900
const GRID := Vector2(640, 360)
const ALL := ["hero", "isle", "fight", "ape", "seaking", "village", "broadside", "logpose", "coop"]
const STAGGER := 9
const DECK := HullBuilder.DECK_Y

var out := ""
var want: Array = []
var t := 0.0
var started := false
var p
var pc
var ship
var w
var gm
var wg
var isl
var cam: Camera3D
var rig: Node3D
var aim := Callable()
var frames: Array = []
var settings
var pups := {}
var foe


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	want = Array(a[1].split(",")) if a.size() > 1 and a[1] != "all" else ALL.duplicate()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var seed_s := OS.get_environment("SITE_SEED")
	root.get_node("GameManager").chain_seed = int(seed_s) if seed_s != "" else 11
	DisplayServer.window_set_size(Vector2i(W, H))
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	# (the helm takes its own camera)
	if cam and not cam.current:
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
	# (attacks aim along the current camera's grandparent: a stand-in rig)
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
			"isle": await _shot_isle()
			"fight": await _shot_fight()
			"ape": await _shot_ape()
			"seaking": await _shot_seaking()
			"village": await _shot_village()
			"broadside": await _shot_broadside()
			"logpose": await _shot_logpose()
			"coop": await _shot_coop()
		aim = Callable()
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
	settings.set_value("video", "psx_preset", 0, false)
	settings.set_value("video", "dither", true, false)
	var psx = root.get_node("PSX")
	psx._post_rect.material.set_shader_parameter("pixel_res", GRID)
	psx._post_rect.material.set_shader_parameter("pixelate", true)
	root.scaling_3d_scale = GRID.y / float(maxi(root.size.y, 1))
	var wob := clampf(float(settings.get_value("video", "wobble")), 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("psx_snap_res", GRID / lerpf(0.25, 2.0, wob))


func _snap(name: String) -> void:
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
	img.save_jpg("%s/%s.jpg" % [out, name], 0.86)
	frames.append([name, img])
	print("shot ", name)


func _burst(name: String, n: int, every: float) -> void:
	for i in range(n):
		await _snap("%s_%d" % [name, i])
		await _wait(every)


func _time(h: float, state: int) -> void:
	w.world_offset += fposmod(h - float(w.hour()), 24.0) / 24.0 * float(w.DAY_LEN)
	w.forced = state
	w.forced_at = w.world_time() - 100.0


func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)


func _ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 40.0, at + Vector3.DOWN * 80.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at


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
	for tr in SkillTree.TREES.keys():
		if SkillTree.is_mastery_tree(tr):
			pr.mastery_of(tr)["pts"] = 999
	var grew := true
	while grew:
		grew = false
		for k in SkillTree.nodes().keys():
			if pr.can_learn(k) == "":
				pr.learn(k)
				grew = true
	pr.owned.erase("h_instinct")


func _cast(id: String) -> void:
	var slot := 4 if Skills.is_ult(id) else 0
	pc.equip(id, slot)
	pc.energy = pc.max_energy()
	pc.ult = 100.0
	pc.cooldowns.clear()
	print("cast ", id, ": ", pc.try_cast(slot))


## No pirate ships but the brig kept for the broadside (stowed out of sight till then).
func _quiet_seas() -> void:
	if foe == null:
		for e in get_nodes_in_group("enemy_ships"):
			if e.kind == "brig" or foe == null:
				foe = e
		foe.set_physics_process(false)
		foe.visible = false
		foe.global_position = Vector3(5000, -50, 5000)
	for e in get_nodes_in_group("enemy_ships"):
		if e != foe:
			e.queue_free()


## The first island of the chain, built and manned.
func _isle() -> void:
	if isl:
		return
	var id := int(wg.chain().start_next[0])
	gm.apply_chain(id, false, w.world_time())
	gm.chain_since = w.world_time()
	var t0 := t
	while (not wg.chain_ready() or not wg.chain_islands.has(id)) and t - t0 < 90.0:
		await process_frame
	isl = wg.chain_islands[id]
	print("isle %s (%s, Lv %d) r %.0f sites %s" % [isl.island_name, isl.theme, int(isl.node["level"]), isl.radius, isl.sites.keys()])


## Island-local p, `up` m over the ground (or the sea) there, in world space.
func _ig(at: Vector2, up: float) -> Vector3:
	return isl.to_global(Vector3(at.x, maxf(isl.height_at(at.x, at.y), 0.0) + up, at.y))


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


## A camera riding with the ship: ship-local position and target, kept level
## (from the sea's surface, or from the hull's height for cameras on deck).
func _ride(from: Vector3, at: Vector3, deck := false) -> void:
	aim = func():
		var xf: Transform3D = ship.get_global_transform_interpolated()
		var flat := Transform3D(Basis(Vector3.UP, xf.basis.get_euler().y), Vector3(xf.origin.x, xf.origin.y if deck else 0.0, xf.origin.z))
		cam.global_position = flat * from
		cam.look_at(flat * at, Vector3.UP)


# --------------------------------------------------------------------------
# Shots
# --------------------------------------------------------------------------
## The sloop under full sail at golden hour, the chain island on the horizon.
func _shot_hero() -> void:
	await _isle()
	_quiet_seas()
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


## The chain island from the sea and from its summit.
func _shot_isle() -> void:
	await _isle()
	_quiet_seas()
	var dd: Vector2 = isl.dock_dir
	var side := Vector2(-dd.y, dd.x)
	var s: Dictionary = isl.sites
	_time(7.4, 1)
	var at: Vector2 = s["dock_end"] + dd * 90.0
	_sail(isl.to_global(Vector3(at.x, 0, at.y)), atan2(dd.x, dd.y) + isl.global_rotation.y)
	_ride(Vector3(-16, 5.0, 48), Vector3(0, 4.0, -60))
	await _wait(5.0)
	await _snap("isle_morning")
	aim = Callable()
	_time(17.2, 0)
	await _wait(1.0)
	_look(_ig(s["dock_end"] + dd * 150.0 + side * 70.0, 22.0), _ig(s["village"], 2.0))
	await _wait(1.0)
	await _snap("isle_gold")
	_look(_ig(s["dock_end"] + dd * 110.0 + side * 40.0, 8.0), _ig(s["village"], 6.0))
	await _wait(0.5)
	await _snap("isle_gold_low")
	_look(_ig(s["dock_end"] + dd * 260.0 - side * 60.0, 110.0), _ig(s["village"] - dd * 80.0, 0.0))
	await _wait(1.0)
	await _snap("isle_high")
	_look(_ig(s["summit"] + dd * 4.0, 9.0), _ig(s["dock"] + dd * 30.0, -6.0))
	await _wait(1.5)
	await _snap("isle_summit")


## Ultimates at the smugglers' camp at dusk, on three staggered grunts.
func _shot_fight() -> void:
	_quiet_seas()
	_time(17.5, 0)
	var camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
	var yaw := PI * 0.5 + 0.35
	var f := Vector3(-sin(yaw), 0, -cos(yaw))
	var r := Vector3(cos(yaw), 0, -sin(yaw))
	# out on the open sand seaward of the camp (its fire and barrels behind, not in the way)
	var base: Vector3 = _ground(camp.grunts[1].global_position + Vector3(4.0, 0, 3.0) - r * 7.0)
	for e in [["petal_storm", "katana", 0.9], ["kraken_wake", "cutlass", 0.25], ["maelstrom", "boarding_axe", 0.25]]:
		_stand(base, yaw)
		_arm(str(e[1]))
		var spots := [f * 3.2, f * 5.0 - r * 2.2, f * 5.6 + r * 2.4]
		var k := 0
		for g in camp.grunts:
			if not is_instance_valid(g) or g.state == 14:
				continue
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
				g.global_position = _ground(base + Vector3(50 + k * 3, 0, 50))
				g.reset_physics_interpolation()
			k += 1
		await _wait(0.8)
		# low and side on from the sea side, near and far in turn: the captain and the grunts both in frame
		var mid := base + f * 2.6
		_cast(str(e[0]))
		await _wait(float(e[2]))
		for i in range(8):
			var far := i % 2 == 1
			var at: Vector3 = p.global_position.lerp(mid, 0.4)
			at.y = mid.y
			_look(at - r * (7.0 if far else 5.0) + f * (0.6 if far else -0.8) + Vector3.UP * 0.45, at + Vector3.UP * 1.3)
			await _snap("fight_%s_%d" % [e[0], i])
			await _wait(0.12)
		await _wait(2.0)


## Blood splats off the ground (they read as dark holes in a still).
func _clean_blood() -> void:
	var splat = root.get_node("FX")._splat_mat
	if splat == null:
		return
	for n in current_scene.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).material_override == splat:
			n.free()


## The Silverback in its clearing: roaring, then a rock lifted overhead.
func _shot_ape() -> void:
	await _isle()
	_quiet_seas()
	_time(17.3, 0)
	var arena = isl.find_child("Arena", true, false)
	var ape = arena.boss
	var c: Vector3 = arena.global_position
	var to_v: Vector3 = _v3((isl.sites["village"] - isl.sites["boss"]).normalized())
	var r := Vector3.UP.cross(to_v).normalized()
	_arm("katana")
	_stand(_ground(c + to_v * 8.5), atan2(to_v.x, to_v.z))
	await _wait(0.3)
	# low behind the captain's shoulder, looking up at it
	var me: Vector3 = p.global_position
	# the roar: low and off to the side, the captain at the frame's edge
	aim = func():
		var a: Vector3 = ape.global_position
		cam.global_position = me.lerp(a, 0.3) + r * 4.0 + Vector3.UP * 0.35
		cam.look_at(a.lerp(me, 0.2) + Vector3.UP * 1.7, Vector3.UP)
	await _wait(0.6)
	await _burst("ape_roar", 4, 0.35)
	await _wait(1.0)
	# the rock overhead: from behind the captain's shoulder, looking up
	aim = func():
		var a: Vector3 = ape.global_position
		var back := (me - a).normalized()
		cam.global_position = me + back * 4.6 + r * 1.5 + Vector3.UP * 0.4
		cam.look_at(a.lerp(me, 0.2) + Vector3.UP * 2.6, Vector3.UP)
	ape._begin_special("throw")
	await _wait(0.5)
	await _burst("ape_lift", 4, 0.12)


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


## An outpost village at night (lanterns, the inn, the fire), and Brinehollow's.
func _shot_village() -> void:
	await _isle()
	_quiet_seas()
	_time(21.3, 0)
	var c: Vector2 = isl.sites["village"]
	var to_dock: Vector2 = (isl.sites["dock"] - c).normalized()
	var side := Vector2(-to_dock.y, to_dock.x)
	var inn: Vector2 = c - to_dock * 24.0
	_stand(_ig(c + to_dock * 6.0 + side * 1.5, 0.0), atan2(-_v3(-to_dock).x, -_v3(-to_dock).z))
	p.sheathe_weapon(true)
	await _wait(2.0)
	_look(_ig(c + to_dock * 15.0 - side * 5.0, 1.7), _ig(inn, 2.2))
	await _wait(1.0)
	await _snap("village_a")
	_look(_ig(c + to_dock * 10.0 + side * 12.0, 7.0), _ig(c - to_dock * 6.0, 0.5))
	await _wait(0.5)
	await _snap("village_b")
	_look(_ig(c + to_dock * 3.0 + side * 3.0, 1.2), _ig(inn, 2.4))
	await _wait(0.5)
	await _snap("village_c")
	# Brinehollow's street
	var bh: Vector3 = Vector3(150.0, 0.0, 60.0)
	_stand(_ground(bh), PI)
	await _wait(2.0)
	_look(Vector3(149.0, 5.0, 33.0), Vector3(150.0, 4.0, 80.0))
	await _wait(1.0)
	await _snap("village_brine")


## A pirate brig alongside at dusk: both broadsides, smoke between the hulls.
func _shot_broadside() -> void:
	_quiet_seas()
	foe.visible = true
	_time(17.9, 1)
	var at := Vector3(560.0, 0.0, 150.0)
	ship.place(at, 0.0)
	ship.set_anchored(true)
	ship.sail = 1.0
	ship.sail_shown = 1.0
	p.current_ship = ship
	p.state_machine.force_state("Idle", {})
	p.global_position = ship.global_transform * Vector3(1.5, 1.2, -2.0)
	p.reset_physics_interpolation()
	foe.set_physics_process(false)
	foe._pos = at + Vector3(-34.0, 0, -6.0)
	foe._heading = 0.12
	foe.global_transform = Transform3D(Basis(Vector3.UP, foe._heading), foe._pos + Vector3(0, 0.85, 0))
	foe.reset_physics_interpolation()
	await _wait(1.5)
	# low over the water off our quarter, looking along the gap between them
	_look(at + Vector3(-12.0, 2.4, 27.0), at + Vector3(-16.0, 5.5, -4.0))
	ship.broadside(-1.0, foe.global_position + Vector3(0, 2, 0), p)
	for c in foe.cannons:
		if (c as Node3D).position.x > 0.0:
			c.aim_at(ship.global_position + Vector3(0, 2, 0))
			c.fire(foe)
	await _wait(0.1)
	await _burst("broadside", 5, 0.2)


## The log pose held up on the pier at sunset, the needle pointing on.
func _shot_logpose() -> void:
	await _isle()
	_quiet_seas()
	_time(17.8, 0)
	p.give_log_pose()
	gm.chain_set = true
	var dd: Vector2 = isl.dock_dir
	var at: Vector2 = isl.sites["dock_end"] - dd * 1.5
	var out_v: Vector3 = _v3(dd)
	_stand(_ig(at, 0.0) + Vector3.UP * 1.5, atan2(-out_v.x, -out_v.z))
	p.unequip_weapon()
	await _wait(1.0)
	p.refresh_look()
	Input.action_press("log_pose")
	await _wait(1.6)
	var me: Vector3 = p.global_position
	var r := Vector3.UP.cross(out_v).normalized()
	_look(me - out_v * 1.0 + r * 0.6 + Vector3.UP * 1.8, me + out_v * 2.0 + Vector3.UP * 1.1)
	await _wait(0.3)
	await _snap("logpose_a")
	_look(me + out_v * 2.0 - r * 1.3 + Vector3.UP * 1.3, me + Vector3.UP * 1.35)
	await _wait(0.3)
	await _snap("logpose_b")
	Input.action_release("log_pose")


## Three captains on the deck under sail at golden hour (two of them co-op puppets).
func _shot_coop() -> void:
	await _isle()
	_quiet_seas()
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
	_ride(Vector3(9.0, 1.0, -16.0), Vector3(0, 4.0, -2.0))
	await _wait(0.3)
	await _snap("coop_c")
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
		if str(e[0]) == "hero_out_c":
			_og(e[1])


## 1200x630 for link previews: the frame scaled to 1200 wide, the middle band kept.
func _og(src: Image) -> void:
	var img: Image = src.duplicate()
	img.resize(1200, 675, Image.INTERPOLATE_BILINEAR)
	var og := img.get_region(Rect2i(0, 22, 1200, 630))
	og.save_jpg("%s/og.jpg" % out, 0.86)

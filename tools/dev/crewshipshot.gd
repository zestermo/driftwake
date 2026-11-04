extends SceneTree
## (1.30) The brig and the galleon (HullLayout._brig, _galleon): the crew's ship taken out of Brinehollow's harbour to
## open water as each class, a sloop's hull alongside for scale, then shots outside (side, stern, bow, from aloft), on
## her decks, in her rooms, (the galleon) on the gun deck and in the stateroom, and finally under sail.
## Args: <out_prefix> [psx]; env FSHOT_CLASS=brig|galleon (both by default), FSHOT_ONLY=side,lounge (just those: the
## part of a shot's name after the class).
var t := 0.0
var out := ""
var cam: Camera3D
var ship
var p
var shots: Array = []
var i := -1
var t0 := 0.0
var classes: Array = ["brig", "galleon"]
var ci := -1
var sloop: Node3D
var sea_at := Vector3.ZERO
var sea_yaw := 0.0


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	if OS.get_environment("FSHOT_CLASS") != "":
		classes = [OS.get_environment("FSHOT_CLASS")]
	change_scene_to_file("res://scenes/world/world.tscn")


func L(v: Vector3) -> Vector3:
	return ship.global_transform * v


func _next_class() -> bool:
	ci += 1
	if ci >= classes.size():
		return false
	var cls: String = classes[ci]
	var SC = load("res://scripts/ship/ship_classes.gd")
	root.get_node("Net").set_ship_kit(SC.switch_to(ship.kit, cls).merged({"guns": 1, "sails": 2, "lanterns": 1, "rudder": 3}, true))
	ship.place(sea_at, sea_yaw)
	ship.sail = 0.0
	var H = ship.layout
	var lw: float = float(H.rings[0][0]) - float(H.rings[H.rings.size() - 1][0])
	var hb: float = H.half_beam
	var cy: float = H.cabin_y
	var pz: float = load("res://scripts/ship/ship_rooms.gd").part_z(H)
	var bow: float = float(H.rings[H.rings.size() - 1][0])
	shots = [
		["%s_side" % cls, Vector3(-lw * 1.15, lw * 0.22, -1.0), Vector3(0, H.mast_top * 0.32, -1.0), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0)],
		["%s_scale" % cls, Vector3(hb + 26.0, 9.0, -lw * 0.9), Vector3(hb + 6.0, 4.0, 0.0), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0), "sloop"],
		["%s_stern" % cls, Vector3(-lw * 0.6, lw * 0.3, lw * 0.85), Vector3(0, 4.0, H.qd_front), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0)],
		["%s_bow" % cls, Vector3(lw * 0.45, 6.0, bow - lw * 0.45), Vector3(0, 3.5, bow + 6.0), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0)],
		["%s_aloft" % cls, Vector3(hb * 2.5, H.mast_top + 10.0, lw * 0.5), Vector3(0, 0.0, -2.0), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0)],
		["%s_deck" % cls, Vector3(1.0, H.deck_y + 2.2, bow + 6.0), Vector3(0, H.deck_y + 1.8, H.qd_front + 2.0), Vector3(-1.2, H.deck_y + 0.1, H.mast_z - 3.0)],
		["%s_waist" % cls, Vector3(-hb + 1.6, H.deck_y + 2.0, H.qd_front - 1.0), Vector3(hb - 1.0, H.deck_y + 0.6, H.mast_z - 6.0), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0)],
		["%s_helm" % cls, Vector3(1.6, H.qd_y + 1.9, H.helm_z + 2.2), Vector3(0, H.qd_y + 1.0, H.qd_front - 4.0), Vector3(0, H.qd_y + 0.05, H.helm_z)],
		["%s_lounge" % cls, Vector3(H.cabin_hw - 1.0, cy + 1.75, H.qd_front + 0.6), Vector3(-H.cabin_hw + 1.0, cy + 0.6, pz - 0.5), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0)],
		["%s_galley" % cls, Vector3(-H.cabin_hw + 1.6, cy + 1.7, H.qd_front + 0.6), Vector3(H.cabin_hw - 0.8, cy + 0.8, pz - 1.0), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0)],
		["%s_aft_room" % cls, Vector3(0.6, cy + 1.7, pz + 0.4), Vector3(-0.6, cy + 0.6, H.qd_back - 0.2), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0)],
		["%s_aft_back" % cls, Vector3(-0.5, cy + 1.7, H.qd_back - 0.5), Vector3(0.5, cy + 0.8, pz), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0)],
	]
	if H.has_lower():
		var lo: float = H.lower_y
		shots.append(["%s_hatch" % cls, Vector3(0.0, H.deck_y + 2.4, float(H.hatch[0]) - 3.0), Vector3(0, lo + 0.5, float(H.hatch[1]) + 1.0), Vector3(-1.5, H.deck_y + 0.1, H.mast_z - 3.0)])
		shots.append(["%s_gundeck" % cls, Vector3(0.0, lo + 1.6, H.lower_back - 1.0), Vector3(0, lo + 0.8, H.lower_front + 2.0), Vector3(-1.5, H.deck_y + 0.1, H.mast_z - 3.0)])
		shots.append(["%s_guns" % cls, Vector3(-2.0, lo + 1.5, 0.5), Vector3(H.half_width(-5.0) - 0.6, lo + 0.8, -8.5), Vector3(-1.5, H.deck_y + 0.1, H.mast_z - 3.0)])
		shots.append(["%s_ports" % cls, Vector3(hb + 7.0, 0.5, -2.0), Vector3(hb - 0.5, lo + 0.6, -5.0), Vector3(-1.5, H.deck_y + 0.1, H.mast_z - 3.0)])
	if H.has_poop():
		var q: float = H.qd_y
		shots.append(["%s_poop" % cls, Vector3(-2.5, H.poop_y + 2.0, H.qd_back - 0.6), Vector3(0, H.qd_y + 0.8, H.qd_front - 3.0), Vector3(0, H.poop_y + 0.05, H.qd_back - 2.0)])
		shots.append(["%s_stateroom" % cls, Vector3(2.8, q + 1.8, H.poop_front + 0.5), Vector3(-1.5, q + 0.6, H.qd_back - 0.6), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0)])
		shots.append(["%s_library" % cls, Vector3(2.0, q + 1.7, H.qd_back - 0.8), Vector3(-H.cabin_hw + 0.3, q + 1.0, H.poop_front + 1.5), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0)])
		shots.append(["%s_castle" % cls, Vector3(-hb - 8.0, H.poop_y + 2.0, H.qd_back + 10.0), Vector3(0, H.qd_y, H.poop_front), Vector3(0, H.deck_y + 0.1, H.mast_z - 3.0)])
	shots.append(["%s_sailing" % cls, Vector3(-lw * 0.9, lw * 0.3, lw * 0.4), Vector3(0, H.mast_top * 0.35, -2.0), Vector3(-1.2, H.deck_y + 0.1, H.mast_z - 3.0), "sail"])
	i = -1
	return true


func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if cam == null:
		if OS.get_cmdline_user_args().has("psx"): root.get_node("Settings").set_value("video", "pixelate", true, false)
		else: root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		ship = get_first_node_in_group("ship")
		p = get_first_node_in_group("player")
		var w = root.get_node("Weather")
		w.forced = 0
		w.forced_at = w.world_time() - 100.0
		w.skip_to(11.0)
		cam = Camera3D.new(); cam.fov = 60; cam.far = 1500
		root.add_child(cam); cam.current = true
		var out_dir := Vector3(ship.global_position.x, 0, ship.global_position.z).normalized()
		sea_at = Vector3(ship.global_position.x, 0, ship.global_position.z) + out_dir * 140.0
		sea_yaw = atan2(out_dir.z, -out_dir.x)
		_next_class()
		return false
	if i < 0 or t - t0 > 1.4:
		if i >= 0:
			root.get_texture().get_image().save_png("%s_%s.png" % [out, shots[i][0]])
			print("shot ", shots[i][0])
		i += 1
		var only := OS.get_environment("FSHOT_ONLY").split(",", false)
		while not only.is_empty() and i < shots.size() and not only.has(str(shots[i][0]).get_slice("_", 1)):
			i += 1
		if i >= shots.size():
			if not _next_class():
				quit()
			return false
		var s: Array = shots[i]
		if sloop:
			sloop.free()
			sloop = null
		if s.size() > 4 and s[4] == "sloop":
			# a sloop's hull alongside, riding the same water
			var H = ship.layout
			var HL = load("res://scripts/ship/hull_layout.gd")
			sloop = Node3D.new()
			root.add_child(sloop)
			load("res://scripts/ship/hull_builder.gd").build(sloop, {"layout": HL.of("sloop", 0), "emblem": "jolly"})
			sloop.global_transform = Transform3D(ship.global_basis, L(Vector3(H.half_beam + 10.0, HL.FREEBOARD - H.freeboard, 0.0)))
		if s.size() > 4 and s[4] == "sail":
			ship.sail = 1.0
			ship.sail_shown = 1.0
			ship.speed = 8.0
		p.state_machine.force_state("Idle", {})
		p.global_position = L(s[3])
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		cam.global_position = L(s[1])
		cam.look_at(L(s[2]), Vector3.UP)
		t0 = t
	elif shots[i].size() > 4 and shots[i][4] == "sail":
		cam.global_position = L(shots[i][1])
		cam.look_at(L(shots[i][2]), Vector3.UP)
	return false

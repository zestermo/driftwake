extends SceneTree
## An ability in action: casts a skill on three grunts by the smugglers' camp and
## films it, effects and all, as a contact sheet (one row per view, frames along
## game time, so hit-stop and slow motion show as held frames).
## Args: <out_prefix> <skill_id> [style: sword|katana|axe|dual_sword|pistol|fist]
##       [views: game,side,front3,top] [frames=8] [span s=1.2] [start s=0.0]
## Writes <out_prefix>_<skill>.png. Env AB_HOUR=21 films it at night; AB_TIER=0/1/2
## with no weapon element awakened / on skills only / on every blow (default 2).
const STAGGER := 9
var t := 0.0
var step := 0
var wait := 0.0
var p
var pc
var camp
var args: PackedStringArray
var skill := ""
var style := "sword"
var views: Array = ["game", "side"]
var frames := 8
var span := 1.2
var start := 0.0
var since := -1.0
var shot_i := 0
var vps: Array = []
var images: Array = []
var basis_at := Basis()
var origin_at := Vector3.ZERO
var busy := false


func _initialize():
	args = OS.get_cmdline_user_args()
	skill = args[1]
	if args.size() > 2:
		style = args[2]
	if args.size() > 3:
		views = Array(args[3].split(","))
	if args.size() > 4:
		frames = int(args[4])
	if args.size() > 5:
		span = float(args[5])
	if args.size() > 6:
		start = float(args[6])
	change_scene_to_file("res://scenes/world/world.tscn")


func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at


func item(id: String):
	return load("res://resources/items/%s.tres" % id)


func arm() -> void:
	p.state_machine.force_state("Idle", {})
	p.unequip_weapon()
	match style:
		"sword":
			p.equip_weapon(item("cutlass"), false)
		"katana":
			p.equip_weapon(item("katana"), false)
		"axe":
			p.equip_weapon(item("boarding_axe"), false)
		"dual_sword":
			p.equip_weapon(item("cutlass"), false)
			p.set_offhand(item("cutlass"))
		"pistol":
			p.equip_weapon(item("pistol"), false)
	if style != "fist":
		p.sheathe_weapon(true)
		p.draw_weapon(true)


func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5:
				return false
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			p = root.get_tree().get_first_node_in_group("player")
			pc = p.power
			var pr = p.progression
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
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
			# AB_TIER=0: no weapon's element awakened; 1: on skills only; 2 (default): on every blow
			var tier := int(OS.get_environment("AB_TIER")) if OS.get_environment("AB_TIER") != "" else 2
			for k in pr.owned.keys():
				if (tier < 1 and str(k).ends_with("_elem")) or (tier < 2 and str(k).ends_with("_elem2")):
					pr.owned.erase(k)
			for id in ["cutlass", "cutlass", "katana", "boarding_axe", "pistol"]:
				p.inventory_component.add_item(item(id), 1)
			var hud = root.get_tree().get_first_node_in_group("hud")
			if hud:
				hud.visible = false
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			if OS.get_environment("AB_HOUR") != "":
				var wx = root.get_node("Weather")
				var kc: Dictionary = (wx.get_script() as GDScript).get_script_constant_map()
				wx.set_world_time(fposmod(float(OS.get_environment("AB_HOUR")) - float(kc["START_HOUR"]), 24.0) / 24.0 * float(kc["DAY_LEN"]))
			step = 1
		1:
			# a flat stage out on the water north of the harbour: a clean backdrop,
			# room to be thrown about, nothing in the way
			var stage := StaticBody3D.new()
			stage.name = "AbilityStage"
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(44, 1, 44)
			cs.shape = box
			stage.add_child(cs)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = box.size
			mi.mesh = bm
			mi.material_override = PSXMat.lit("sand", Color(0.95, 0.92, 0.85))
			stage.add_child(mi)
			root.get_tree().current_scene.add_child(stage)
			stage.global_position = Vector3(150, 2.0, -110)
			var land := Vector3(150, 2.5, -96)
			p.global_position = land + Vector3.UP * 0.2
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			arm()
			# three grunts ahead (-Z), staggered so they stand and take it
			var spots := [Vector3(0, 0, -3.2), Vector3(-2.2, 0, -5.0), Vector3(2.4, 0, -5.6)]
			var k := 0
			for g in camp.grunts:
				if not is_instance_valid(g) or g.state == 14:
					continue
				if k < spots.size():
					g.humanoid.seated = false
					g.global_position = land + spots[k] + Vector3.UP * 0.3
					g.velocity = Vector3.ZERO
					g.reset_physics_interpolation()
					g._stagger_len = 30.0
					g._set_state(STAGGER)
					g.health.current_health = 900.0
				else:
					g.global_position = ground(land + Vector3(40 + k * 3, 0, 40))
				k += 1
			var rig: Node3D = root.get_viewport().get_camera_3d().get_parent().get_parent()
			rig.rotation.y = 0.0
			p.player_model.rotation.y = 0.0
			step = 2
			wait = 0.5
		2:
			basis_at = p.player_model.global_basis.orthonormalized()
			origin_at = p.global_position
			_make_views()
			# (also "heavy": the weapon's heavy attack; "riposte_counter": the
			# answer to a parried blow, on the nearest grunt)
			if skill == "heavy":
				p.state_machine.force_state("HeavyAttack", {})
				print("cast heavy: true")
			elif skill == "riposte_counter":
				p.state_machine.force_state("Technique", {"id": "riposte_counter", "target": camp.grunts[0]})
				print("cast riposte_counter: true")
			else:
				var slot := 4 if Skills.is_ult(skill) else 0
				pc.equip(skill, slot)
				pc.energy = pc.max_energy()
				pc.ult = 100.0
				pc.cooldowns.clear()
				print("cast ", skill, ": ", pc.try_cast(slot))
			basis_at = p.player_model.global_basis.orthonormalized()
			origin_at = p.global_position
			since = 0.0
			step = 3
		3:
			since += d
			if not busy and shot_i < frames and since >= start + span * float(shot_i) / maxf(frames - 1, 1):
				busy = true
				_grab()
			if shot_i >= frames and not busy:
				_sheet()
				quit()
	return false


func _make_views() -> void:
	for v in views:
		var sv := SubViewport.new()
		sv.size = Vector2i(400, 260)
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(sv)
		var cam := Camera3D.new()
		cam.fov = 60.0
		sv.add_child(cam)
		cam.current = true
		vps.append([sv, cam, str(v)])
	_aim()


## Cameras fixed on where the cast began: the game's view (behind and above), the
## right side, the front three-quarter, straight down.
func _aim() -> void:
	var f := -basis_at.z
	var r := basis_at.x
	var c: Vector3 = origin_at + Vector3.UP * 1.0
	for e in vps:
		var cam: Camera3D = e[1]
		match str(e[2]):
			"game":
				cam.look_at_from_position(c - f * 4.2 + Vector3.UP * 1.9, c + f * 2.6, Vector3.UP)
			"side":
				cam.look_at_from_position(c + r * 6.5 + f * 2.4 + Vector3.UP * 0.5, c + f * 2.4, Vector3.UP)
			"front3":
				cam.look_at_from_position(c + f * 7.5 + r * 3.5 + Vector3.UP * 1.0, c + f * 1.5, Vector3.UP)
			"top":
				cam.look_at_from_position(c + f * 2.5 + Vector3.UP * 11.0 + r * 0.01, c + f * 2.5, Vector3.FORWARD)


func _grab() -> void:
	if shot_i == 0:
		_aim()
	await RenderingServer.frame_post_draw
	var row: Array = []
	for e in vps:
		row.append((e[0] as SubViewport).get_texture().get_image())
	images.append(row)
	shot_i += 1
	busy = false


func _sheet() -> void:
	var w := 400
	var h := 260
	var sheet := Image.create(w * images.size(), h * vps.size(), false, Image.FORMAT_RGBA8)
	for i in range(images.size()):
		for j in range(vps.size()):
			var img: Image = images[i][j]
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(i * w, j * h))
	var path := "%s_%s.png" % [args[0], skill]
	sheet.save_png(path)
	print("SAVED ", path)

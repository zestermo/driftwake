extends SceneTree
## The enemies' tells filmed as strips from behind the captain (the game camera's side): the
## rifleman's shove, a grunt's low sweep and feint, an elite's dash out of a heavy, Grell's charge,
## Morrow's Tide Rush, the Brood Queen's burrow and a poison puddle. Saves <out>/<scene>_<n>.png.
## Args: [out_dir] [scenes, comma-separated] (default res://tools/dev/out/enemies, all)
const TK = preload("res://tools/dev/test_kit.gd")
const ALL := ["shove", "sweep", "feint", "dash", "grell", "morrow", "queen", "puddle"]
var t := 0.0
var out := "res://tools/dev/out/enemies"
var todo: Array = ALL.duplicate()
var p
var isl
var cam: Camera3D
var name_ := ""
var t0 := 0.0
var times: Array = []
var shots := 0
var foe: Node3D
var spot := Vector3.ZERO


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	if a.size() > 1:
		todo = Array(a[1].split(","))
	TK.seed_of(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	change_scene_to_file("res://scenes/world/world.tscn")


func _up() -> void:
	if p.current_state_name() == "Downed":
		p.body_model.end_ragdoll()
		p.body_model.reset_pose()
	p.state_machine.force_state("Idle", {})
	p.health_component.heal(99999.0)


func _put(at: Vector3, face: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	p.player_model.rotation.y = atan2(-face.x, -face.z)


func _ground(x: float, z: float) -> Vector3:
	var l: Vector3 = isl.to_local(Vector3(x, 0, z))
	return isl.to_global(Vector3(l.x, isl.height_at(l.x, l.z) + 0.3, l.z))


func _quiet(camp) -> void:
	for x in camp.grunts:
		if is_instance_valid(x) and x != foe:
			x.process_mode = Node.PROCESS_MODE_DISABLED


func _begin(n: String) -> void:
	name_ = n
	shots = 0
	_up()
	var camp = isl.get_node("SmugglersCamp")
	match n:
		"shove", "sweep", "feint", "dash":
			var s = camp.grunts[2]
			var f := Vector3(-sin(s.post_yaw), 0.0, -cos(s.post_yaw))
			foe = camp.grunts[4] if n == "shove" else camp.grunts[3]
			for x in camp.grunts:
				if x.role == "rifle" and n == "shove":
					foe = x
			_quiet(camp)
			foe.process_mode = Node.PROCESS_MODE_INHERIT
			_put(s.post + f * 0.6 + Vector3.UP * 0.3, f)
			foe.global_position = s.post + f * (0.6 + (2.6 if n == "dash" else 1.8)) + Vector3.UP * 0.3
			foe.reset_physics_interpolation()
			foe.health.heal(999.0)
			foe.alert()
			foe._set_state(3)
			foe._cooldown = 9.0
			match n:
				"shove":
					foe._start_shove()
					times = [0.05, 0.2, 0.35, 0.5, 0.62, 0.8]
				"sweep":
					foe._attack = "sweep"
					foe._swing_i = 0
					foe._start_wind()
					times = [0.1, 0.35, 0.6, 0.68, 0.78, 1.0]
				"feint":
					foe._attack = "feint"
					foe._swing_i = 0
					foe._start_wind()
					times = [0.15, 0.4, 0.5, 0.65, 0.8, 0.9]
				"dash":
					foe.elite_rank = true
					foe._dash_cd = 0.0
					foe._dodge_chance = 1.0
					p.state_machine.force_state("HeavyAttack", {})
					p.player_model.rotation.y = s.post_yaw
					times = [0.04, 0.12, 0.2, 0.28, 0.4, 0.6]
		"grell":
			var den = isl.get_node("PirateDen")
			for g in den.grunts:
				if g.captain:
					foe = g
			_quiet(den)
			var c: Vector3 = den.global_position
			var inland: Vector3 = isl.global_position - c
			inland.y = 0.0
			inland = inland.normalized()
			foe.global_position = _ground(c.x + inland.x * 4.0, c.z + inland.z * 4.0)
			foe.reset_physics_interpolation()
			_put(_ground(c.x + inland.x * 14.0, c.z + inland.z * 14.0), -inland)
			foe.alert()
			foe._start_rush()
			times = [0.2, 0.5, 0.8, 1.0, 1.25, 1.6]
		"morrow":
			var fort = root.find_children("*", "RedtideFort", true, false)[0]
			foe = fort.boss
			_put(fort.to_global(Vector3(0, 6.4, 2.0)), fort.to_global(Vector3(0, 0, -1)) - fort.to_global(Vector3.ZERO))
			foe.alert()
			foe.global_position = fort.to_global(Vector3(0, 6.4, -8.0))
			foe.reset_physics_interpolation()
			foe._start_rush()
			times = [0.2, 0.5, 0.7, 0.82, 0.95, 1.3]
		"queen", "puddle":
			var cave = isl.get_node("BroodCave")
			foe = cave.queen
			_put(foe.global_position + Vector3(0.0, 0.3, 10.0), Vector3(0, 0, -1))
			if n == "queen":
				foe.wake()
				foe._begin("burrow")
				times = [0.3, 0.9, 1.5, 2.1, 2.6, 2.95, 3.4]
			else:
				var at: Vector3 = p.global_position + Vector3(1.5, 2.0, -2.5)
				root.get_node("FX").spit(at, Vector3(0, -6.0, 0), 6.0, 1.6, 4.0, 3.0)
				times = [0.25, 0.6, 1.5, 3.4, 4.2]
	t0 = t


func _cam() -> void:
	var a: Vector3 = p.global_position
	var b: Vector3 = foe.global_position if foe and is_instance_valid(foe) else a + Vector3(0, 0, -5)
	if name_ == "puddle":
		b = p.global_position + Vector3(1.5, 0, -2.5)
	var d := b - a
	d.y = 0.0
	d = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
	var far := 9.0 if name_ in ["grell", "morrow", "queen"] else 4.2
	cam.global_position = a - d * far * 0.55 + Vector3.UP * (far * 0.45) + d.cross(Vector3.UP) * 1.2
	cam.look_at((a + b) * 0.5 + Vector3.UP * 0.6, Vector3.UP)


func _process(d: float) -> bool:
	t += d
	if t < 2.5:
		return false
	if p == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false):
			c._finish(true)
		var hud = get_first_node_in_group("hud")
		if hud:
			hud.visible = false
		p = get_first_node_in_group("player")
		p.health_component.max_health = 99999.0
		isl = root.get_node("World/Islands/Brinehollow")
		# (the player reads the camera's rig two parents up)
		var rig := Node3D.new()
		var arm := Node3D.new()
		root.add_child(rig)
		rig.add_child(arm)
		cam = Camera3D.new()
		cam.fov = 55
		cam.far = 800
		arm.add_child(cam)
		cam.current = true
		return false
	if name_ == "":
		if todo.is_empty():
			quit()
			return true
		_begin(str(todo.pop_front()))
	_cam()
	if shots < times.size() and t - t0 >= float(times[shots]):
		var path := ProjectSettings.globalize_path("%s/%s_%d.png" % [out, name_, shots])
		root.get_texture().get_image().save_png(path)
		print("shot %s_%d at %.2f s (foe state %s)" % [name_, shots, t - t0, str(foe.get("state")) if foe else "-"])
		shots += 1
		if shots >= times.size():
			name_ = ""
	return false

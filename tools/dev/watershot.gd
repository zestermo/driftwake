extends SceneTree
## Water shots: a grunt shoved off the beach into the sea (plunge, float,
## swim back), then the player knocked under while swimming. Args: <out_prefix>
var t := 0.0
var p
var cam: Camera3D
var out := ""
var phase := 0
var t0 := 0.0
var g
var ocean
var edge := Vector3.INF
var deep := Vector3.INF
var to_sea := Vector3.ZERO
var shots := []
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n, " grunt ", g.state if g else -1, " player ", p.current_state_name())
func view(focus: Vector3, dist: float, h: float) -> void:
	var r := Vector3(-to_sea.z, 0, to_sea.x)
	cam.global_position = focus + r * dist + Vector3(0, h, 0) - to_sea * 1.5
	cam.look_at(focus + Vector3(0, 0.3, 0), Vector3.UP)
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if p == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
		var hud = root.get_tree().get_first_node_in_group("hud")
		if hud: hud.visible = false
		p = root.get_tree().get_first_node_in_group("player")
		p.health_component.max_health = 99999.0
		p.health_component.current_health = 99999.0
		ocean = root.get_node("Ocean")
		var ship = root.get_tree().get_first_node_in_group("ship")
		p.global_position = ship.global_transform * Vector3(0, 2.0, 0)
		p.reset_physics_interpolation()
		cam = Camera3D.new(); cam.fov = 50; cam.far = 800
		var r2 := Node3D.new(); var a2 := Node3D.new()
		root.add_child(r2); r2.add_child(a2); a2.add_child(cam)
		var isl = root.get_node("World/Islands/Brinehollow")
		var c := Vector2(46, 110)
		var ts := Vector2(1, 0.15).normalized()
		for f in range(4, 90):
			var l: Vector2 = c + ts * float(f)
			var gp: Vector3 = isl.to_global(Vector3(l.x, 0, l.y))
			var dd: float = ocean.depth_at(gp, [], true)
			if edge == Vector3.INF and dd > -0.3:
				edge = isl.to_global(Vector3(l.x, 0, l.y)) - isl.to_global(Vector3(c.x, 0, c.y)).normalized() * 0.0
				edge.y = -dd
			if dd > 3.0 and dd < 30.0:
				deep = gp
				break
		to_sea = deep - edge; to_sea.y = 0; to_sea = to_sea.normalized()
		var camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
		g = camp.grunts[3]
		g.humanoid.seated = false
		return false
	var e := t - t0
	match phase:
		0:
			if t < 4.0: return false
			cam.current = true
			g.global_position = edge - to_sea * 1.0 + Vector3.UP * 0.6
			g.reset_physics_interpolation()
			g._yaw = atan2(to_sea.x, to_sea.z)  # back to the sea
			g.facing.rotation.y = g._yaw
			phase = 1; t0 = t
		1:
			view(edge + to_sea * 3.0, 7.5, 2.2)
			if e < 0.8: return false
			g._knock_down(to_sea * 9.0 + Vector3.UP * 5.0)
			shots = [[0.3, "1_thrown"], [0.75, "2_splash"], [1.2, "3_under"], [1.9, "4_rising"], [2.8, "5_floating"], [3.8, "6_swimming"], [6.0, "7_to_shore"], [9.0, "8_ashore"]]
			phase = 2; t0 = t
		2:
			var hp: Vector3 = g.humanoid.hips.global_position
			view(Vector3(hp.x, 0.0, hp.z), 6.5, 1.8)
			if shots.size() > 0 and e >= shots[0][0]:
				shot("g" + shots[0][1])
				print("   hip depth ", snappedf(ocean.get_wave_height(hp) - hp.y, 0.01))
				shots.pop_front()
			if shots.is_empty():
				# the player: swimming, knocked under, floats back up
				p.global_position = Vector3(deep.x, ocean.get_wave_height(deep) - 0.5, deep.z) + to_sea * 4.0
				p.reset_physics_interpolation()
				phase = 3; t0 = t
		3:
			view(p.global_position + Vector3(0, 0.6, 0), 5.0, 1.0)
			if e < 1.5: return false
			p.knock_down(Vector3(0.5, -6.0, 0.0) + to_sea * 2.0)
			shots = [[0.3, "1_hit"], [0.9, "2_under"], [1.8, "3_rising"], [2.8, "4_surfacing"], [3.6, "5_treading"]]
			phase = 4; t0 = t
		4:
			var hp: Vector3 = p.body_model.hips.global_position
			view(Vector3(hp.x, 0.0, hp.z), 5.0, 1.2)
			if shots.size() > 0 and e >= shots[0][0]:
				shot("p" + shots[0][1])
				print("   hip depth ", snappedf(ocean.get_wave_height(hp) - hp.y, 0.01))
				shots.pop_front()
			if shots.is_empty():
				quit()
	return false

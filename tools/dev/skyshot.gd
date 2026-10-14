extends SceneTree
## Birds (SkyBirds): Brinehollow's harbour gulls from the dock, the high flock
## over the island, a gull close up in flight (following it), parrots over the
## forest, and the ship's gulls near land from astern. Two frames a shot, 0.5 s
## apart. Args: <out_prefix> [psx]
var t := 0.0
var out := ""
var cam: Camera3D
var p
var ship
var wx
var isl
var sky
var shots: Array = ["harbour", "flock", "gull_close", "parrots", "ship"]
var i := -1
var frame := 0
var t0 := 0.0
var follow: Dictionary


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func set_hour(h: float) -> void:
	wx.skip_to(h)


func _process(dt: float) -> bool:
	t += dt
	if t < 2.0: return false
	if cam == null:
		if OS.get_cmdline_user_args().has("psx"): root.get_node("Settings").set_value("video", "psx_preset", 4, false)
		else: root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		p = get_first_node_in_group("player")
		ship = get_first_node_in_group("ship")
		wx = root.get_node("Weather")
		wx.forced = 0
		wx.forced_at = wx.world_time() - 100.0
		set_hour(10.5)
		isl = root.get_node("World/Islands/Brinehollow")
		sky = root.get_node("Weather/Ambience/SkyBirds")
		cam = Camera3D.new(); cam.fov = 62; cam.far = 1500
		root.add_child(cam); cam.current = true
		return false
	if i >= 0 and i < shots.size():
		_follow(shots[i])
	if i < 0 or (t - t0 > 0.5 and t0 > 0.0):
		if i >= 0:
			root.get_texture().get_image().save_png("%s_%s_%d.png" % [out, shots[i], frame])
			frame += 1
			t0 = t
			if frame < 2:
				return false
		i += 1
		frame = 0
		if i >= shots.size():
			print("SAVED")
			quit()
			return false
		_setup(shots[i])
		t0 = t + 5.0
	return false


func _birds(kind: int) -> Array:
	return sky.birds.filter(func(b): return b["kind"] == kind and not b["gone"])


func _setup(s: String) -> void:
	match s:
		"harbour":
			var dp: Vector2 = isl._dock_point(isl.DOCK_LENGTH)
			var end: Vector3 = isl.to_global(Vector3(dp.x, isl.DOCK_DECK_Y, dp.y))
			p.global_position = end + Vector3.UP * 0.3
			var perched: Array = sky.birds.filter(func(b): return b["mode"] == 4 and b["kind"] == 0)
			var look: Vector3 = perched[0]["pos"] if not perched.is_empty() else isl.global_position
			var back := (end - look)
			back.y = 0.0
			cam.global_position = look + back.normalized() * 9.0 + Vector3.UP * 3.0
			cam.look_at(look + Vector3.UP * 4.0, Vector3.UP)
		"flock":
			var dark := _birds(1)
			var c: Vector3 = dark[0]["pos"] if not dark.is_empty() else isl.global_position + Vector3.UP * 50.0
			cam.global_position = Vector3(c.x, 0.0, c.z) + Vector3(60.0, 12.0, 40.0)
			cam.global_position.y = float(root.get_node("Ocean").get_wave_height(cam.global_position)) + 12.0 + maxf(isl.height_at(isl.to_local(cam.global_position).x, isl.to_local(cam.global_position).z), 0.0)
			cam.look_at(c, Vector3.UP)
		"gull_close":
			var g := _birds(0).filter(func(b): return b["mode"] == 2)
			follow = g[0] if not g.is_empty() else {}
		"parrots":
			var pr := _birds(2)
			follow = pr[0] if not pr.is_empty() else {}
		"ship":
			var wg = root.get_node("World/Islands")
			for k in range(32):
				var a := k * TAU / 32.0
				var c: Vector2 = wg.starter_center + Vector2(cos(a), sin(a)) * 360.0
				if wg._deep_enough(c, 140.0):
					ship.place(Vector3(c.x, 0, c.y), a + PI * 0.5)
					break
			ship.set_anchored(false)
			ship.sail = 0.67
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * Vector3(0, HullBuilder.DECK_Y + 0.3, 1.0)
			p.reset_physics_interpolation()
			t0 = t + 14.0


func _follow(s: String) -> void:
	match s:
		"gull_close":
			if follow.is_empty(): return
			var at: Vector3 = follow["pos"]
			var yaw := float(follow["yaw"])
			cam.global_position = at + Basis(Vector3.UP, yaw) * Vector3(2.2, 0.6, 1.4)
			cam.look_at(at, Vector3.UP)
		"parrots":
			if follow.is_empty(): return
			var at: Vector3 = follow["pos"]
			cam.global_position = at + Vector3(7.0, 2.5, 7.0)
			cam.look_at(at, Vector3.UP)
		"ship":
			var xf: Transform3D = ship.get_global_transform_interpolated()
			cam.global_position = xf * Vector3(-7.0, 8.0, 30.0)
			cam.look_at(xf * Vector3(0, 9.0, 0.0), Vector3.UP)
			if p.global_position.distance_to(xf.origin) > 15.0:
				p.global_position = xf * Vector3(0, HullBuilder.DECK_Y + 0.3, 1.0)

extends SceneTree
## Sea polish: the foam wake behind the ship under way (from astern, from
## above), the turquoise shallows round Brinehollow and another island, and
## rain pooling on deck. Args: <out_prefix>
var t := 0.0
var out := ""
var cam: Camera3D
var ship
var p
var w
var step := 0
var t0 := 0.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)
func set_hour(h: float) -> void:
	var dh := fposmod(h - float(w.hour()), 24.0)
	w.world_offset += dh / 24.0 * float(w.DAY_LEN)
func behind(back: float, up: float, look_ahead: float) -> void:
	var f: Vector3 = -ship.global_basis.z
	f.y = 0.0
	f = f.normalized()
	cam.global_position = ship.global_position - f * back + Vector3.UP * up
	cam.look_at(ship.global_position + f * look_ahead, Vector3.UP)
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	match step:
		0:
			# ("psx": the game's sharper preset, for the README; not saved)
			if OS.get_cmdline_user_args().has("psx"): root.get_node("Settings").set_value("video", "psx_preset", 4, false)
			else: root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			get_first_node_in_group("hud").visible = false
			ship = get_first_node_in_group("ship")
			p = get_first_node_in_group("player")
			w = root.get_node("Weather")
			set_hour(10.0)
			cam = Camera3D.new(); cam.fov = 60; cam.far = 1500; root.add_child(cam); cam.current = true
			# out past the dock, sailing on (the sails full, held at speed)
			var sc: Vector2 = root.get_node("World/Islands").starter_center
			ship.place(Vector3(sc.x + 330.0, 0.0, sc.y + 120.0), 0.6)
			for e in get_nodes_in_group("enemy_ships"): e.queue_free()
			t0 = t; step = 1
		1:
			ship.sail = 1.0
			ship.speed = 11.0
			ship._yaw_rate = 0.14 if t - t0 > 3.0 else 0.0
			p.global_position = ship.global_transform * Vector3(0, 0.8, 2.0)
			behind(26.0, 11.0, 0.0)
			if t - t0 < 8.0: return false
			snap("wake_astern")
			t0 = t; step = 2
		2:
			ship.sail = 1.0
			ship.speed = 11.0
			ship._yaw_rate = 0.14
			p.global_position = ship.global_transform * Vector3(0, 0.8, 2.0)
			cam.global_position = ship.global_position + Vector3(0, 55.0, 0) - (-ship.global_basis.z) * 30.0
			cam.look_at(ship.global_position - (-ship.global_basis.z) * 30.0, -ship.global_basis.z)
			if t - t0 < 1.5: return false
			snap("wake_above")
			# the shallows: Brinehollow's shore from the sea, high up
			var sc: Vector2 = root.get_node("World/Islands").starter_center
			ship.place(Vector3(sc.x + 2000.0, 0.0, sc.y), 0.0)
			cam.global_position = Vector3(sc.x + 150.0, 45.0, sc.y + 230.0)
			cam.look_at(Vector3(sc.x, 0.0, sc.y + 40.0), Vector3.UP)
			p.global_position = cam.global_position + Vector3(0, 20, 0)
			t0 = t; step = 3
		3:
			if t - t0 < 2.0: return false
			snap("shallows_brinehollow")
			t0 = t; step = 4
		4:
			# rain on deck (soaked through), seen from the stern cabin roof
			var sc: Vector2 = root.get_node("World/Islands").starter_center
			ship.place(Vector3(sc.x + 330.0, 0.0, sc.y + 120.0), 0.6)
			w.force(2)
			ship.wet = 1.0
			t0 = t; step = 5
		5:
			ship.sail = 0.0
			if t - t0 < 0.3:
				p.global_position = ship.global_transform * Vector3(0, 0.8, 4.2)
			cam.global_position = ship.global_transform * Vector3(0.6, 3.2, 6.0)
			cam.look_at(ship.global_transform * Vector3(0, 0.3, -1.0), Vector3.UP)
			if t - t0 < 3.0: return false
			snap("rain_deck")
			quit()
	return false

extends SceneTree
## The Sea King fighting our ship: circling, rearing over the deck, its head
## down on the deck, its tail up. Args: <out_prefix>
var t := 0.0
var out := ""
var cam: Camera3D
var ship
var sk
var p
var step := 0
var t0 := 0.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)
func aim() -> void:
	var at: Vector3 = ship.global_position.lerp(sk.head_position(), 0.5)
	cam.global_position = ship.global_transform * Vector3(-30.0, 14.0, 16.0)
	cam.look_at(at + Vector3(0, 3, 0), Vector3.UP)
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	match step:
		0:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			get_first_node_in_group("hud").visible = false
			ship = get_first_node_in_group("ship")
			p = get_first_node_in_group("player")
			sk = get_first_node_in_group("sea_kings")
			for e in get_nodes_in_group("enemy_ships"): e.queue_free()
			ship.place(Vector3(sk.lair.x + 60.0, 0.0, sk.lair.y), 0.0)
			cam = Camera3D.new(); cam.fov = 60; cam.far = 1500; root.add_child(cam); cam.current = true
			t0 = t; step = 1
		1:
			if t - t0 < 0.3: return false
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * Vector3(0, 0.8, 2.0)
			p.reset_physics_interpolation()
			t0 = t; step = 2
		2:
			aim()
			if t - t0 < 5.0: return false
			sk._next = 999.0
			snap("circle")
			sk._start_rear(ship)
			t0 = t; step = 3
		3:
			aim()
			if t - t0 < 1.1: return false
			snap("rear")
			t0 = t; step = 4
		4:
			aim()
			if t - t0 < 1.0: return false
			snap("bite")
			t0 = t; step = 5
		5:
			aim()
			if t - t0 < 2.0: return false
			sk._next = 999.0
			sk._start_tail(ship)
			t0 = t; step = 6
		6:
			aim()
			if t - t0 < 1.35: return false
			snap("tail")
			quit()
	return false

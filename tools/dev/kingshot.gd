extends SceneTree
## The Sea King fighting our ship: circling (from off her quarter and low from
## the water), rearing over the deck, its head down on the deck (and a close look
## at it), its tail up. Args: <out_prefix> [storm] [psx]
var t := 0.0
var out := ""
var cam: Camera3D
var ship
var sk
var p
var step := 0
var t0 := 0.0
var view := "high"
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)
func aim() -> void:
	var at: Vector3 = ship.global_position.lerp(sk.head_position(), 0.5)
	match view:
		"low":
			# down at the water outside its circle, looking back past the coils at the head and the ship
			var side: Vector3 = (sk.head_position() - ship.global_position) * Vector3(1, 0, 1)
			var r: Vector3 = Vector3.UP.cross(side.normalized())
			cam.global_position = ship.global_position + side * 2.1 + r * 14.0 + Vector3(0, 3.0, 0)
			cam.look_at(sk.head_position().lerp(ship.global_position, 0.3) + Vector3(0, 2, 0), Vector3.UP)
		"wide":
			# high over her, the whole length of it in frame
			var side: Vector3 = (sk.head_position() - ship.global_position) * Vector3(1, 0, 1)
			cam.global_position = ship.global_position - side * 0.6 + Vector3(0, 48.0, 0)
			cam.look_at(sk.head_position() + side * 0.3, Vector3.UP)
		"head":
			var h: Vector3 = sk.head_position()
			var fwd: Vector3 = -(sk._head.global_basis.z as Vector3)
			var side: Vector3 = sk._head.global_basis.x
			cam.global_position = h + fwd * 9.0 + side * 6.5 + Vector3(0, 3.5, 0)
			cam.look_at(h + Vector3(0, 0.5, 0), Vector3.UP)
		_:
			cam.global_position = ship.global_transform * Vector3(-30.0, 14.0, 16.0)
			cam.look_at(at + Vector3(0, 3, 0), Vector3.UP)
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if cam: aim()
	match step:
		0:
			# ("psx": the game's sharper preset, for the README; not saved)
			if OS.get_cmdline_user_args().has("psx"): root.get_node("Settings").set_value("video", "pixelate", true, false)
			else: root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			if OS.get_cmdline_user_args().has("storm"):
				var w = root.get_node("Weather")
				w.forced = 3
				w.forced_at = w.world_time() - 100.0
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
			if t - t0 < 5.0: return false
			sk._next = 999.0
			snap("circle")
			view = "low"
			t0 = t; step = 3
		3:
			if t - t0 < 0.4: return false
			snap("circle_low")
			view = "wide"
			t0 = t; step = 30
		30:
			if t - t0 < 0.4: return false
			snap("circle_wide")
			view = "high"
			sk._start_rear(ship)
			t0 = t; step = 4
		4:
			if t - t0 < 1.1: return false
			snap("rear")
			view = "low"
			t0 = t; step = 5
		5:
			if t - t0 < 0.4: return false
			snap("rear_low")
			view = "high"
			t0 = t; step = 6
		6:
			if t - t0 < 0.8: return false
			snap("bite")
			view = "head"
			t0 = t; step = 7
		7:
			if t - t0 < 0.4: return false
			snap("bite_head")
			view = "high"
			t0 = t; step = 8
		8:
			if t - t0 < 2.0: return false
			sk._next = 999.0
			sk._start_tail(ship)
			t0 = t; step = 9
		9:
			if t - t0 < 1.35: return false
			snap("tail")
			quit()
	return false

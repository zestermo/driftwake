extends SceneTree
## The ship gadgets (1.28) at work on the crew's ship in the world: the burst launcher's blast and spray (from astern),
## the harpoon's line to an enemy ship ahead (from the side), the smoke screen's bank (from astern, high).
## Args: <out_prefix> [tier 0-2]. Writes <out>_burst.png, <out>_harpoon.png, <out>_smoke.png.
var t := 0.0
var out := ""
var tier := 2
var cam: Camera3D
var ship
var es
var step := 0
var t0 := 0.0


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	tier = int(a[1]) if a.size() > 1 else 2
	change_scene_to_file("res://scenes/world/world.tscn")


func L(v: Vector3) -> Vector3:
	return ship.global_transform * v


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, name])
	print("shot ", name)


func _process(d: float) -> bool:
	t += d
	if t < 2.0:
		return false
	var SG = load("res://scripts/ship/ship_gadgets.gd")
	match step:
		0:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			get_first_node_in_group("hud").visible = false
			ship = get_first_node_in_group("ship")
			var w = root.get_node("Weather")
			w.forced = 0
			w.forced_at = w.world_time() - 100.0
			w.skip_to(11.0)
			cam = Camera3D.new()
			cam.fov = 60
			cam.far = 1500
			root.add_child(cam)
			cam.current = true
			es = get_nodes_in_group("enemy_ships")[0]
			es.global_transform = Transform3D(Basis(Vector3.UP, ship.global_rotation.y + PI * 0.5), L(Vector3(0, 0, -55)) + Vector3(0, es.global_position.y - ship.global_position.y, 0))
			es._pos = Vector3(es.global_position.x, 0, es.global_position.z)
			es.set_physics_process(false)
			cam.global_position = L(Vector3(-14, 7, 30))
			cam.look_at(L(Vector3(0, 1, 8)), Vector3.UP)
			SG.apply(ship, "burst_launcher", tier, null, null)
			t0 = t
			step = 1
		1:
			if t - t0 > 0.25:
				_shot("burst")
				load("res://scripts/ship/harpoon_cannon.gd").harpoon(ship, es, tier)
				cam.global_position = L(Vector3(-38, 10, -24))
				cam.look_at(L(Vector3(0, 2, -30)), Vector3.UP)
				t0 = t
				step = 2
		2:
			if t - t0 > 1.2:
				_shot("harpoon")
				SG.apply(ship, "smoke_screen", tier, null, null)
				cam.global_position = L(Vector3(-25, 16, 45))
				cam.look_at(L(Vector3(0, 2, 4)), Vector3.UP)
				t0 = t
				step = 3
		3:
			if t - t0 > 3.0:
				_shot("smoke")
				quit()
	return false

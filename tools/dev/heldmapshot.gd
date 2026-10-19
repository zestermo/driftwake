extends SceneTree
## The held map on Brinehollow: the captain looks round a few places (the harbour, the ruins' path, the
## lighthouse hill), stands on the quay and takes the map out. Shots: the game camera on the island page
## (_isle), on the chart (_chart), the captain holding it seen from the front (_front), and half way
## through unrolling (_unroll). Args: <out_prefix> [psx]
var t := 0.0
var out := ""
var step := 0
var t0 := 0.0
var p
var cam: Camera3D


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func _shot(nm: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, nm])
	print("shot ", nm)


func _process(d: float) -> bool:
	t += d
	if t < 2.5:
		return false
	match step:
		0:
			if OS.get_cmdline_user_args().has("psx"):
				root.get_node("Settings").set_value("video", "pixelate", true, false)
			else:
				root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			p = get_first_node_in_group("player")
			var gm = root.get_node("GameManager")
			var mf = load("res://scripts/map/map_fog.gd")
			var w = get_first_node_in_group("world_gen")
			var dd: Dictionary = load("res://scripts/map/map_isles.gd").of(w.starter_island)
			var o: Vector2 = dd["o"]
			for q in [Vector2(0, -62), Vector2(0, -110), Vector2(-30, -20), Vector2(-62, 58), Vector2(-40, 20), Vector2(40, -45), Vector2(78, -30)]:
				mf.look(gm, dd, Vector3(o.x + q.x, 30.0 if q == Vector2(78, -30) else 4.0, o.y + q.y))
			var at: Vector2 = o + Vector2(6, -100)
			p.state_machine.force_state("Idle", {})
			p.global_position = Vector3(at.x, 6.0, at.y)
			p.reset_physics_interpolation()
			p.player_model.rotation.y = 0.0
			get_first_node_in_group("hud").visible = false
			t0 = t
		1:
			if t - t0 < 1.5:
				return false
			p.get_node("MapHold").toggle()
			t0 = t
		2:
			if t - t0 < 0.17:
				return false
			_shot("unroll")
			t0 = t
		3:
			if t - t0 < 1.2:
				return false
			_shot("isle")
			var c3 := root.get_viewport().get_camera_3d()
			var sh = p.body_model.get_node("MapSheet")
			print("CAM ", c3.global_position - p.global_position, " fwd ", -c3.global_basis.z, " sheet ", sh.global_position - p.global_position,
				" rig ", c3.get_parent().get_parent().global_position - p.global_position, " facing ", -p.player_model.global_basis.z,
				" hands ", p.body_model.hand_l.global_position - p.global_position, p.body_model.hand_r.global_position - p.global_position)
			p.get_node("MapHold").page.show_isle(false)
			t0 = t
		4:
			if t - t0 < 0.6:
				return false
			_shot("chart")
			p.get_node("MapHold").page.show_isle(true)
			cam = Camera3D.new()
			cam.fov = 50.0
			root.add_child(cam)
			var f: Vector3 = -p.player_model.global_basis.z
			var r: Vector3 = p.player_model.global_basis.x
			cam.global_position = p.global_position + f * 2.2 + r * 0.9 + Vector3.UP * 1.7
			cam.look_at(p.global_position + Vector3.UP * 1.1, Vector3.UP)
			cam.current = true
			t0 = t
		5:
			if t - t0 < 0.4:
				return false
			_shot("front")
			quit()
	step += 1
	return false

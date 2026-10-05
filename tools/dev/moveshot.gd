extends SceneTree
## Player: neck portrait, dash off-hand, plunge attack frames. Args: <out_prefix>
var t := 0.0
var p
var cam: Camera3D
var out := ""
var phase := 0
var t0 := 0.0
var shots := 0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n, " state ", p.current_state_name(), " act ", p.body_model.current_action())
func tap(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
	var e2 := InputEventAction.new(); e2.action = a; e2.pressed = false; Input.parse_input_event(e2)
func side(dist: float, h: float, side_sign: float = 1.0) -> void:
	var f: Vector3 = -p.player_model.global_basis.z; f.y = 0; f = f.normalized()
	var r := Vector3(-f.z, 0, f.x) * side_sign
	var foc: Vector3 = p.global_position + Vector3(0, 1.0, 0)
	cam.global_position = foc + r * dist + f * 1.0 + Vector3(0, h, 0)
	cam.look_at(foc, Vector3.UP)
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if p == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
		var hud = root.get_tree().get_first_node_in_group("hud")
		if hud: hud.visible = false
		p = root.get_tree().get_first_node_in_group("player")
		var r2 := Node3D.new(); var a2 := Node3D.new()
		root.add_child(r2); r2.add_child(a2)
		cam = Camera3D.new(); cam.fov = 45; cam.far = 600
		a2.add_child(cam)
		var isl = root.get_node("World/Islands/Brinehollow")
		var spot := Vector2(-6, -75)
		p.global_position = isl.to_global(Vector3(spot.x, isl.height_at(spot.x, spot.y) + 0.3, spot.y))
		p.reset_physics_interpolation()
		return false
	var e := t - t0
	match phase:
		0:
			if t < 2.5: return false
			cam.current = true
			p.player_model.rotation.y = 0.0
			phase = 1; t0 = t
		1:
			var foc: Vector3 = p.global_position + Vector3(0, 1.55, 0)
			cam.global_position = foc + Vector3(1.1, 0.1, -1.1)
			cam.look_at(foc, Vector3.UP)
			if e > 0.4 and not has_meta("n1"): set_meta("n1", 1); shot("neck_front")
			if e > 0.6:
				cam.global_position = foc + Vector3(1.4, 0.15, 0.6)
				cam.look_at(foc, Vector3.UP)
			if e > 0.9:
				shot("neck_side"); tap("ready_weapon"); phase = 2; t0 = t
		2:
			if e < 0.8: return false
			# dash forward (everything faces -Z: camera rig yaw 0)
			p.player_model.rotation.y = 0.0
			Input.action_press("move_forward")
			tap("dodge")
			phase = 3; t0 = t
		3:
			var foc3: Vector3 = p.global_position + Vector3(0, 1.0, 0)
			cam.global_position = foc3 + Vector3(4.0, 0.6, -0.8)
			cam.look_at(foc3, Vector3.UP)
			if e > 0.1 and not has_meta("d1"): set_meta("d1", 1); shot("dash_fwd")
			if e > 0.5:
				Input.action_release("move_forward")
				phase = 4; t0 = t
		4:
			if e < 0.6: return false
			Input.action_press("move_right")
			tap("dodge")
			phase = 5; t0 = t
		5:
			var foc: Vector3 = p.global_position + Vector3(0, 1.0, 0)
			cam.global_position = foc + Vector3(0.4, 0.6, -4.0)
			cam.look_at(foc, Vector3.UP)
			if e > 0.1 and not has_meta("d2"): set_meta("d2", 1); shot("dash_side")
			if e > 0.5:
				Input.action_release("move_right")
				phase = 6; t0 = t
		6:
			if e < 0.6: return false
			Input.action_press("jump")
			phase = 7; t0 = t
		7:
			var foc7: Vector3 = p.global_position + Vector3(0, 1.0, 0)
			cam.global_position = Vector3(foc7.x + 5.0, cam.global_position.y if e > 0.05 else foc7.y + 0.8, foc7.z)
			cam.look_at(foc7, Vector3.UP)
			if e > 0.25: Input.action_release("jump")
			if e > 0.3 and not has_meta("j"):
				set_meta("j", 1); tap("light_attack")
			var times := [0.4, 0.5, 0.62, 0.78, 0.95]
			if shots < times.size() and e >= times[shots]:
				shot("plunge%d" % shots); shots += 1
			if shots >= times.size(): quit()
	return false

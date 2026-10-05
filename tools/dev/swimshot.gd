extends SceneTree
## Swimming shots. Args: <out_prefix>
var t := 0.0
var p
var ship
var cam: Camera3D
var out := ""
var phase := 0
var t0 := 0.0
var rig
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n, " state ", p.current_state_name())
func side(dist: float = 3.2, h: float = 0.9, ahead: float = 0.0) -> void:
	var f: Vector3 = -p.player_model.global_basis.z; f.y = 0; f = f.normalized()
	var r := Vector3(-f.z, 0, f.x)
	var foc: Vector3 = p.global_position + Vector3(0, 1.0, 0) + f * ahead
	cam.global_position = foc + r * dist + f * 1.2 + Vector3(0, h, 0)
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
		ship = root.get_tree().get_first_node_in_group("ship")
		cam = Camera3D.new(); cam.fov = 50; cam.far = 800
		var r2 := Node3D.new(); var a2 := Node3D.new()
		root.add_child(r2); r2.add_child(a2); a2.add_child(cam)
		rig = r2
		p.global_position = ship.global_transform * Vector3(9.0, 2.0, 0.6)
		p.reset_physics_interpolation()
		return false
	var e := t - t0
	match phase:
		0:
			if t < 4.0: return false
			cam.current = true
			p.player_model.rotation.y = ship.global_rotation.y + PI * 0.5
			phase = 1; t0 = t
		1:
			side()
			if e < 0.6: return false
			shot("tread")
			rig.rotation.y = ship.global_rotation.y + PI
			Input.action_press("move_forward")
			phase = 2; t0 = t
		2:
			side(3.4, 1.2)
			if e < 1.6: return false
			shot("swim1")
			phase = 3; t0 = t
		3:
			side(3.4, 1.2)
			if e < 0.35: return false
			shot("swim2")
			Input.action_press("dodge")
			phase = 4; t0 = t
		4:
			side(4.0, 1.4)
			if e < 0.8: return false
			shot("dive")
			Input.action_release("dodge"); Input.action_release("move_forward")
			phase = 5; t0 = t
		5:
			if e < 1.5: return false
			var lad = ship.get_node("ShipModel/LadderStarboard")
			p.global_position = lad.global_transform * Vector3(0, -1.6, 0.6)
			p.reset_physics_interpolation()
			phase = 6; t0 = t
		6:
			if e < 0.6: return false
			p.start_climb({"kind": "ladder", "ladder": ship.get_node("ShipModel/LadderStarboard")})
			phase = 7; t0 = t
		7:
			var lad = ship.get_node("ShipModel/LadderStarboard")
			cam.global_position = lad.global_transform * Vector3(2.4, 0.2, 3.2)
			cam.look_at(lad.global_transform * Vector3(0, -0.4, 0), Vector3.UP)
			if e > 0.8 and not has_meta("c1"): set_meta("c1", 1); shot("climb1")
			if e > 1.6 and not has_meta("c2"): set_meta("c2", 1); shot("climb2")
			if e > 2.3 and not has_meta("c3"): set_meta("c3", 1); shot("climb3")
			if e > 3.2:
				shot("deck"); quit()
	return false

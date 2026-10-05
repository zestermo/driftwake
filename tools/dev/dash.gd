extends SceneTree
var t := 0.0
var step := 0
var p
var start: Vector3
var yaw0 := 0.0
var fails := 0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func press(a: String, on := true) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = on; Input.parse_input_event(e)
func check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n); if not c: fails += 1
func cam_axes() -> Array:
	var yaw: float = root.get_node("World/CameraRig").global_rotation.y
	return [Vector3(-sin(yaw), 0, -cos(yaw)), Vector3(cos(yaw), 0, -sin(yaw))]
func _process(d: float) -> bool:
	t += d
	match step:
		0:
			if t < 1.0: return false
			p = root.get_tree().get_first_node_in_group("player")
			var isl = root.get_node("World/Islands/Brinehollow")
			var v = isl.VILLAGE + Vector2(0, 6)
			p.global_position = Vector3(150 + v.x, isl.hv(v) + 0.3, 150 + v.y); p.reset_physics_interpolation()
			press("ready_weapon"); press("ready_weapon", false); step = 1; t = 0
		1:
			if t < 0.8: return false
			start = p.global_position; yaw0 = p.player_model.rotation.y
			press("move_right"); press("dodge"); press("dodge", false); step = 2; t = 0
		2:
			if t > 0.05 and t < 0.1:
				pass
			if t > 0.12 and p.body_model.current_action() != "": 
				check("dash action plays (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dash")
				step = 3
		3:
			if p.current_state_name() != "Dodge":
				press("move_right", false)
				var ax = cam_axes()
				var moved: Vector3 = p.global_position - start
				print("   moved right %.2f m, forward %.2f m, turned %.1f deg" % [moved.dot(ax[1]), moved.dot(ax[0]), rad_to_deg(absf(wrapf(p.player_model.rotation.y - yaw0, -PI, PI)))])
				check("armed sidestep goes camera-right ~3 m", moved.dot(ax[1]) > 2.4 and absf(moved.dot(ax[0])) < 0.8)
				check("body keeps facing (no turn)", absf(wrapf(p.player_model.rotation.y - yaw0, -PI, PI)) < 0.2)
				press("ready_weapon"); press("ready_weapon", false); step = 4; t = 0
		4:
			if t < 0.8: return false
			start = p.global_position; yaw0 = p.player_model.rotation.y
			press("dodge"); press("dodge", false); step = 5; t = 0
		5:
			if t > 0.6:
				var back: Vector3 = p.player_model.global_basis.z
				var moved2: Vector3 = p.global_position - start
				print("   backstep %.2f m" % moved2.dot(back))
				check("no input = backstep", moved2.dot(back) > 2.0)
				print("RESULT fails=", fails); quit()
	return false

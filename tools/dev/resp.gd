extends SceneTree
var t := 0.0
var step := 0
var p
var n := 0
var worst := 0.0
var lagged := 0
var switches := 0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func press(a: String, on := true) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = on; Input.parse_input_event(e)
func _physics_process(d: float) -> bool:
	t += d
	if step == 0 and t > 1.0:
		p = root.get_tree().get_first_node_in_group("player")
		var isl = root.get_node("World/Islands/Brinehollow")
		var v = isl.VILLAGE + Vector2(0, 6)
		p.global_position = Vector3(150 + v.x, isl.hv(v) + 0.3, 150 + v.y); p.reset_physics_interpolation()
		press("move_forward"); press("sprint"); step = 1; t = 0
	elif step == 1 and t > 0.5:
		step = 2; t = 0; press("move_left")
	elif step >= 2:
		# alternate left/right every 0.2 s; compare velocity to the input direction each tick
		if fmod(t, 0.4) < d and t > 0.05: press("move_left", false); press("move_right"); switches += 1
		elif fmod(t + 0.2, 0.4) < d: press("move_right", false); press("move_left"); switches += 1
		var rig = root.get_node("World/CameraRig")
		var yaw: float = rig.global_rotation.y
		var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var f := Vector3(-sin(yaw), 0, -cos(yaw)); var r := Vector3(cos(yaw), 0, -sin(yaw))
		var want := (f * -inp.y + r * inp.x).normalized()
		var hv := Vector3(p.velocity.x, 0, p.velocity.z)
		if n > 2 and hv.length() > 0.1:
			var ang := rad_to_deg(hv.normalized().angle_to(want))
			worst = maxf(worst, ang)
			if ang > 1.0: lagged += 1
		n += 1
		if t > 2.0:
			print("ticks off-input: %d over %d direction switches" % [lagged, switches]); print("max angle between velocity and input over %d ticks: %.1f deg" % [n, worst])
			press("move_left", false); press("move_right", false); press("move_forward", false); press("sprint", false)
			step = 3
	return false
func _process(_d):
	if step == 3:
		step = 4; t = 0
	elif step == 4 and t > 0.15:
		print("speed 0.15 s after release: %.2f m/s" % Vector2(p.velocity.x, p.velocity.z).length()); quit()
	return false

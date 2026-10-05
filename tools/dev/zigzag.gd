extends SceneTree
var t := 0.0
var step := 0
var p
var head: Node3D
var cam_r: Vector3
var cam_f: Vector3
var lat := []
var fwd := []
var sw := 0.0
var side := 1
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func press(a: String, on := true) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = on; Input.parse_input_event(e)
func _physics_process(d: float) -> bool:
	t += d
	match step:
		0:
			if t < 1.0: return false
			p = root.get_tree().get_first_node_in_group("player")
			var isl = root.get_node("World/Islands/Brinehollow")
			var v = isl.VILLAGE + Vector2(0, 6)
			p.global_position = Vector3(150 + v.x, isl.hv(v) + 0.3, 150 + v.y)
			p.reset_physics_interpolation()
			head = p.body_model.find_child("Head", true, false)
			var rig = root.get_node("World/CameraRig")
			var yaw: float = rig.global_rotation.y
			cam_f = Vector3(-sin(yaw), 0, -cos(yaw)); cam_r = Vector3(cos(yaw), 0, -sin(yaw))
			press("move_forward"); press("sprint"); step = 1; t = 0
		1:
			if t > 1.0:
				step = 2; t = 0; sw = 0
				press("move_left")
		2:
			sw += d
			if sw > 0.3:
				sw = 0
				if side > 0: press("move_left", false); press("move_right")
				else: press("move_right", false); press("move_left")
				side = -side
			if t > 0.6:
				var rel: Vector3 = head.global_position - p.global_position
				lat.append(rel.dot(cam_r)); fwd.append(rel.dot(cam_f))
			if t > 3.0:
				print("head lateral swing p2p %.2f m  (min %.2f max %.2f)" % [lat.max() - lat.min(), lat.min(), lat.max()])
				print("head forward offset range %.2f .. %.2f" % [fwd.min(), fwd.max()])
				quit()
	return false

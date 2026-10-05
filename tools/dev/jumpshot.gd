extends SceneTree
## Running jump, side view: lean frames. Args: <out_prefix>
var t := 0.0
var p
var cam: Camera3D
var out := ""
var phase := 0
var t0 := 0.0
var shots := 0
var log_t := 0.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
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
			Input.action_press("move_forward")
			phase = 1; t0 = t
		1:
			if e < 1.0: return false
			Input.action_press("jump")
			phase = 2; t0 = t
		2:
			var foc: Vector3 = p.global_position + Vector3(0, 1.0, 0)
			cam.global_position = foc + Vector3(5.0, 0.3, 0)
			cam.look_at(foc, Vector3.UP)
			if e > 0.3: Input.action_release("jump")
			var times := [0.05, 0.18, 0.32, 0.5, 0.65, 0.8]
			if shots < times.size() and e >= times[shots]:
				var up: Vector3 = p.lean.global_basis.y
				print("frame ", shots, " vy ", snappedf(p.velocity.y, 0.1), " lean fwd ", snappedf(-up.z, 0.03), " state ", p.current_state_name())
				root.get_texture().get_image().save_png("%s_%d.png" % [out, shots]); shots += 1
			if shots >= times.size(): quit()
	return false

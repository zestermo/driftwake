extends SceneTree
## Foot IK shots: standing across a step and on a slope, IK off vs on.
## Args: <out_prefix>
var t := 0.0
var p
var cam: Camera3D
var out := ""
var phase := 0
var t0 := 0.0
var isl
var box: StaticBody3D
var base := Vector3.ZERO
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	var h = p.body_model
	print("shot ", n, " ik_w ", snappedf(h._ik_w, 0.01), " h ", h._ik_h, " drop ", snappedf(h._ik_drop, 0.01))
func place(pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.reset_physics_interpolation()
	p.player_model.rotation.y = yaw
	p.velocity = Vector3.ZERO
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if p == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
		var hud = root.get_tree().get_first_node_in_group("hud")
		if hud: hud.visible = false
		p = root.get_tree().get_first_node_in_group("player")
		isl = root.get_node("World/Islands/Brinehollow")
		cam = Camera3D.new(); cam.fov = 40; cam.far = 500
		var r2 := Node3D.new(); var a2 := Node3D.new()
		root.add_child(r2); r2.add_child(a2); a2.add_child(cam)
		var spot := Vector2(6, -56)
		base = isl.to_global(Vector3(spot.x, isl.height_at(spot.x, spot.y), spot.y))
		# a 25 cm step under the left half
		box = StaticBody3D.new()
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.0, 0.5, 1.6); cs.shape = bs
		box.add_child(cs)
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = bs.size; mi.mesh = bm
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.45, 0.35, 0.25); mi.material_override = mat
		box.add_child(mi)
		root.add_child(box)
		box.global_position = base + Vector3(-0.62, 0.0, 0)
		place(base + Vector3(0, 0.3, 0), 0.0)
		return false
	var e := t - t0
	var foc: Vector3 = p.global_position + Vector3(0, 0.75, 0)
	cam.global_position = foc + Vector3(0.6, 0.1, 3.6)
	cam.look_at(foc, Vector3.UP)
	match phase:
		0:
			if t < 4.0: return false
			cam.current = true
			p.body_model.foot_ik = false
			phase = 1; t0 = t
		1:
			if e < 0.8: return false
			shot("step_off")
			p.body_model.foot_ik = true
			phase = 2; t0 = t
		2:
			if e < 0.8: return false
			shot("step_on")
			# walk across the step edge
			Input.action_press("move_left")
			phase = 3; t0 = t
		3:
			if e < 0.35: return false
			shot("step_walk1")
			phase = 4; t0 = t
		4:
			if e < 0.3: return false
			shot("step_walk2")
			Input.action_release("move_left")
			box.queue_free()
			# a slope: find the steepest walkable bit near the village
			var best := Vector3.ZERO; var bg := 0.0
			for x in range(-30, 30, 2):
				for z in range(-80, -20, 2):
					var h0: float = isl.height_at(x, z)
					if h0 < 1.0: continue
					var gx: float = isl.height_at(x + 1, z) - isl.height_at(x - 1, z)
					var g := absf(gx) * 0.5
					if g > bg and g < 0.6:
						bg = g; best = Vector3(x, h0, z)
			print("slope ", bg)
			place(isl.to_global(best) + Vector3(0, 0.4, 0), 0.0)
			p.body_model.foot_ik = false
			phase = 5; t0 = t
		5:
			if e < 1.0: return false
			shot("slope_off")
			p.body_model.foot_ik = true
			phase = 6; t0 = t
		6:
			if e < 0.8: return false
			shot("slope_on")
			quit()
	return false

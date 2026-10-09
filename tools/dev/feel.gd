extends SceneTree
var t := 0.0
var step := 0
var wait := 0.0
var p
var fails := 0
var peak := -999.0
var base_y := 0.0
var peaks := []
var turn_t := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func press(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
func release(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = false; Input.parse_input_event(e)
func tap(a: String) -> void:
	press(a); release(a)
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func st() -> String: return p.current_state_name()
func _physics_process(_d):
	if p and step in [21, 22, 24, 25]:
		peak = maxf(peak, p.global_position.y - base_y)
	return false
func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.0: return false
			p = root.get_tree().get_first_node_in_group("player")
			# flat spot in the village square
			var isl = root.get_node("World/Islands/Brinehollow")
			var v = isl.VILLAGE + Vector2(0, 6)
			p.global_position = Vector3(150 + v.x, isl.hv(v) + 0.3, 150 + v.y)
			p.reset_physics_interpolation()
			tap("ready_weapon"); wait = 0.6
		1:
			tap("light_attack"); wait = 0.1
		2:
			check("hit 1 = slash_r", st() == "LightAttack" and p.body_model.current_action() == "slash_r")
			wait = 0.35
		3:
			press("move_right"); wait = 0.25   # reposition between hits
		4:
			check("moving cancels recovery (Move state)", st() == "Move")
			release("move_right"); wait = 0.1
			tap("light_attack")
		5:
			wait = 0.05
		6:
			check("after moving, next click continues combo (hit 2 = slash_l)", p.body_model.current_action() == "slash_l")
			wait = 0.55
		7:
			tap("light_attack"); wait = 0.08
		8:
			check("hit 3 = spin finisher", p.body_model.current_action() == "slash_spin")
			wait = 0.2
		9:
			var trails := 0
			for c in p.body_model.get_children():
				if c is MeshInstance3D and c.mesh is ImmediateMesh: trails += 1
			check("slash trail spawned", trails >= 1)
			wait = 1.2
		10:
			tap("light_attack"); wait = 0.08
		11:
			check("after finisher, combo restarts at hit 1", p.body_model.current_action() == "slash_r")
			wait = 2.0
		12:
			tap("light_attack"); wait = 0.08
		13:
			check("after a long pause, combo restarts", p.body_model.current_action() == "slash_r")
			wait = 1.5
		14:
			# dust/particles exist after roll
			tap("dodge"); wait = 0.1
		15:
			var parts := 0
			for c in root.get_tree().current_scene.get_children():
				if c is CPUParticles3D: parts += 1
			check("dodge spawns dust particles", parts > 0)
			wait = 1.0
		16:
			tap("ready_weapon"); wait = 0.6
		17:
			# lean into turns: run in a circle
			press("move_forward"); press("sprint"); wait = 0.4
		18:
			# sweep the camera while sprinting = a sustained curve
			root.get_node("World/CameraRig").rotation.y += 2.2 * d
			if t > 0.0 and wait <= 0.0:
				pass
			turn_t += d
			if turn_t < 0.7: return false
		19:
			var roll: float = Basis(p.lean.basis.orthonormalized()).get_euler().z
			check("leans INTO the turn, i.e. left (roll %.2f rad)" % roll, roll > 0.05)
			release("move_forward"); release("sprint"); wait = 0.8
		20:
			base_y = p.global_position.y; peak = -999.0
			press("jump"); release("jump"); step = 21; wait = 0.0
			return false
		21:
			if st() in ["Idle", "Move"] and t > 0: pass
			if p.is_on_floor() and peak > 0.2:
				peaks.append(peak); step = 23
			return false
		23:
			wait = 0.3; step = 24
			base_y = p.global_position.y; peak = -999.0
			press("jump")
			return false
		24:
			if p.is_on_floor() and peak > 0.2:
				release("jump"); peaks.append(peak); step = 26
			return false
		26:
			print("   short hop %.2f m, held jump %.2f m" % [peaks[0], peaks[1]])
			check("tap = short hop, hold = full jump", peaks[0] < peaks[1] * 0.8)
			# jump buffer: drop from height, press jump just before landing
			p.global_position += Vector3(0, 3.0, 0); p.velocity = Vector3.ZERO; p.reset_physics_interpolation()
			step = 27
			return false
		27:
			if st() == "Fall" and p.velocity.y < -6.0:
				var space = p.get_world_3d().direct_space_state
				var q = PhysicsRayQueryParameters3D.create(p.global_position, p.global_position + Vector3(0, -0.6, 0), 1)
				if not space.intersect_ray(q).is_empty():
					tap("jump"); step = 28
			return false
		28:
			wait = 0.15
		29:
			check("buffered jump fires on landing", st() == "Jump" or p.velocity.y > 2.0)
			print("RESULT fails=", fails)
			quit()
	step += 1
	return false

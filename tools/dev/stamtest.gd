extends SceneTree
## Stamina gating, weapon-specific heavy attacks, sprint speed, camera look-at.
var t := 0.0
var step := 0
var wait := 0.0
var p
var fails := 0
var heavies := 0
var seen_anims := {}
var max_spd := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func act(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
	var e2 := InputEventAction.new(); e2.action = a; e2.pressed = false; Input.parse_input_event(e2)
func hold(a: String, on: bool) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = on; Input.parse_input_event(e)
func check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n); if not c: fails += 1
func rig() -> Node3D:
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	return cam.get_parent().get_parent() as Node3D
func _process(d: float) -> bool:
	t += d
	if p and p.body_model.current_action() != "":
		seen_anims[p.body_model.current_action()] = true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.0: return false
			p = root.get_tree().get_first_node_in_group("player")
			check("stamina starts full", is_equal_approx(p.stamina, p.MAX_STAMINA))
			check("sprint speed is 9", is_equal_approx(p.sprint_speed, 9.0))
			act("ready_weapon"); wait = 0.7; step = 1
		1:
			# spam heavy: 30, then 45 (fatigue), and the third (67.5) is refused
			if p.current_state_name() == "HeavyAttack":
				return false
			if heavies < 6:
				act("heavy_attack"); heavies += 1; wait = 0.12
				return false
			step = 2
		2:
			check("cutlass heavy is a thrust", seen_anims.has("thrust") and not seen_anims.has("heavy"))
			var cost: float = p.state_machine.current_state.heavy_cost()
			check("stamina ran out (%.1f, a heavy costs %.1f now)" % [p.stamina, cost], p.stamina < cost)
			# (regen may have crept back to half the cost, which is enough to try)
			p.stamina = minf(p.stamina, cost * 0.4)
			var before: float = p.stamina
			act("heavy_attack"); wait = 0.1; step = 3
			set_meta("before", before)
		3:
			check("empty bar refuses a heavy (state %s)" % p.current_state_name(), p.current_state_name() != "HeavyAttack")
			wait = 3.5; step = 4
		4:
			check("stamina regenerates (%.1f)" % p.stamina, p.stamina > 90.0)
			var s0: float = p.stamina
			act("dodge"); wait = 0.05; set_meta("s0", s0); step = 5
		5:
			check("dodge costs stamina (%.1f -> %.1f)" % [get_meta("s0"), p.stamina], p.stamina <= float(get_meta("s0")) - p.DODGE_COST + 0.5)
			wait = 3.0; step = 6
		6:
			var axe = ItemDB.get_item("boarding_axe")
			p.inventory_component.add_item(axe, 1)
			p.equip_weapon(axe, true)
			seen_anims.clear()
			wait = 0.8; step = 7
		7:
			act("heavy_attack"); wait = 1.2; step = 8
		8:
			check("axe heavy is the whirlwind", seen_anims.has("axe_whirl"))
			act("ready_weapon"); wait = 0.6; step = 9
		9:
			hold("move_forward", true); hold("sprint", true); wait = 0.0; step = 10; t = 0.0
		10:
			var hv := Vector2(p.velocity.x, p.velocity.z).length()
			max_spd = maxf(max_spd, hv)
			if t < 1.2: return false
			hold("move_forward", false); hold("sprint", false)
			check("sprint tops out at ~9 m/s (%.2f)" % max_spd, max_spd > 8.5 and max_spd < 9.5)
			check("sprinting drains stamina (%.1f)" % p.stamina, p.stamina < 90.0)
			# run the bar dry mid-sprint: winded, drops back to the jog
			p.stamina = 3.0
			hold("move_forward", true); hold("sprint", true); wait = 0.8; step = 20
		20:
			var hv := Vector2(p.velocity.x, p.velocity.z).length()
			check("winded: sprint stops when empty (speed %.2f, winded %s)" % [hv, p.winded], p.winded and hv < 6.5)
			hold("move_forward", false); hold("sprint", false)
			wait = 0.6; step = 11
		11:
			var b = p.body_model
			check("head looks along the camera aim when behind", b.look_weight > 0.9 and not p._looking_at_cam)
			# (weapon out you strafe facing the camera, so it can't get in front: sheathe)
			p.sheathe_weapon(true)
			var r := rig()
			r.global_rotation.y = p.player_model.global_rotation.y + PI  # camera swings in front
			wait = 0.4; step = 12
		12:
			check("camera in front -> face tracks the camera", p._looking_at_cam)
			var b = p.body_model
			var to_cam: Vector3 = root.get_viewport().get_camera_3d().global_position - b.head.global_position
			var face: Vector3 = -b.head.global_basis.z
			to_cam.y = 0; face.y = 0
			check("face turned toward the camera (%.0f deg off)" % rad_to_deg(face.angle_to(to_cam)), face.angle_to(to_cam) < deg_to_rad(40))
			print("RESULT fails=", fails); quit()
	return false

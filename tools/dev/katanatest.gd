extends SceneTree
## Katana: scabbard on the hip, two-handed hold, the slow three-cut combo, the
## held drawing strike (charge levels, creeping, the dash cut, standing down)
## and the hanging parry.
const STAGGER := 9; const DOWN := 11; const DEAD := 14
var t := 0.0
var step := 0
var wait := 0.0
var p
var camp
var g
var fails := 0
var saw := {}
var hp0 := 0.0
var d0 := 0.0
var pos0 := Vector3.ZERO
var creep := 0.0
var gpos0 := Vector3.ZERO
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func rig():
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	return cam.get_parent().get_parent() as Node3D
func face(target: Vector3) -> void:
	var d: Vector3 = target - p.global_position; d.y = 0
	rig().rotation.y = atan2(-d.x, -d.z)
	p.player_model.rotation.y = atan2(-d.x, -d.z)
func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at
func park(x, at: Vector3) -> void:
	x.humanoid.seated = false
	x.global_position = at + Vector3.UP * 0.3
	x.velocity = Vector3.ZERO
	x.reset_physics_interpolation()
func target_grunt(dist: float) -> void:
	var i := 0
	for x in camp.grunts:
		if is_instance_valid(x) and x != g and x.state != DEAD and x.state != DOWN:
			i += 1
			park(x, ground(p.global_position + Vector3(40 + i * 3, 0, 40)))
	park(g, ground(p.global_position - p.player_model.global_basis.z * dist))
	g._stagger_len = 30.0
	g._set_state(STAGGER)
	g.health.current_health = 400.0
	hp0 = 400.0
func attack(action: String) -> void:
	p.input_buffer.buffer_action(action)
func hilt_gap() -> float:
	var b = p.body_model
	return (b.hand_l.global_position - b.weapon.global_transform * Vector3(0, 0, 0.17)).length()
func _physics_process(_d: float) -> bool:
	if p:
		saw[p.body_model.current_action()] = true
		if p.current_state_name() == "Iai" and Input.is_action_pressed("move_forward"):
			creep = maxf(creep, Vector2(p.velocity.x, p.velocity.z).length())
	return false
func _process(d: float) -> bool:
	t += d
	if camp:
		for x in camp.grunts:
			if is_instance_valid(x):
				x._cooldown = 99.0; x._pistol_cd = 99.0; x._shot_cd = 99.0; x._shove_cd = 99.0
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			var spot: Vector3 = ground(camp.grunts[1].global_position + Vector3(12, 0, 0))
			p.global_position = spot + Vector3.UP * 0.2
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			p.state_machine.force_state("Idle", {})
			var katana = load("res://resources/items/katana.tres")
			var cutlass = load("res://resources/items/cutlass.tres")
			p.inventory_component.add_item(katana, 1)
			p.inventory_component.add_item(cutlass, 1)
			p.sheathe_weapon(true)
			p.equip_weapon(katana, false)
			var b = p.body_model
			check("the katana is its own style (%s)" % p.style(), p.style() == "katana")
			check("its scabbard hangs on the hip", b._katana_socket != null and b._katana_socket.get_node_or_null("Saya") != null)
			check("sheathed, the blade sits in the scabbard", b.weapon.get_parent() == b._katana_socket)
			check("no second blade with a two-handed katana", not p.set_offhand(cutlass) and p.offhand_weapon == null)
			p.draw_weapon()
			wait = 0.8
			step += 1
		1:
			var b = p.body_model
			check("drawn, the blade is in the right hand", b.weapon.get_parent() == b.hand_r)
			check("...the scabbard stays on the hip", b._katana_socket.get_node_or_null("Saya") != null)
			check("both hands on the hilt (left hand %.2f m off)" % hilt_gap(), hilt_gap() < 0.12)
			g = camp.grunts[1]
			face(p.global_position + Vector3(0, 0, -10))
			target_grunt(1.6)
			saw = {}
			attack("light_attack")
			wait = 0.72
			step += 1
		2:
			attack("light_attack")
			wait = 0.72
			step += 1
		3:
			attack("light_attack")
			wait = 1.2
			step += 1
		4:
			check("the combo: right cut, left cut, stab (%s)" % str(saw.keys()), saw.has("katana_r") and saw.has("katana_l") and saw.has("katana_stab"))
			check("the cuts land (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
			# drawing strike, released at once (no charge)
			target_grunt(2.0)
			p.stamina = p.max_stamina
			Input.action_press("heavy_attack")
			attack("heavy_attack")
			wait = 0.3
			step += 1
		5:
			var b = p.body_model
			check("holding heavy readies the drawing strike (%s / %s)" % [p.current_state_name(), b.current_action()], p.current_state_name() == "Iai" and b.current_action() == "iai_ready")
			check("...the blade back in its scabbard", b.weapon.get_parent() == b._katana_socket)
			pos0 = p.global_position
			attack("light_attack")
			wait = 0.8
			step += 1
		6:
			d0 = hp0 - g.health.current_health
			check("an uncharged draw cuts (%.0f)" % d0, d0 > 0.0)
			check("...with the blade in hand again", p.body_model.weapon.get_parent() == p.body_model.hand_r)
			# full charge, creeping forward meanwhile
			target_grunt(2.6)
			p.stamina = p.max_stamina
			creep = 0.0
			attack("heavy_attack")
			wait = 0.15
			step += 1
		7:
			Input.action_press("move_forward")
			wait = 0.6
			step += 1
		8:
			Input.action_release("move_forward")
			check("you can creep while charging (%.1f m/s)" % creep, creep > 0.5 and creep < 3.5)
			target_grunt(2.6)
			wait = 0.8
			step += 1
		9:
			var st = p.state_machine.get_node("Iai")
			check("the charge reaches level 2 (%d)" % st.level, st.level == 2)
			pos0 = p.global_position
			gpos0 = g.humanoid.hips.global_position
			attack("light_attack")
			wait = 0.3
			step += 1
		10:
			var dist := Vector2(p.global_position.x - pos0.x, p.global_position.z - pos0.z).length()
			check("the charged draw dashes forward, through the grunt (%.1f m)" % dist, dist > 3.0)
			check("...and the grunt crumples (state %d, limp %s)" % [g.state, str(g.humanoid.ragdoll != null and g.humanoid.ragdoll.stiffness_target == 0.0)],
				g.state == DOWN and g.humanoid.ragdoll != null and g.humanoid.ragdoll.stiffness_target == 0.0)
			wait = 0.5
			step += 1
		11:
			var d2: float = hp0 - g.health.current_health
			check("a full charge cuts much harder (%.0f vs %.0f)" % [d2, d0], d2 > d0 * 2.0)
			var hp: Vector3 = g.humanoid.hips.global_position
			var moved := Vector2(hp.x - gpos0.x, hp.z - gpos0.z).length()
			print("   grunt root moved %.2f m, state %d" % [Vector2(g.global_position.x - gpos0.x, g.global_position.z - gpos0.z).length(), g.state])
			check("...folding where it stood, not thrown (hips moved %.2f m)" % moved, moved < 0.6)
			wait = 0.6
			step = 20
		20:
			check("...and gets back up soon after (state %d)" % g.state, g.state != DOWN)
			Input.action_release("heavy_attack")
			# stand down: let go of heavy without attacking
			p.stamina = p.max_stamina
			Input.action_press("heavy_attack")
			attack("heavy_attack")
			wait = 0.3
			step = 12
		12:
			Input.action_release("heavy_attack")
			wait = 0.6
			step += 1
		13:
			var b = p.body_model
			check("letting go stands down (%s)" % p.current_state_name(), p.current_state_name() != "Iai")
			check("...blade back in hand", b.weapon.get_parent() == b.hand_r)
			attack("parry")
			wait = 0.12
			step += 1
		14:
			var b = p.body_model
			var down: float = (-b.weapon.global_basis.z.normalized()).y
			check("parry: the katana hangs point-down (%s, blade dir y %.2f)" % [b.current_action(), down], b.current_action() == "parry" and down < -0.6)
			check("...held up high in both hands (hands %.2f m above the shoulders, left %.2f m off the hilt)" % [b.hand_r.global_position.y - b.arm_r.global_position.y, hilt_gap()],
				b.hand_r.global_position.y > b.arm_r.global_position.y + 0.15 and hilt_gap() < 0.12)
			# sprinting: the katana rides in its scabbard, ready for the running draw
			wait = 0.6
			step = 30
		30:
			face(p.global_position + Vector3(0, 0, -10))
			Input.action_press("sprint")
			Input.action_press("move_forward")
			wait = 0.8
			step += 1
		31:
			var b = p.body_model
			check("sprinting slips the katana into its scabbard (sprinting %s, in scabbard %s)" % [str(p.sprinting), str(b.weapon.get_parent() == b._katana_socket)],
				p.sprinting and b._run_sheath and b.weapon.get_parent() == b._katana_socket)
			# a grunt winding up a red (unblockable) chop just ahead
			target_grunt(2.0)
			g._yaw = atan2(p.global_position.x - g.global_position.x, p.global_position.z - g.global_position.z)
			g.facing.rotation.y = g._yaw
			g._set_state(0)
			g._attack = "peril"
			g._start_wind()
			saw = {}
			attack("light_attack")
			wait = 0.4
			step += 1
		32:
			Input.action_release("sprint")
			Input.action_release("move_forward")
			check("attacking at a sprint is the running draw (%s)" % str(saw.keys()), saw.has("quick_draw"))
			check("...it breaks the red wind-up and staggers (state %d, peril %s)" % [g.state, str(g._peril_on)], g.state == STAGGER and not g._peril_on)
			check("...and cuts (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
			wait = 0.8
			step += 1
		33:
			var b = p.body_model
			check("stopped: the katana back in hand (%s)" % b.weapon.get_parent().name, b.weapon.get_parent() == b.hand_r)
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false

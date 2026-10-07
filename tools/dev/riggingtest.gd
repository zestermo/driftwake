extends SceneTree
## The bigger ship's decks: up the stairs to the quarterdeck, through the
## cabin door to the bunk and galley, the helm up top, prompts only right next
## to things, climbing the rigging by hand (W up into the crow's nest, room to
## walk round the mast, S back down), jumping off, climbing one-handed with
## the cutlass out and chopping, letting go, a swing on a yard rope, and the
## rope ladder: down it from the deck into the sea, back up from the water.
var t := 0.0
var step := 0
var wait := 0.0
var p
var ship
var fails := 0
var t0 := 0.0
var maxy := -INF
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func L(v: Vector3) -> Vector3:
	return ship.global_transform * v
func local() -> Vector3:
	return ship.to_local(p.global_position)
func put(v: Vector3, face_yaw: float = 0.0) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = L(v)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	var rig := cam_rig()
	rig.global_rotation.y = ship.global_rotation.y + face_yaw
	p.player_model.global_rotation.y = ship.global_rotation.y + face_yaw
func cam_rig() -> Node3D:
	return root.get_viewport().get_camera_3d().get_parent().get_parent() as Node3D
func interact() -> void:
	var ic = p.interaction_component
	if ic.current_interactable:
		ic.current_interactable.interact(p)
func prompt() -> String:
	var ic = p.interaction_component
	return ic.current_interactable.prompt_text if ic.current_interactable else ""
func tap(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
	var e2 := InputEventAction.new(); e2.action = a; e2.pressed = false; Input.parse_input_event(e2)
func st() -> String:
	return p.current_state_name()
func _process(d: float) -> bool:
	t += d
	if t > 160.0:
		check("timed out at step %d" % step, false)
		print("RESULT FAILED (%d)" % fails)
		quit()
		return true
	if p and step >= 1:
		maxy = maxf(maxy, local().y)
	if wait > 0.0:
		wait -= d
		return false
	var HB = load("res://scripts/ship/hull_builder.gd")
	match step:
		0:
			if t < 2.0: return false
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			p = get_first_node_in_group("player")
			ship = get_first_node_in_group("ship")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.equip_weapon(load("res://resources/items/cutlass.tres"), false)
			p.sheathe_weapon(true)
			check("the ship is ~23 m long and ~9 m in the beam", HB.RINGS[0][0] - HB.RINGS[HB.RINGS.size() - 1][0] > 21.0 and HB.half_width(0.0) > 4.0)
			# walk up the starboard stairs (toward the stern)
			put(Vector3(3.35, HB.DECK_Y + 0.1, HB.STAIR_Z0 - 1.0), PI)
			Input.action_press("move_forward")
			t0 = t
			step += 1
		1:
			if local().z < HB.QD_FRONT + 1.0 and t - t0 < 4.0:
				return false
			Input.action_release("move_forward")
			check("up the stairs onto the quarterdeck (y %.2f)" % local().y, absf(local().y - HB.QD_Y) < 0.3 and local().z > HB.QD_FRONT)
			# the helm is up here
			put(Vector3(0, HB.QD_Y + 0.1, HB.HELM_Z + 0.3))
			wait = 0.4
			step += 1
		2:
			check("the wheel is on the quarterdeck: F there steers (%s)" % prompt(), prompt().to_lower().contains("steer"))
			put(Vector3(0, HB.QD_Y + 0.1, HB.HELM_Z + 1.9))
			wait = 0.4
			step += 1
		3:
			check("two steps back from the wheel: no prompt (%s)" % prompt(), prompt() == "")
			# a cannon: right behind it, F mans it; two metres off, nothing
			var seat: Vector3 = ship.to_local(ship.cannons[0].interactable.global_position)
			var inboard := Vector3(-signf(seat.x) * 2.0, 0, 0)
			put(Vector3(seat.x, HB.DECK_Y + 0.1, seat.z) + inboard)
			set_meta("seat", seat)
			wait = 0.4
			step += 1
		4:
			check("two metres from a cannon: no prompt (%s)" % prompt(), not prompt().contains("cannon"))
			var seat: Vector3 = get_meta("seat")
			put(Vector3(seat.x - signf(seat.x) * 0.3, HB.DECK_Y + 0.1, seat.z))
			wait = 0.4
			step += 1
		5:
			check("right behind it: F mans the cannon (%s)" % prompt(), prompt().contains("cannon"))
			# in through the cabin door
			put(Vector3(0, HB.DECK_Y + 0.1, HB.QD_FRONT - 2.0), PI)
			Input.action_press("move_forward")
			t0 = t
			step += 1
		6:
			if local().z < HB.QD_FRONT + 2.0 and t - t0 < 3.0:
				return false
			Input.action_release("move_forward")
			check("through the door into the cabin (z %.1f, y %.2f)" % [local().z, local().y], HB.in_cabin(local()) and absf(local().y - HB.DECK_Y) < 0.2)
			check("...under the quarterdeck: a roof over you", local().y < HB.QD_Y - 1.0)
			# the storage chest by the door
			put(ship.STORAGE_AT + Vector3(0.6, 0.1, 0.7))
			wait = 0.4
			step += 1
		7:
			check("the storage chest in the cabin (%s)" % prompt(), prompt().to_lower().contains("storage"))
			check("you wake beside the bunk (respawn point in the cabin)", HB.in_cabin(ship.to_local(ship.respawn_point.global_position)))
			# the foot of the starboard rigging
			put(Vector3(3.05, HB.DECK_Y + 0.1, HB.MAST_Z + 0.75), PI * 0.5)
			wait = 0.4
			step += 1
		8:
			check("at the foot of the rigging, F grabs on (%s)" % prompt(), prompt().contains("rigging"))
			interact()
			wait = 0.8
			step += 1
		9:
			check("...and you hang there until you climb", st() == "Climb" and local().y < HB.DECK_Y + 1.6)
			Input.action_press("move_forward")
			maxy = -INF
			t0 = t
			step += 1
		10:
			if st() == "Climb" and t - t0 < 12.0:
				return false
			Input.action_release("move_forward")
			print("   climbed for %.1f s, highest %.1f" % [t - t0, maxy])
			check("W: up the ratlines into the crow's nest (y %.1f)" % local().y, absf(local().y - HB.NEST_Y) < 0.4 and Vector2(local().x, local().z - HB.MAST_Z).length() < HB.NEST_R)
			wait = 0.6
			step += 1
		11:
			check("standing in the nest", p.is_on_floor() and absf(local().y - HB.NEST_Y) < 0.4)
			# room to walk round the mast: half a circle at 0.95 m, nothing in the way
			var free := true
			var r := 0.95
			for i in range(12):
				var a0 := PI * i / 12.0
				var a1 := PI * (i + 1) / 12.0
				var from := Transform3D(ship.global_basis, L(Vector3(cos(a0) * r, HB.NEST_Y + 0.05, HB.MAST_Z + sin(a0) * r)))
				var mv: Vector3 = L(Vector3(cos(a1) * r, HB.NEST_Y + 0.05, HB.MAST_Z + sin(a1) * r)) - from.origin
				if p.test_move(from, mv):
					free = false
			check("...with room to walk round the mast", free)
			put(ship.to_local(ship.ship_model.get_node("RiggingS").down_zone.global_position) - Vector3(0, 0.85, 0), -PI * 0.5)
			wait = 0.4
			step += 1
		12:
			check("...and F by the gap grabs on to climb down (%s)" % prompt(), prompt().contains("down"))
			interact()
			wait = 0.8
			step += 1
		13:
			Input.action_press("move_back")
			t0 = t
			step += 1
		14:
			if st() == "Climb" and t - t0 < 12.0:
				return false
			Input.action_release("move_back")
			wait = 0.5
			step += 1
		15:
			check("S: back down on deck", absf(local().y - HB.DECK_Y) < 0.25 and p.is_on_floor())
			# up a little, then jump off
			put(Vector3(3.05, HB.DECK_Y + 0.1, HB.MAST_Z + 0.75), PI * 0.5)
			wait = 0.3
			step += 1
		16:
			interact()
			wait = 0.5
			step += 1
		17:
			Input.action_press("move_forward")
			wait = 1.5
			step += 1
		18:
			Input.action_release("move_forward")
			set_meta("y_on", local().y)
			check("part way up (y %.1f)" % local().y, st() == "Climb" and local().y > HB.DECK_Y + 2.5)
			tap("jump")
			wait = 0.15
			step += 1
		19:
			check("Space jumps off (%s)" % st(), st() in ["Fall", "Jump"])
			wait = 2.5
			step += 1
		20:
			check("...and you come down (y %.1f, %s)" % [local().y, st()], local().y < float(get_meta("y_on")) - 1.0)
			# armed: the cutlass out one-handed, a chop, then let go
			put(Vector3(3.05, HB.DECK_Y + 0.1, HB.MAST_Z + 0.75), PI * 0.5)
			wait = 0.3
			step += 1
		21:
			interact()
			wait = 0.5
			step += 1
		22:
			Input.action_press("move_forward")
			wait = 1.0
			step += 1
		23:
			Input.action_release("move_forward")
			tap("ready_weapon")
			wait = 0.6
			step += 1
		24:
			check("Z on the rigging: the cutlass out, one hand holding on", p.armed and p.body_model.climb_hold == "l" and st() == "Climb")
			set_meta("stam", p.stamina)
			tap("light_attack")
			wait = 0.12
			step += 1
		25:
			check("left click: an overhead chop (%s)" % p.body_model.current_action(), p.body_model.current_action() == "climb_chop")
			wait = 0.6
			step += 1
		26:
			check("...still holding on", st() == "Climb" and p.stamina < float(get_meta("stam")))
			tap("interact")
			wait = 0.15
			step += 1
		27:
			check("F lets go (%s)" % st(), st() in ["Fall", "Idle", "Move"])
			p.sheathe_weapon(true)
			wait = 2.0
			step += 1
		28:
			# grab the starboard yard rope (its end, at the deck)
			var rope = ship._rig.get_node("RopeS")
			var end: Vector3 = rope.end_point()
			p.state_machine.force_state("Idle", {})
			p.global_position = Vector3(end.x, L(Vector3(0, HB.DECK_Y, 0)).y + 0.1, end.z)
			p.reset_physics_interpolation()
			cam_rig().global_rotation.y = ship.global_rotation.y + PI * 0.5
			wait = 0.4
			step += 1
		29:
			check("by the rope, F grabs it (%s)" % prompt(), prompt().contains("rope"))
			interact()
			set_meta("x0", local().x)
			set_meta("min_x", local().x)
			maxy = -INF
			t0 = t
			step += 1
		30:
			set_meta("min_x", minf(float(get_meta("min_x")), local().x))
			if t - t0 < 1.4:
				check_once("swinging on the rope", st() == "Swing")
				return false
			print("   rope swing: from x %.1f to %.1f, up to %.1f" % [get_meta("x0"), get_meta("min_x"), maxy])
			check("...it swings you across the deck", float(get_meta("x0")) - float(get_meta("min_x")) > 3.0)
			check("...off your feet", maxy > HB.DECK_Y + 0.8)
			Input.action_press("jump")
			wait = 0.1
			step += 1
		31:
			Input.action_release("jump")
			check("jump lets go", st() != "Swing")
			check("...the rope hangs again (and can be grabbed)", ship._rig.get_node("RopeS").interactable.enabled)
			wait = 1.5
			step += 1
		32:
			# the rope ladder: F at its head on deck, S down into the sea
			var lad = ship.ship_model.get_node("LadderStarboard")
			p.state_machine.force_state("Idle", {})
			p.global_position = lad.global_transform * Vector3(0, 0.1, -0.6)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			wait = 0.5
			step += 1
		33:
			check("at the ladder's head on deck (%s)" % prompt(), prompt().contains("ladder"))
			interact()
			wait = 0.9
			step += 1
		34:
			check("...over the rail onto the ladder", st() == "Climb")
			Input.action_press("move_back")
			t0 = t
			step += 1
		35:
			if st() == "Climb" and t - t0 < 6.0:
				return false
			Input.action_release("move_back")
			wait = 1.5
			step += 1
		36:
			check("S down off the bottom: into the sea (%s)" % st(), st() == "Swim")
			var lad = ship.ship_model.get_node("LadderStarboard")
			p.global_position = lad.global_transform * Vector3(0, -HB.LADDER_LEN + 0.6, 0.8)
			p.reset_physics_interpolation()
			wait = 1.0
			step += 1
		37:
			check("in the sea by the ladder: swimming", st() == "Swim")
			interact()
			wait = 0.5
			step += 1
		38:
			check("F grabs the ladder", st() == "Climb")
			Input.action_press("move_forward")
			t0 = t
			step += 1
		39:
			if st() == "Climb" and t - t0 < 8.0:
				return false
			Input.action_release("move_forward")
			wait = 0.4
			step += 1
		40:
			check("W: up the ladder onto the deck (y %.2f)" % local().y, absf(local().y - HB.DECK_Y) < 0.25 and ship.aboard(p.global_position))
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit()
	return false


var _once := {}
func check_once(name: String, cond: bool) -> void:
	if _once.has(name):
		return
	_once[name] = true
	check(name, cond)

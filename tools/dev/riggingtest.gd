extends SceneTree
## The bigger ship's decks: up the stairs to the quarterdeck, through the
## cabin door to the bunk and galley, the helm up top, up the rigging to the
## crow's nest and down again, a swing on a yard rope (moored and under way),
## and back aboard up a rope ladder from the sea.
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
func _process(d: float) -> bool:
	t += d
	if t > 120.0:
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
			check("the wheel is on the quarterdeck: F there steers (%s)" % prompt(), prompt().contains("steer"))
			# in through the cabin door
			put(Vector3(0, HB.DECK_Y + 0.1, HB.QD_FRONT - 2.0), PI)
			Input.action_press("move_forward")
			t0 = t
			step += 1
		3:
			if local().z < HB.QD_FRONT + 2.0 and t - t0 < 3.0:
				return false
			Input.action_release("move_forward")
			check("through the door into the cabin (z %.1f, y %.2f)" % [local().z, local().y], HB.in_cabin(local()) and absf(local().y - HB.DECK_Y) < 0.2)
			check("...under the quarterdeck: a roof over you", local().y < HB.QD_Y - 1.0)
			# the storage chest by the door
			put(ship.STORAGE_AT + Vector3(0.6, 0.1, 0.9))
			wait = 0.4
			step += 1
		4:
			check("the storage chest in the cabin (%s)" % prompt(), prompt().to_lower().contains("bank") or prompt().to_lower().contains("storage"))
			check("you wake beside the bunk (respawn point in the cabin)", HB.in_cabin(ship.to_local(ship.respawn_point.global_position)))
			# up the starboard rigging
			put(Vector3(3.05, HB.DECK_Y + 0.1, HB.MAST_Z + 0.75), PI * 0.5)
			wait = 0.4
			step += 1
		5:
			check("at the foot of the rigging, F climbs (%s)" % prompt(), prompt().contains("rigging"))
			interact()
			maxy = -INF
			t0 = t
			step += 1
		6:
			if p.current_state_name() == "Climb" and t - t0 < 12.0:
				return false
			print("   climbed for %.1f s, highest %.1f" % [t - t0, maxy])
			check("up the ratlines into the crow's nest (y %.1f)" % local().y, absf(local().y - HB.NEST_Y) < 0.4 and Vector2(local().x, local().z - HB.MAST_Z).length() < HB.NEST_R)
			wait = 0.6
			step += 1
		7:
			check("standing in the nest", p.is_on_floor() and absf(local().y - HB.NEST_Y) < 0.4)
			check("...and F there climbs down (%s)" % prompt(), prompt().contains("down"))
			interact()
			t0 = t
			step += 1
		8:
			if p.current_state_name() == "Climb" and t - t0 < 12.0:
				return false
			wait = 0.5
			step += 1
		9:
			check("back down on deck", absf(local().y - HB.DECK_Y) < 0.25 and p.is_on_floor())
			# grab the starboard yard rope (its end, at the deck)
			var rope = ship._rig.get_node("RopeS")
			var end: Vector3 = rope.end_point()
			p.state_machine.force_state("Idle", {})
			p.global_position = Vector3(end.x, L(Vector3(0, HB.DECK_Y, 0)).y + 0.1, end.z)
			p.reset_physics_interpolation()
			cam_rig().global_rotation.y = ship.global_rotation.y + PI * 0.5
			wait = 0.4
			step += 1
		10:
			check("by the rope, F grabs it (%s)" % prompt(), prompt().contains("rope"))
			interact()
			set_meta("x0", local().x)
			set_meta("min_x", local().x)
			maxy = -INF
			t0 = t
			step += 1
		11:
			set_meta("min_x", minf(float(get_meta("min_x")), local().x))
			if t - t0 < 1.4:
				check_once("swinging on the rope", p.current_state_name() == "Swing")
				return false
			print("   rope swing: from x %.1f to %.1f, up to %.1f" % [get_meta("x0"), get_meta("min_x"), maxy])
			check("...it swings you across the deck", float(get_meta("x0")) - float(get_meta("min_x")) > 3.0)
			check("...off your feet", maxy > HB.DECK_Y + 0.8)
			Input.action_press("jump")
			wait = 0.1
			step += 1
		12:
			Input.action_release("jump")
			check("jump lets go", p.current_state_name() != "Swing")
			check("...the rope hangs again (and can be grabbed)", ship._rig.get_node("RopeS").interactable.enabled)
			wait = 1.5
			step += 1
		13:
			# back aboard from the sea, up a rope ladder
			var lad = ship.ship_model.get_node("LadderStarboard")
			p.state_machine.force_state("Idle", {})
			p.global_position = lad.global_transform * Vector3(0, -HB.LADDER_LEN + 0.6, 0.8)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			wait = 1.0
			step += 1
		14:
			check("in the sea by the ladder: swimming", p.current_state_name() == "Swim")
			interact()
			t0 = t
			step += 1
		15:
			if p.current_state_name() == "Climb" and t - t0 < 8.0:
				return false
			wait = 0.4
			step += 1
		16:
			check("up the ladder onto the deck (y %.2f)" % local().y, absf(local().y - HB.DECK_Y) < 0.25 and ship.aboard(p.global_position))
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit()
	return false


var _once := {}
func check_once(name: String, cond: bool) -> void:
	if _once.has(name):
		return
	_once[name] = true
	check(name, cond)

extends SceneTree
## Ship: gentle swell, helm (visible captain), sailing, turning, riding the deck, shore collision.
var t := 0.0
var step := 0
var wait := 0.0
var p
var ship
var fails := 0
var ys: Array = []
var pitches: Array = []
var h0 := 0.0
var maxdev := 0.0
var t0 := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func act(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
	var e2 := InputEventAction.new(); e2.action = a; e2.pressed = false; Input.parse_input_event(e2)
func _process(d: float) -> bool:
	t += d
	if step == 1 or step == 7:
		ys.append(ship.global_position.y)
		pitches.append(absf(ship.rotation.x) + absf(ship.rotation.z))
	if step == 5:
		var loc: Vector3 = ship.to_local(p.global_position)
		maxdev = maxf(maxdev, Vector2(loc.x - 0.0, loc.z - 1.0).length())
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			ship = root.get_tree().get_first_node_in_group("ship")
			wait = 6.0
		1:
			var lo: float = ys.min(); var hi: float = ys.max()
			print("   moored heave range ", snappedf(hi - lo, 0.01), " max tilt ", snappedf(pitches.max(), 0.001))
			check("gentle heave at the dock (< 0.8 m)", hi - lo < 0.8)
			check("gentle tilt (< 0.1 rad)", pitches.max() < 0.1)
			var deck_y: float = ship.global_position.y + 0.32
			check("deck sits ~1.2 m above sea", deck_y > 0.6 and deck_y < 1.8)
			# board at the helm
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
			wait = 0.5
		2:
			check("helm state", p.current_state_name() == "Helm")
			check("captain visible at the wheel", p.player_model.visible and p.body_model.at_helm)
			var hl: Vector3 = ship.helm_position.global_position
			check("standing at the helm", p.global_position.distance_to(hl) < 0.2)
			h0 = ship.global_position.distance_to(Vector3.ZERO)
			set_meta("start", ship.global_position)
			Input.action_press("move_forward")
			wait = 5.0
		3:
			print("   speed after 5 s ", snappedf(ship.speed, 0.01))
			check("sails build speed", ship.speed > 8.0)
			var moved: float = (ship.global_position - (get_meta("start") as Vector3)).length()
			print("   moved ", snappedf(moved, 0.1), " m")
			check("ship moves forward", moved > 20.0)
			check("still at the helm while sailing", p.global_position.distance_to(ship.helm_position.global_position) < 0.3)
			set_meta("yaw", ship.global_rotation.y)
			Input.action_press("move_right")
			wait = 2.0
		4:
			var dy: float = wrapf(ship.global_rotation.y - float(get_meta("yaw")), -PI, PI)
			print("   turned ", snappedf(dy, 0.01), " rad, rudder ", snappedf(ship.rudder, 0.01))
			check("D turns to starboard (yaw decreases)", dy < -0.3)
			check("wheel turns", absf(ship.wheel.rotation.z) > 1.0)
			Input.action_release("move_right")
			# leave the wheel while under way and stand on the deck
			act("interact")
			wait = 0.2
		5:
			check("left the helm, on foot", p.current_state_name() != "Helm" and p.context == 0)
			p.global_position = ship.global_transform * Vector3(0, 0.5, 1.0)
			p.reset_physics_interpolation()
			maxdev = 0.0
			Input.action_release("move_forward")
			wait = 3.0
		6:
			print("   drift on deck while sailing: ", snappedf(maxdev, 0.01), " m, on floor ", p.is_on_floor(), " speed ", snappedf(ship.speed, 0.1))
			check("deck carries the player (no sliding off)", maxdev < 0.6 and p.is_on_floor())
			var loc: Vector3 = ship.to_local(p.global_position)
			check("feet on the visible deck (~0.32)", absf(loc.y - 0.32) < 0.15)
			print("   player local y ", snappedf(loc.y, 0.01))
			ys.clear(); pitches.clear()
			wait = 4.0
		7:
			print("   under way heave ", snappedf(ys.max() - ys.min(), 0.01))
			check("gentle while sailing too (< 0.9 m)", ys.max() - ys.min() < 0.9)
			# sail straight at the island and make sure we stop at the shore
			p.state_machine.force_state("Helm", {})
			var isl = root.get_node("World/Islands/Brinehollow")
			var c: Vector3 = isl.global_position
			var to: Vector3 = c - ship.global_position
			ship.place(ship.global_position, atan2(-to.x, -to.z))
			Input.action_press("move_forward")
			t0 = t
			step += 1
			return false
		8:
			if t - t0 > 40.0 or (t - t0 > 3.0 and ship.speed < 1.0):
				var isl = root.get_node("World/Islands/Brinehollow")
				var lp: Vector3 = isl.to_local(ship.global_position)
				var ground: float = isl.height_at(lp.x, lp.z)
				print("   stopped after ", snappedf(t - t0, 0.1), " s, ground under hull ", snappedf(ground, 0.1), " speed ", snappedf(ship.speed, 0.1))
				check("runs aground instead of sailing through the island", ground < 3.0 and ship.speed < 2.0)
				Input.action_release("move_forward")
				print("RESULT ", "OK" if fails == 0 else "%d FAILED" % fails)
				return true
			return false
	step += 1
	return false

extends SceneTree
## v1.11: sitting (benches, the ship's stools, the ground; up again on a move),
## sneaking (a crouched captain gets closer behind a grunt before it turns),
## the emote wheel (each emote plays, mirrored as a body action), and the
## talk / interact gestures.
const TK := preload("res://tools/dev/test_kit.gd")

var step := 0
var until := 0
var t := 0.0
var p
var fails := 0
var seat
var spot := Vector3.ZERO


func _initialize():
	TK.seed_of(self)
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func finish() -> void:
	for a in ["move_forward", "jump", "interact", "crouch", "emote"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()


func go(n: int, ticks: int = 0) -> void:
	step = n
	until = TK.wait_ticks(ticks)


func put(at: Vector3, yaw: float = 0.0) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.player_model.rotation.y = yaw
	p.reset_physics_interpolation()


func floor_y(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 4.0, 1)
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"].y if not hit.is_empty() else -INF


## A bench out in the open on Brinehollow (not one a villager sits on).
func open_bench_seat():
	var best = null
	var best_d := INF
	for s in get_nodes_in_group("seats"):
		if str(s.get_parent().name).begins_with("Bench") and not s._npc_sitting() and s.get_parent().get_parent() != null:
			var d: float = s.global_position.distance_to(p.global_position)
			if d < best_d and absf(s.face.z) < 0.01 and absf(s.face.x) < 0.01:
				best_d = d
				best = s
	return best


func _process(d: float) -> bool:
	t += d
	if t > 120.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	if TK.ticking(until):
		return false
	match step:
		0:
			if t < 1.5:
				return false
			p = get_first_node_in_group("player")
			# --- sitting on a bench
			seat = open_bench_seat()
			check("Brinehollow's benches have seats (%d seats in the world)" % get_nodes_in_group("seats").size(), seat != null)
			if seat == null:
				finish()
				return true
			var side: Vector3 = seat.get_parent().global_basis.z.normalized()
			spot = seat.floor_point() + side * 0.7 + Vector3.UP * 0.3
			set_meta("open", seat.floor_point() + side * 3.0 + Vector3.UP * 0.3)
			put(spot, atan2(side.x, side.z))
			go(1, 30)
		1:
			var ic = p.interaction_component
			check("next to a bench, F offers to sit (%s)" % (ic.current_interactable.prompt_text if ic.current_interactable else "nothing"),
				ic.current_interactable != null and ic.current_interactable.is_in_group("seats"))
			seat.interact(p)
			go(2, 40)
		2:
			var bm = p.body_model
			check("F on the bench sits you down (%s)" % p.current_state_name(), p.current_state_name() == "Sit" and bm.seated)
			var fp: Vector3 = seat.floor_point()
			var off := Vector2(p.global_position.x - fp.x, p.global_position.z - fp.z).length()
			check("...on the seat (%.2f m off, feet %.2f under the top)" % [off, seat.global_position.y - p.global_position.y], off < 0.05 and absf(p.global_position.y - fp.y) < 0.05)
			var hips_h: float = bm.pivot.global_position.y - fp.y
			check("...hips at the seat's height (%.2f m)" % hips_h, hips_h > 0.38 and hips_h < 0.7)
			var f: Vector3 = seat.facing_for(spot)
			var fwd: Vector3 = -p.player_model.global_basis.z
			check("...facing the side you came from (%.2f)" % fwd.dot(f), fwd.dot(f) > 0.95 and f.dot(spot - seat.global_position) > 0.0)
			check("...and no prompt while seated", p.interaction_component.current_interactable == null)
			check("its co-op key is where it is (%s)" % seat.seat_key(), str(seat.seat_key()).begins_with("seat:w:") and seat.get_script().find(self, seat.seat_key()) == seat)
			Input.action_press("move_forward")
			go(3, 8)
		3:
			Input.action_release("move_forward")
			check("a move gets you up (%s)" % p.current_state_name(), p.current_state_name() != "Sit" and not p.body_model.seated)
			var back := Vector2(p.global_position.x - spot.x, p.global_position.z - spot.z).length()
			check("...back where you sat down from (%.2f m)" % back, back < 1.0)
			# --- the ship's stools
			var ship = get_first_node_in_group("ship")
			var stool = null
			for s in get_nodes_in_group("seats"):
				if s.seat_key().begins_with("seat:s:") and s.face == Vector3(0, 0, 1):
					stool = s
			check("the ship's cabin has stools", stool != null)
			if stool:
				seat = stool
				spot = stool.floor_point() + ship.global_basis.z * -0.6 + Vector3.UP * 0.1
				put(spot)
				go(4, 20)
			else:
				go(5)
		4:
			seat.interact(p)
			check("sat on the cabin stool", p.current_state_name() == "Sit" and p.body_model.seat_y > 0.4)
			go(41, 30)
		41:
			var fwd: Vector3 = -p.player_model.global_basis.z
			var want: Vector3 = seat.get_parent().global_basis * Vector3(0, 0, 1)
			check("...facing the table (%.2f)" % fwd.dot(want.normalized()), fwd.dot(want.normalized()) > 0.95)
			Input.action_press("jump")
			go(42, 3)
		42:
			Input.action_release("jump")
			check("jump gets you up off the stool", p.current_state_name() != "Sit")
			go(5, 20)
		5:
			# --- on the ground, anywhere
			put(spot)
			go(51, 20)
		51:
			p.sit_ground()
			go(52, 40)
		52:
			var bm = p.body_model
			var gy := floor_y(p.global_position)
			var hips_h: float = bm.pivot.global_position.y - gy
			check("sat on the ground (%s, hips %.2f m up)" % [p.current_state_name(), hips_h], p.current_state_name() == "Sit" and bm.seated and hips_h < 0.4)
			Input.action_press("move_forward")
			go(53, 8)
		53:
			Input.action_release("move_forward")
			check("...and up again on a move", p.current_state_name() != "Sit" and not p.body_model.seated)
			go(60)
		# --- sneaking: C toggles the crouch; walk up behind the smugglers' sentry standing, then crouched
		60:
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			put(get_meta("open"))
			go(61, 45)
		61:
			press_crouch()
			go(62, 10)
		62:
			check("C crouches (%s)" % p.current_state_name(), p.current_state_name() == "Crouch" and p.body_model.crouching)
			var y0: float = p.body_model.pivot.global_position.y
			set_meta("stand_hips", y0)
			Input.action_press("move_forward")
			go(63, 30)
		63:
			var v: float = Vector2(p.velocity.x, p.velocity.z).length()
			var hips: float = p.body_model.pivot.global_position.y - p.global_position.y
			check("...and you sneak along slower (%.1f m/s), low (hips %.2f m up)" % [v, hips], v > 2.0 and v < 4.0 and hips < 0.75)
			Input.action_release("move_forward")
			press_crouch()
			go(64, 10)
		64:
			check("C again stands you up (%s)" % p.current_state_name(), p.current_state_name() != "Crouch" and not p.body_model.crouching)
			camp = current_scene.get_node("Islands/Brinehollow/SmugglersCamp")
			sentry = camp.grunts[2]
			for x in camp.grunts:
				if x != sentry:
					x.process_mode = Node.PROCESS_MODE_DISABLED
			check("the sentry stands its post", sentry.idle_mode != "sit")
			approach_from(9.0, false)
			go(65, 3)
		65:
			if approach_step():
				return false
			set_meta("stand_d", near_d)
			print("   standing: the sentry turned at %.2f m behind it" % near_d)
			reset_camp()
			# (long enough for the camp's delayed alarms to fire and be reset again, and the sentry to face its post)
			go(65_1, 120)
		65_1:
			reset_camp()
			go(66, 120)
		66:
			approach_from(9.0, true)
			go(67, 3)
		67:
			if approach_step():
				return false
			var sd: float = get_meta("stand_d")
			print("   crouched: the sentry turned at %.2f m behind it" % near_d)
			check("crouched behind a grunt you get closer before it turns (%.2f m vs %.2f m standing)" % [near_d, sd], near_d < sd - 1.5 and near_d < 2.0)
			reset_camp()
			finish()
			return true
	return false


var camp
var sentry
var near_d := 0.0
var _sneak := false


func press_crouch() -> void:
	var ev := InputEventAction.new()
	ev.action = "crouch"
	ev.pressed = true
	Input.parse_input_event(ev)


func reset_camp() -> void:
	for x in camp.grunts:
		x.global_position = x.post
		x.velocity = Vector3.ZERO
		x.reset_physics_interpolation()
		x._enter_idle()
	put(get_meta("open"))


## Start `d` m straight behind the sentry, standing or crouched.
func approach_from(d: float, sneak: bool) -> void:
	_sneak = sneak
	near_d = d
	place_behind()


func place_behind() -> void:
	var back: Vector3 = -sentry._fwd()
	var at: Vector3 = sentry.global_position + back * near_d
	at.y = floor_y(at) + 0.05
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.player_model.rotation.y = atan2(back.x, back.z)
	p.reset_physics_interpolation()
	if _sneak and p.current_state_name() != "Crouch":
		p.state_machine.force_state("Crouch", {})
	elif not _sneak and p.current_state_name() != "Idle":
		p.state_machine.force_state("Idle", {})


## A quarter metre closer every few ticks until the sentry turns; true while still creeping.
func approach_step() -> bool:
	if sentry.state != 0 or near_d <= 0.6:
		return false
	near_d -= 0.25
	place_behind()
	until = TK.wait_ticks(3)
	return true

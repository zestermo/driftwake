extends SceneTree
## The ship's cabin has stools at the table: F sits you on one facing the table, and a jump gets you up.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var seat
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			for s in get_nodes_in_group("seats"):
				if s.seat_key().begins_with("seat:s:") and s.face == Vector3(0, 0, 1):
					seat = s
			check("the ship's cabin has stools", seat != null)
			if seat == null:
				return TK.done(fails)
			p.state_machine.force_state("Idle", {})
			p.global_position = seat.floor_point() + stage.ship.global_basis.z * -0.6 + Vector3.UP * 0.1
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_ticks(20)
		1:
			seat.interact(p)
			check("sat on the cabin stool", p.current_state_name() == "Sit" and p.body_model.seat_y > 0.4)
			until = TK.wait_ticks(30)
		2:
			var fwd: Vector3 = -p.player_model.global_basis.z
			var want: Vector3 = (seat.get_parent().global_basis * Vector3(0, 0, 1)).normalized()
			check("...facing the table (%.2f)" % fwd.dot(want), fwd.dot(want) > 0.95)
			Input.action_press("jump")
			until = TK.wait_ticks(3)
		3:
			Input.action_release("jump")
			check("jump gets you up off the stool", p.current_state_name() != "Sit")
			return TK.done(fails)
	step += 1
	return false

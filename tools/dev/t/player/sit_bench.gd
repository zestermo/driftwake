extends SceneTree
## Next to a bench F offers to sit: you sit on the seat (hips at its height) facing the side you came from, with
## no prompt while seated and a co-op key for the spot; a move gets you up where you sat down from.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var seat
var spot := Vector3.ZERO
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "bench": Vector3(0, 0, -4)})


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
			for c in stage.bench.get_children():
				if c.is_in_group("seats"):
					seat = c
					break
			var side: Vector3 = stage.bench.global_basis.z.normalized()
			spot = seat.floor_point() + side * 0.7 + Vector3.UP * 0.3
			p.state_machine.force_state("Idle", {})
			p.global_position = spot
			p.velocity = Vector3.ZERO
			p.player_model.rotation.y = atan2(side.x, side.z)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(30)
		1:
			var ic = p.interaction_component
			check("next to a bench, F offers to sit (%s)" % (ic.current_interactable.prompt_text if ic.current_interactable else "nothing"),
				ic.current_interactable != null and ic.current_interactable.is_in_group("seats"))
			seat.interact(p)
			until = TK.wait_ticks(40)
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
			until = TK.wait_ticks(8)
		3:
			Input.action_release("move_forward")
			check("a move gets you up (%s)" % p.current_state_name(), p.current_state_name() != "Sit" and not p.body_model.seated)
			var back := Vector2(p.global_position.x - spot.x, p.global_position.z - spot.z).length()
			check("...back where you sat down from (%.2f m)" % back, back < 1.0)
			return TK.done(fails)
	step += 1
	return false

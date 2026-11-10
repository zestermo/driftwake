extends SceneTree
## (1.31) The skimmer: fired in a jump over open water it comes out under you and you land on it; turning right
## the rider leans forward over the toes (skim_lean > 0), left back on the heels (< 0); Space jumps off it (up and
## on with the ride, the board stowed).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var st
var step := 0
var until := 0
var fails := 0
var lean_r := 0.0
var lean_l := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true})


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
			st = p.get_node("StateMachine/Skimmer")
			p.gadgets.give("skimmer", 0)
			# in the air over deep water, well out from the shore
			p.global_position = Vector3(stage.SHORE_X + 14.0, p.water_surface(Vector3(stage.SHORE_X + 14.0, 0, 0)) + 4.0, 0)
			p.reset_physics_interpolation()
			p.velocity = Vector3(0, 3.0, 0)
			p.state_machine.force_state("Fall", {})
			until = TK.wait_ticks(3)
		1:
			p.gadgets.ready_at.clear()
			check("fired in the air over water it comes out under you (%s)" % p.current_state_name(), p.gadgets.fire() and p.current_state_name() == "Skimmer")
			until = TK.wait_secs(1.2)
		2:
			check("...and you ride it on the water", p.current_state_name() == "Skimmer" and absf(p.global_position.y - p.water_surface() - st.RIDE_H) < 0.4)
			# going along +X, push right of it: a right turn
			stage.camera_rig.rotation.y = -PI * 0.5
			TK.press("move_forward")
			until = TK.wait_secs(1.5)
		3:
			TK.press("move_right")
			until = TK.wait_secs(0.5)
		4:
			lean_r = p.body_model.skim_lean
			TK.release("move_right")
			TK.press("move_left")
			until = TK.wait_secs(0.7)
		5:
			lean_l = p.body_model.skim_lean
			TK.release("move_left")
			print("  lean turning right %.2f, left %.2f" % [lean_r, lean_l])
			check("turning right the rider leans forward", lean_r > 0.15)
			check("turning left the rider leans back", lean_l < -0.15)
			TK.act("jump")
			until = TK.wait_ticks(4)
		6:
			TK.release("move_forward")
			check("Space jumps off (%s, up %.1f)" % [p.current_state_name(), p.velocity.y], p.current_state_name() in ["Fall", "Jump"] and p.velocity.y > 3.0 and st.last_end == "jump")
			check("...the board stowed", p.lean.get_node_or_null("Skimmer") == null)
			return TK.done(fails)
	step += 1
	return false

extends SceneTree
## The wheels on a pad: LB + d-pad right opens the emote wheel, the right stick points (the camera holds still)
## and the pick stays once the stick is let go; A picks it (waves, and LB+A's skill doesn't fire), B puts the
## wheel away with nothing done.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var rig: Node3D
var yaw0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func button(b: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = down
	Input.parse_input_event(e)


func axis(a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			rig = (get_first_node_in_group("player_camera") as Node).get_parent().get_parent()
			button(JOY_BUTTON_LEFT_SHOULDER, true)
			button(JOY_BUTTON_DPAD_RIGHT, true)
			until = TK.wait_ticks(3)
		1:
			check("LB + d-pad right opens the emote wheel", p.emote_wheel.is_open())
			yaw0 = rig.rotation.y
			axis(JOY_AXIS_RIGHT_Y, -1.0)
			until = TK.wait_ticks(3)
		2:
			check("the stick up picks the top one (%d)" % p.emote_wheel._pick, p.emote_wheel._pick == 0)
			check("...and the camera holds still", is_equal_approx(rig.rotation.y, yaw0))
			axis(JOY_AXIS_RIGHT_Y, 0.0)
			until = TK.wait_ticks(3)
		3:
			check("the pick stays with the stick let go (%d)" % p.emote_wheel._pick, p.emote_wheel._pick == 0)
			button(JOY_BUTTON_A, true)
			button(JOY_BUTTON_A, false)
			until = TK.wait_ticks(4)
		4:
			check("A picks it: a wave (%s)" % p.body_model.current_action(), not p.emote_wheel.is_open() and p.body_model.current_action() == "emote_wave")
			check("...and LB+A's skill didn't fire (%s)" % p.current_state_name(), p.current_state_name() != "Skill")
			button(JOY_BUTTON_DPAD_RIGHT, false)
			p.body_model.stop_action()
			until = TK.wait_ticks(3)
		5:
			button(JOY_BUTTON_DPAD_RIGHT, true)
			until = TK.wait_ticks(3)
		6:
			axis(JOY_AXIS_RIGHT_X, 1.0)
			until = TK.wait_ticks(3)
		7:
			check("open again, the stick right points at a plank (%d)" % p.emote_wheel._pick, p.emote_wheel.is_open() and p.emote_wheel._pick > 0)
			axis(JOY_AXIS_RIGHT_X, 0.0)
			button(JOY_BUTTON_B, true)
			button(JOY_BUTTON_B, false)
			until = TK.wait_ticks(3)
		8:
			check("B puts it away with nothing done (%s)" % p.body_model.current_action(), not p.emote_wheel.is_open() and not str(p.body_model.current_action()).begins_with("emote"))
			button(JOY_BUTTON_DPAD_RIGHT, false)
			button(JOY_BUTTON_LEFT_SHOULDER, false)
			until = TK.wait_ticks(3)
		9:
			check("still put away after letting go of the d-pad", not p.emote_wheel.is_open() and not str(p.body_model.current_action()).begins_with("emote"))
			return TK.done(fails)
	step += 1
	return false

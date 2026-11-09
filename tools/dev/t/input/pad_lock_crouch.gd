extends SceneTree
## (1.31) The pad: R3 locks on (Targeting); LB + R3 still pings (the layer), not a lock; holding B past
## Pad.CROUCH_HOLD crouches (a tap dodges as ever).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var tg
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"dummy": Vector3(0.5, 0, -6.0)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _btn(b: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	e.device = 0
	Input.parse_input_event(e)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			tg = p.get_node("Targeting")
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_ticks(3)
		1:
			_btn(JOY_BUTTON_RIGHT_STICK, true)
			_btn(JOY_BUTTON_RIGHT_STICK, false)
			until = TK.wait_ticks(3)
		2:
			check("R3 locks on", tg.locked())
			_btn(JOY_BUTTON_RIGHT_STICK, true)
			_btn(JOY_BUTTON_RIGHT_STICK, false)
			until = TK.wait_ticks(3)
		3:
			check("R3 again lets go", not tg.locked())
			_btn(JOY_BUTTON_LEFT_SHOULDER, true)
			until = TK.wait_ticks(2)
		4:
			_btn(JOY_BUTTON_RIGHT_STICK, true)
			_btn(JOY_BUTTON_RIGHT_STICK, false)
			until = TK.wait_ticks(3)
		5:
			check("LB + R3 doesn't lock (it's the ping)", not tg.locked())
			_btn(JOY_BUTTON_LEFT_SHOULDER, false)
			until = TK.wait_secs(1.0)
		6:
			_btn(JOY_BUTTON_B, true)
			until = TK.wait_secs(1.4)
		7:
			_btn(JOY_BUTTON_B, false)
			check("holding B crouches (%s)" % p.current_state_name(), p.current_state_name() == "Crouch")
			return TK.done(fails)
	step += 1
	return false

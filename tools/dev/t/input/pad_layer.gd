extends SceneTree
## The pad's buttons press their actions, holding LB swaps the face buttons onto the skills (and back), a
## button held across the swap is let go, and a held trigger counts as one press (not one per motion event).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var probe: Node


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


## Heavy presses an event reader saw through Pad.pressed (the input buffer's way; the buffer itself gets eaten by the attack).
func heavies() -> int:
	return int(probe.get_meta("n", 0))


func make_probe() -> void:
	var s := GDScript.new()
	s.source_code = "extends Node
func _unhandled_input(e: InputEvent) -> void:
	if Pad.pressed(e, \"heavy_attack\"):
		set_meta(\"n\", int(get_meta(\"n\", 0)) + 1)
"
	s.reload()
	probe = Node.new()
	probe.set_script(s)
	root.add_child(probe)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var pad = root.get_node("Pad")
	match step:
		0:
			p = stage.player
			button(JOY_BUTTON_Y, true)
			until = TK.wait_ticks(2)
		1:
			check("Y presses ready_weapon", Input.is_action_pressed("ready_weapon"))
			check("...and the pad is the device in use", pad.using_pad)
			button(JOY_BUTTON_Y, false)
			button(JOY_BUTTON_LEFT_SHOULDER, true)
			button(JOY_BUTTON_X, true)
			until = TK.wait_ticks(2)
		2:
			check("LB is the skills layer", pad.layer)
			check("LB+X is skill 1, not interact", Input.is_action_pressed("skill_1") and not Input.is_action_pressed("interact"))
			button(JOY_BUTTON_X, false)
			button(JOY_BUTTON_LEFT_SHOULDER, false)
			until = TK.wait_ticks(2)
		3:
			check("letting LB go ends the layer", not pad.layer and not Input.is_action_pressed("skill_1"))
			button(JOY_BUTTON_X, true)
			until = TK.wait_ticks(2)
		4:
			check("X is interact again", Input.is_action_pressed("interact") and not Input.is_action_pressed("skill_1"))
			# LB while X is still held: interact is let go, and X's release later leaves nothing stuck
			button(JOY_BUTTON_LEFT_SHOULDER, true)
			until = TK.wait_ticks(2)
		5:
			check("a button held into the layer lets its base action go", not Input.is_action_pressed("interact"))
			button(JOY_BUTTON_X, false)
			button(JOY_BUTTON_LEFT_SHOULDER, false)
			until = TK.wait_ticks(2)
		6:
			check("nothing stuck after", not Input.is_action_pressed("interact") and not Input.is_action_pressed("skill_1"))
			make_probe()
			axis(JOY_AXIS_TRIGGER_RIGHT, 0.7)
			axis(JOY_AXIS_TRIGGER_RIGHT, 0.8)
			until = TK.wait_ticks(1)
		7:
			axis(JOY_AXIS_TRIGGER_RIGHT, 0.9)
			axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
			until = TK.wait_ticks(1)
		8:
			check("RT holds heavy_attack", Input.is_action_pressed("heavy_attack"))
			check("a held RT buffers one heavy, not one per motion event (%d)" % heavies(), heavies() == 1)
			axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
			until = TK.wait_ticks(2)
		9:
			check("RT let go lets heavy_attack go", not Input.is_action_pressed("heavy_attack"))
			return TK.done(fails)
	step += 1
	return false

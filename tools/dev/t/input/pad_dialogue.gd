extends SceneTree
## (1.31) A conversation on a pad: A finishes the line, the d-pad steps the choices, A takes the picked one;
## B walks away mid-talk without a dodge. No pointer in a conversation.
const TK := preload("res://tools/dev/test_kit.gd")
const TALK := {"speaker": "Tester", "start": "q", "nodes": {"q": {"text": "Pick one.", "choices": [
	{"text": "One", "next": "end", "flag": "pad_one"}, {"text": "Two", "next": "end", "flag": "pad_two"},
	{"text": "Three", "next": "end", "flag": "pad_three"}]}}}
var stage
var p
var dlg
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


func tap(b: int) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			dlg = root.get_node("Dialogue")
			dlg.define("t_pad", TALK)
			dlg.start("t_pad")
			until = TK.wait_ticks(3)
		1:
			check("the talk is on", dlg.active)
			tap(JOY_BUTTON_A)
			until = TK.wait_ticks(3)
		2:
			check("A finished the line: the choices are up", dlg._box.has_choices())
			check("no pointer in a conversation", not root.get_node("Pad").cursor.shown)
			tap(JOY_BUTTON_DPAD_DOWN)
			until = TK.wait_ticks(2)
		3:
			check("d-pad down picks the second (%d)" % dlg._box._sel, dlg._box._sel == 1)
			tap(JOY_BUTTON_DPAD_DOWN)
			tap(JOY_BUTTON_DPAD_UP)
			until = TK.wait_ticks(2)
		4:
			check("down and up: back on the second (%d)" % dlg._box._sel, dlg._box._sel == 1)
			tap(JOY_BUTTON_A)
			until = TK.wait_ticks(3)
		5:
			check("A takes it: Two", dlg.has_flag("pad_two") and not dlg.has_flag("pad_one"))
			check("...the talk's over", not dlg.active)
			check("...with no jump (%s)" % p.current_state_name(), p.current_state_name() != "Jump")
			until = TK.wait_secs(0.6)
		6:
			dlg.start("t_pad")
			until = TK.wait_ticks(3)
		7:
			tap(JOY_BUTTON_B)
			until = TK.wait_ticks(3)
		8:
			check("B walks away", not dlg.active)
			check("...without a dodge (%s)" % p.current_state_name(), p.current_state_name() != "Dodge")
			return TK.done(fails)
	step += 1
	return false

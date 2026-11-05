extends SceneTree
## (1.31) The pause menu on a pad's d-pad (Godot's ui_* had no pad buttons): Menu opens it on Resume, the d-pad
## steps the focus (no pointer), A presses the focused button (Options), the d-pad moves a slider there, B backs
## out to the pause menu and B closes it, and none of it jumps, dodges or opens the action wheel in play.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gm
var cur
var vol := 0.0
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


func focused() -> Control:
	return gm._pc.viewport().gui_get_focus_owner()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			root.size = Vector2i(1920, 1080)
			p = stage.player
			gm = root.get_node("GameMenu")
			cur = root.get_node("Pad").cursor
			tap(JOY_BUTTON_START)
			until = TK.wait_ticks(4)
		1:
			var f := focused()
			check("Menu opens the pause menu on Resume (%s)" % (f.get("text") if f else "none"), gm.screen() == "pause" and f is Button and f.text == "Resume")
			check("no pointer while a button has focus", not cur.shown)
			tap(JOY_BUTTON_DPAD_DOWN)
			until = TK.wait_ticks(2)
		2:
			var f := focused()
			check("d-pad down steps the focus (%s)" % (f.get("text") if f else "none"), f is Button and f.text != "Resume")
			tap(JOY_BUTTON_DPAD_DOWN)
			tap(JOY_BUTTON_DPAD_DOWN)
			tap(JOY_BUTTON_DPAD_RIGHT)
			until = TK.wait_ticks(2)
		3:
			var f := focused()
			check("...down twice more and right: Options (%s)" % (f.get("text") if f else "none"), f is Button and f.text == "Options")
			check("...the pointer stays hidden (d-pad: focus)", not cur.shown)
			tap(JOY_BUTTON_A)
			until = TK.wait_ticks(3)
		4:
			check("A presses it: Options (%s)" % gm.screen(), gm.screen() == "options")
			check("...with no jump (%s)" % p.current_state_name(), p.current_state_name() != "Jump")
			var master: HSlider = null
			for s in gm._screens["options"].find_children("*", "HSlider", true, false):
				if str(s.get_parent().get_child(0).text) == "Master":
					master = s
			master.grab_focus()
			vol = master.value
			tap(JOY_BUTTON_DPAD_LEFT)
			until = TK.wait_ticks(2)
		5:
			var f := focused()
			check("d-pad left on a slider turns it down (%.2f -> %.2f)" % [vol, (f as Range).value], f is HSlider and (f as Range).value < vol)
			(f as Range).value = vol
			tap(JOY_BUTTON_B)
			until = TK.wait_ticks(3)
		6:
			check("B backs out to the pause menu (%s)" % gm.screen(), gm.screen() == "pause")
			tap(JOY_BUTTON_B)
			until = TK.wait_ticks(3)
		7:
			check("B closes it (%s)" % gm.screen(), gm.screen() == "")
			check("...no dodge (%s)" % p.current_state_name(), p.current_state_name() != "Dodge")
			check("...and the action wheel didn't open", not p.action_wheel.is_open())
			return TK.done(fails)
	step += 1
	return false

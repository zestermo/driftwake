extends SceneTree
## The crew's chat: Enter opens nothing in a solo game. Open, the captain stands still while you type and no
## menu, wheel or the pause menu opens on the keys typed; Enter sends the line, which comes back (through
## Net, the host's relay) as a line with your name over the HUD; a crewmate's line carries theirs. Lines fade
## after a while and all come back while you type; only the last six are kept; Esc puts the line away.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var box
var start := Vector3.ZERO
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


func key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		Input.parse_input_event(e)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var net = root.get_node("Net")
	var menu = root.get_node("GameMenu")
	match step:
		0:
			p = stage.player
			box = p.chat_box
			TK.act("chat")
			until = TK.wait_ticks(3)
		1:
			check("solo: Enter opens no chat", not box.is_open() and not p.input_locked)
			box.open()
			start = p.global_position
			Input.action_press("move_forward")
			key(KEY_I)
			key(KEY_T)
			until = TK.wait_ticks(20)
		2:
			Input.action_release("move_forward")
			check("typing: the captain stands still (%.2f m)" % p.global_position.distance_to(start), p.global_position.distance_to(start) < 0.05 and p.input_locked)
			check("...and I opens no inventory, T no emote wheel", not menu.is_open() and not p.emote_wheel.is_open())
			box._line.text = "  Land ho!  "
			box._line.text_submitted.emit(box._line.text)
			until = TK.wait_ticks(3)
		3:
			check("Enter sends it and puts the line away", not box.is_open() and not p.input_locked)
			var s: Array = box.shown()
			check("the line comes back with your name (%s)" % str(s), s.size() == 1 and s[0][0] == p.display_name() + ":" and s[0][1] == "Land ho!" and s[0][2] == 1.0)
			net._all_chat(2, "Aye, captain")
			s = box.shown()
			check("a crewmate's line carries theirs (%s)" % str(s), s.size() == 2 and s[1][0] == "A crewmate:" and s[1][1] == "Aye, captain")
			net._chat_send(1, "   ")
			check("an empty line isn't sent", box.shown().size() == 2)
			box._rows[0][1] = box.SHOW + box.FADE
			box._rows[1][1] = box.SHOW + box.FADE
			until = TK.wait_ticks(2)
		4:
			check("lines fade out after a while", box.shown().all(func(r): return r[2] == 0.0))
			box.open()
			until = TK.wait_ticks(2)
		5:
			check("...and all come back while you type", box.shown().all(func(r): return r[2] == 1.0))
			key(KEY_ESCAPE)
			until = TK.wait_ticks(3)
		6:
			check("Esc puts the line away (no pause menu)", not box.is_open() and not p.input_locked and not menu.is_open())
			for i in range(8):
				net._all_chat(1, "line %d" % i)
			var s: Array = box.shown()
			check("only the last six lines are kept", s.size() == 6 and s[5][1] == "line 7")
			return TK.done(fails)
	step += 1
	return false

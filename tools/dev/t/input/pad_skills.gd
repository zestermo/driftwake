extends SceneTree
## The pad's skill list (bottom left): hidden on keys, shown once a pad button is pressed; a line a skill
## equipped, by button and name (empty slots left out); dim until LB is held; the setting turns it off.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ls
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ls = root.find_child("PadSkills", true, false)
			check("the HUD has the pad skill list", ls != null)
			if ls == null:
				return TK.done(fails)
			for i in range(p.power.loadout.size()):
				p.power.loadout[i] = "soru" if i == 0 else ""
			until = TK.wait_secs(0.7)
		1:
			check("hidden while playing on keys", not ls.visible)
			button(JOY_BUTTON_A, true)
			button(JOY_BUTTON_A, false)
			until = TK.wait_secs(0.4)
		2:
			var l: Array = ls.lines()
			check("a pad press shows it, dim (%.2f)" % ls.modulate.a, ls.visible and ls.modulate.a < 0.8 and ls.modulate.a > 0.4)
			check("one line, X SQUALL STEP, the empty slots left out (%s)" % str(l), l.size() == 1 and l[0][0] == "X" and l[0][1] == "SQUALL STEP")
			button(JOY_BUTTON_LEFT_SHOULDER, true)
			until = TK.wait_ticks(3)
		3:
			check("bright while LB is held (%.2f)" % ls.modulate.a, ls.modulate.a > 0.95)
			button(JOY_BUTTON_LEFT_SHOULDER, false)
			root.get_node("Settings").set_value("gameplay", "pad_skills", false, false)
			until = TK.wait_secs(0.4)
		4:
			check("the setting turns it off", not ls.visible)
			root.get_node("Settings").set_value("gameplay", "pad_skills", true, false)
			return TK.done(fails)
	step += 1
	return false

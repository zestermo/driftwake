extends SceneTree
## Prompts name the device in use: keys and clicks until a pad button is pressed, then the pad's buttons (the
## skills as LB+, right even while LB is held), and back on a key press; the HUD's interact key cap and the
## controls page flip with it.
const TK := preload("res://tools/dev/test_kit.gd")
const G := preload("res://scripts/input/glyphs.gd")
var stage
var p
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


func cap() -> String:
	return (stage.hud._interact_key.get_child(0) as Label).text


func page_key(what: String) -> String:
	var gm = root.get_node("GameMenu")
	for i in range(gm.BINDINGS.size()):
		if gm.BINDINGS[i][0] == what:
			return gm._binding_keys[i].text
	return "?"


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			check("keyboard first: jump is Space (%s)" % G.of("jump"), G.of("jump") == "Space")
			check("light attack is Left click (%s)" % G.of("light_attack"), G.of("light_attack") == "Left click")
			check("interact is F (%s)" % G.of("interact"), G.of("interact") == "F")
			stage.hud._interact_text = "Talk"
			stage.hud._show_interact()
			check("the HUD's key cap says F (%s)" % cap(), cap() == "F")
			check("the controls page says Space for jump (%s)" % page_key("Jump / double jump"), page_key("Jump / double jump") == "Space")
			button(JOY_BUTTON_A, true)
			button(JOY_BUTTON_A, false)
			until = TK.wait_ticks(2)
		1:
			check("a pad press: jump is A (%s)" % G.of("jump"), G.of("jump") == "A")
			check("heavy is RT, parry LT, interact X (%s %s %s)" % [G.of("heavy_attack"), G.of("parry"), G.of("interact")],
				G.of("heavy_attack") == "RT" and G.of("parry") == "LT" and G.of("interact") == "X")
			check("skill 1 is LB+X, the ultimate LB+RT (%s, %s)" % [G.of("skill_1"), G.of("ultimate")], G.of("skill_1") == "LB+X" and G.of("ultimate") == "LB+RT")
			check("the HUD's key cap says X (%s)" % cap(), cap() == "X")
			check("the controls page says A for jump (%s)" % page_key("Jump / double jump"), page_key("Jump / double jump") == "A")
			button(JOY_BUTTON_LEFT_SHOULDER, true)
			until = TK.wait_ticks(2)
		2:
			check("LB held: jump is still called A (%s)" % G.of("jump"), G.of("jump") == "A")
			button(JOY_BUTTON_LEFT_SHOULDER, false)
			var k := InputEventKey.new()
			k.physical_keycode = KEY_W
			k.pressed = true
			Input.parse_input_event(k)
			var ku := k.duplicate()
			ku.pressed = false
			Input.parse_input_event(ku)
			until = TK.wait_ticks(2)
		3:
			check("a key press: back to Space (%s)" % G.of("jump"), G.of("jump") == "Space")
			check("...and the key cap to F (%s)" % cap(), cap() == "F")
			return TK.done(fails)
	step += 1
	return false

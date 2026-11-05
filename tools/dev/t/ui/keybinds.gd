extends SceneTree
## (1.30.1) Options > Controls rebinds keys: click a row and press a key (or a mouse button); a key another action
## had swaps over; Esc cancels; the binding survives a save and load; Reset puts every key back. Prompts follow.
const TK := preload("res://tools/dev/test_kit.gd")
const G := preload("res://scripts/input/glyphs.gd")
const KB := preload("res://scripts/input/keybinds.gd")
var stage
var gm
var st
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func click(b: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = b
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func page(action: String) -> String:
	return gm._bind_buttons[action].text


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			gm = root.get_node("GameMenu")
			st = root.get_node("Settings")
			check("defaults: jump Space, dodge Ctrl", G.key_of("jump") == "Space" and G.key_of("dodge") == "Ctrl")
			gm.open("controls")
			until = TK.wait_ticks(2)
		1:
			check("the page lists jump as Space (%s)" % page("jump"), page("jump") == "Space")
			check("inventory shows both its keys (%s)" % page("inventory"), page("inventory") == "Tab / I")
			gm.start_bind("jump")
			check("a clicked row waits for a key (%s)" % page("jump"), page("jump") == "Press a key...")
			key(KEY_K)
			until = TK.wait_ticks(2)
		2:
			check("jump is now K (%s, page %s)" % [G.key_of("jump"), page("jump")], G.key_of("jump") == "K" and page("jump") == "K")
			check("the menu stayed open on the page", gm._current == "controls")
			check("pressing K jumps now", InputMap.event_is_action(_ev(KEY_K), "jump") and not InputMap.event_is_action(_ev(KEY_SPACE), "jump"))
			gm.start_bind("dodge")
			key(KEY_K)
			until = TK.wait_ticks(2)
		3:
			check("dodge took K (%s)" % G.key_of("dodge"), G.key_of("dodge") == "K")
			check("jump swapped onto dodge's Ctrl (%s)" % G.key_of("jump"), G.key_of("jump") == "Ctrl")
			check("the page says so (%s)" % gm._bind_note.text, gm._bind_note.text.contains("swapped"))
			check("pad bindings untouched (dodge still B)", G.pad_of("dodge") == "B" \
				and InputMap.action_get_events("dodge").any(func(e): return e is InputEventJoypadButton))
			gm.start_bind("parry")
			key(KEY_ESCAPE)
			until = TK.wait_ticks(2)
		4:
			check("Esc cancels: parry still Q, menu still open (%s)" % G.key_of("parry"), G.key_of("parry") == "Q" and gm._current == "controls" and gm.bind_wait == "")
			gm.start_bind("skill_1")
			click(MOUSE_BUTTON_XBUTTON1)
			until = TK.wait_ticks(2)
		5:
			check("skill 1 on Mouse 4 (%s)" % G.key_of("skill_1"), G.key_of("skill_1") == "Mouse 4")
			check("the skill bar's key cap says M4 (%s)" % G.short_of("skill_1"), G.short_of("skill_1") == "M4")
			check("a prompt names the new key (%s)" % G.fill("Roll ({dodge})"), G.fill("Roll ({dodge})") == "Roll (K)")
			# a save and load: the InputMap back to defaults, then the saved settings read again
			KB.reset()
			check("(reset the map: jump Space)", G.key_of("jump") == "Space")
			st.reload(st.save_path())
			check("after a load: jump Ctrl, dodge K, skill 1 Mouse 4", G.key_of("jump") == "Ctrl" and G.key_of("dodge") == "K" and G.key_of("skill_1") == "Mouse 4")
			check("tests never write the player's own settings file", st.save_path() != st.PATH)
			gm._screens["controls"].find_child("ResetKeys", true, false).pressed.emit()
			until = TK.wait_ticks(2)
		6:
			check("Reset: jump Space, dodge Ctrl, skill 1 is 1", G.key_of("jump") == "Space" and G.key_of("dodge") == "Ctrl" and G.key_of("skill_1") == "1")
			check("...and the page (%s %s)" % [page("jump"), page("dodge")], page("jump") == "Space" and page("dodge") == "Ctrl")
			var cfg := ConfigFile.new()
			cfg.load(st.save_path())
			check("nothing rebound in the save", not cfg.has_section("keys") or cfg.get_section_keys("keys").is_empty())
			gm.close()
			return TK.done(fails)
	step += 1
	return false


func _ev(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e

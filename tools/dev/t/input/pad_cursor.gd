extends SceneTree
## (1.31) The pad's pointer in menus: the pause menu opens with Resume focused (no ring, A would press it);
## the left stick brings the ring and moves it, slow near the centre and fast at full tilt; A over Options
## clicks it (a real mouse click: the page opens) without the captain jumping; B backs out to the pause menu
## and out of it without a dodge; the mouse moving hides the ring; in play the stick and A never move or click it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gm
var cur
var at := Vector2.ZERO
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


## A control inside the menu's PixelCanvas, in the root's canvas.
func root_point(c: Control) -> Vector2:
	var pc = gm._pc
	return pc.get_global_transform() * (c.get_global_rect().get_center() * float(pc.stretch_shrink))


func pause_button(text: String) -> Button:
	for b in gm._screens["pause"].find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			root.size = Vector2i(1920, 1080)
			p = stage.player
			gm = root.get_node("GameMenu")
			cur = root.get_node("Pad").cursor
			button(JOY_BUTTON_START, true)
			button(JOY_BUTTON_START, false)
			until = TK.wait_ticks(5)
		1:
			check("Menu opens the pause menu (%s)" % gm.screen(), gm.screen() == "pause")
			check("the pointer is live in a menu on a pad", cur.active)
			check("...but hidden while a button has focus", not cur.shown)
			check("it's the root's last child (sees pad presses first)", cur.get_index() == root.get_child_count() - 1)
			at = cur.pos
			axis(JOY_AXIS_LEFT_X, 0.3)
			until = TK.wait_ticks(20)
		2:
			var slow: float = cur.pos.x - at.x
			check("a small push shows the ring and moves it a little (%.1f px)" % slow, cur.shown and slow > 0.5 and slow < 30.0)
			at = cur.pos
			axis(JOY_AXIS_LEFT_X, 1.0)
			until = TK.wait_ticks(20)
		3:
			var fast: float = cur.pos.x - at.x
			check("full tilt goes much faster (%.1f px)" % fast, fast > 120.0)
			axis(JOY_AXIS_LEFT_X, 0.0)
			check("the stick steps no focus while it's the pointer", gm.screen() == "pause")
			cur.point_at(root_point(pause_button("Options")))
			until = TK.wait_ticks(2)
		4:
			button(JOY_BUTTON_A, true)
			until = TK.wait_ticks(2)
		5:
			check("A held: the left button's down", Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
			check("...and the captain's jump isn't", not Input.is_action_pressed("jump"))
			button(JOY_BUTTON_A, false)
			until = TK.wait_ticks(3)
		6:
			check("A over Options clicked it (%s)" % gm.screen(), gm.screen() == "options")
			check("no jump came of it (%s)" % p.current_state_name(), p.current_state_name() != "Jump")
			button(JOY_BUTTON_B, true)
			button(JOY_BUTTON_B, false)
			until = TK.wait_ticks(3)
		7:
			check("B backs out to the pause menu (%s)" % gm.screen(), gm.screen() == "pause")
			button(JOY_BUTTON_B, true)
			button(JOY_BUTTON_B, false)
			until = TK.wait_ticks(3)
		8:
			check("B again closes it (%s)" % gm.screen(), gm.screen() == "")
			check("...without a dodge (%s)" % p.current_state_name(), p.current_state_name() != "Dodge" and not Input.is_action_pressed("dodge"))
			check("the pointer's off in play", not cur.active and not cur.shown)
			button(JOY_BUTTON_START, true)
			button(JOY_BUTTON_START, false)
			until = TK.wait_ticks(4)
		9:
			axis(JOY_AXIS_LEFT_Y, 1.0)
			until = TK.wait_ticks(6)
		10:
			axis(JOY_AXIS_LEFT_Y, 0.0)
			check("open again, the stick shows the ring", cur.shown)
			var m := InputEventMouseMotion.new()
			m.position = Vector2(300, 300)
			m.relative = Vector2(30, 0)
			Input.parse_input_event(m)
			until = TK.wait_ticks(3)
		11:
			check("the mouse moving hides it", not cur.shown and not root.get_node("Pad").using_pad)
			gm.close()
			until = TK.wait_ticks(3)
		12:
			at = cur.pos
			axis(JOY_AXIS_LEFT_X, 1.0)
			button(JOY_BUTTON_A, true)
			until = TK.wait_ticks(10)
		13:
			check("in play the stick never moves the pointer", cur.pos == at and not cur.shown)
			check("...and A is the jump, not a click", not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
			axis(JOY_AXIS_LEFT_X, 0.0)
			button(JOY_BUTTON_A, false)
			return TK.done(fails)
	step += 1
	return false

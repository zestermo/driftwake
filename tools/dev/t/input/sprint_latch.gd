extends SceneTree
## L3 latches the sprint: one click and you run while the stick is pushed; let the stick centre and it stops.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
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


func stick_y(v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = JOY_AXIS_LEFT_Y
	e.axis_value = v
	Input.parse_input_event(e)


func flat_speed() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var pad = root.get_node("Pad")
	match step:
		0:
			p = stage.player
			stick_y(-1.0)
			until = TK.wait_secs(0.5)
		1:
			check("the left stick walks you (%.1f m/s)" % flat_speed(), flat_speed() > 5.0 and flat_speed() < 7.0)
			button(JOY_BUTTON_LEFT_STICK, true)
			button(JOY_BUTTON_LEFT_STICK, false)
			until = TK.wait_secs(0.5)
		2:
			check("a click of L3 latches the sprint", pad.sprint_latched and Input.is_action_pressed("sprint"))
			check("...and you sprint with L3 let go (%.1f m/s)" % flat_speed(), p.sprinting and flat_speed() > 8.0)
			# a mouse nudge (no Shift) must not drop a pad's sprint
			var mm := InputEventMouseMotion.new()
			mm.relative = Vector2(2, 0)
			Input.parse_input_event(mm)
			until = TK.wait_ticks(3)
		3:
			check("a mouse nudge leaves the latch", Input.is_action_pressed("sprint"))
			stick_y(0.0)
			until = TK.wait_secs(0.4)
		4:
			check("centring the stick ends the latch", not pad.sprint_latched and not Input.is_action_pressed("sprint"))
			return TK.done(fails)
	step += 1
	return false

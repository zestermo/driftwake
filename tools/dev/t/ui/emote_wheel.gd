extends SceneTree
## Holding T opens the emote wheel: pointing up and letting go waves, pointing down sits you on the ground; moving
## ends a full-body emote (the hornpipe).
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


func point(v: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.relative = v
	mm.screen_relative = v
	p.emote_wheel._input(mm)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			Input.action_press("emote")
			until = TK.wait_ticks(3)
		1:
			check("holding T opens the wheel", p.emote_wheel.is_open())
			point(Vector2(0, -80))
			check("pointing up picks the top one (%d)" % p.emote_wheel._pick, p.emote_wheel._pick == 0)
			Input.action_release("emote")
			until = TK.wait_ticks(4)
		2:
			check("letting go of T waves (%s)" % p.body_model.current_action(), not p.emote_wheel.is_open() and p.body_model.current_action() == "emote_wave")
			p.body_model.stop_action()
			Input.action_press("emote")
			until = TK.wait_ticks(3)
		3:
			point(Vector2(0, 80))
			Input.action_release("emote")
			until = TK.wait_ticks(30)
		4:
			check("pointing down picks Sit: on the ground (%s)" % p.current_state_name(), p.current_state_name() == "Sit" and p.body_model.seat_y < 0.25)
			p.state_machine.force_state("Idle", {})
			p.emote("dance")
			Input.action_press("move_forward")
			until = TK.wait_ticks(10)
		5:
			Input.action_release("move_forward")
			check("moving ends the hornpipe (%s)" % p.body_model.current_action(), p.body_model.current_action() != "emote_dance")
			return TK.done(fails)
	step += 1
	return false

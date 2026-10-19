extends SceneTree
## A jump out of a sprint costs stamina; too winded for it and you still jump, as a plain running jump.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var seen := {}
var step := 0
var until := 0
var fails := 0
var before := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func home() -> void:
	p.global_position = Vector3(0, stage.GROUND_Y + 0.05, 0)
	p.reset_physics_interpolation()


func _process(_d: float) -> bool:
	if p != null:
		var a: String = p.body_model.current_action()
		if a != "":
			seen[a] = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			TK.press("move_forward")
			TK.press("sprint")
			until = TK.wait_secs(0.8)
		1:
			check("sprinting before the jump", p.sprinting)
			before = p.stamina
			seen.clear()
			TK.act("jump")
			until = TK.wait_ticks(2)
		2:
			check("the sprint jump took stamina (%.1f -> %.1f)" % [before, p.stamina], p.stamina < before - 8.0)
			check("...and is the sprint bound", seen.has("jump_sprint"))
			until = TK.wait_secs(1.2)
		3:
			TK.release("sprint")
			TK.release("move_forward")
			home()
			until = TK.wait_secs(0.4)
		4:
			TK.press("move_forward")
			TK.press("sprint")
			until = TK.wait_secs(0.7)
		5:
			p.stamina = 2.0
			p.velocity.x = 0.0
			p.velocity.z = -p.sprint_speed
			seen.clear()
			TK.act("jump")
			until = TK.wait_ticks(2)
		6:
			check("winded: the jump still happens (%s)" % p.current_state_name(), p.current_state_name() in ["Jump", "Fall"] and p.velocity.y > 0.0)
			check("...as a running jump, not the sprint bound (%s)" % [seen.keys()], seen.has("jump_run") and not seen.has("jump_sprint"))
			TK.release("sprint")
			TK.release("move_forward")
			return TK.done(fails)
	step += 1
	return false

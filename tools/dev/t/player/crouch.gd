extends SceneTree
## C toggles the crouch: you sneak along slower and low, and C again stands you up.
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			TK.press("crouch")
			until = TK.wait_ticks(10)
		1:
			check("C crouches (%s)" % p.current_state_name(), p.current_state_name() == "Crouch" and p.body_model.crouching)
			Input.action_press("move_forward")
			until = TK.wait_ticks(30)
		2:
			var v: float = Vector2(p.velocity.x, p.velocity.z).length()
			var hips: float = p.body_model.pivot.global_position.y - p.global_position.y
			check("...and you sneak along slower (%.1f m/s), low (hips %.2f m up)" % [v, hips], v > 2.0 and v < 4.0 and hips < 0.75)
			Input.action_release("move_forward")
			TK.press("crouch")
			until = TK.wait_ticks(10)
		3:
			check("C again stands you up (%s)" % p.current_state_name(), p.current_state_name() != "Crouch" and not p.body_model.crouching)
			return TK.done(fails)
	step += 1
	return false

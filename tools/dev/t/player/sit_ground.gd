extends SceneTree
## Sitting on the ground anywhere (hips low), and up again on a move.
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
			p.sit_ground()
			until = TK.wait_ticks(40)
		1:
			var bm = p.body_model
			var hips_h: float = bm.pivot.global_position.y - stage.GROUND_Y
			check("sat on the ground (%s, hips %.2f m up)" % [p.current_state_name(), hips_h], p.current_state_name() == "Sit" and bm.seated and hips_h < 0.4)
			Input.action_press("move_forward")
			until = TK.wait_ticks(8)
		2:
			Input.action_release("move_forward")
			check("...and up again on a move", p.current_state_name() != "Sit" and not p.body_model.seated)
			return TK.done(fails)
	step += 1
	return false

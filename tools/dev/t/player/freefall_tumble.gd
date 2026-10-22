extends SceneTree
## A long freefall (~3.5 s with no air step, ability or attack): the body goes limp and tumbles; it lands in the
## usual get-up with the usual fall damage.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


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
			p.global_position.y += 140.0
			p.reset_physics_interpolation()
			hp0 = p.health_component.current_health
			until = TK.wait_secs(3.0)
		1:
			check("three seconds in, still falling upright (%s)" % p.current_state_name(), p.current_state_name() == "Fall" and p.body_model.ragdoll == null)
			until = TK.wait_secs(0.8)
		2:
			check("past ~3.5 s of freefall the body tumbles limp (%s)" % p.current_state_name(), p.current_state_name() == "Downed" and p.body_model.ragdoll != null)
			until = TK.wait_secs(6.0)
		3:
			check("the landing hurts as a fall does (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health < hp0 - 30.0)
			check("down on the ground, getting up or up (%s, %.1f m up)" % [p.current_state_name(), p.global_position.y - 3.0], p.global_position.y < 4.5)
			until = TK.wait_secs(4.0)
		4:
			check("back on your feet (%s)" % p.current_state_name(), p.current_state_name() in ["Idle", "Move"] and p.body_model.ragdoll == null)
			return TK.done(fails)
	step += 1
	return false

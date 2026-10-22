extends SceneTree
## Breakfall (Acrobatics): knocked airborne by a heavy blow, jump rights you in the air (the ragdoll ends, upright,
## falling); without it the same press does nothing.
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


func _knock() -> void:
	p.global_position.y += 6.0
	p.reset_physics_interpolation()
	p.knock_down(Vector3(5.0, 4.0, 0.0))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			_knock()
			until = TK.wait_secs(0.3)
		1:
			TK.act("jump")
			until = TK.wait_ticks(3)
		2:
			check("without Breakfall a jump press leaves you in the ragdoll (%s)" % p.current_state_name(), p.current_state_name() == "Downed" and p.body_model.ragdoll != null)
			until = TK.wait_secs(5.0)
		3:
			check("up again (%s)" % p.current_state_name(), p.current_state_name() in ["Idle", "Move"])
			p.progression.owned["ac_breakfall"] = true
			p._recalc_stats()
			_knock()
			until = TK.wait_secs(0.3)
		4:
			check("knocked airborne (%s)" % p.current_state_name(), p.current_state_name() == "Downed" and p.body_model.ragdoll != null)
			TK.act("jump")
			until = TK.wait_ticks(3)
		5:
			check("Breakfall rights you in the air (%s, %s)" % [p.current_state_name(), p.body_model.current_action()],
				p.current_state_name() == "Fall" and p.body_model.ragdoll == null and p.body_model.current_action() == "breakfall")
			check("still in the air", not p.is_on_floor())
			until = TK.wait_secs(0.5)
		6:
			check("upright (%.2f)" % p.body_model.pivot.rotation.x, absf(wrapf(p.body_model.pivot.rotation.x, -PI, PI)) < 0.4)
			until = TK.wait_secs(2.0)
		7:
			check("landed on your feet (%s)" % p.current_state_name(), p.current_state_name() in ["Idle", "Move"] and p.is_on_floor())
			return TK.done(fails)
	step += 1
	return false

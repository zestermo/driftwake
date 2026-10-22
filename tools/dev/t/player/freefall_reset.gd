extends SceneTree
## Air steps keep the freefall timer reset (no tumble while you keep stepping), and once tumbling an air step pulls
## you out of it, upright.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var tumbled := false


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if p != null and step < 5 and p.current_state_name() == "Downed":
		tumbled = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.progression.owned["m_geppo"] = true
			p.progression.owned["m_skywalk"] = true
			p.set_ability("double_jump", true)
			p.global_position.y += 420.0
			p.reset_physics_interpolation()
			until = TK.wait_secs(2.4)
		1, 3:
			TK.act("jump")
			until = TK.wait_secs(2.4)
		2:
			check("an air step 2.4 s in (%s)" % p.current_state_name(), p.current_state_name() in ["Jump", "Fall"])
			until = TK.wait_ticks(1)
		4:
			check("stepping every 2.4 s, never a tumble over 7 s of falling", not tumbled)
			until = TK.wait_secs(1.6)
		5:
			check("no steps left: it tumbles (%s)" % p.current_state_name(), p.current_state_name() == "Downed" and p.body_model.ragdoll != null)
			p.jumps_remaining = 1
			TK.act("jump")
			until = TK.wait_ticks(3)
		6:
			check("an air step pulls you out of the tumble (%s, %s)" % [p.current_state_name(), p.body_model.current_action()],
				p.current_state_name() in ["Jump", "Fall"] and p.body_model.ragdoll == null and p.body_model.current_action() == "double_jump")
			until = TK.wait_secs(0.6)
		7:
			check("upright again (%.2f)" % p.body_model.pivot.rotation.x, absf(wrapf(p.body_model.pivot.rotation.x, -PI, PI)) < 0.4)
			return TK.done(fails)
	step += 1
	return false

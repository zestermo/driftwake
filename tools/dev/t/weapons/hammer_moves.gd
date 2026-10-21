extends SceneTree
## A warhammer's moveset past the combo (its tree mastered): Rising Crush at a sprint lands on the dummy, the parry
## holds the haft up across the front, the combo's fourth blow is Wrecking Spin and lands, and Hammerfall drops
## from the air, its landing shockwave hitting the dummy.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var taken := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.4), "weapon": "warhammer"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func haft() -> Vector3:
	return -(p.body_model.weapon.global_basis.z as Vector3).normalized()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			# (the dummy heals to full when it would die: count what lands instead)
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			stage.camera_rig.rotation.y = 0.0
			p.progression.master_all()
			until = TK.wait_secs(0.6)
		1:
			taken = 0.0
			p.quick_draw = true
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		2:
			check("at a sprint, Rising Crush (%s)" % p.body_model.current_action(), p.body_model.current_action() == "ham_rush")
			until = TK.wait_secs(0.6)
		3:
			check("it lands (%.0f damage)" % taken, taken > 0.0)
			until = TK.wait_secs(1.0)
		4:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.4)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			p.state_machine.force_state("Parry", {})
			until = TK.wait_secs(0.15)
		5:
			check("the parry (%s): the haft up across the front (%.2f up, %.2f across)" % [p.body_model.current_action(), haft().y, absf(haft().x)],
				p.body_model.current_action() == "parry" and haft().y > 0.2 and absf(haft().x) > 0.5)
			until = TK.wait_secs(0.8)
		6:
			if not p.is_free():
				return false
			p.remember_combo(3)
			taken = 0.0
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		7:
			check("mastered, the combo's fourth blow is Wrecking Spin (%s)" % p.body_model.current_action(), p.body_model.current_action() == "ham_spin")
			until = TK.wait_secs(0.9)
		8:
			check("it lands (%.0f damage)" % taken, taken > 0.0)
			until = TK.wait_secs(0.8)
		9:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 3.5, 1.8)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			taken = 0.0
			p.state_machine.force_state("Plunge", {})
			until = TK.wait_ticks(3)
		10:
			check("attacked in the air, Hammerfall (%s)" % p.body_model.current_action(), p.body_model.current_action() == "ham_dive")
			until = TK.wait_secs(1.0)
		11:
			check("it lands with a shockwave that hits the dummy (%.0f damage)" % taken, taken > 0.0)
			check("the hammer driven into the ground (%s)" % p.body_model.current_action(), p.body_model.current_action() in ["ham_land", ""])
			return TK.done(fails)
	step += 1
	return false

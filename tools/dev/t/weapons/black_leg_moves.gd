extends SceneTree
## Black-leg's moveset past the light kicks (its tree mastered): the combo's fourth is Handstand Spin, down on both
## hands (planted on the ground) with the legs split and turning, and it lands; Arrow Kick at a sprint lands; the
## parry raises the lead shin; Cyclone Heel drops from the air turning and its landing (a hand down) hits.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var taken := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.2)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func rel(n: Node3D) -> Vector3:
	return n.global_position - p.global_position


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.learn_black_leg()
			p.progression.master_all()
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		1:
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 1.3)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			p.remember_combo(3)
			taken = 0.0
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		2:
			check("mastered, the combo's fourth is Handstand Spin (%s)" % p.body_model.current_action(), p.body_model.current_action() == "bl_4")
			until = TK.wait_secs(0.5)
		3:
			var b = p.body_model
			var hl := rel(b.hand_l)
			var hr := rel(b.hand_r)
			var fl: Vector3 = b.shin_l.global_transform * Vector3(0, b.shin_l.position.y, 0) - p.global_position
			check("upside down on both hands, planted on the ground (%.2f / %.2f m), the feet up high (%.2f m)" % [hl.y, hr.y, fl.y],
				absf(hl.y) < 0.15 and absf(hr.y) < 0.15 and fl.y > 0.8)
			until = TK.wait_secs(0.3)
		4:
			check("it lands (%.0f)" % taken, taken > 0.0)
			until = TK.wait_secs(0.8)
		5:
			if not p.is_free():
				return false
			check("back on the feet the right way up (pitch %.2f)" % p.body_model.pivot.rotation.x, absf(p.body_model.pivot.rotation.x) < 0.3)
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 3.0)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			taken = 0.0
			p.quick_draw = true
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		6:
			check("at a sprint, Arrow Kick (%s)" % p.body_model.current_action(), p.body_model.current_action() == "bl_rush")
			until = TK.wait_secs(0.6)
		7:
			check("it lands (%.0f)" % taken, taken > 0.0)
			until = TK.wait_secs(0.8)
		8:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.0)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			p.state_machine.force_state("Parry", {})
			until = TK.wait_secs(0.15)
		9:
			var b = p.body_model
			var knee := rel(b.shin_l)
			check("the parry (%s) raises the lead shin (knee %.2f m up)" % [b.current_action(), knee.y], b.current_action() == "parry" and knee.y > 0.6)
			until = TK.wait_secs(0.8)
		10:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 3.5, 1.6)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			taken = 0.0
			p.state_machine.force_state("Plunge", {})
			until = TK.wait_ticks(3)
		11:
			check("attacked in the air, Cyclone Heel (%s)" % p.body_model.current_action(), p.body_model.current_action() == "bl_air")
			until = TK.wait_secs(1.0)
		12:
			check("it hits the dummy (%.0f)" % taken, taken > 0.0)
			check("landed on one hand (%s)" % p.body_model.current_action(), p.body_model.current_action() in ["bl_air_land", ""])
			return TK.done(fails)
	step += 1
	return false

extends SceneTree
## A greatsword's moveset past the combo (its tree mastered): sprinting it drags the point low behind; Running Cleave
## at a sprint lands on the dummy; the parry stands the blade up in front, its flat to them; the combo's fourth blow
## is Gale Turn and lands; Falling Cleave drops from the air and its landing line hits the dummy.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var GA
var taken := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.4), "weapon": "greatsword"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blade() -> Vector3:
	return -(p.body_model.weapon.global_basis.z as Vector3).normalized()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			GA = load("res://scripts/player_states/greatsword_arts.gd")
			# (the dummy heals to full when it would die: count what lands instead)
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			stage.camera_rig.rotation.y = PI
			p.progression.master_all()
			until = TK.wait_secs(0.6)
		1:
			TK.press("move_forward")
			TK.press("sprint")
			until = TK.wait_secs(0.9)
		2:
			var tip: Vector3 = GA.tip(p) - p.global_position
			var back: float = tip.dot(p.player_model.global_basis.z)
			check("sprinting (%s), the point drags low behind (%.2f m up, %.2f m back), one hand on it" % [str(p.body_model.sprinting), tip.y, back],
				p.body_model.sprinting and tip.y < 0.4 and back > 0.6)
			TK.release("sprint")
			TK.release("move_forward")
			until = TK.wait_secs(0.6)
		3:
			stage.camera_rig.rotation.y = 0.0
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.6)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			taken = 0.0
			p.quick_draw = true
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		4:
			check("at a sprint, Running Cleave (%s)" % p.body_model.current_action(), p.body_model.current_action() == "gs_rush")
			until = TK.wait_secs(0.6)
		5:
			check("it lands (%.0f damage)" % taken, taken > 0.0)
			until = TK.wait_secs(1.0)
		6:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.4)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			p.state_machine.force_state("Parry", {})
			until = TK.wait_secs(0.15)
		7:
			check("the parry (%s): the blade stood up in front (%.2f up)" % [p.body_model.current_action(), blade().y],
				p.body_model.current_action() == "parry" and blade().y > 0.7)
			until = TK.wait_secs(0.8)
		8:
			if not p.is_free():
				return false
			p.remember_combo(3)
			taken = 0.0
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		9:
			check("mastered, the combo's fourth blow is Gale Turn (%s)" % p.body_model.current_action(), p.body_model.current_action() == "gs_4")
			until = TK.wait_secs(0.9)
		10:
			check("it lands (%.0f damage)" % taken, taken > 0.0)
			until = TK.wait_secs(0.8)
		11:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 3.5, 2.2)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			taken = 0.0
			p.state_machine.force_state("Plunge", {})
			until = TK.wait_ticks(3)
		12:
			check("attacked in the air, Falling Cleave (%s)" % p.body_model.current_action(), p.body_model.current_action() == "gs_dive")
			until = TK.wait_secs(1.0)
		13:
			check("it lands with a cleave line that hits the dummy (%.0f damage)" % taken, taken > 0.0)
			check("the blade driven into the ground (%s)" % p.body_model.current_action(), p.body_model.current_action() in ["gs_land", ""])
			return TK.done(fails)
	step += 1
	return false

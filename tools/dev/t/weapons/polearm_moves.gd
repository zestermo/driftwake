extends SceneTree
## A spear's moveset past the combo (its tree mastered): the Leg Sweep at a sprint puts the dummy down from three
## paces, the sprint's jump is a pole vault (higher and further), the parry holds the shaft level across the
## front, and Falling Spear dives from the air and its landing ring hits the dummy.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hc
var hp := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -3.0), "weapon": "spear"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func shaft() -> Vector3:
	return -(p.body_model.weapon.global_basis.z as Vector3).normalized()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			hc = stage.dummy.get_node("HealthComponent")
			stage.camera_rig.rotation.y = 0.0
			p.progression.master_all()
			until = TK.wait_secs(0.6)
		1:
			hp = hc.current_health
			p.quick_draw = true
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		2:
			check("at a sprint, the Leg Sweep (%s)" % p.body_model.current_action(), p.body_model.current_action() == "pole_legsweep")
			until = TK.wait_secs(0.6)
		3:
			check("it cuts the dummy's legs from three paces (%.0f -> %.0f)" % [hp, hc.current_health], hc.current_health < hp)
			until = TK.wait_secs(0.8)
		4:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(6.0, 0.05, 0)
			p.reset_physics_interpolation()
			p.velocity = Vector3(0, 0, -p.sprint_speed)
			p.state_machine.force_state("Jump", {})
			until = TK.wait_ticks(2)
		5:
			check("a sprint's jump with the spear drawn is a pole vault (%s)" % p.body_model.current_action(), p.body_model.current_action() == "pole_vault")
			check("higher and further than a bound (up %.1f, carry %.1f)" % [p.velocity.y, p.air_speed], p.velocity.y > p.jump_force * 1.15 and p.air_speed > p.sprint_speed * 1.2)
			until = TK.wait_secs(0.4)
		6:
			check("one hand on it over the top: the left lets go", p.body_model.pole_cur[3] < 0.0)
			until = TK.wait_secs(1.0)
		7:
			if not p.is_on_floor():
				return false
			p.state_machine.force_state("Idle", {})
			until = TK.wait_secs(0.4)
		8:
			p.state_machine.force_state("Parry", {})
			until = TK.wait_secs(0.15)
		9:
			check("the parry (%s): the shaft held level across the front (%.2f up)" % [p.body_model.current_action(), shaft().y],
				p.body_model.current_action() == "parry" and absf(shaft().y) < 0.4)
			until = TK.wait_secs(0.8)
		10:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 3.5, 1.6)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			hp = hc.current_health
			p.state_machine.force_state("Plunge", {})
			until = TK.wait_ticks(3)
		11:
			check("attacked in the air, Falling Spear (%s)" % p.body_model.current_action(), p.body_model.current_action() == "pole_dive")
			until = TK.wait_secs(1.0)
		12:
			check("it lands with a ring that hits the dummy (%.0f -> %.0f)" % [hp, hc.current_health], hc.current_health < hp)
			check("and the spear's point goes into the ground (%s)" % p.body_model.current_action(), p.body_model.current_action() in ["pole_land", ""])
			return TK.done(fails)
	step += 1
	return false

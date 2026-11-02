extends SceneTree
## A fighting staff's moveset past the combo (its tree mastered): the combo's fourth blow is Wind Wheel and lands;
## the Vault Kick at a sprint lands; each crew technique (Twin Gale, Sweep the Legs) played alone lands on the dummy.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hits := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.0), "weapon": "staff"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func stand(off: float) -> void:
	p.global_position = stage.dummy.global_position + Vector3(0, 0.05, off)
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	hits = 0


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(_h, _a): hits += 1)
			stage.camera_rig.rotation.y = 0.0
			p.progression.master_all()
			until = TK.wait_secs(0.6)
		1:
			stand(1.9)
			p.remember_combo(3)
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		2:
			check("mastered, the combo's fourth blow is Wind Wheel (%s)" % p.body_model.current_action(), p.body_model.current_action() == "sf_4")
			until = TK.wait_secs(0.9)
		3:
			check("it lands (%d)" % hits, hits >= 1)
			until = TK.wait_secs(0.8)
		4:
			if not p.is_free():
				return false
			stand(3.2)
			p.quick_draw = true
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		5:
			check("at a sprint, the Vault Kick (%s)" % p.body_model.current_action(), p.body_model.current_action() == "sf_dash")
			until = TK.wait_secs(0.6)
		6:
			check("it lands (%d)" % hits, hits >= 1)
			until = TK.wait_secs(0.8)
		7:
			if not p.is_free():
				return false
			stand(2.4)
			check("C plays Twin Gale (%s)" % p.crew_tech.id(), p.crew_tech.id() == "twin_gale")
			p.state_machine.force_state("CrewTechnique", {"id": "twin_gale", "role": "solo"})
			until = TK.wait_secs(1.4)
		8:
			check("Twin Gale alone lands (%d)" % hits, hits >= 2)
			until = TK.wait_secs(0.8)
		9:
			if not p.is_free():
				return false
			stand(2.4)
			p.state_machine.force_state("CrewTechnique", {"id": "sweep_the_legs", "role": "solo"})
			until = TK.wait_secs(1.6)
		10:
			check("Sweep the Legs alone lands (%d)" % hits, hits >= 2)
			return TK.done(fails)
	step += 1
	return false

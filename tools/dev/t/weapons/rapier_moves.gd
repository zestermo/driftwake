extends SceneTree
## A rapier's moveset past the combo (its tree mastered): the combo's fourth blow is Mercury Flurry and lands four times;
## the Fleche at a sprint lands; each crew technique (Mirror Match, Through the Sleeve) played alone lands on the dummy.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hits := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.0), "weapon": "rapier"})


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
			check("mastered, the combo's fourth blow is Mercury Flurry (%s)" % p.body_model.current_action(), p.body_model.current_action() == "rp_4")
			until = TK.wait_secs(0.9)
		3:
			check("it lands four times (%d)" % hits, hits >= 4)
			until = TK.wait_secs(0.8)
		4:
			if not p.is_free():
				return false
			stand(3.2)
			p.quick_draw = true
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		5:
			check("at a sprint, the Fleche (%s)" % p.body_model.current_action(), p.body_model.current_action() == "rp_dash")
			until = TK.wait_secs(0.6)
		6:
			check("it lands (%d)" % hits, hits >= 1)
			until = TK.wait_secs(0.8)
		7:
			if not p.is_free():
				return false
			stand(2.4)
			check("C plays Mirror Match (%s)" % p.crew_tech.id(), p.crew_tech.id() == "mirror_match")
			p.state_machine.force_state("CrewTechnique", {"id": "mirror_match", "role": "solo"})
			until = TK.wait_secs(1.4)
		8:
			check("Mirror Match alone lands (%d)" % hits, hits >= 2)
			until = TK.wait_secs(0.8)
		9:
			if not p.is_free():
				return false
			stand(2.4)
			p.state_machine.force_state("CrewTechnique", {"id": "through_sleeve", "role": "solo"})
			until = TK.wait_secs(1.6)
		10:
			check("Through the Sleeve alone lands (%d)" % hits, hits >= 2)
			return TK.done(fails)
	step += 1
	return false

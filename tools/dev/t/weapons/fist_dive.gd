extends SceneTree
## Diving Fist (the fists' air move, flag mv_meteor_kick): attacked in the air, the fist drawn back and a fist-first
## dive (fs_dive) that lands on the dummy and bounces you back off it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var taken := 0.0
var saw := {}
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -3.0)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if p != null:
		saw[p.body_model.current_action()] = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.progression.owned["u_meteor"] = true
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			until = TK.wait_secs(0.6)
		1:
			p.global_position = stage.dummy.global_position + Vector3(0, 3.5, 3.0)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			p.player_model.rotation.y = 0.0
			taken = 0.0
			p.state_machine.force_state("Plunge", {})
			until = TK.wait_ticks(3)
		2:
			check("attacked in the air, Diving Fist (%s)" % p.body_model.current_action(), p.body_model.current_action() == "fs_dive")
			until = TK.wait_secs(0.8)
		3:
			check("the fist lands on the dummy (%.0f)" % taken, taken > 0.0)
			check("...and bounces you off it (%s)" % str(saw.keys()), saw.has("vault_back"))
			return TK.done(fails)
	step += 1
	return false

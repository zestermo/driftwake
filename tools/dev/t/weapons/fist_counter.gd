extends SceneTree
## Shoulder Throw is a counter: cast, the hands open to catch (fs_catch); a grunt's blow caught in it does no harm and
## comes out as the throw (shoulder_throw) on the one who threw it, who's hurt; with Heavy Landing the grunt standing
## where he comes down is knocked flat and hurt too. Uncaught, the guard just times out.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var thrower
var bystander
var hp_t := 0.0
var hp_b := 0.0
var hp_p := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(0, 0, -1.5), "yaw": 0.0, "mode": "stand", "seed": 11},
		{"post": Vector3(0, 0, -6.0), "yaw": 0.0, "mode": "stand", "seed": 12}]})


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
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.progression.master_all()
			check("two grunts", stage.camp != null and stage.camp.grunts.size() == 2)
			if stage.camp == null or stage.camp.grunts.size() < 2:
				return TK.done(fails)
			thrower = stage.camp.grunts[0]
			bystander = stage.camp.grunts[1]
			until = TK.wait_secs(0.8)
		1:
			p.global_position = Vector3(0, p.global_position.y, 0)
			p.reset_physics_interpolation()
			p.player_model.rotation.y = 0.0
			p.power.equip("hip_toss", 0)
			p.power.energy = p.power.max_energy()
			check("Shoulder Throw cast", p.power.try_cast(0))
			until = TK.wait_ticks(4)
		2:
			check("the hands open to catch (%s)" % p.body_model.current_action(), p.body_model.current_action() == "fs_catch")
			hp_t = thrower.health.current_health
			hp_b = bystander.health.current_health
			hp_p = p.health_component.current_health
			var blow := HitData.new()
			blow.damage = 12.0
			p.hurtbox.take_hit(blow, thrower)
			until = TK.wait_ticks(2)
		3:
			check("the blow is caught: no harm (%.0f -> %.0f)" % [hp_p, p.health_component.current_health], p.health_component.current_health >= hp_p - 0.5)
			var tech = p.state_machine.get_node("Technique")
			check("...and answered with the throw (%s, %s)" % [p.current_state_name(), tech.id], p.current_state_name() == "Technique" and tech.id == "shoulder_throw")
			check("...the throw's pose (%s)" % p.body_model.current_action(), p.body_model.current_action() == "shoulder_throw")
			until = TK.wait_secs(1.2)
		4:
			check("the thrower is hurt (%.0f -> %.0f)" % [hp_t, thrower.health.current_health], thrower.health.current_health < hp_t)
			check("Heavy Landing: the grunt where he came down is hurt (%.0f -> %.0f)" % [hp_b, bystander.health.current_health],
				bystander.health.current_health < hp_b)
			until = TK.wait_secs(1.5)
		5:
			if not p.is_free():
				return false
			p.power.cooldowns["hip_toss"] = 0.0
			p.power.energy = p.power.max_energy()
			check("cast again", p.power.try_cast(0))
			until = TK.wait_secs(1.3)
		6:
			check("the guard ends: timed out, or a grunt's blow caught and thrown (%s %s)" % [p.current_state_name(), p.state_machine.get_node("Technique").id], (p.current_state_name() != "Technique" and not p.power.buff("riposte")) or p.state_machine.get_node("Technique").id == "shoulder_throw")
			return TK.done(fails)
	step += 1
	return false

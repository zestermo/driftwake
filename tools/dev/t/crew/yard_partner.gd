extends SceneTree
## Alone in a training yard (by a straw dummy), a crew technique that throws a crewmate is played with the yard's
## sparring partner: it steps in at your side, takes the throw (Skyward Kick), is on your side (nothing hits it, its blows
## look for the foes) and leaves once you walk off; away from the yard the self version plays as before.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0
var top := 0.0
var y0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"dummy": Vector3(0, 0, -6)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if mate and is_instance_valid(mate) and step == 2:
		top = maxf(top, mate.global_position.y)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.unequip_weapon()
			p.learn_black_leg()
			TK.act("ready_weapon")
			y0 = p.global_position.y
			until = TK.wait_secs(0.7)
		1:
			check("by a training dummy, alone: the yard (%s)" % p.crew_tech.trigger(), stage.has_node("SparringPartner"))
			mate = stage.get_node("SparringPartner")
			check("the sparring partner takes the crewmate's side", mate.current_state_name() == "CrewTechnique" and mate.state_machine.current_state.role == "partner")
			check("you lead it", p.current_state_name() == "CrewTechnique" and p.state_machine.current_state.role == "lead")
			check("it's on your side: nothing hits it, its blows look for the foes", mate.hurtbox.collision_layer == 0 and mate.foe_mask() == 32 and not mate.is_in_group("enemies"))
			until = TK.wait_secs(3.0)
		2:
			check("kicked high (%.1f m)" % (top - y0), top - y0 > 6.0)
			check("down on its feet", mate.is_on_floor())
			p.crew_tech.cooldown = 0.0
			check("used again it's called back to your side (%s)" % p.crew_tech.trigger(), mate.global_position.distance_to(p.global_position) < 2.5 and mate.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(3.0)
		3:
			p.global_position = Vector3(0, y0, 40)
			p.reset_physics_interpolation()
			p.crew_tech.cooldown = 0.0
			until = TK.wait_secs(1.6)
		4:
			check("walked off: it leaves", not is_instance_valid(mate) or mate.is_queued_for_deletion())
			check("away from the yard: the self version (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique" and p.state_machine.current_state.role == "solo")
			return TK.done(fails)
	step += 1
	return false

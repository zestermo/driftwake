extends SceneTree
## A Driftfruit power's cast (1.27, FruitCastState): the press plays its pose (Iron Slam: df_slam) and nothing happens
## through the wind-up; the power goes off on the strike key (the grunt beside you floored); the state ends at the
## cast's length. Knocked out of the cast before its strike, it fizzles. An ultimate can't be hurt through its gather.
const TK := preload("res://tools/dev/test_kit.gd")
const Y := 3.05
var stage
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -2.5), "role": "sword", "seed": 7}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func ready(p, g, fruit: String, id: String, slot: int) -> void:
	p.power.fruit = fruit
	p.global_position = Vector3(0, Y, 0)
	p.reset_physics_interpolation()
	g.set_physics_process(false)
	g.poise._immune_until = -1
	g.poise.value = g.poise.full
	g.hitbox.deactivate()
	g._set_state(g.S.IDLE)
	g.global_position = Vector3(0, Y, -2.5)
	g.health.current_health = g.health.max_health
	hp0 = g.health.current_health
	p.power.loadout[slot] = id
	p.power.energy = p.power.max_energy()
	p.power.ult = p.power.ULT_MAX
	p.power._ult_lock = 0.0
	p.power.cooldowns.clear()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var g = stage.camp.grunts[0]
	var FC = load("res://scripts/player_states/fruit_cast_state.gd")
	match step:
		0:
			until = TK.wait_secs(2.0)
		1:
			ready(p, g, "iron", "iron_slam", 0)
			until = TK.wait_ticks(3)
		2:
			g.set_physics_process(true)
			p.state_machine.force_state("Idle", {})
			check("Iron Slam casts", p.power.try_cast(0))
			check("...into its cast, its pose playing (%s, %s)" % [p.current_state_name(), p.body_model.current_action()],
				p.current_state_name() == "FruitCast" and p.body_model.current_action() == "df_slam")
			until = TK.wait_secs(FC.strike_of("iron_slam") * 0.5)
		3:
			check("...nothing yet in the wind-up (state %d)" % int(g.state), int(g.state) != int(g.S.DOWN) and g.health.current_health == hp0)
			until = TK.wait_secs(FC.strike_of("iron_slam") * 0.5 + 0.1)
		4:
			check("...on the strike key the grunt beside you is floored (state %d)" % int(g.state), int(g.state) == int(g.S.DOWN))
			until = TK.wait_secs(0.6)
		5:
			check("...and the cast is over (%s)" % p.current_state_name(), p.current_state_name() != "FruitCast")
			until = TK.wait_secs(4.0)
		6:
			# knocked out of the wind-up: it fizzles
			ready(p, g, "iron", "iron_slam", 0)
			until = TK.wait_ticks(3)
		7:
			g.set_physics_process(true)
			p.state_machine.force_state("Idle", {})
			p.power.try_cast(0)
			p.state_machine.force_state("Idle", {})
			until = TK.wait_secs(1.0)
		8:
			check("cut short before its strike, it fizzles (state %d)" % int(g.state), int(g.state) != int(g.S.DOWN) and g.health.current_health == hp0)
			# an ultimate: untouchable through the gather
			ready(p, g, "storm", "judgement_bolt", p.power.ULT)
			g.set_physics_process(true)
			p.state_machine.force_state("Idle", {})
			check("Judgement Bolt casts", p.power.try_cast(p.power.ULT))
			until = TK.wait_ticks(4)
		9:
			check("...untouchable through its gather", not p.hurtbox.monitorable)
			until = TK.wait_secs(1.4)
		10:
			check("...and touchable again after it", p.hurtbox.monitorable)
			return TK.done(fails)
	step += 1
	return false

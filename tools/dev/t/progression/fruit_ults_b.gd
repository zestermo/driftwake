extends SceneTree
## The fruit ultimates, part 2 (1.27): Iron Fortress and Meteor Drop, Bubble Prison and Bubble Sanctuary, Time Freeze
## and Overclock, Sonic Boom and Resonance Cascade, and Ember's Solar Flare.
const TK := preload("res://tools/dev/test_kit.gd")
const Y := 3.05
## [fruit, ultimate, how far ahead the foe stands, how long to wait before looking]
const CASES := [["iron", "iron_fortress", 4.0, 0.15], ["iron", "meteor_drop", 7.0, 2.5], ["bubble", "bubble_prison", 6.0, 0.15],
	["bubble", "bubble_sanctuary", 6.0, 0.1], ["clockwork", "time_freeze", 10.0, 0.15], ["clockwork", "overclock", 6.0, 0.1],
	["echo", "sonic_boom", 20.0, 0.15], ["echo", "resonance_cascade", 10.0, 0.15], ["ember", "solar_flare", 6.0, 0.15]]
var stage
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var me0 := 0.0
var k := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -4), "role": "sword", "seed": 31}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func place(p, g, c: Array) -> void:
	p.power.fruit = str(c[0])
	p.power.buffs.clear()
	p.power.clouds.clear()
	p.power.cyclones.clear()
	p.global_position = Vector3(0, Y, 0)
	p.reset_physics_interpolation()
	p.player_model.global_basis = Basis.IDENTITY
	g.global_position = Vector3(0, Y, -float(c[2]))
	# (the grunt stands still from here until the cast: what its AI is up to mustn't decide the check)
	g.set_physics_process(false)
	# (fresh poise: a foe floored by the last case is immune to the next knockdown for Poise.IMMUNE s)
	g.poise._immune_until = -1
	g.poise.value = g.poise.full
	# (and calm: not mid-swing or guarding, as a foe stood waiting would be)
	g.hitbox.deactivate()
	g._set_state(g.S.IDLE)
	g.velocity = Vector3.ZERO
	g.health.current_health = g.health.max_health
	hp0 = g.health.current_health
	p.health_component.current_health = p.health_component.max_health * 0.5
	me0 = p.health_component.current_health
	p.power.loadout[p.power.ULT] = str(c[1])
	p.power.ult = p.power.ULT_MAX
	p.power._ult_lock = 0.0
	p.power.cooldowns.clear()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var g = stage.camp.grunts[0]
	match step:
		0:
			until = TK.wait_secs(2.0)
		1:
			# (a foe still down from the last case gets up where its body lies: wait till it's up)
			if int(g.state) in [int(g.S.DOWN), int(g.S.GETUP)]:
				return false
			place(p, g, CASES[k])
			p.power.bubble_hits = 0
			p.power.cooldowns["rewind"] = 8.0
			until = TK.wait_ticks(3)
		2:
			g.set_physics_process(true)
			p.state_machine.force_state("Idle", {})
			# (facing north again: the idle state may have turned the model during the wait, and the cones and front_foe
			# read where it faces)
			p.player_model.global_basis = Basis.IDENTITY
			check("%s casts from the ultimate slot" % CASES[k][1], p.power.try_cast(p.power.ULT))
			check("...the gauge spent", p.power.ult == 0.0)
			until = TK.wait_secs(float(CASES[k][3]))
		3:
			var hurt: bool = g.health.current_health < hp0
			var st := int(g.state)
			match str(CASES[k][1]):
				"iron_fortress":
					check("...Iron Guard on, the foe near floored (state %d)" % st, p.power.buff("iron_guard") and st == int(g.S.DOWN))
				"meteor_drop":
					check("...landed in a crater: the foe floored (state %d, %.0f -> %.0f)" % [st, hp0, g.health.current_health], st == int(g.S.DOWN) and hurt)
				"bubble_prison", "time_freeze":
					check("...the foe held (state %d)" % st, st in [int(g.S.STAGGER), int(g.S.HITSTUN)])
				"bubble_sanctuary":
					check("...healed and shielded (%.0f -> %.0f, %d bubbles)" % [me0, p.health_component.current_health, p.power.bubble_hits], p.health_component.current_health > me0 + 5.0 and p.power.bubble_hits >= 3)
				"overclock":
					check("...every power ready, and quicker", p.power.cooldowns.is_empty() and p.power.buff("haste"))
				"sonic_boom", "solar_flare":
					check("...the foe struck down (state %d, %.0f -> %.0f)" % [st, hp0, g.health.current_health], hurt and st == int(g.S.DOWN))
				"resonance_cascade":
					check("...the foe marked and slowed, Echo Strike on (%.2f)" % g.slow_k, g.get_node_or_null("SonarMark") != null and g.slow_k < 1.0 and p.power.buff("echo_strike"))
			k += 1
			if k >= CASES.size():
				return TK.done(fails)
			until = TK.wait_secs(5.5)
			step = 1
			return false
	step += 1
	return false

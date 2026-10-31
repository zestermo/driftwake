extends SceneTree
## The fruits' fifth powers (1.27): Static Burst strikes the foe beside you; Gale Burst throws it away; Second Wind and
## Bubble Bath heal you; Lunge gets behind the foe and slows it; Grasping Vine hauls the foe in; Anvil floors it;
## Accelerate brings your other powers nearer; Ringing Ears slows the foes round you.
const TK := preload("res://tools/dev/test_kit.gd")
const Y := 3.05
## [fruit, skill, how far ahead the foe stands]
const CASES := [["storm", "static_burst", 2.5], ["gust", "gale_burst", 2.5], ["bear", "second_wind", 6.0],
	["wolf", "lunge", 6.0], ["vine", "grasping_vine", 9.0], ["iron", "anvil", 2.0], ["bubble", "bubble_bath", 6.0],
	["clockwork", "accelerate", 6.0], ["echo", "ringing_ears", 3.0]]
var stage
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var me0 := 0.0
var k := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -4), "role": "sword", "seed": 41}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func place(p, g, c: Array) -> void:
	p.power.fruit = str(c[0])
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
	p.power.loadout[0] = str(c[1])
	p.power.energy = p.power.max_energy()
	p.power.cooldowns.clear()
	if str(c[1]) == "accelerate":
		p.power.cooldowns["rewind"] = 6.0


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
			until = TK.wait_ticks(3)
		2:
			g.set_physics_process(true)
			p.state_machine.force_state("Idle", {})
			# (facing north again: the idle state may have turned the model during the wait, and the cones and front_foe
			# read where it faces)
			p.player_model.global_basis = Basis.IDENTITY
			check("%s casts" % CASES[k][1], p.power.try_cast(0))
			until = TK.wait_secs(0.6 if k == 4 else 0.15)
		3:
			var d: float = Vector2(g.global_position.x, g.global_position.z).length()
			match k:
				0:
					check("...the foe beside you struck (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
				1:
					check("...thrown away (state %d)" % int(g.state), int(g.state) == int(g.S.DOWN))
				2, 6:
					check("...you're healed (%.0f -> %.0f)" % [me0, p.health_component.current_health], p.health_component.current_health > me0 + 5.0)
				3:
					var behind: float = p.global_position.z - g.global_position.z
					check("...behind the foe, and it slowed (%.1f m past it, %.2f)" % [-behind, g.slow_k], behind < -0.5 and g.slow_k < 1.0)
				4:
					check("...the foe hauled in (9 m -> %.1f m)" % d, d < 5.0)
				5:
					check("...the foe floored (state %d, %.1f m off)" % [int(g.state), d], int(g.state) == int(g.S.DOWN))
				7:
					check("...your other powers nearer ready (%.1f s)" % float(p.power.cooldowns.get("rewind", 0.0)), float(p.power.cooldowns.get("rewind", 0.0)) <= 2.1)
				8:
					check("...the foe near you slowed (%.2f)" % g.slow_k, g.slow_k < 1.0)
			k += 1
			if k >= CASES.size():
				return TK.done(fails)
			until = TK.wait_secs(4.5)
			step = 1
			return false
	step += 1
	return false

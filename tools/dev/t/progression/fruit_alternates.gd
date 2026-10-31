extends SceneTree
## The fruit trees' alternates (1.27, mastery 16): each a second take on one of its fruit's powers, cast and landing on
## a foe in its reach.
const TK := preload("res://tools/dev/test_kit.gd")
const Y := 3.05
## [fruit, alternate, how far ahead the foe stands, what it does: "hurt", "slowed", "down"]
const CASES := [["storm", "thunder_lance", 7.0, "down"], ["gust", "wind_blade", 9.0, "hurt"], ["wolf", "shadow_pounce", 6.0, "hurt"],
	["bear", "overhead_smash", 2.0, "down"], ["vine", "thorn_lash", 6.0, "slowed"], ["iron", "iron_uppercut", 2.0, "down"],
	["bubble", "soap_spray", 4.0, "slowed"], ["clockwork", "slow_bolt", 9.0, "slowed"], ["echo", "echo_ring", 3.0, "hurt"],
	["ember", "flare_burst", 2.5, "hurt"]]
var stage
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var k := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -4), "role": "sword", "seed": 21}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var g = stage.camp.grunts[0]
	match step:
		0:
			until = TK.wait_secs(2.0)
		1:
			if int(g.state) in [int(g.S.DOWN), int(g.S.GETUP)]:
				return false
			var c: Array = CASES[k]
			p.power.fruit = str(c[0])
			p.global_position = Vector3(0, Y, 0)
			p.reset_physics_interpolation()
			g.set_physics_process(false)
			g.poise._immune_until = -1
			g.poise.value = g.poise.full
			g.hitbox.deactivate()
			g._set_state(g.S.IDLE)
			g.global_position = Vector3(0, Y, -float(c[2]))
			g.velocity = Vector3.ZERO
			g.health.current_health = g.health.max_health
			hp0 = g.health.current_health
			p.power.loadout[0] = str(c[1])
			p.power.energy = p.power.max_energy()
			p.power.cooldowns.clear()
			until = TK.wait_ticks(3)
		2:
			g.set_physics_process(true)
			p.state_machine.force_state("Idle", {})
			p.player_model.global_basis = Basis.IDENTITY
			check("%s casts" % CASES[k][1], p.power.try_cast(0))
			until = TK.wait_secs(0.2)
		3:
			var st := int(g.state)
			match str(CASES[k][3]):
				"down":
					check("...the foe floored (state %d)" % st, st == int(g.S.DOWN))
				"hurt":
					check("...the foe hurt (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
				"slowed":
					check("...the foe slowed (%.2f)" % g.slow_k, g.slow_k < 1.0)
			k += 1
			if k >= CASES.size():
				return TK.done(fails)
			until = TK.wait_secs(4.5)
			step = 1
			return false
	step += 1
	return false

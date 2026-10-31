extends SceneTree
## The fruits' third powers (1.27): Storm's Thundercloud strikes the foe under it; Gust's Updraft throws foes up; Iron
## Slam floors everyone round you; Bubble Trap holds the foe ahead, then pops it; Bear Hug lifts the foe ahead and
## throws it.
const TK := preload("res://tools/dev/test_kit.gd")
const Y := 3.05
## [fruit, skill, how far ahead the foe stands]
const CASES := [["storm", "thundercloud", 5.0], ["gust", "gust_updraft", 5.0], ["iron", "iron_slam", 3.0],
	["bubble", "bubble_trap", 6.0], ["bear", "bear_hug", 1.8]]
var stage
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var pos0 := Vector3.ZERO
var k := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -4), "role": "sword", "seed": 71}, {"post": Vector3(3, 0, -4), "role": "sword", "seed": 72}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## The captain at the middle facing -z, the first grunt the case's distance in front, the second out of the way (the
## physics server sees them there a tick later, so the cast is the next step's).
func place(p, gs: Array, c: Array) -> void:
	p.power.fruit = str(c[0])
	p.global_position = Vector3(0, Y, 0)
	p.reset_physics_interpolation()
	p.player_model.global_basis = Basis.IDENTITY
	gs[0].global_position = Vector3(0, Y, -float(c[2]))
	gs[1].global_position = Vector3(12, Y, 12)
	for g in gs:
		g.set_physics_process(false)
		# (fresh poise: a foe floored by the last case is immune to the next knockdown for Poise.IMMUNE s)
		g.poise._immune_until = -1
		g.poise.value = g.poise.full
		# (and calm: not mid-swing or guarding, as a foe stood waiting would be)
		g.hitbox.deactivate()
		g._set_state(g.S.IDLE)
		g.velocity = Vector3.ZERO
		g.health.current_health = g.health.max_health
	hp0 = gs[0].health.current_health
	pos0 = gs[0].global_position
	p.power.loadout[0] = str(c[1])
	p.power.energy = p.power.max_energy()
	p.power.cooldowns.clear()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var gs: Array = stage.camp.grunts
	var g = gs[0]
	match step:
		0:
			until = TK.wait_secs(2.0)
		1:
			# (a foe still down from the last case gets up where its body lies: wait till it's up)
			if int(g.state) in [int(g.S.DOWN), int(g.S.GETUP)]:
				return false
			# each case: placed, then cast, then its own look (step 3), then the next case
			place(p, gs, CASES[k])
			until = TK.wait_ticks(3)
		2:
			g.set_physics_process(true)
			p.state_machine.force_state("Idle", {})
			# (facing north again: the idle state may have turned the model during the wait, and the cones and front_foe
			# read where it faces)
			p.player_model.global_basis = Basis.IDENTITY
			check("%s casts" % CASES[k][1], p.power.try_cast(0))
			until = TK.wait_secs([1.5, 0.15, 0.1, 0.1, 1.2][k])
		3:
			match k:
				0:
					check("...it strikes the foe under it (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
				1:
					check("...the foe over it thrown up (state %d)" % int(g.state), int(g.state) == int(g.S.DOWN))
				2:
					check("...the foe beside you floored (state %d)" % int(g.state), int(g.state) == int(g.S.DOWN))
				3:
					check("...the foe ahead held (state %d)" % int(g.state), int(g.state) == int(g.S.STAGGER))
				4:
					var rb = g.humanoid.ragdoll.root_body() if g.humanoid.ragdoll else null
					var flung: float = maxf(Vector2(g.global_position.x - pos0.x, g.global_position.z - pos0.z).length(), (rb.global_position - pos0).length() if rb else 0.0)
					check("...lifted and thrown (hurt %.0f -> %.0f, flung %.1f m)" % [hp0, g.health.current_health, flung], g.health.current_health < hp0 and flung > 2.0)
			until = TK.wait_secs([6.0, 4.0, 4.0, 3.3, 0.1][k])
		4:
			if k == 0:
				check("...the cloud clears after 6 s", p.power.clouds.is_empty())
			if k == 3:
				check("...then the bubble pops (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
			k += 1
			if k >= CASES.size():
				return TK.done(fails)
			until = TK.wait_secs(1.5)
			step = 1
			return false
	step += 1
	return false

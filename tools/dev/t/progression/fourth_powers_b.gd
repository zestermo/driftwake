extends SceneTree
## The fruits' fourth powers, part 2 (1.27): Storm's Thunder Spear strikes down its line; Gust's Pull Gale drags the
## foe ahead in; Bear's Maul floors the foe ahead; Wolf's Hamstring slows it; Vine's Root Field holds it; Echo Strike
## makes a landed blow come again, half as hard.
const TK := preload("res://tools/dev/test_kit.gd")
const Y := 3.05
## [fruit, skill, how far ahead the foe stands]
const CASES := [["storm", "thunder_spear", 12.0], ["gust", "pull_gale", 8.0], ["bear", "maul", 2.0],
	["wolf", "hamstring", 2.0], ["vine", "root_field", 5.0], ["echo", "echo_strike", 2.0]]
var stage
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var hp1 := 0.0
var pos0 := Vector3.ZERO
var k := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -4), "role": "sword", "seed": 51}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func place(p, g, c: Array) -> void:
	p.power.fruit = str(c[0])
	p.power.buffs.clear()
	p.global_position = Vector3(0, Y, 0)
	p.reset_physics_interpolation()
	p.player_model.global_basis = Basis.IDENTITY
	g.global_position = Vector3(0, Y, -float(c[2]))
	# (the grunt stands still from here until the cast: what its AI is up to mustn't decide the check)
	g.set_physics_process(false)
	g.velocity = Vector3.ZERO
	g.health.current_health = g.health.max_health
	hp0 = g.health.current_health
	pos0 = g.global_position
	p.power.loadout[0] = str(c[1])
	p.power.energy = p.power.max_energy()
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
			place(p, g, CASES[k])
			until = TK.wait_ticks(3)
		2:
			g.set_physics_process(true)
			p.state_machine.force_state("Idle", {})
			check("%s casts" % CASES[k][1], p.power.try_cast(0))
			if k == 5:
				# a blow landed under Echo Strike
				var hd := HitData.new()
				hd.damage = 10.0
				g.hurtbox.take_hit(hd, p)
				p.power.on_sword_hit(g, hd)
				hp1 = g.health.current_health
			until = TK.wait_secs([0.1, 0.6, 0.1, 0.2, 0.2, 0.6][k])
		3:
			match k:
				0:
					check("...the foe 12 m down the line struck (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
				1:
					var d: float = Vector2(g.global_position.x, g.global_position.z).length()
					check("...the foe ahead dragged in (%.1f m -> %.1f m)" % [CASES[k][2], d], d < 5.0)
				2:
					check("...the foe ahead floored (state %d)" % int(g.state), int(g.state) == int(g.S.DOWN))
				3:
					check("...the foe hurt and slowed (%.0f -> %.0f, %.2f)" % [hp0, g.health.current_health, g.slow_k], g.health.current_health < hp0 and g.slow_k < 1.0)
				4:
					check("...the foe by the roots held (state %d)" % int(g.state), int(g.state) == int(g.S.STAGGER))
				5:
					check("...the blow comes again (%.0f after it, %.0f after its echo)" % [hp1, g.health.current_health], g.health.current_health < hp1 - 1.0)
			k += 1
			if k >= CASES.size():
				return TK.done(fails)
			until = TK.wait_secs(4.0)
			step = 1
			return false
	step += 1
	return false

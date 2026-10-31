extends SceneTree
## The fruit ultimates, part 1 (1.27): Storm's Tempest and Judgement Bolt, Gust's Cyclone and Hurricane, Bear's
## Avalanche and Great Roar, Wolf's Blood Moon and Pack Fury, Vine's Forest Prison and Thorn Storm: each cast from the
## ultimate slot on a full gauge, each doing its thing to a foe in its reach.
const TK := preload("res://tools/dev/test_kit.gd")
const Y := 3.05
## [fruit, ultimate, how far ahead the foe stands, how long to wait before looking]
const CASES := [["storm", "tempest", 5.0, 1.5], ["storm", "judgement_bolt", 8.0, 0.15], ["gust", "cyclone", 13.0, 1.2],
	["gust", "hurricane", 4.0, 0.15], ["bear", "bear_avalanche", 8.0, 0.2], ["bear", "great_roar", 8.0, 0.15],
	["wolf", "blood_moon", 6.0, 0.1], ["wolf", "pack_fury", 4.0, 0.15], ["vine", "forest_prison", 6.0, 0.15],
	["vine", "thorn_storm", 5.0, 0.15]]
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
			place(p, g, CASES[k])
			until = TK.wait_ticks(3)
		2:
			g.set_physics_process(true)
			p.state_machine.force_state("Idle", {})
			check("%s casts from the ultimate slot" % CASES[k][1], p.power.try_cast(p.power.ULT))
			check("...the gauge spent", p.power.ult == 0.0)
			until = TK.wait_secs(float(CASES[k][3]))
		3:
			var hurt: bool = g.health.current_health < hp0
			var st := int(g.state)
			match str(CASES[k][1]):
				"tempest":
					check("...a cloud over the foe striking it (%.0f -> %.0f)" % [hp0, g.health.current_health], hurt)
				"judgement_bolt", "hurricane":
					check("...the foe struck down (state %d, %.0f -> %.0f)" % [st, hp0, g.health.current_health], hurt and st == int(g.S.DOWN))
				"cyclone":
					var d: float = g.global_position.distance_to(Vector3(0, Y, -7))
					check("...the foe dragged into it (%.1f m from it)" % d, d < 4.5)
				"bear_avalanche":
					check("...the foe in the path floored, you through (state %d, at %.1f m)" % [st, -p.global_position.z], st == int(g.S.DOWN) and -p.global_position.z > 8.0)
				"great_roar", "forest_prison":
					check("...the foe struck and held (state %d, %.0f -> %.0f)" % [st, hp0, g.health.current_health], hurt and st == int(g.S.STAGGER))
				"blood_moon":
					check("...the howl's strength and health back (%.0f -> %.0f)" % [me0, p.health_component.current_health], p.power.buff("howl") and p.health_component.current_health > me0 + 5.0)
				"pack_fury":
					check("...the foe cut and slowed (%.0f -> %.0f, %.2f)" % [hp0, g.health.current_health, g.slow_k], hurt and g.slow_k < 1.0)
				"thorn_storm":
					check("...the foe cut (%.0f -> %.0f)" % [hp0, g.health.current_health], hurt)
			k += 1
			if k >= CASES.size():
				return TK.done(fails)
			until = TK.wait_secs(5.5)
			step = 1
			return false
	step += 1
	return false

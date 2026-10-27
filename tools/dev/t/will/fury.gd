extends SceneTree
## Fury Will at work: Red Mist (+1% damage per 4% health missing), Berserk (the skill: 10 s of a 4% heal per blow
## landed and blows taken 20% harder), Unbowed (once a fight the felling blow leaves 1 health and nothing lands for
## 2 s; a second felling blow in the same fight isn't refused), Thick Blood (damage over time on you halved).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var g
var step := 0
var until := 0
var fails := 0
var k0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass",
		"grunts": [{"post": Vector3(0, 0, -8.0), "yaw": 0.0, "mode": "stand", "seed": 43, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func give(key: String, v: float = 1.0) -> void:
	pr.stat(key)
	pr._stats[key] = v


func blow(dmg: float, dot := false) -> HitData:
	var hd := HitData.new()
	hd.damage = dmg
	hd.dot = dot
	hd.knockback_force = 0.0
	hd.stagger_duration = 0.0
	return hd


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			g = stage.camp.grunts[0]
			var hc = p.health_component
			var w = p.power.will
			k0 = p.damage_multiplier()
			hc.current_health = hc.max_health * 0.5
			check("hurt, no Red Mist: no more damage", is_equal_approx(p.damage_multiplier(), k0))
			give("red_mist")
			print("   mult %.3f -> %.3f" % [k0, p.damage_multiplier()])
			check("Red Mist at half health: +12.5% damage", is_equal_approx(p.damage_multiplier() - k0, 0.125 * p.equipped_weapon.power()))
			give("red_mist", 0.0)
			check("Thick Blood off: a bleed's tick in full", is_equal_approx(w.incoming(blow(10.0, true), 10.0), 10.0))
			give("thick_blood", 0.5)
			check("...on: halved", is_equal_approx(w.incoming(blow(10.0, true), 10.0), 5.0))
			check("...a blade isn't", is_equal_approx(w.incoming(blow(10.0), 10.0), 10.0))
			give("thick_blood", 0.0)
			p.state_machine.force_state("Technique", {"id": "will_berserk"})
			until = TK.wait_secs(0.6)
		1:
			var hc = p.health_component
			var w = p.power.will
			check("Berserk: the roar starts 10 s of it", p.power.buff("w_berserk") and p.power.buffs["w_berserk"] > 9.0)
			check("...blows on you land 20% harder", is_equal_approx(w.incoming(blow(10.0), 10.0), 12.0))
			var h0: float = hc.current_health
			w.landed(blow(50.0))
			check("...a blow landed heals 4%% of it (%.1f)" % (hc.current_health - h0), is_equal_approx(hc.current_health - h0, 2.0))
			p.power.buffs["w_berserk"] = 0.0
			p.state_machine.force_state("Idle", {})
			hc.current_health = 10.0
			check("no Unbowed: a felling blow isn't refused", w.incoming(blow(80.0), 80.0) == 80.0)
			give("unbowed")
			until = TK.wait_ticks(2)
		2:
			var hc = p.health_component
			p.fought()
			p.hurtbox.take_hit(blow(80.0), g)
			check("Unbowed: the felling blow leaves you at 1 (%.1f)" % hc.current_health, is_equal_approx(hc.current_health, 1.0))
			p.hurtbox.take_hit(blow(80.0), g)
			check("...and nothing lands for a moment", is_equal_approx(hc.current_health, 1.0) and p.power.will.untouchable())
			until = TK.wait_secs(2.2)
		3:
			var w = p.power.will
			p.fought()
			check("2 s on: touchable again", not w.untouchable())
			check("...the same fight: the next felling blow isn't refused", w.incoming(blow(80.0), 80.0) == 80.0)
			return TK.done(fails)
	step += 1
	return false

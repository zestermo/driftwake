extends SceneTree
## The 1.24 upgrades to today's paths. Iron Will: Mirror Guard (a parried blow sent back into the attacker), Stomp
## (Emission's third version: a coated heavy's quake round you knocks a shield aside). Sense: Ambush Sense (a foe
## starting an attack behind you warns you; one in front doesn't), Glimpse (the skill: foes and closed chests within
## 40 m marked through walls for 3 s, then gone), Weak Point (a boss's unbroken parts marked; a broken one not).
## Captain's Will: Intimidate (the roar's weak foes give up and go, not killed: no loot, the bounty rises), Rally (you
## and a crewmate near deal 10% more while it's on), Plant the Flag (the skill: a flag where you stand, mending you
## within 6 m).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var g
var s
var mate
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var b0 := 0
var WS


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass", "chest": [["gold", 5]], "crew": [{"name": "Mate", "at": Vector3(3, 0, 0)}],
		"grunts": [{"post": Vector3(0, 0, -2.0), "yaw": 0.0, "mode": "stand", "seed": 46, "role": "sword", "shield": true},
			{"post": Vector3(0, 0, 5.0), "yaw": PI, "mode": "stand", "seed": 47, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func give(key: String, v: float = 1.0) -> void:
	pr.stat(key)
	pr._stats[key] = v


func blow(dmg: float) -> HitData:
	var hd := HitData.new()
	hd.damage = dmg
	hd.knockback_force = 0.0
	return hd


func marks() -> int:
	var n := 0
	for c in current_scene.get_children():
		if c.name.begins_with("Glimpse") or c.name.begins_with("WeakPoint"):
			n += c._marks.size()
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			WS = load("res://scripts/powers/will_sight.gd")
			p = stage.player
			pr = p.progression
			g = stage.camp.grunts[0]
			s = stage.camp.grunts[1]
			mate = stage.crew[0]
			p.health_component.max_health = 5000.0
			p.health_component.current_health = 5000.0
			# Mirror Guard
			hp0 = g.health.current_health
			p.is_parrying = true
			p.hurtbox.take_hit(blow(12.0), g)
			check("a parried blow without Mirror Guard: nothing back", g.health.current_health == hp0)
			give("mirror_guard")
			p.hurtbox.take_hit(blow(12.0), g)
			check("Mirror Guard: the parried blow goes back into him (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
			p.is_parrying = false
			# Stomp
			g._set_state(g.S.CIRCLE)
			p.power.add_buff("coat", 5.0)
			var hit: Array = p.power.emission(3)
			check("Stomp: the quake round you strikes him and knocks his shield aside", g in hit and g._shield_down_t > 0.0)
			p.power.buffs["coat"] = 0.0
			# Ambush Sense
			give("observation")
			check("no Ambush Sense: one behind you only flashes", not s._ambush_warn())
			give("ambush_sense")
			check("Ambush Sense: one starting an attack behind you warns you", s._ambush_warn())
			check("...one in front doesn't", not g._ambush_warn())
			# Glimpse
			p.state_machine.force_state("Technique", {"id": "will_glimpse"})
			until = TK.wait_secs(0.5)
		1:
			print("   marks %d" % marks())
			check("Glimpse: the two foes and the chest marked through walls", marks() == 3)
			until = TK.wait_secs(3.2)
		2:
			check("...3 s on, gone", marks() == 0)
			var bp = load("res://scripts/enemies/beasts/beast_parts.gd").new()
			var boss := Node3D.new()
			stage.add_child(boss)
			bp.add("tusk", 50.0, [boss], 2.0, "", Color.WHITE)
			bp.add("plate", 50.0, [boss], 2.0, "", Color.WHITE)
			bp.hurt("plate", 60.0)
			WS.weak_points(p, boss, bp)
			until = TK.wait_ticks(3)
		3:
			var shown := 0
			for c in current_scene.get_children():
				if c.name.begins_with("WeakPoint"):
					for mk in c._marks:
						if mk[1].visible:
							shown += 1
			check("Weak Point: the unbroken part marked, the broken one not (%d)" % shown, shown == 1)
			# Intimidate
			give("intimidate")
			s.health.current_health = s.health.max_health * 0.2
			b0 = int(p.bounty)
			var tech = p.state_machine.get_node("Technique")
			tech._pc = p.power
			tech._conquer()
			until = TK.wait_secs(3.5)
		4:
			check("Intimidate: the weak foe gave up and went, not killed", not is_instance_valid(s) or (s.state == s.S.DEAD and s.health.current_health > 0.0))
			check("...the bounty rose (%d -> %d)" % [b0, int(p.bounty)], int(p.bounty) > b0)
			# Rally
			p.fought()
			give("will_rally", 0.1)
			until = TK.wait_secs(1.2)
		5:
			check("Rally: on while you fight (+%.2f)" % p.power.will.damage_k(), is_equal_approx(p.power.will.damage_k(), 0.1))
			give("will_rally", 0.0)
			p.health_component.current_health = 1000.0
			p.state_machine.force_state("Technique", {"id": "will_flag"})
			until = TK.wait_secs(2.5)
		6:
			var flag: Node = null
			for c in current_scene.get_children():
				if c.name.begins_with("WarFlag"):
					flag = c
			check("Plant the Flag: a flag where you stood", flag != null)
			check("...mending you beside it (%.0f)" % p.health_component.current_health, p.health_component.current_health > 1000.0)
			return TK.done(fails)
	step += 1
	return false

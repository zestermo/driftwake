extends SceneTree
## Bond Will alone: bonded to the crew's ship. Aboard, Link takes 15% of a blow on you onto her hull; Crew's Strength
## counts her as a crewmate; your blows aboard fill the joint gauge; Shelter, once a fight, turns a blow landing while
## you're under 30% health; Twin Finisher's second weapon is her broadside.
const TK := preload("res://tools/dev/test_kit.gd")
var WB
var stage
var p
var pr
var ship
var bond
var step := 0
var until := 0
var fails := 0
var hull0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


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
	return hd


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			WB = load("res://scripts/powers/will_bond.gd")
			p = stage.player
			pr = p.progression
			ship = stage.ship
			bond = p.power.will.bond
			give("will_link")
			give("crew_strength", 0.04)
			give("shelter")
			p.global_position = ship.global_transform * Vector3(0, 1.6, 0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(45)
		1:
			check("alone aboard: linked to the ship", WB.links.get(bond.me(), "") == "ship")
			check("...she counts for Crew's Strength", is_equal_approx(bond.damage_k(), 0.04))
			hull0 = ship.hull
			var took: float = bond.incoming(blow(20.0), 20.0)
			check("a 20 blow: 17 on you, 3 on her hull (%.1f, %.1f)" % [took, hull0 - ship.hull], is_equal_approx(took, 17.0) and is_equal_approx(hull0 - ship.hull, 3.0))
			bond.landed(blow(50.0))
			check("a blow landed aboard fills the joint gauge (half without the Joint Gauge node: %.0f)" % bond.gauge, is_equal_approx(bond.gauge, 10.0))
			var hc = p.health_component
			hc.current_health = hc.max_health * 0.2
			p.fought()
			check("Shelter: hurt, a blow does nothing", bond.incoming(blow(20.0), 20.0) == 0.0)
			check("...once a fight", bond.incoming(blow(20.0), 20.0) < 20.0 and bond.incoming(blow(20.0), 20.0) > 0.0)
			p.global_position = Vector3(0, stage.GROUND_Y + 0.2, 0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(45)
		2:
			check("ashore, far from her: no link", WB.links.get(bond.me(), "") == "")
			check("...no Crew's Strength", bond.damage_k() == 0.0)
			return TK.done(fails)
	step += 1
	return false

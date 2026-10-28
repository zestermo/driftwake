extends SceneTree
## Bond Will with a crewmate (a stand-in captain, the host deciding as it does with no network): Link to the nearest
## within 15 m (host-decided, kept on every machine), 15% of a blow on whoever's linked to us split off to them, a
## share sent to us taken; Crew's Strength +4% for the crewmate near; the joint gauge filled by our blows with the link
## beside us; Twin Finisher refused until it's full, then (the lead) striking the foe and spending it; the mate's half
## landing too; Shelter called for a crewmate badly hurt beside us, and a sheltered blow on us taking nothing.
const TK := preload("res://tools/dev/test_kit.gd")
var WB
var stage
var p
var pr
var mate
var g
var bond
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass", "crew": [{"name": "Mate", "at": Vector3(2, 0, 0)}],
		"grunts": [{"post": Vector3(0, 0, -6.0), "yaw": 0.0, "mode": "stand", "seed": 45, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


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
			mate = stage.crew[0]
			g = stage.camp.grunts[0]
			bond = p.power.will.bond
			g.health.max_health = 5000.0
			g.health.current_health = 5000.0
			p.health_component.max_health = 1000.0
			p.health_component.current_health = 1000.0
			pr.gift("will", 30)
			if pr.will_color == "":
				pr.attune("tide")
			check("Link (Bond, 1) and Crew's Strength (2)", pr.buy("w_link_v") and pr.buy("h_crew") and pr.passives.has("h_crew"))
			check("...Joint Gauge (2) at 4 spent", pr.buy("w_mist_v") and pr.buy("w_gauge"))
			check("...Shelter (2), Twin Finisher (3) at 8: on the bar", pr.buy("w_shelter") and pr.buy("w_twin_v") and "will_twin" in p.power.loadout)
			until = TK.wait_ticks(45)
		1:
			var me: String = bond.me()
			check("linked to the crewmate beside us (%s)" % str(WB.links.get(me, "")), WB.links.get(me, "") == root.get_node("Net").key_of(mate))
			check("Crew's Strength: +4%% with one near (%.2f)" % bond.damage_k(), is_equal_approx(bond.damage_k(), 0.04))
			WB.links[root.get_node("Net").key_of(mate)] = me
			check("a blow on us with the crewmate linked to us: 15% of it is theirs", is_equal_approx(bond.incoming(blow(20.0), 20.0), 17.0))
			WB.links.erase(root.get_node("Net").key_of(mate))
			hp0 = p.health_component.current_health
			WB.all("took", [me, 10.0])
			check("...and a share sent to us is taken (%.0f)" % (hp0 - p.health_component.current_health), is_equal_approx(hp0 - p.health_component.current_health, 10.0))
			var slot: int = p.power.loadout.find("will_twin")
			check("Twin Finisher waits for the gauge (%s)" % p.power.can_cast(slot), p.power.can_cast(slot) == "Joint gauge not full")
			for i in 5:
				bond.landed(blow(50.0))
			check("five 50 blows beside the link fill it (%.0f)" % bond.gauge, is_equal_approx(bond.gauge, WB.GAUGE_MAX))
			p.power.energy = p.power.max_energy()
			check("...then it casts", p.power.can_cast(slot) == "")
			hp0 = g.health.current_health
			p.power.try_cast(slot)
			until = TK.wait_secs(1.3)
		2:
			check("Twin Finisher: the foe struck (%.0f -> %.0f), the gauge spent" % [hp0, g.health.current_health], g.health.current_health < hp0 and bond.gauge == 0.0)
			check("...and we're hittable again", p.hurtbox.monitorable)
			p.state_machine.force_state("Idle", {})
			mate.global_position = p.global_position + Vector3(1.5, 0, 0)
			mate.health_component.current_health = mate.health_component.max_health * 0.2
			pr.stat("shelter")
			pr._stats["shelter"] = 1.0
			until = TK.wait_secs(2.0)
		3:
			check("hurt crewmate beside us: Shelter called for them", str(WB.sheltered.get(root.get_node("Net").key_of(mate), [""])[0]) == bond.me())
			WB.sheltered[bond.me()] = [root.get_node("Net").key_of(mate), 0.5]
			check("...and a sheltered blow on us takes nothing", bond.incoming(blow(30.0), 30.0) == 0.0)
			hp0 = g.health.current_health
			g.global_position = p.global_position + Vector3(0, 0, -3)
			p.state_machine.force_state("Technique", {"id": "will_twin_mate", "target": g})
			until = TK.wait_secs(1.3)
		4:
			check("the mate's half of a Twin Finisher lands too", g.health.current_health < hp0)
			return TK.done(fails)
	step += 1
	return false

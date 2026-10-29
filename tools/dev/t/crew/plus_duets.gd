extends SceneTree
## (1.26) Each wave-1 weapon's second crew technique (its "Crew Technique" variant switched over): alone, its solo
## version lands on the foe ahead (Powder Share: you're reloaded and hit harder); with a crewmate joined, both play a
## side (a setup's finisher and a combined attack's far-side blow are the crewmate's, struck on the same foe; Powder
## Share's energy and buff land on the crewmate).
const TK := preload("res://tools/dev/test_kit.gd")
## [tree, weapon item ("" bare hands), off hand ("" none, "same" a copy, "kicks" black leg, or an item)]
const KINDS := [["sword", "cutlass", ""], ["katana", "katana", ""], ["pistol", "pistol", ""], ["polearm", "spear", ""],
	["greatsword", "greatsword", ""], ["dual", "cutlass", "same"], ["axe", "boarding_axe", ""], ["dagger", "dagger", ""],
	["dual_dagger", "dagger", "same"], ["hammer", "warhammer", ""], ["dual_axe", "boarding_axe", "same"], ["corsair", "cutlass", "pistol"],
	["long_gun", "musket", ""], ["cannon", "hand_cannon", ""], ["slingshot", "slingshot", ""], ["unarmed", "", ""], ["black_leg", "", "kicks"]]
var stage
var p
var mate
var net
var WP
var i := 0
var tid := ""
var by_me := 0.0
var by_mate := 0.0
var e0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -3)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## A support technique's gift landed on captain `c` (CrewTechniques.SUPPORT).
func gifted(c) -> bool:
	var s: Dictionary = load("res://scripts/combat/crew_techniques.gd").SUPPORT[tid]
	var ok := true
	if s.get("rally", false):
		ok = ok and c.power.buff("crew_rally")
	if s.has("shield"):
		ok = ok and c.crew_tech.marked("shielded")
	if s.has("vanish"):
		ok = ok and c.power.buff("slipped")
	if c == mate and s.has("energy"):
		ok = ok and c.power.energy > e0
	return ok


func home() -> void:
	p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 3.0)
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	stage.camera_rig.rotation.y = 0.0


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			net = root.get_node("/root/Net")
			WP = load("res://scripts/progression/weapon_plus.gd")
			stage.dummy.remove_from_group("training_dummies")
			stage.dummy.health_component.max_health = 100000.0
			stage.dummy.health_component.current_health = 100000.0
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, a):
				if a == mate:
					by_mate += h.damage
				else:
					by_me += h.damage)
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(40, 0.1, 0), 0.0, Node.new(), "Mate")
			until = TK.wait_secs(0.6)
		1:
			if i >= KINDS.size():
				return TK.done(fails)
			var k: Array = KINDS[i]
			var db = load("res://scripts/loot/item_db.gd")
			p.unequip_weapon()
			if k[1] != "":
				p.equip_weapon(db.get_item(k[1]), true)
			match str(k[2]):
				"same":
					p.set_offhand(p.equipped_weapon.duplicate())
				"kicks":
					p.learn_black_leg()
				"":
					pass
				_:
					p.set_offhand(db.get_item(k[2]))
			p.progression.master_all()
			var pre: String = load("res://scripts/progression/skill_trees.gd").ELEMENTS[k[0]][0]
			p.progression.set_version(pre + "_crew", 1)
			tid = WP.crew_of(k[0])
			until = TK.wait_secs(0.8)
		2:
			if not p.is_free():
				return false
			check("%s: C plays %s (%s)" % [KINDS[i][0], tid, p.crew_tech.id()], p.crew_tech.id() == tid)
			home()
			mate.global_position = p.global_position + Vector3(40, 0.1, 0)
			mate.reset_physics_interpolation()
			p.crew_tech.cooldown = 0.0
			p.power.buffs.clear()
			p.crew_tech.marks.clear()
			by_me = 0.0
			check("%s alone: its solo version (%s)" % [tid, p.crew_tech.trigger()], p.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(1.6)
		3:
			if WP.CREW[tid]["kind"] == "support":
				check("%s alone: its gift on you" % tid, gifted(p))
			else:
				check("%s alone: it lands on the foe (%.0f)" % [tid, by_me], by_me > 0.0)
			until = TK.wait_secs(0.4)
		4:
			if not p.is_free():
				return false
			home()
			mate.global_position = p.global_position + Vector3(2.0, 0.1, 0)
			mate.reset_physics_interpolation()
			mate.velocity = Vector3.ZERO
			mate.power.buffs.clear()
			mate.crew_tech.marks.clear()
			mate.power.energy = 0.0
			e0 = 0.0
			p.crew_tech.cooldown = 0.0
			by_me = 0.0
			by_mate = 0.0
			until = TK.wait_ticks(4)
		5:
			net.everyone("_all_crew_offer", [net.key_of(p), tid, 6.0])
			net.crew_join(p, mate)
			until = TK.wait_ticks(4)
		6:
			if WP.CREW[tid]["kind"] != "support":
				check("%s together: both play a side (%s / %s)" % [tid, p.current_state_name(), mate.current_state_name()],
					p.current_state_name() == "CrewTechnique" and mate.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(1.6)
		7:
			if WP.CREW[tid]["kind"] == "support":
				check("%s together: its gift on the crewmate (energy %.0f -> %.0f)" % [tid, e0, mate.power.energy], gifted(mate))
			else:
				check("%s together: your blow and the crewmate's land on the same foe (%.0f / %.0f)" % [tid, by_me, by_mate], by_me > 0.0 and by_mate > 0.0)
			i += 1
			step = 1
			until = TK.wait_secs(0.6)
			return false
	step += 1
	return false

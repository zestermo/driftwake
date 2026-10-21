extends SceneTree
## The Captain grows by level with no points: each level adds health, damage, stamina, energy and defense by
## itself; the milestones come at their level (Soru 8 on the bar, a third weapon loadout at 10, Tekkai 14, a fourth
## passive slot at 25); the Captain tree always shows.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func to_level(lv: int) -> void:
	while pr.level < lv:
		pr.add_xp(pr.xp_to_next(pr.level) - pr.xp)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			var hp0: float = p.health_component.max_health
			var dmg0: float = p.damage_multiplier()
			var st0: float = p.max_stamina
			var en0: float = p.power.max_energy()
			var def0: float = p.defense()
			check("level 1: the Captain tree shows, no milestones yet", "captain" in pr.visible_trees("captain") and pr.owns("c_root") and not pr.owns("m_soru"))
			to_level(7)
			print("   lv7: hp %.1f dmg %.2f stam %.1f energy %.1f def %.1f" % [p.health_component.max_health, p.damage_multiplier(), p.max_stamina, p.power.max_energy(), p.defense()])
			check("6 levels: +33 health", is_equal_approx(p.health_component.max_health - hp0, 33.0))
			check("...+12% damage", is_equal_approx(p.damage_multiplier() - dmg0, 0.12))
			check("...+3.6 stamina, +3.6 energy, +3 defense", is_equal_approx(p.max_stamina - st0, 3.6) and is_equal_approx(p.power.max_energy() - en0, 3.6) and is_equal_approx(p.defense() - def0, 3.0))
			check("...and no skill points", pr.skill_points == 0)
			check("no Soru before 8", not pr.knows("soru"))
			to_level(8)
			check("level 8: Soru by itself, on the bar", pr.knows("soru") and "soru" in p.power.loadout)
			var slots0: int = p.loadout_slots()
			to_level(10)
			check("level 10: a third weapon loadout (%d -> %d)" % [slots0, p.loadout_slots()], p.loadout_slots() == slots0 + 1)
			to_level(14)
			check("level 14: Tekkai", pr.knows("tekkai"))
			check("three passive slots until 25", pr.passives.size() == 3)
			to_level(25)
			check("level 25: a fourth passive slot", pr.owns("c_slot4") and pr.passives.size() == 4)
			return TK.done(fails)
	step += 1
	return false

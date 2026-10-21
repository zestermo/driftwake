extends SceneTree
## A save from before the skills rework (progression format 2) loads with its level, xp, mastery, uses, gold
## and gear kept and every node refunded: no skill points any more (the Captain grows by level), each weapon's
## points back (one a mastery level) with its big nodes by level, tiers by use alone (a skill used enough ranks
## up by itself), a life skill's perks owned from its kept mastery, the Captain's milestones by level.
## Saved again it loads as it is.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_refund_migration.dat"
var SG
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			SG = load("res://scripts/game/save_game.gd")
			p = stage.player
			pr = p.progression
			p.inventory_component.add_item(ItemDB.get_item("gold"), 250)
			var gold0: int = p.inventory_component.count("gold")
			set_meta("gold", gold0)
			SG.use_test_file(SAVE)
			SG.save(p)
			var f := FileAccess.open(SAVE, FileAccess.READ)
			var data: Dictionary = f.get_var()
			f.close()
			data["progression"] = {"format": 2, "level": 9, "xp": 120, "sp": 1,
				"owned": ["origin", "c_agility", "s_root", "s_edge", "s_flying", "sea_root", "sea_trim"],
				"mastery": {"sword": {"lv": 5, "xp": 30, "pts": 0}, "sea": {"lv": 3, "xp": 5, "pts": 2}, "nonsense": {"lv": 9, "xp": 0, "pts": 9}},
				"tiers": {"flying_slash": 2}, "uses": {"flying_slash": 20, "soru": 16}}
			f = FileAccess.open(SAVE, FileAccess.WRITE)
			f.store_var(data)
			f.close()
			pr.from_dict({})
			p.unequip_weapon()
			check("load", SG.load_into(p))
			print("   level %d xp %d sword %s sea %s owned %s" % [pr.level, pr.xp, pr.mastery_of("sword"), pr.mastery_of("sea"), pr.owned.keys()])
			check("level and xp kept", pr.level == 9 and pr.xp == 120)
			check("no skill points any more", pr.skill_points == 0)
			check("weapon mastery kept, its points back (one a level)", pr.mastery_level("sword") == 5 and int(pr.mastery_of("sword")["xp"]) == 30 and pr.points_free("sword") == 4)
			check("Sailing's mastery kept, its Sea Hand owned by itself, a point a level", pr.mastery_level("sea") == 3 and pr.owns("sea_hand") and pr.points_free("sea") == 2)
			check("old nodes gone, the weapon's nodes back by mastery", not pr.owns("c_agility") and pr.owns("s_flying") and not pr.owns("s_swordfish"))
			check("the Captain's milestone by level: Soru at 8", pr.owns("m_soru") and pr.knows("soru") and not pr.owns("c_quarter"))
			check("tiers by use alone: Soru's 16 uses rank it up (no points)", pr.skill_tier("soru") == 2)
			check("...uses kept", pr.uses_of("flying_slash") == 20)
			check("a tree that's no more is dropped", not pr.mastery.has("nonsense"))
			check("gold kept", p.inventory_component.count("gold") == int(get_meta("gold")))
			check("gear kept: the cutlass in hand", p.equipped_weapon != null and p.equipped_weapon.id == "cutlass")
			SG.save(p)
			pr.from_dict({})
			check("load again", SG.load_into(p))
			check("...as it was", pr.points_free("sword") == 4 and pr.skill_tier("soru") == 2 and pr.owns("m_soru"))
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false

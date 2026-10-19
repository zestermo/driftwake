extends SceneTree
## Weapon families: mastery earned with a cutlass also builds the other blades (a quarter of it), the Corsair
## (a blade and a gun) gets it from both sides, a share never carries on a second step (no pistol from the
## cutlass), the axe and the fists keep to themselves; carried xp levels the kin up with points of their own,
## and fractions of a point add up over many small gains.
const TK := preload("res://tools/dev/test_kit.gd")
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


func total(tree: String) -> int:
	var m: Dictionary = pr.mastery_of(tree)
	var n := int(m["xp"])
	for lv in range(1, int(m["lv"])):
		n += pr.mastery_to_next(lv)
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			var ST = load("res://scripts/progression/skill_tree.gd")
			check("the families: blades, heavy, guns, fists", ST.FAMILIES.keys() == ["blades", "heavy", "guns", "fists"])
			check("the Corsair is a blade and a gun", ST.families_of("corsair") == ["blades", "guns"])
			pr.add_mastery("sword", 400)
			print("   sword %d katana %d dual %d dagger %d twin %d corsair %d pistol %d axe %d unarmed %d" % [total("sword"), total("katana"),
				total("dual"), total("dagger"), total("dual_dagger"), total("corsair"), total("pistol"), total("axe"), total("unarmed")])
			check("cutlass xp is the cutlass's own", total("sword") == 400)
			check("...and a quarter of it to every other blade", total("katana") == 100 and total("dual") == 100 and total("dagger") == 100
				and total("dual_dagger") == 100 and total("corsair") == 100)
			check("...never a second step on (no pistol from the cutlass via the Corsair)", total("pistol") == 0)
			check("the axe and the fists keep to themselves", total("axe") == 0 and total("unarmed") == 0)
			check("carried xp levels the katana up, with a point to spend there", pr.mastery_level("katana") == 2 and pr.points("katana") == 1)
			pr.add_mastery("pistol", 40)
			check("pistol xp feeds the Corsair, not the cutlass", total("corsair") == 110 and total("sword") == 400)
			for i in range(10):
				pr.add_mastery("pistol", 1)
			check("fractions add up: ten single points carry two and a half (%d)" % (total("corsair") - 110), total("corsair") == 112)
			pr.add_mastery("pistol", 2)
			check("...and the half isn't lost (%d)" % (total("corsair") - 110), total("corsair") == 113)
			var k0 := total("katana")
			pr.on_hit()
			check("a cutlass hit in a fight builds the katana too", total("katana") == k0 + 1)
			return TK.done(fails)
	step += 1
	return false

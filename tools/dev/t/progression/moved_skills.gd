extends SceneTree
## Squall Step and Ballast (1.23) are learned by doing, not handed out by Captain level: Squall Step is Acrobatics'
## (its Dodge branch, at 8) and Ballast Defense's (its Grit branch, at 10), each bought with Adventure points and
## onto the bar by itself; two captains at the same level no longer share them.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var STS
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


func to_level(tree: String, lv: int) -> void:
	while pr.mastery_level(tree) < lv:
		var m: Dictionary = pr.mastery_of(tree)
		pr.add_mastery(tree, pr.mastery_to_next(int(m["lv"])) - int(m["xp"]))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			STS = load("res://scripts/progression/skill_trees.gd")
			while pr.level < 15:
				pr.add_xp(pr.xp_to_next(pr.level) - pr.xp)
			check("Captain 15: neither by itself", not pr.knows("soru") and not pr.knows("tekkai"))
			check("Squall Step in Acrobatics' Dodge branch, Ballast in Defense's Grit", STS.node_def("m_soru")["tree"] == "acrobatics" and STS.node_def("v_tekkai")["tree"] == "defense"
				and int(STS.node_def("m_soru")["branch"]) == 1 and int(STS.node_def("v_tekkai")["branch"]) == 2)
			to_level("acrobatics", 7)
			check("Acrobatics 7: Squall Step waits (%s)" % pr.buy_why("m_soru"), pr.buy_why("m_soru") == "Needs Acrobatics 8")
			to_level("acrobatics", 8)
			check("Acrobatics 8: bought with Adventure points, on the bar", pr.buy("m_soru") and pr.knows("soru") and "soru" in p.power.loadout)
			to_level("defense", 10)
			check("Defense 10: Ballast bought too", pr.buy("v_tekkai") and pr.knows("tekkai") and "tekkai" in p.power.loadout)
			check("...its price an Adventure tech's", STS.price("v_tekkai") == 3 and STS.price("m_soru") == 2)
			return TK.done(fails)
	step += 1
	return false

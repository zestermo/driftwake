extends SceneTree
## (1.26) Every WeaponPlus tree's additions, on the trees: the alternates come by themselves at mastery 8 / 14 / 20
## (not before), the standard one first, switched to the alternate anywhere; the aerial heavy is bought from 10; the
## second ultimate waits on its lead-up, which waits on the second element; a bridge is bought from either side; the
## crew variant's second version switches C to the new technique; and R swaps ultimates only out of a fight.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var STS
var WP
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


func to_level(tree: String, lv: int) -> void:
	while pr.mastery_level(tree) < lv:
		var m: Dictionary = pr.mastery_of(tree)
		pr.add_mastery(tree, pr.mastery_to_next(int(m["lv"])) - int(m["xp"]))


func tree_checks(t: String) -> void:
	var pre: String = STS.ELEMENTS[t][0]
	var d: Dictionary = WP.TREES[t]
	pr.discover(t)
	to_level(t, 7)
	check("%s: no alternate before mastery 8" % t, not pr.owns(pre + "_alt_air"))
	to_level(t, 8)
	check("%s: at 8 the aerial alternate is yours, the standard one active" % t, pr.owns(pre + "_alt_air") and pr.version_of(pre + "_alt_air") == 0
		and pr.stat(WP.alt_key(t, "air")) == 0.0 and not pr.owns(pre + "_alt_sprint"))
	check("%s: switched to the alternate away from any rest spot" % t, not pr.can_respec() and pr.set_version(pre + "_alt_air", 1) and pr.stat(WP.alt_key(t, "air")) > 0.0)
	check("%s: the aerial heavy waits for 10 (%s)" % [t, pr.buy_why(pre + "_airheavy")], pr.buy_why(pre + "_airheavy").begins_with("Needs"))
	to_level(t, 14)
	check("%s: at 14 the sprint alternate, not yet the right-click" % t, pr.owns(pre + "_alt_sprint") and not pr.owns(pre + "_alt_heavy"))
	pr.gift(t, 40)
	check("%s: the aerial heavy bought at 10+" % t, pr.buy(pre + "_airheavy") and pr.stat(WP.air_heavy_key(t)) > 0.0)
	var b: Dictionary = STS.node_def(d["bridges"][0][0])
	var a: String = b["needs"][0]
	var c: String = b["needs"][1]
	check("%s: a bridge waits on a node beside it (%s)" % [t, pr.buy_why(b["id"])], not pr.owns(a) and not pr.owns(c) and pr.buy_why(b["id"]).begins_with("Needs"))
	pr.owned[c] = true
	var from_c: String = pr.buy_why(b["id"])
	pr.owned.erase(c)
	pr.owned[a] = true
	check("%s: ...bought from either side (%s / %s)" % [t, from_c, pr.buy_why(b["id"])], from_c == "" and pr.buy_why(b["id"]) == "")
	pr.owned.erase(a)
	to_level(t, 30)
	check("%s: at 20 and on, the right-click alternate too" % t, pr.owns(pre + "_alt_heavy"))
	var lb: String = d["lead_b"][0]
	var ub: String = d["ult_b"][0]
	check("%s: the second ultimate waits on its lead-up (%s)" % [t, pr.buy_why(ub)], pr.buy_why(ub).begins_with("Needs"))
	check("%s: the lead-up waits on the second element (%s)" % [t, pr.buy_why(lb)], pr.buy_why(lb).begins_with("Needs"))
	pr.gift(t, 40)
	check("%s: elements, lead-up and the second ultimate bought" % t, pr.buy(pre + "_elem") and pr.buy(pre + "_elem2") and pr.buy(lb) and pr.buy(ub) and pr.knows(str(d["ult_b"][1])))
	check("%s: the crew variant bought, the first technique still on C" % t, pr.buy(pre + "_crew") and pr.stat("crew2_" + t) == 0.0)
	check("%s: switched to %s anywhere" % [t, d["crew"]], pr.set_version(pre + "_crew", 1) and pr.stat("crew2_" + t) > 0.0)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			STS = load("res://scripts/progression/skill_trees.gd")
			WP = load("res://scripts/progression/weapon_plus.gd")
			for t in WP.TREES.keys():
				tree_checks(t)
			check("Kraken's Wake bought and on R", pr.buy("s_kraken") and p.power.equip("kraken_wake", p.power.ULT))
			var ub: String = WP.TREES["sword"]["ult_b"][1]
			p.fought()
			check("mid-fight R keeps its ultimate (%s)" % p.power.equip_why(ub, p.power.ULT), p.power.equip_why(ub, p.power.ULT) == "Not mid-fight")
			until = TK.wait_secs(1.0)
		1:
			p._since_fight = 999.0
			p._since_hit = 999.0
			check("out of a fight it swaps (%s)" % p.power.equip_why("undertow", p.power.ULT), p.power.equip("undertow", p.power.ULT) and p.power.loadout[p.power.ULT] == "undertow")
			return TK.done(fails)
	step += 1
	return false

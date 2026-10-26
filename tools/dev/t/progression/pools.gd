extends SceneTree
## Points per tree (1.23, option A): each weapon earns its own points by its mastery (2 a level, +1 every 5: 2 when
## found, 11 at 5, 39 at 18, 66 at 30) and spends them only on itself; Captain levels give none. Adventure points
## come a point a level any Adventure tree gains and buy only Adventure nodes. Prices come from the kind and the gate.
## Steps cost a point a step, add their effect, stop when full, and need the node they hang on (not the root's); the
## second element needs the first.
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
	stage = TK.stage(self, {"hud": false, "weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func to_level(tree: String, lv: int) -> void:
	while pr.mastery_level(tree) < lv:
		var m: Dictionary = pr.mastery_of(tree)
		pr.add_mastery(tree, pr.mastery_to_next(int(m["lv"])) - int(m["xp"]))


func captain(lv: int) -> void:
	while pr.level < lv:
		pr.add_xp(pr.xp_to_next(pr.level) - pr.xp)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			STS = load("res://scripts/progression/skill_trees.gd")
			var table: Array = [1, 5, 10, 15, 18, 20, 25, 30].map(func(l): return pr.tree_earned(l))
			check("a tree's points by mastery %s" % str(table), table == [2, 11, 22, 33, 39, 44, 55, 66])
			check("prices by kind and gate: Quick Draw 2, Iai Upgrade 5, Thousand Petals 11, a step 1, Geppo 1, Iron Wall 3",
				STS.price("k_draw") == 2 and STS.price("k_iai") == 5 and STS.price("k_petals") == 11
				and STS.price("k_keen") == 1 and STS.price("m_geppo") == 1 and STS.price("df_wall") == 3)
			check("the Captain's nodes aren't bought", STS.price("c_quarter") == 0 and STS.price("talent_5") == 0)
			check("a weapon pays from its own pool", STS.pool_of("katana") == "katana" and STS.pool_of("acrobatics") == "adventure" and STS.pool_of("captain") == "")
			check("a new captain: no Adventure points, the cutlass's 2", pr.pool("adventure") == 0 and pr.pool("sword") == 2)
			to_level("acrobatics", 3)
			check("Acrobatics 3: 2 Adventure points", pr.pool("adventure") == 2)
			to_level("swim", 2)
			check("...Swimming 2: one more, the pool is shared", pr.pool("adventure") == 3)
			check("Geppo bought with an Adventure point: a second jump", pr.buy("m_geppo") and pr.pool("adventure") == 2 and int(pr.stat("air_jumps")) == 1)
			check("...Swimming's Long Strokes from the same pool", pr.buy("sw_long") and pr.pool("adventure") == 1)
			# (bare-handed, so the levels' kills teach no katana mastery)
			p.unequip_weapon()
			captain(20)
			check("Captain 20: no weapon points from it", pr.pool("sword") == 2)
			to_level("katana", 20)
			check("katana 20: 44 katana points, the cutlass still 2", pr.pool("katana") == 44 and pr.points_free("katana") == 44 and pr.pool("sword") == 2)
			check("...Combat reads the found weapons' together", pr.pool("combat") == 46 + pr.pool("unarmed"))
			var d0: float = pr.style_stat("dmg", "katana")
			check("a step of Keen Edge (off the root: nothing needed)", pr.buy("k_keen") and pr.steps_of("k_keen") == 1 and pr.pool("katana") == 43)
			check("...+5%% katana damage", is_equal_approx(pr.style_stat("dmg", "katana") - d0, 0.05))
			check("...the cutlass doesn't feel it, nor its pool", pr.style_stat("dmg", "sword") == 0.0 and pr.pool("sword") == 2)
			for i in range(4):
				pr.buy("k_keen")
			check("Keen Edge full at 5 (%s)" % pr.buy_why("k_keen"), pr.steps_of("k_keen") == 5 and not pr.buy("k_keen") and pr.buy_why("k_keen") == "Full")
			check("Steel Nerves needs Cut the Shot first (%s)" % pr.buy_why("k_nerves"), not pr.buy("k_nerves") and pr.buy_why("k_nerves") == "Needs Cut the Shot first")
			check("...then it can be bought", pr.buy("k_deflect") and pr.buy("k_nerves"))
			to_level("katana", 25)
			check("Blossom Path needs Falling Petals first (%s)" % pr.buy_why("k_elem2"), pr.buy_why("k_elem2") == "Needs Falling Petals first")
			check("...Falling Petals, then Blossom Path", pr.buy("k_elem") and pr.buy("k_elem2") and pr.elemental("katana", 2))
			check("Adventure points don't buy weapon nodes", pr.pool("adventure") == 1 and pr.pool("katana") == 55 - 5 - 2 - 1 - 6 - 7)
			check("owns_node reads a bought step", pr.owns_node("k_keen") and not pr.owns_node("k_whet"))
			return TK.done(fails)
	step += 1
	return false

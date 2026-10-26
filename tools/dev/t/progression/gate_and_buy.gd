extends SceneTree
## Everything past a weapon's root is bought with that weapon's own points; its mastery gates it and earns them. A
## fresh katana has its root and nothing comes by itself; Quick Draw needs mastery 2 (4 points by then) and costs 2; a
## Captain level brings no weapon points; a bought technique goes on the bar by itself; the ultimate needs 30, and
## waits for points when they're short; only the weapon in hand learns.
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			STS = load("res://scripts/progression/skill_trees.gd")
			check("the katana in hand trains the katana tree (%s)" % p.style(), p.style() == "katana")
			check("a fresh katana: its root and nothing else", pr.owns("k_root") and not pr.owns("k_draw") and not pr.has_move("quick_draw"))
			check("Quick Draw needs mastery 2 (%s)" % pr.buy_why("k_draw"), not pr.buy("k_draw") and pr.buy_why("k_draw") == "Needs Katana 2")
			to_level("katana", 2)
			check("mastery 2: nothing comes by itself, 4 katana points", not pr.owns("k_draw") and pr.pool("katana") == 4)
			check("...Quick Draw bought for 2, its move unlocked", pr.buy("k_draw") and pr.has_move("quick_draw") and pr.pool("katana") == 2)
			pr.add_xp(pr.xp_to_next(1))
			check("Captain 2: no weapon points", pr.level == 2 and pr.pool("katana") == 2)
			to_level("katana", 5)
			check("mastery 5: 11 earned, 9 to spend", pr.pool("katana") == 9)
			check("...Cut the Shot bought: a parry cuts gunshots", pr.buy("k_deflect") and pr.style_stat("parryshot", "katana") > 0.0)
			check("...Wind Severer bought for 3, on the bar by itself", pr.buy("k_wind") and "wind_sever" in p.power.loadout and pr.pool("katana") == 4)
			check("...bought once", pr.buy_why("k_wind") == "Learned" and not pr.buy("k_wind"))
			check("no carry-over: the cutlass learned nothing", pr.mastery_level("sword") == 1 and int(pr.mastery_of("sword")["xp"]) == 0 and pr.pool("sword") == 2)
			var k0 := int(pr.mastery_of("katana")["xp"])
			pr.on_hit()
			check("a hit with the katana in hand: +%d katana mastery" % pr.MASTERY_PER_HIT, int(pr.mastery_of("katana")["xp"]) == k0 + pr.MASTERY_PER_HIT)
			check("the ultimate needs mastery 30 (%s)" % pr.buy_why("k_petals"), pr.buy_why("k_petals") == "Needs Katana 30")
			to_level("katana", 30)
			check("mastery 30: 66 earned, nothing by itself, the ultimate costs 11", not pr.knows("petal_storm") and STS.price("k_petals") == 11 and pr.pool("katana") == 66 - 7)
			pr.gift("katana", 10 - pr.pool("katana"))
			check("...with 10 left it waits (%s)" % pr.buy_why("k_petals"), pr.buy_why("k_petals") == "Needs 11 Katana points")
			pr.gift("katana", 1)
			check("...with 11 it's yours", pr.buy("k_petals") and pr.knows("petal_storm") and pr.pool("katana") == 0)
			check("...the xp bar stops at the top", pr.tree_level("katana") == 30 and pr.tree_xp_next("katana") == 0)
			return TK.done(fails)
	step += 1
	return false

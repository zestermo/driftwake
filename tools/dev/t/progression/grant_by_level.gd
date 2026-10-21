extends SceneTree
## A weapon's big nodes come by themselves at their mastery level: a fresh katana has only its root, mastery 2
## brings Quick Draw (its move unlocked), 5 Wind Severer (on the bar by itself), and each level a point to spend;
## big nodes can't be bought; the ultimate waits for 30; only the weapon in hand learns (no carry-over to the
## other blades).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
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
			check("the katana in hand trains the katana tree (%s)" % p.style(), p.style() == "katana")
			check("a fresh katana: its root and nothing else", pr.owns("k_root") and not pr.owns("k_draw") and not pr.has_move("quick_draw"))
			check("a big node can't be bought (%s)" % pr.can_learn("k_draw"), not pr.learn("k_draw") and pr.can_learn("k_draw") == "Comes at Katana 2")
			to_level("katana", 2)
			check("mastery 2: Quick Draw by itself, its move unlocked", pr.owns("k_draw") and pr.has_move("quick_draw"))
			check("...and a point to spend", pr.points_free("katana") == 1)
			to_level("katana", 5)
			check("mastery 5: Wind Severer, on the bar by itself", pr.knows("wind_sever") and "wind_sever" in p.power.loadout)
			check("...Cut the Shot (3) on the way: a parry cuts gunshots", pr.owns("k_deflect") and pr.style_stat("parryshot", "katana") > 0.0)
			check("...the ultimate waits for 30", not pr.owns("k_petals") and not pr.knows("petal_storm"))
			check("...four points to spend", pr.points_free("katana") == 4)
			check("no carry-over: the cutlass learned nothing", pr.mastery_level("sword") == 1 and int(pr.mastery_of("sword")["xp"]) == 0)
			var k0 := int(pr.mastery_of("katana")["xp"])
			pr.on_hit()
			check("a hit with the katana in hand: +%d katana mastery" % pr.MASTERY_PER_HIT, int(pr.mastery_of("katana")["xp"]) == k0 + pr.MASTERY_PER_HIT)
			to_level("katana", 30)
			check("mastery 30: Thousand Petals and the element", pr.knows("petal_storm") and pr.elemental("katana", 1) and pr.elemental("katana", 2))
			check("...the xp bar stops at the top", pr.tree_level("katana") == 30 and pr.tree_xp_next("katana") == 0)
			check("...29 points in all", pr.points_free("katana") == 29)
			return TK.done(fails)
	step += 1
	return false

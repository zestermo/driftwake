extends SceneTree
## Cooking at the galley: the galley screen opens on the recipes; with fish and rice in the bag Cook makes
## Fisherman's Stew (raw rice goes before hardtack, the ingredients leave the bag) and builds Cooking mastery
## (twice for a dish's first time); short of ingredients it refuses; a taught recipe (Captain's Feast) stays
## locked until Food.teach; a drink gives back stamina.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var inv
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


func give(id: String, n: int) -> void:
	inv.add_item(ItemDB.get_item(id), n)


## All the Cooking xp so far, across its levels.
func cook_xp() -> int:
	var t := int(pr.mastery_of("cook")["xp"])
	for lv in range(1, pr.mastery_level("cook")):
		t += int(pr.mastery_to_next(lv))
	return t


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			inv = p.inventory_component
			for st in inv.items.duplicate():
				if st.item.ingredient in ["fish", "grain"] or st.item.id == "fish_stew":
					inv.remove_item(st.item, st.quantity)
			give("fish", 2)
			give("rice", 1)
			give("biscuit", 1)
			var gm = root.get_node("GameMenu")
			gm.open_galley(2)
			until = TK.wait_ticks(2)
		1:
			var gm = root.get_node("GameMenu")
			check("the galley screen is open", gm._current == "galley")
			var scr = gm._galley
			var xp0 := cook_xp()
			var lv0: int = pr.mastery_level("cook")
			scr._pick("fish_stew")
			scr.cook_selected()
			check("Cook: two Fisherman's Stew from one fish and one grain", inv.count("fish_stew") == 2 and inv.count("fish") == 1)
			check("raw rice went in, not the hardtack", inv.count("rice") == 0 and inv.count("biscuit") == 1)
			var first: int = cook_xp() - xp0
			print("   cooking: lv %d -> %d, +%d xp" % [lv0, pr.mastery_level("cook"), first])
			check("Cooking mastery grows (+%d, the first time twice)" % first, first == 2 * (Food.COOK_XP + 2 * Food.COOK_XP_PER))
			xp0 = cook_xp()
			scr.cook_selected()
			check("again from hardtack, once more xp (+%d)" % (cook_xp() - xp0), inv.count("fish_stew") == 4 and inv.count("biscuit") == 0 and cook_xp() - xp0 == Food.COOK_XP + 2 * Food.COOK_XP_PER)
			check("short of grain it refuses", Food.cook(p, "fish_stew", 1) != "" and inv.count("fish_stew") == 4)
			check("Captain's Feast is locked until taught", not Food.known(pr, "captains_feast") and Food.cook(p, "captains_feast", 1).contains("recipe"))
			check("taught once", Food.teach(pr, "captains_feast") and not Food.teach(pr, "captains_feast") and Food.known(pr, "captains_feast"))
			gm.close()
			p.stamina = 10.0
			p.heal_cd = 0.0
			p.state_machine.force_state("Idle", {})
			give("rum", 1)
			p.use_item(ItemDB.get_item("rum"))
			until = TK.wait_secs(1.0)
		2:
			check("rum gives back stamina (%.0f)" % p.stamina, p.stamina >= 10.0 + 34.0)
			return TK.done(fails)
	step += 1
	return false

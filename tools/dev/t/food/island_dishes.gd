extends SceneTree
## Island dishes (1.28): each theme's staple (Food.STAPLES) is an item with an icon, every listed meal has its
## graded items; a dish named for an ingredient takes exactly that item (Jungle Pepperpot won't take plain
## peppercorns for the chili), a plain tag never eats the named one (Truffle Risotto: truffle + greens needs a
## second greens), "island" takes any staple (Feast of the Isles), and a quick cook takes the staple out.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var inv
var step := 0
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


func empty_bag() -> void:
	for st in inv.items.duplicate():
		inv.remove_item(st.item, st.quantity)


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	match step:
		0:
			p = stage.player
			inv = p.inventory_component
			var ok := true
			for theme in Food.STAPLES:
				var it := ItemDB.get_item(Food.STAPLES[theme]) as ItemData
				if it == null or it.icon == null or it.ingredient == "":
					ok = false
					print("  missing staple item/icon: ", Food.STAPLES[theme])
			check("every theme's staple is an ingredient item with an icon", ok)
			ok = true
			for id in Food.ORDER:
				if ItemDB.get_item(id) == null or ItemDB.get_item(id).icon == null or ItemDB.get_item(Food.graded(id, 3)) == null:
					ok = false
					print("  missing meal item/icon: ", id)
			check("every listed meal has its item, icon and graded copies", ok)
			var themes := {}
			for id in Food.MEALS:
				if Food.MEALS[id].has("theme"):
					themes[Food.MEALS[id]["theme"]] = int(themes.get(Food.MEALS[id]["theme"], 0)) + 1
			check("two dishes for each theme with a staple (%s)" % str(themes), themes.size() == Food.STAPLES.size() and themes.values().all(func(n): return n == 2))
			check("a named ingredient reads by its name", Food.recipe_text("jungle_pepperpot").contains("Fire Chili"))
			# pepperpot wants the chili itself
			empty_bag()
			give("pepper", 2)
			give("egg", 1)
			give("mushroom", 1)
			check("plain pepper doesn't stand in for the fire chili", Food.picks(inv, "jungle_pepperpot").is_empty())
			give("fire_chili", 1)
			var use := Food.picks(inv, "jungle_pepperpot")
			check("with a fire chili the pepperpot can be made", not use.is_empty())
			check("Quick cook makes it", Food.cook(p, "jungle_pepperpot", 1) == "" and inv.count("jungle_pepperpot") == 1)
			check("the chili's used up, the pepper kept", inv.count("fire_chili") == 0 and inv.count("pepper") == 2)
			# truffle + greens: the greens slot can't take the truffle the dish is named for
			empty_bag()
			give("black_truffle", 1)
			give("rice", 1)
			check("one truffle doesn't fill both the truffle and the greens", Food.picks(inv, "truffle_risotto").is_empty())
			give("mushroom", 1)
			use = Food.picks(inv, "truffle_risotto")
			var names := use.map(func(u): return (u[0] as ItemData).id)
			check("with a mushroom: truffle for the truffle, mushroom for the greens (%s)" % str(names), names.has("black_truffle") and names.has("mushroom"))
			empty_bag()
			give("black_truffle", 2)
			give("rice", 1)
			use = Food.picks(inv, "truffle_risotto")
			var truffles := 0
			for u in use:
				if (u[0] as ItemData).id == "black_truffle":
					truffles += int(u[1])
			check("two truffles: the second one serves as the greens", truffles == 2)
			# "island" takes any staple
			empty_bag()
			give("fire_chili", 1)
			give("ember_salt", 1)
			give("sea_grapes", 1)
			give("fish", 2)
			give("egg", 2)
			check("Food.have counts staples for 'island'", Food.have(inv, "island") == 3)
			check("three staples fill the feast's island ingredients", not Food.picks(inv, "isles_feast").is_empty())
			check("a feast can't be cooked off the ship", Food.can_cook(p, "harbour_feast", 1).contains("galley"))
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit(1 if fails else 0)
			step = 1
	return false

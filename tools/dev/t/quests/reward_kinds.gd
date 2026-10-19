extends SceneTree
## Quest rewards beyond gold and items: a recipe is taught to the captain present (gold instead once they know
## it); a charted place is lifted out of the fog and found for the crew; a discount the crew earned takes its cut
## off a shop's prices (and only that shop's). Never XP.
const TK := preload("res://tools/dev/test_kit.gd")
const SHOPS := preload("res://scripts/game/shops.gd")
var stage
var p
var j
var gm
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func entry(id: String, reward: Dictionary) -> Dictionary:
	return {"id": id, "title": id, "giver": "Kai", "isle": "Test Isle", "pos": Vector3.ZERO, "src": "npc", "goals": ["Tell Kai"], "step": 0,
		"done": false, "reward": reward, "cost": []}


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			j = root.get_node("Journal")
			j.reset()
			var inv = p.inventory_component
			var xp0: int = p.progression.xp
			p.progression.recipes.erase("captains_feast")
			for e in [entry("t_cook", {"gold": 10, "recipe": "captains_feast"}), entry("t_cook2", {"gold": 10, "recipe": "captains_feast"}),
					entry("t_chart", {"gold": 5, "chart": true}), entry("t_deal", {"gold": 5, "discount": ["t_shop", 0.2, "Test Goods"]})]:
				j.apply("take", [e])
			var g0: int = inv.count("gold")
			var here: Vector3 = p.global_position
			j.apply("done", ["t_cook", here, 1, []])
			var food = load("res://scripts/items/food.gd")
			check("a recipe reward teaches the captain present", food.known(p.progression, "captains_feast") and inv.count("gold") == g0 + 10)
			j.apply("done", ["t_cook2", here, 1, []])
			check("...known already: gold instead (%d)" % (inv.count("gold") - g0), inv.count("gold") == g0 + 20 + int(load("res://scripts/quests/quest_rewards.gd").MAP_GOLD))
			gm = root.get_node("GameManager")
			var cells := PackedInt32Array([5, 6, 7])
			j.apply("done", ["t_chart", here + Vector3(0, 0, 900), 1, ["isle77", "place3", "the sunken shrine", 30, cells]])
			check("a charted place is found for the crew, wherever they stand", gm.charted.has("spot:isle77:place3"))
			check("...and the fog round it lifted", gm.fog.has("isle77") and (gm.fog["isle77"] as PackedByteArray).size() == 900
				and gm.fog["isle77"][6] == 255 and gm.fog["isle77"][8] == 0)
			check("no XP from any of it", p.progression.xp == xp0)
			SHOPS.extra["t_shop"] = {"name": "Test Goods", "line": "Hm.", "trade": "grocer", "stock": [["rum", 1]], "buys": {}}
			SHOPS.extra["t_other"] = {"name": "Other Goods", "line": "Hm.", "trade": "grocer", "stock": [["rum", 1]], "buys": {}}
			j.apply("done", ["t_deal", here, 1, []])
			root.get_node("GameMenu").open_shop("t_shop")
			until = TK.wait_ticks(2)
		1:
			var menu = root.get_node("GameMenu")
			var scr = menu._shop
			var full: int = SHOPS.price_of(SHOPS.extra["t_shop"]["stock"][0])
			check("the crew's discount comes off the shop's price (%d of %d)" % [scr.price_at(0), full], scr.price_at(0) == roundi(full * 0.8) and scr.price_at(0) < full)
			var inv = p.inventory_component
			inv.add_item(ItemDB.get_item("gold"), 500)
			var g: int = inv.count("gold")
			scr.buy(SHOPS.extra["t_shop"]["stock"][0])
			check("...and that's what buying costs", inv.count("gold") == g - roundi(full * 0.8))
			menu.close()
			menu.open_shop("t_other")
			check("another shop: full price", menu._shop.price_at(0) == full)
			menu.close()
			return TK.done(fails)
	step += 1
	return false

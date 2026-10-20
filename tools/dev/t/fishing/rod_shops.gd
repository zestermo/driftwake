extends SceneTree
## Fishing rods: four tiers, each equipment-slot gear with an icon, priced on the economy's curve, every tier
## better than the one below (reach, bite time, reel window, rare odds). Marlo (Brinehollow's fish stall) always
## has the driftwood rod and some days the bamboo; a fisher artisan has a rod in their day's stock; the master's
## rod turns up only at treasure merchants (some days), never at a town grocer, cook, smith, tailor or armourer.
const TK := preload("res://tools/dev/test_kit.gd")
const SHOPS := preload("res://scripts/game/shops.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func ids_on(shop: String, day: int) -> Array:
	var out: Array = []
	for e in SHOPS.stock_on(shop, day):
		out.append(SHOPS.item_of(e).id)
	return out


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var ok := true
	var prices: Array = []
	for t in Rods.TIERS:
		var it: ItemData = ItemDB.get_item(Rods.item_id(t))
		ok = ok and it != null and it.is_gear() and it.gear_slot == "equipment" and Rods.tier_of(it) == t and it.icon != null
		prices.append(Economy.price(it))
	check("four rods, equipment-slot gear with icons", ok)
	check("priced on the curve, dearer by tier (%s)" % str(prices), prices[0] < prices[1] and prices[1] < prices[2] and prices[2] < prices[3])
	var better := true
	for i in range(1, Rods.TIERS.size()):
		var a: String = Rods.TIERS[i - 1]
		var b: String = Rods.TIERS[i]
		better = better and Rods.stat(b, "range") > Rods.stat(a, "range") and Rods.stat(b, "bite") < Rods.stat(a, "bite") \
			and Rods.stat(b, "window") > Rods.stat(a, "window") and Rods.stat(b, "rare") > Rods.stat(a, "rare")
	check("each tier casts farther, bites sooner, holds longer, finds rarer", better)
	ok = true
	var marlo_bamboo := 0
	var master_days := 0
	var town_master := 0
	for day in range(40):
		var m := ids_on("marlo", day)
		ok = ok and m.has("rod_driftwood")
		marlo_bamboo += 1 if m.has("rod_bamboo") else 0
		master_days += 1 if ids_on("nessa", day).has("rod_master") else 0
		for s in ["marlo", "ida", "haldor", "gus", "sela", "vey"]:
			town_master += 1 if ids_on(s, day).has("rod_master") else 0
	check("Marlo always has the driftwood rod", ok)
	check("...and the bamboo some days (%d of 40)" % marlo_bamboo, marlo_bamboo > 3 and marlo_bamboo < 40)
	check("a treasure merchant has a master's rod some days (%d of 40)" % master_days, master_days > 1 and master_days < 30)
	check("...and no town trader ever does", town_master == 0)
	SHOPS.extra["t_fisher"] = {"name": "t", "line": "", "trade": "artisan", "stock": [["fish"]], "pool": Rods.fisher_pool(), "size": 1, "buys": {}}
	var fisher := 0
	for day in range(20):
		for id in ids_on("t_fisher", day):
			fisher += 1 if str(id).begins_with("rod_") else 0
	SHOPS.extra.erase("t_fisher")
	check("a fisher's camp has a rod each day (%d over 20 days)" % fisher, fisher == 20)
	return TK.done(fails)

extends SceneTree
## One price curve: an item's worth and price go up x1.6 a tier, every trader's asking price is the curve's
## (Economy.price), every ship upgrade level is its line's base x1.6 a level, and nothing sells back for more
## than half what it costs. Prints the curve.
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


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var row := []
	var up := true
	for t in range(7):
		var it: ItemData = ItemDB.tiered("cutlass", t)
		row.append(Economy.price(it))
		if t > 0:
			var k: float = float(row[t]) / float(row[t - 1])
			up = up and k > 1.4 and k < 1.8
	print("   a cutlass by tier: %s" % str(row))
	check("a tier up costs ~x1.6 (%s)" % str(row), up)
	var on_curve := true
	var fair := true
	for id in SHOPS.SHOPS.keys():
		for e in SHOPS.SHOPS[id]["stock"]:
			var it: ItemData = SHOPS.item_of(e)
			on_curve = on_curve and SHOPS.price_of(e) == Economy.price(it)
			for sid in SHOPS.SHOPS.keys():
				fair = fair and SHOPS.offer(sid, it) * 2 <= SHOPS.price_of(e)
	check("every trader asks the curve's price", on_curve)
	check("nothing sells back for more than half its price", fair)
	var lines = load("res://scripts/ship/ship_lines.gd")
	var steps := true
	for id in lines.ORDER:
		for lv in range(1, lines.max_level(id)):
			var k: float = float(lines.price(id, lv)) / float(lines.price(id, lv - 1))
			steps = steps and k > 1.45 and k < 1.75
	check("each ship upgrade level costs ~x1.6 the one before", steps)
	print("   hull plating: %s" % str(range(lines.max_level("armour")).map(func(i): return lines.price("armour", i))))
	return TK.done(fails)

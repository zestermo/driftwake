extends SceneTree
## Specialist shops with a short rotating stock: a trader's stock is the same all day and turns over from one
## day to the next (its staples always there); smiths, armourers, tailors and grocers never sell blue and up,
## the treasure merchant always has something rare (a blue+ weapon with its trait); and what you sell can be
## bought back at what they paid, from the stall's buy-back row.
const TK := preload("res://tools/dev/test_kit.gd")
const SHOPS := preload("res://scripts/game/shops.gd")
var stage
var p
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


func ids(stock: Array) -> Array:
	return stock.map(func(e): return SHOPS.item_of(e).id)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			check("the same stock all day", ids(SHOPS.stock_on("haldor", 3)) == ids(SHOPS.stock_on("haldor", 3)))
			var turned := 0
			var staples := true
			for d in range(1, 9):
				var a := ids(SHOPS.stock_on("haldor", d))
				if a != ids(SHOPS.stock_on("haldor", d + 1)):
					turned += 1
				for e in SHOPS.shop("haldor")["stock"]:
					staples = staples and a.has(SHOPS.item_of(e).id)
			print("   haldor day 1: %s" % [ids(SHOPS.stock_on("haldor", 1))])
			print("   haldor day 2: %s" % [ids(SHOPS.stock_on("haldor", 2))])
			check("Haldor's rack turns over from day to day (%d of 8 days)" % turned, turned >= 5)
			check("...his staples always there", staples)
			var rare_in_trades: Array = []
			var nessa_rare := true
			var trait_ok := true
			for d in range(1, 11):
				for id in ["haldor", "vey", "sela", "ida", "marlo", "gus"]:
					for e in SHOPS.stock_on(id, d):
						if int(SHOPS.item_of(e).rarity) >= 2:
							rare_in_trades.append("%s:%s" % [id, SHOPS.item_of(e).id])
				var rares: Array = SHOPS.stock_on("nessa", d).map(func(e): return SHOPS.item_of(e)).filter(func(it): return int(it.rarity) >= 2)
				nessa_rare = nessa_rare and not rares.is_empty()
				for it in rares:
					trait_ok = trait_ok and (not it.is_weapon() or it.weapon_trait != "")
			check("smiths, tailors and grocers never sell blue and up %s" % [rare_in_trades], rare_in_trades.is_empty())
			check("the treasure merchant always has something rare", nessa_rare)
			check("...a rare weapon there carries its trait", trait_ok)
			var gm = root.get_node("GameMenu")
			gm.open_shop("haldor")
			until = TK.wait_ticks(2)
		1:
			var gm = root.get_node("GameMenu")
			var scr = gm._shop
			var inv = p.inventory_component
			var it: ItemData = ItemDB.get_item("cutlass@1")
			inv.add_item(it, 1)
			var g0: int = inv.count("gold")
			var each: int = SHOPS.offer("haldor", it)
			scr.sell(it, 1)
			check("sold to Haldor for %d" % each, inv.count("gold") == g0 + each and inv.count("cutlass@1") == 0)
			var back: Array = SHOPS.sold_back("haldor")
			check("it waits in his buy-back row at what he paid", back.size() == 1 and (back[0][0] as ItemData).id == "cutlass@1" and int(back[0][2]) == each)
			var i: int = scr.back_slot(0)
			scr._pick("shop", i)
			scr._act(false)
			check("bought back at that price", inv.count("cutlass@1") == 1 and inv.count("gold") == g0 and SHOPS.sold_back("haldor").is_empty())
			gm.close()
			return TK.done(fails)
	step += 1
	return false

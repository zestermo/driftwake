extends SceneTree
## (1.28.1, Zach) The gadget belt is an item: carrying one gives two gadget slots (tap O to switch) and wears its pouch on
## the back (none without it), bought for its price (Gadgets.buy_belt) and sold by chandlers.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var GD = load("res://scripts/gadgets/gadget_data.gd")
			var G = load("res://scripts/gadgets/gadgets.gd")
			var b = p.gadgets
			b.owned["smoke"] = {"tier": 0, "charges": 3, "cd": 0.0}
			b.owned["tar"] = {"tier": 0, "charges": 3, "cd": 0.0}
			b.fit()
			check("one gadget without a belt (%d)" % b.capacity(), b.capacity() == 1)
			check("...and no pouch on the back", p.body_model.torso.get_node_or_null("GadgetPouch") == null)
			var inv = p.inventory_component
			inv.add_item(ItemDB.get_item("gold"), 500)
			check("the belt bought (%s)" % G.buy_belt(p), inv.count(GD.BELT_ITEM) == 1 and inv.count("gold") == 500 - GD.BELT_PRICE)
			b.fit()
			check("a gadget belt carried: two slots (%s)" % str(b.slots), b.capacity() == 2 and b.slots.size() == 2 and "tar" in b.slots)
			var s0: String = b.gadget()
			b.cycle()
			check("tap O switches between them (%s -> %s)" % [s0, b.gadget()], b.gadget() != s0 and b.gadget() != "")
			check("the belt's pouch is worn on the back", p.body_model.torso.get_node_or_null("GadgetPouch") != null)
			check("chandlers sell the belt", load("res://scripts/island/harbour_vendor.gd").CHANDLER_STOCK.any(func(e): return e[0] == GD.BELT_ITEM))
			return TK.done(fails)
	return false

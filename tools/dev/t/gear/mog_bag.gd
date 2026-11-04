extends SceneTree
## (1.30) Transmog: a piece put in a cosmetic slot leaves the bag (no copies), only a piece of that slot's kind fits
## (any stats or level), swapping puts the old one back where the new one was, and taking it out returns it to the bag.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gear
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


func index_of(inv, it) -> int:
	for i in range(inv.items.size()):
		if inv.items[i].item == it:
			return i
	return -1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			gear = load("res://scripts/loot/gear.gd")
			var inv = p.inventory_component
			var eq = p.equipment
			var hat = gear.make("head", "tricorn", {"hat": "tricorn"}, "", 4)
			var cap = gear.make("head", "bandana", {"hat": "bandana"}, "", 0)
			var boots = gear.make("feet", "boots", {"feet": "boots"}, "", 0)
			inv.add_item(hat, 1)
			inv.add_item(cap, 1)
			inv.add_item(boots, 1)
			var n: int = inv.items.size()
			check("boots don't fit the head's cosmetic slot", not eq.mog_from_bag(inv, index_of(inv, boots), "head") and inv.items.size() == n)
			check("a high-tier hat goes in the head's cosmetic slot", eq.mog_from_bag(inv, index_of(inv, hat)) and eq.get_cosmetic("head") == hat)
			check("...and leaves the bag", index_of(inv, hat) == -1 and inv.items.size() == n - 1)
			var at := index_of(inv, cap)
			check("swapping in another hat", eq.mog_from_bag(inv, at, "head") and eq.get_cosmetic("head") == cap)
			check("...puts the first back where the second was", index_of(inv, hat) == at and index_of(inv, cap) == -1)
			check("taking it out returns it to the bag", eq.unmog_to_bag(inv, "head") and eq.get_cosmetic("head") == null and index_of(inv, cap) != -1)
			check("...with nothing left in the slot to take", not eq.unmog_to_bag(inv, "head"))
			check("the stats never saw it", not eq.slots.values().has(hat) and not eq.slots.values().has(cap))
			return TK.done(fails)
	step += 1
	return false

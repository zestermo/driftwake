extends SceneTree
## Hammers are found and sold: every design is an item (warhammer, kanabo, shipwright's mallet, iron maul, anchor
## hammer) with its model and icon; the loot pools, Haldor's forge and the treasure merchants' kinds carry them; a
## rolled one is mostly common designs with the anchor hammer rarer; a blue one rolls a trait hammers can have.
const TK := preload("res://tools/dev/test_kit.gd")
const DESIGNS := ["warhammer", "kanabo", "shipwrights_mallet", "maul", "anchor_hammer"]
var stage
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var WD = load("res://scripts/props/weapon_designs.gd")
	var ok := true
	for id in DESIGNS:
		var it = ItemDB.get_item(id)
		ok = ok and it != null and it.weapon_model == "hammer" and it.icon != null and Props.weapon_mesh(it.model()).get_meta("model", "") == it.model()
	check("every hammer design is an item with its model and icon", ok)
	check("the ids are the five designs %s" % str(WD.item_ids("hammer")), WD.item_ids("hammer").size() == 5 and DESIGNS.all(func(x): return x in WD.item_ids("hammer")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 5000:
		var id: String = WD.pick_id("hammer", rng)
		seen[id] = int(seen.get(id, 0)) + 1
	print("   rolled: %s" % str(seen))
	check("every design turns up", seen.size() == 5)
	check("the anchor hammer is the rarest (%d against the warhammer's %d)" % [seen["anchor_hammer"], seen["warhammer"]], seen["anchor_hammer"] * 2 < seen["warhammer"])
	check("in the islands' loot and the encounters' and the treasure merchants' kinds",
		"warhammer" in load("res://scripts/island/island_content.gd").LOOT_WEAPONS and "warhammer" in load("res://scripts/quests/island_encounters.gd").LOOT
		and "hammer" in load("res://scripts/game/shops.gd").RARE_KINDS)
	var forge: Array = load("res://scripts/game/shops.gd").SHOPS["haldor"]["pool"].map(func(e): return str(e[0]))
	check("Haldor's forge can stock them %s" % str(forge.filter(func(x): return x.get_slice("@", 0) in DESIGNS)), "warhammer" in forge and "kanabo" in forge)
	var blue = load("res://scripts/items/loot.gd").weapon("hammer", 2, rng)
	check("a blue hammer rolls a hammer trait (%s)" % blue.id, blue.weapon_model == "hammer" and blue.weapon_trait in WeaponTraits.pool("hammer"))
	return TK.done(fails)

extends SceneTree
## Polearms are found and sold: every design is an item (spear, trident, naginata, bisento, halberd, pitchfork) with
## its model and icon; the loot pools, Haldor's forge and the treasure merchants' kinds carry them; a rolled one is
## mostly common designs with the bisento rarer; a purple one rolls a trait (1.22: loot traits from purple up) polearms can have.
const TK := preload("res://tools/dev/test_kit.gd")
const DESIGNS := ["spear", "trident", "naginata", "bisento", "halberd", "pitchfork"]
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
		ok = ok and it != null and it.weapon_model == "polearm" and it.icon != null and Props.weapon_mesh(it.model()).get_meta("model", "") == it.model()
	check("every polearm design is an item with its model and icon", ok)
	check("the ids are the six designs %s" % str(WD.item_ids("polearm")), WD.item_ids("polearm").size() == 6 and DESIGNS.all(func(x): return x in WD.item_ids("polearm")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 6000:
		var id: String = WD.pick_id("polearm", rng)
		seen[id] = int(seen.get(id, 0)) + 1
	print("   rolled: %s" % str(seen))
	check("every design turns up", seen.size() == 6)
	check("the bisento is the rarest (%d against the spear's %d)" % [seen["bisento"], seen["spear"]], seen["bisento"] * 2 < seen["spear"])
	check("a cutlass rolls as it always did (one draw)", WD.pick_id("cutlass", rng) in WD.item_ids("cutlass"))
	check("in the islands' loot and the encounters' and the treasure merchants' kinds",
		"spear" in load("res://scripts/island/island_content.gd").LOOT_WEAPONS and "spear" in load("res://scripts/quests/island_encounters.gd").LOOT
		and "polearm" in load("res://scripts/game/shops.gd").RARE_KINDS)
	var forge: Array = load("res://scripts/game/shops.gd").SHOPS["haldor"]["pool"].map(func(e): return str(e[0]))
	check("Haldor's forge can stock them %s" % str(forge.filter(func(x): return x.get_slice("@", 0) in DESIGNS)), "spear" in forge and "trident" in forge)
	var blue = load("res://scripts/items/loot.gd").weapon("polearm", 3, rng)
	check("a purple polearm rolls a polearm trait (%s)" % blue.id, blue.weapon_model == "polearm" and blue.weapon_trait in WeaponTraits.pool("polearm"))
	return TK.done(fails)

extends SceneTree
## Cannons are rarer than the other kinds: every design is an item (hand cannon, swivel gun, carronade, dragon cannon,
## bombard) with its model and icon, the bombard the rarest roll; no island's pool lists them, but a boss's hoard
## sometimes turns its weapon into one (a plain chest far less often); Haldor's forge, the treasure merchants and the
## Shift+F10 rack carry them; a purple one rolls a trait cannons can have; the bag shows its range.
const TK := preload("res://tools/dev/test_kit.gd")
const DESIGNS := ["hand_cannon", "swivel_gun", "carronade", "dragon_cannon", "bombard"]
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## How many of `n` chests holding `gold` and a cutlass come out with a cannon in them.
func cannons(gold: int, n: int) -> int:
	var L = load("res://scripts/items/loot.gd")
	var found := 0
	for i in n:
		var g := ItemStack.new()
		g.item = ItemDB.get_item("gold")
		g.quantity = gold
		var w := ItemStack.new()
		w.item = ItemDB.get_item("cutlass")
		w.quantity = 1
		var contents: Array[ItemStack] = [g, w]
		for st in L.chest(contents, "cn_test_%d_%d" % [gold, i], false):
			if st.item.weapon_model == "cannon":
				found += 1
	return found


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var WD = load("res://scripts/props/weapon_designs.gd")
	var ok := true
	for id in DESIGNS:
		var it = ItemDB.get_item(id)
		ok = ok and it != null and it.weapon_model == "cannon" and it.icon != null and Props.weapon_mesh(it.model()).get_meta("model", "") == it.model()
	check("every cannon design is an item with its model and icon", ok)
	check("the ids are the five designs %s" % str(WD.item_ids("cannon")), WD.item_ids("cannon").size() == 5 and DESIGNS.all(func(x): return x in WD.item_ids("cannon")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 5000:
		var id: String = WD.pick_id("cannon", rng)
		seen[id] = int(seen.get(id, 0)) + 1
	print("   rolled: %s" % str(seen))
	check("every design turns up, the bombard the rarest", seen.size() == 5 and seen["bombard"] * 2 < seen["hand_cannon"])
	check("no island's pool lists them", not ("hand_cannon" in load("res://scripts/island/island_content.gd").LOOT_WEAPONS)
		and not ("hand_cannon" in load("res://scripts/quests/island_encounters.gd").LOOT))
	var hoard := cannons(60, 300)
	var plain := cannons(10, 300)
	print("   cannons: %d of 300 hoards, %d of 300 plain chests" % [hoard, plain])
	check("a boss's hoard turns its weapon into a cannon now and then (%d / 300)" % hoard, hoard > 20 and hoard < 110)
	check("a plain chest far less often (%d / 300)" % plain, plain > 0 and plain * 3 < hoard)
	var shops = load("res://scripts/game/shops.gd")
	check("the treasure merchants' kinds carry them", "cannon" in shops.RARE_KINDS)
	var forge: Array = shops.SHOPS["haldor"]["pool"].map(func(e): return str(e[0]))
	check("Haldor's forge can stock them %s" % str(forge.filter(func(x): return x.get_slice("@", 0) in DESIGNS)), "hand_cannon" in forge and "carronade@1" in forge)
	check("the Shift+F10 rack has them", load("res://scenes/player/player.gd").DEBUG_RACK.has("cannon"))
	var purple = load("res://scripts/items/loot.gd").weapon("cannon", 3, rng)
	check("a purple cannon rolls a cannon trait (%s)" % purple.id, purple.weapon_model == "cannon" and purple.weapon_trait in WeaponTraits.pool("cannon"))
	var ws: Dictionary = load("res://scripts/ui/inventory_screen.gd").weapon_stats(ItemDB.get_item("hand_cannon"))
	check("the bag shows it as a gun with its range (%s)" % str(ws), ws["gun"] and float(ws["range"]) >= 50.0 and float(ws["damage"]) > 40.0)
	return TK.done(fails)

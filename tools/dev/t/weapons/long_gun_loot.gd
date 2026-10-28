extends SceneTree
## Long guns are found and sold like cutlasses: every design is an item (sea musket, long rifle, blunderbuss, boarding
## carbine, double fowler, jezail, musketoon) with its model and icon; the jezail is the rarest roll; the islands' chest pools and
## the encounters' loot list the musket (and a chest's long gun never becomes a greatsword, though now and then a
## cannon); Haldor's forge, the treasure
## merchants and the Shift+F10 rack carry them; a purple one rolls a trait long guns can have; the bag shows its range.
const TK := preload("res://tools/dev/test_kit.gd")
const DESIGNS := ["musket", "long_rifle", "blunderbuss", "boarding_carbine", "fowling_piece", "jezail", "musketoon"]
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
		ok = ok and it != null and it.weapon_model == "longgun" and it.icon != null and Props.weapon_mesh(it.model()).get_meta("model", "") == it.model()
	check("every long gun design is an item with its model and icon", ok)
	check("the ids are the seven designs %s" % str(WD.item_ids("longgun")), WD.item_ids("longgun").size() == 7 and DESIGNS.all(func(x): return x in WD.item_ids("longgun")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 6000:
		var id: String = WD.pick_id("longgun", rng)
		seen[id] = int(seen.get(id, 0)) + 1
	print("   rolled: %s" % str(seen))
	check("every design turns up, the jezail the rarest (%d against the musket's %d)" % [seen.get("jezail", 0), seen.get("musket", 0)],
		seen.size() == 7 and seen["jezail"] * 2 < seen["musket"])
	check("the islands' chests and the encounters list the musket", "musket" in load("res://scripts/island/island_content.gd").LOOT_WEAPONS
		and "musket" in load("res://scripts/quests/island_encounters.gd").LOOT)
	var found := 0
	var other := 0
	for i in 300:
		var g := ItemStack.new()
		g.item = ItemDB.get_item("gold")
		g.quantity = 60
		var w := ItemStack.new()
		w.item = ItemDB.get_item("musket")
		w.quantity = 1
		var contents: Array[ItemStack] = [g, w]
		for st in load("res://scripts/items/loot.gd").chest(contents, "lg_test_%d" % i, false):
			if st.item.is_weapon():
				if st.item.weapon_model == "longgun":
					found += 1
				elif st.item.weapon_model != "cannon":
					other += 1
	check("a hoard's long gun stays a long gun, or now and then a cannon, never a blade (%d of 300, %d turned)" % [found, other], found > 200 and other == 0)
	var shops = load("res://scripts/game/shops.gd")
	check("the treasure merchants' kinds carry them", "longgun" in shops.RARE_KINDS)
	var forge: Array = shops.SHOPS["haldor"]["pool"].map(func(e): return str(e[0]))
	check("Haldor's forge can stock them %s" % str(forge.filter(func(x): return x.get_slice("@", 0) in DESIGNS)), "musket" in forge and "blunderbuss" in forge and "long_rifle@1" in forge)
	check("the Shift+F10 rack has them", load("res://scenes/player/player.gd").DEBUG_RACK.has("longgun"))
	var purple = load("res://scripts/items/loot.gd").weapon("longgun", 3, rng)
	check("a purple long gun rolls a long gun trait (%s)" % purple.id, purple.weapon_model == "longgun" and purple.weapon_trait in WeaponTraits.pool("longgun"))
	var ws: Dictionary = load("res://scripts/ui/inventory_screen.gd").weapon_stats(ItemDB.get_item("long_rifle"))
	check("the bag shows a long rifle as a gun with its range (%s)" % str(ws), ws["gun"] and float(ws["range"]) > 80.0 and float(ws["damage"]) > 30.0)
	return TK.done(fails)

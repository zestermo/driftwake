extends SceneTree
## Slingshots are found and sold like cutlasses: every design is an item (slingshot, bone, vine, iron, beetle) with its
## model and icon, the beetle the rarest; the islands' chest pools and the encounters' loot list it (and a chest's
## slingshot never becomes a greatsword); Haldor's forge, the treasure merchants and the Shift+F10 rack carry them; a
## purple one rolls a trait slingshots can have; the bag shows its range.
const TK := preload("res://tools/dev/test_kit.gd")
const DESIGNS := ["slingshot", "bone_slingshot", "vine_slingshot", "iron_slingshot", "beetle_slingshot"]
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
	var WD = load("res://scripts/props/weapon_designs.gd")
	var ok := true
	for id in DESIGNS:
		var it = ItemDB.get_item(id)
		ok = ok and it != null and it.weapon_model == "slingshot" and it.icon != null and Props.weapon_mesh(it.model()).get_meta("model", "") == it.model()
	check("every slingshot design is an item with its model and icon", ok)
	check("the ids are the five designs %s" % str(WD.item_ids("slingshot")), WD.item_ids("slingshot").size() == 5 and DESIGNS.all(func(x): return x in WD.item_ids("slingshot")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 5000:
		var id: String = WD.pick_id("slingshot", rng)
		seen[id] = int(seen.get(id, 0)) + 1
	print("   rolled: %s" % str(seen))
	check("every design turns up, the beetle the rarest", seen.size() == 5 and seen["beetle_slingshot"] * 2 < seen["slingshot"])
	check("the islands' chests and the encounters list it", "slingshot" in load("res://scripts/island/island_content.gd").LOOT_WEAPONS
		and "slingshot" in load("res://scripts/quests/island_encounters.gd").LOOT)
	var other := 0
	for i in 200:
		var g := ItemStack.new()
		g.item = ItemDB.get_item("gold")
		g.quantity = 60
		var w := ItemStack.new()
		w.item = ItemDB.get_item("slingshot")
		w.quantity = 1
		var contents: Array[ItemStack] = [g, w]
		for st in load("res://scripts/items/loot.gd").chest(contents, "sl_test_%d" % i, false):
			if st.item.is_weapon() and st.item.weapon_model not in ["slingshot", "cannon"]:
				other += 1
	check("a hoard's slingshot never turns into a blade (%d)" % other, other == 0)
	var shops = load("res://scripts/game/shops.gd")
	check("the treasure merchants' kinds carry them", "slingshot" in shops.RARE_KINDS)
	var forge: Array = shops.SHOPS["haldor"]["pool"].map(func(e): return str(e[0]))
	check("Haldor's forge can stock them", "slingshot" in forge and "iron_slingshot@1" in forge)
	check("the Shift+F10 rack has them", load("res://scenes/player/player.gd").DEBUG_RACK.has("slingshot"))
	var purple = load("res://scripts/items/loot.gd").weapon("slingshot", 3, rng)
	check("a purple slingshot rolls a slingshot trait (%s)" % purple.id, purple.weapon_model == "slingshot" and purple.weapon_trait in WeaponTraits.pool("slingshot"))
	var ws: Dictionary = load("res://scripts/ui/inventory_screen.gd").weapon_stats(ItemDB.get_item("vine_slingshot"))
	check("the bag shows it as a quick gun with its range (%s)" % str(ws), ws["gun"] and float(ws["range"]) >= 30.0 and float(ws["rate"]) > 2.5)
	return TK.done(fails)

extends SceneTree
## Greatswords are found and sold, rarer than the other kinds: every design is an item (greatsword, black greatblade,
## claymore, sawtooth greatblade, greatcleaver, Sea King's Fang) with its model and icon; the Fang is the rarest roll;
## no island's pool lists them, but a chest that keeps a blade sometimes turns it into one (a boss's hoard about a
## third of the time, a plain chest far less often); Haldor's forge, the treasure merchants and the Shift+F10 rack
## carry them; a blue one rolls a trait greatswords can have.
const TK := preload("res://tools/dev/test_kit.gd")
const DESIGNS := ["greatsword", "black_greatblade", "claymore", "sawtooth_greatblade", "greatcleaver", "sea_kings_fang"]
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


## How many of `n` chests holding `gold` and a cutlass come out with a greatsword in them.
func greats(gold: int, n: int) -> int:
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
		for st in L.chest(contents, "gs_test_%d_%d" % [gold, i], false):
			if st.item.weapon_model == "greatsword":
				found += 1
	return found


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var WD = load("res://scripts/props/weapon_designs.gd")
	var ok := true
	for id in DESIGNS:
		var it = ItemDB.get_item(id)
		ok = ok and it != null and it.weapon_model == "greatsword" and it.icon != null and Props.weapon_mesh(it.model()).get_meta("model", "") == it.model()
	check("every greatsword design is an item with its model and icon", ok)
	check("the ids are the six designs %s" % str(WD.item_ids("greatsword")), WD.item_ids("greatsword").size() == 6 and DESIGNS.all(func(x): return x in WD.item_ids("greatsword")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 6000:
		var id: String = WD.pick_id("greatsword", rng)
		seen[id] = int(seen.get(id, 0)) + 1
	print("   rolled: %s" % str(seen))
	check("every design turns up", seen.size() == 6)
	check("the Sea King's Fang is the rarest (%d against the greatsword's %d)" % [seen["sea_kings_fang"], seen["greatsword"]], seen["sea_kings_fang"] * 2 < seen["greatsword"])
	check("no island's pool lists them", not ("greatsword" in load("res://scripts/island/island_content.gd").LOOT_WEAPONS)
		and not ("greatsword" in load("res://scripts/quests/island_encounters.gd").LOOT))
	var hoard := greats(60, 300)
	var plain := greats(10, 300)
	print("   greatswords: %d of 300 hoards, %d of 300 plain chests" % [hoard, plain])
	check("a boss's hoard turns its blade into a greatsword about a third of the time (%d / 300)" % hoard, hoard > 50 and hoard < 140)
	check("a plain chest far less often (%d / 300)" % plain, plain > 0 and plain * 3 < hoard)
	check("the treasure merchants' kinds carry them", "greatsword" in load("res://scripts/game/shops.gd").RARE_KINDS)
	var forge: Array = load("res://scripts/game/shops.gd").SHOPS["haldor"]["pool"].map(func(e): return str(e[0]))
	check("Haldor's forge can stock them %s" % str(forge.filter(func(x): return x.get_slice("@", 0) in DESIGNS)), "greatsword" in forge and "claymore@1" in forge)
	check("the Shift+F10 rack has them", load("res://scenes/player/player.gd").DEBUG_RACK.has("greatsword"))
	var blue = load("res://scripts/items/loot.gd").weapon("greatsword", 2, rng)
	check("a blue greatsword rolls a greatsword trait (%s)" % blue.id, blue.weapon_model == "greatsword" and blue.weapon_trait in WeaponTraits.pool("greatsword"))
	return TK.done(fails)

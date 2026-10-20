extends SceneTree
## The fish table: every catch is an item the galley takes as fish, the rarer worth more; what bites depends on the
## water (a marlin only in deep water, a flounder only off the shore), the coast (parrotfish off jungle islands)
## and the hour (moonfish by night, bream by day); the roll is the same on the same seed; the rod, the bait and Sea
## Lore bring rarer fish, Master Angler's odds more legendaries; a landed legendary teaches Sea Legend's Platter,
## and a catch's Fishing mastery grows with its rarity.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func rolls(ids: Array, rare: float, legend: float, n: int, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out: Array = []
	for i in range(n):
		out.append(FishTable.roll(ids, rare, legend, rng))
	return out


func share(got: Array, min_rarity: int) -> float:
	var k := 0
	for id in got:
		k += 1 if FishTable.rarity_of(id) >= min_rarity else 0
	return float(k) / got.size()


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var p = stage.player
	var ok := true
	var worth := [0.0, 0.0, 0.0, 0.0, 0.0]
	var n := [0, 0, 0, 0, 0]
	for id in FishTable.CATCHES.keys():
		var it: ItemData = ItemDB.get_item(id)
		ok = ok and it != null and it.ingredient == "fish" and it.icon != null
		if it and str(FishTable.CATCHES[id][0]) != "":
			ok = ok and int(it.rarity) == FishTable.rarity_of(id)
			worth[int(it.rarity)] += it.worth()
			n[int(it.rarity)] += 1
	check("every catch is an item the galley takes as fish, with an icon and its rarity", ok)
	var avg: Array = []
	for r in range(5):
		avg.append(snappedf(worth[r] / maxi(n[r], 1), 0.1))
	check("rarer fish are worth more (%s)" % str(avg), avg[0] < avg[1] and avg[1] < avg[2] and avg[2] < avg[3] and avg[3] < avg[4])
	var shore := FishTable.pool("shore", "", false)
	var deep := FishTable.pool("deep", "", false)
	check("a king marlin bites only in deep water, a flounder only off the shore", deep.has("fish_king_marlin") and not shore.has("fish_king_marlin")
		and shore.has("fish_flounder") and not deep.has("fish_flounder"))
	check("parrotfish only off a jungle coast", FishTable.pool("shore", "jungle", false).has("fish_parrotfish") and not shore.has("fish_parrotfish"))
	check("moonfish by night, bream by day", FishTable.pool("sea", "", true).has("fish_moonfish") and not FishTable.pool("sea", "", false).has("fish_moonfish")
		and shore.has("fish_bream") and not FishTable.pool("shore", "", true).has("fish_bream"))
	var sea := FishTable.pool("sea", "", false)
	check("the same seed lands the same fish", rolls(sea, 1.0, 1.0, 30, 77) == rolls(sea, 1.0, 1.0, 30, 77) and rolls(sea, 1.0, 1.0, 30, 77) != rolls(sea, 1.0, 1.0, 30, 78))
	var plain := share(rolls(deep, 1.0, 1.0, 3000, 5), 2)
	var fine := share(rolls(deep, Rods.stat("master", "rare") * Bait.rare_k("bait_glow", true), 1.0, 3000, 5), 2)
	check("a master's rod and glow bait by night bring rarer fish (%.2f -> %.2f rare or better)" % [plain, fine], fine > plain * 1.5)
	var leg0 := share(rolls(deep, 1.5, 1.0, 6000, 9), 4)
	var leg1 := share(rolls(deep, 1.5, 2.0, 6000, 9), 4)
	check("Master Angler's odds: more legendaries (%.3f -> %.3f)" % [leg0, leg1], leg1 > leg0 * 1.5)
	var pr = p.progression
	var inv = p.inventory_component
	check("a rare fish counts as fish in the galley", _galley_takes(inv))
	var F = load("res://scripts/fishing/fishing.gd")
	var xp0 := fish_xp(pr)
	F.land(p, "fish_sardine")
	var xp1 := fish_xp(pr)
	F.land(p, "fish_king_marlin")
	var xp2 := fish_xp(pr)
	check("Fishing mastery grows with rarity (%d for a sardine, %d for a marlin)" % [xp1 - xp0, xp2 - xp1], xp2 - xp1 > (xp1 - xp0) * 4)
	check("a landed legendary teaches Sea Legend's Platter", Food.known(pr, FishTable.LEGEND_RECIPE) and inv.count("fish_king_marlin") >= 1)
	return TK.done(fails)


func _galley_takes(inv) -> bool:
	var before: int = Food.have(inv, "fish")
	inv.add_item(ItemDB.get_item("fish_tuna"), 1)
	return Food.have(inv, "fish") == before + 1


func fish_xp(pr) -> int:
	var m: Dictionary = pr.mastery_of("fish")
	var total := int(m["xp"])
	for lv in range(1, int(m["lv"])):
		total += pr.mastery_to_next(lv)
	return total

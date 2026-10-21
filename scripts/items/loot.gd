class_name Loot
extends RefCounted
## The economy's loot rolls (v1.18): scarce, and every captain's own.
## - Kills: each captain's machine rolls its own coins (kill_gold, from the creature's table) and its
##   own drops (roll_drops, Net.kill_loot), so a crew never fights over a drop.
## - Chests (LootBag with a save id, plunder afloat): what the island or the ship put in is the most
##   it can hold; the first time a captain opens one it's rolled for them (chest), seeded by the chest
##   and the captain, so a reload can't reroll it and a crewmate's copy rolls differently. Gold and
##   treasure thin out, supplies half, a generic weapon stays now and then (a boss's hoard always),
##   rerolled to a design of the same kind and, from blue up, given a named trait (WeaponTraits).
##   Uniques, Devil Fruits, gear and salvage stay as they are, and so do the weapons in Brinehollow's
##   own hand-placed chests (part of its story's pacing).
## Numbers tuned in play.

const KILL_GOLD_K := 0.45
const CHEST_GOLD_K := 0.45
const TREASURE_KEEP := 0.35
const SUPPLY_KEEP := 0.5
const ARMS_KEEP := 0.3
## A chest put in with at least this much gold is a boss's hoard: its weapons always stay.
const HOARD_GOLD := 55


## The local captain's name: what makes a chest's roll theirs.
static func captain() -> String:
	var p := (Engine.get_main_loop() as SceneTree).get_first_node_in_group("player")
	return str(p.get("appearance").get("name", "Captain")) if p else "Captain"


static func rng_for(key: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%s" % [key, captain()])
	return r


## A roll from `rng`, or the global one (kills: each machine's own, seeded by the tests).
static func _f(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng else randf()


## x as a whole number, the fraction as the chance of one more.
static func _whole(x: float, rng: RandomNumberGenerator) -> int:
	var n := int(floor(x))
	return n + (1 if _f(rng) < x - n else 0)


static func _keep(n: int, k: float, rng: RandomNumberGenerator) -> int:
	var out := 0
	for i in range(n):
		if _f(rng) < k:
			out += 1
	return out


## A kill's coins for this captain (`count`: what the creature's table rolled, before the economy);
## a kill that has coins always gives at least one.
static func kill_gold(count: int) -> int:
	if count <= 0:
		return 0
	return maxi(_whole(count * KILL_GOLD_K * lerpf(0.6, 1.4, randf()), null), 1)


## A kill's drops for this captain: table [[item id, chance, count], ...] -> [[item ref, count], ...].
static func roll_drops(table: Array) -> Array:
	var out: Array = []
	for d in table:
		if randf() < float(d[1]):
			out.append([SaveGame.item_ref(ItemDB.get_item(str(d[0]))), int(d[2])])
	return out


## A weapon generic enough to roll: a design anyone might find (not a unique).
static func generic(it: ItemData) -> bool:
	if not it.is_weapon() or not WeaponDesigns.BASE_ITEM.has(it.weapon_model):
		return false
	var base := it.id.get_slice("+", 0).get_slice("@", 0)
	return base in WeaponDesigns.item_ids(it.weapon_model)


## A weapon of `kind` at `tier` (a random design), with a trait from blue up.
static func weapon(kind: String, tier: int, rng: RandomNumberGenerator) -> ItemData:
	var it := ItemDB.tiered(WeaponDesigns.pick_id(kind, rng), tier)
	if tier >= WeaponTraits.MIN_TIER:
		it = ItemDB.with_trait(it.id.get_slice("+", 0), WeaponTraits.roll(kind, rng))
	return it


## A chest's contents rolled for this captain (see the header). `placed`: a hand-placed chest of the
## home island, whose weapons stay.
static func chest(contents: Array[ItemStack], key: String, placed: bool) -> Array[ItemStack]:
	var rng := rng_for(key)
	var hoard := false
	for st in contents:
		if st.item.id == "gold" and st.quantity >= HOARD_GOLD:
			hoard = true
	var out: Array[ItemStack] = []
	for st in contents:
		var it := st.item
		var n := st.quantity
		if it.id == "gold":
			n = maxi(_whole(n * CHEST_GOLD_K * rng.randf_range(0.7, 1.3), rng), 1)
		elif it.is_loot() and it.id.begins_with("treasure"):
			n = maxi(_keep(n, TREASURE_KEEP, rng), 1 if hoard else 0)
		elif it.is_consumable() and it.devil_fruit == "":
			n = _keep(n, SUPPLY_KEEP, rng)
		elif generic(it) and not placed:
			if hoard or rng.randf() < ARMS_KEEP:
				it = weapon(it.weapon_model, int(it.rarity), rng)
				# (tomahawks and reavers' axes are carried in pairs: found two at a time, ready for both hands)
				if WeaponDesigns.comes_paired(it.id.get_slice("+", 0).get_slice("@", 0)):
					n = 2
			else:
				n = 0
		if n > 0:
			var ns := ItemStack.new()
			ns.item = it
			ns.quantity = n
			out.append(ns)
	if out.is_empty():
		var g := ItemStack.new()
		g.item = ItemDB.get_item("gold")
		g.quantity = rng.randi_range(1, 3)
		out.append(g)
	return out

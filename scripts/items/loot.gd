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
## (1.22) how many kills that carry coins pay any
const KILL_COIN_CHANCE := 0.6
## (1.22) a trophy part's drop chance against its creature's table
const PART_K := 0.3
const CHEST_GOLD_K := 0.45
const TREASURE_KEEP := 0.35
const SUPPLY_KEEP := 0.5
const ARMS_KEEP := 0.3
## 1.22's loot (Zach's tables, docs/v1_22_plan.md): a chest's weapon (from its island's own pool, at the island's tier)
## stays this often by kind of chest, its rarity rolled round the island's tier ([-1, 0, +1, +2] weights), clamped
## 1-4, and purple or gold only where the island's tier is 3 or more. Traits only from purple up in loot (vendors keep
## their own). Brinehollow's hand-placed chests: a random pistol, cutlass, dagger or axe (a hatchet among its designs), green or (HOME_BLUE) blue.
const ARMS_BY_KIND := {"ordinary": 0.25, "hidden": 0.5, "hoard": 1.0}
const RARITY_SPREAD := {"ordinary": [0.35, 0.5, 0.13, 0.02], "hidden": [0.0, 0.6, 0.35, 0.05], "hoard": [0.0, 0.7, 0.27, 0.03]}
const HIDDEN_KEYS := ["dive", "buried", "map", "wreck", "treasure"]
const HOME_KINDS := ["pistol", "cutlass", "dagger", "axe"]
const HOME_BLUE := 0.15
const LOOT_TRAIT_TIER := 3
## A chest put in with at least this much gold is a boss's hoard: its weapons always stay.
const HOARD_GOLD := 55
## Greatswords are rarer than the other kinds and in no island's pool: a blade weapon a chest keeps is one this
## often (a boss's hoard more often). Drawn from the chest's own second stream, so the rest of its roll is unchanged.
const GREAT_CHANCE := 0.1
const GREAT_HOARD := 0.3


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


## A kill's coins for this captain (`count`: what the creature's table rolled, before the economy): 60% of kills
## that carry coins pay (1.22), at least one.
static func kill_gold(count: int) -> int:
	if count <= 0 or randf() >= KILL_COIN_CHANCE:
		return 0
	return maxi(_whole(count * KILL_GOLD_K * lerpf(0.6, 1.4, randf()), null), 1)


## A kill's drops for this captain: table [[item id, chance, count], ...] -> [[item ref, count], ...].
static func roll_drops(table: Array) -> Array:
	var out: Array = []
	for d in table:
		var it := ItemDB.get_item(str(d[0]))
		# (1.22: a trophy part, tusk or plume or hide, a third as often as the table says: ~15% for a 0.5 part;
		# food from hunting as it was, the galley needs it)
		var k := PART_K if it and it.is_loot() else 1.0
		if randf() < float(d[1]) * k:
			out.append([SaveGame.item_ref(ItemDB.get_item(str(d[0]))), int(d[2])])
	return out


## A weapon generic enough to roll: a design anyone might find (not a unique).
static func generic(it: ItemData) -> bool:
	if not it.is_weapon() or not WeaponDesigns.BASE_ITEM.has(it.weapon_model):
		return false
	var base := it.id.get_slice("+", 0).get_slice("@", 0)
	return base in WeaponDesigns.item_ids(it.weapon_model)


## A weapon of `kind` at `tier` (a random design), with a trait from purple up (1.22).
static func weapon(kind: String, tier: int, rng: RandomNumberGenerator) -> ItemData:
	var it := ItemDB.tiered(WeaponDesigns.pick_id(kind, rng), tier)
	if tier >= maxi(WeaponTraits.MIN_TIER, LOOT_TRAIT_TIER):
		it = ItemDB.with_trait(it.id.get_slice("+", 0), WeaponTraits.roll(kind, rng))
	return it


## A rarity round the island's `tier` (a chest's weapon is put in at it) for a kind of chest: RARITY_SPREAD's
## [-1, 0, +1, +2] weights, clamped 1-4, purple and up only where the tier is 3+.
static func rarity_round(tier: int, kind_of_chest: String, rng: RandomNumberGenerator) -> int:
	var w: Array = RARITY_SPREAD[kind_of_chest]
	var x := rng.randf()
	var off := 2
	for i in range(4):
		x -= float(w[i])
		if x < 0.0:
			off = i - 1
			break
	var r := clampi(tier + off, 1, 4)
	if tier < 3:
		return mini(r, 2)
	# (1.23 bounty heat's small upside: +0.5% purple a bounty tier, on islands that can have it)
	if r == 2 and rng.randf() < BOUNTY_PURPLE * _bounty_tier():
		r = 3
	return r


## The local captain's bounty tier (Bounty), for the chests' small upside (1.23: a counterweight, not a reward).
const BOUNTY_GOLD := 0.02
const BOUNTY_PURPLE := 0.005


static func _bounty_tier() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var p := tree.get_first_node_in_group("player") if tree else null
	return Bounty.tier_of(int(p.get("bounty"))) if p and p.get("bounty") != null else 0


## A chest's contents rolled for this captain (see the header). `placed`: a hand-placed chest of the
## home island, whose weapons stay.
static func chest(contents: Array[ItemStack], key: String, placed: bool) -> Array[ItemStack]:
	var rng := rng_for(key)
	var hoard := key.contains("hoard")
	for st in contents:
		if st.item.id == "gold" and st.quantity >= HOARD_GOLD:
			hoard = true
	var kind_of_chest := "hoard" if hoard else ("hidden" if HIDDEN_KEYS.any(func(k): return key.contains(k)) else "ordinary")
	var arms_rng := rng_for(key + "|arms")
	var out: Array[ItemStack] = []
	for st in contents:
		var it := st.item
		var n := st.quantity
		if it.id == "gold":
			n = maxi(_whole(n * CHEST_GOLD_K * rng.randf_range(0.7, 1.3) * (1.0 + BOUNTY_GOLD * _bounty_tier()), rng), 1)
		elif it.is_loot() and it.id.begins_with("treasure"):
			n = maxi(_keep(n, TREASURE_KEEP, rng), 1 if hoard else 0)
		elif it.is_consumable() and it.devil_fruit == "":
			n = _keep(n, SUPPLY_KEEP, rng)
		elif generic(it) and placed:
			# (Brinehollow's own chests: always a weapon, part of its story's pacing, but no two captains' the same)
			it = weapon(HOME_KINDS[arms_rng.randi() % HOME_KINDS.size()], 2 if arms_rng.randf() < HOME_BLUE else 1, arms_rng)
		elif generic(it):
			if arms_rng.randf() < float(ARMS_BY_KIND[kind_of_chest]):
				var kind := it.weapon_model
				if kind not in ["pistol", "longgun"] and rng_for(key + "|great").randf() < (GREAT_HOARD if hoard else GREAT_CHANCE):
					kind = "greatsword"
				it = weapon(kind, rarity_round(int(it.rarity), kind_of_chest, arms_rng), rng)
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

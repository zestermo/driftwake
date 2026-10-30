class_name FruitPool
extends RefCounted
## The Driftfruits' world pool (1.27, docs/v1_27_raids_fruits_plan.md "Decided"): each fruit exists once per save.
## A source (a chest, a boss's hoard, a merchant, a stronghold's vault) draws a free fruit of its tier; drawing it
## reserves it ("fruit:<id>", a world flag, everyone's); an enemy user beaten or a fruit lost frees it again (`release`),
## and it turns up elsewhere. Tiers and sell prices by the ten (the plan's roster); only fruits the game has (an item)
## are ever drawn.

const TIERS := {"bubble": "joke", "wolf": "solid", "bear": "solid", "vine": "solid", "iron": "solid", "clockwork": "solid",
	"echo": "solid", "ember": "legendary", "storm": "legendary", "gust": "legendary"}
const SELL := {"joke": 15000, "solid": 60000, "legendary": 200000}


static func _gm(tree: SceneTree) -> Node:
	return tree.root.get_node_or_null("/root/GameManager")


static func taken(tree: SceneTree, id: String) -> bool:
	var gm := _gm(tree)
	return gm != null and gm.world_flags.has("fruit:" + id)


## The fruits of `tier` the game has that are free in this save.
static func free_of(tree: SceneTree, tier: String) -> Array:
	return TIERS.keys().filter(func(id): return TIERS[id] == tier and DevilFruits.FRUITS.has(id) and not taken(tree, id))


## Draw a free fruit of `tier` (reserved for everyone), or "" if none is free.
static func draw(tree: SceneTree, tier: String, rng: RandomNumberGenerator) -> String:
	var ids := free_of(tree, tier)
	if ids.is_empty():
		return ""
	ids.sort()
	var id: String = ids[rng.randi() % ids.size()]
	tree.root.get_node("/root/Net").world_flag("fruit:" + id)
	return id


## A fruit back in the pool (its enemy user beaten, or lost): the host clears its flag for everyone.
static func release(tree: SceneTree, id: String) -> void:
	var gm := _gm(tree)
	if gm:
		gm.world_flags.erase("fruit:" + id)


static func sell_price(id: String) -> int:
	return int(SELL.get(str(TIERS.get(id, "solid")), 60000))

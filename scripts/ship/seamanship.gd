class_name Seamanship
extends RefCounted
## Each captain's Seamanship: the "sea" mastery tree (SkillTree._build_seamanship), saved with the
## captain like weapon mastery (a guest's is their own). Mastery is earned on the captain's own machine
## by sailing at the helm, hitting ships with her guns, repairs and pumping, and ships sunk near them.
## The tree's bonuses are station bonuses (read here): each counts only while you man that station,
## and half again more (Bosun) while a crewmate mans another one.

## Metres sailed at the helm for a point of mastery xp.
const SAIL_M := 25.0
const GUN_HIT := 8
const PATCH := 12
const BAIL := 1
const CAPSTAN := 3
## A ship sunk within SUNK_REACH of you, by kind.
const SUNK := {"gunboat": 30, "sloop": 40, "marine": 50, "brig": 60}
const SUNK_REACH := 250.0


static func me(tree: SceneTree) -> Player:
	return tree.get_first_node_in_group("player") as Player


static func xp(tree: SceneTree, n: int) -> void:
	var p := me(tree)
	if p:
		p.progression.add_mastery("sea", n)


static func stat(tree: SceneTree, key: String) -> float:
	var p := me(tree)
	return p.progression.stat(key) if p else 0.0


## A station's bonus for our captain manning it (`ship`: the crew's ship, for who else is at a station).
static func station(tree: SceneTree, key: String, ship: Ship) -> float:
	var v := stat(tree, key)
	return v * crew_k(tree, ship) if v != 0.0 else 0.0


## Half again (Bosun) while a crewmate mans another station: the helm, or one of her guns.
static func crew_k(tree: SceneTree, ship: Ship) -> float:
	var c := stat(tree, "crew")
	if c <= 0.0 or not Net.coop():
		return 1.0
	if ship and ship.helm_other:
		return 1.0 + c
	for k in Net.seats.keys():
		if int(Net.seats[k]) != Net.my_id() and Net.node_of(str(k)) is ShipCannon:
			return 1.0 + c
	return 1.0


## The helmsman's bonuses on her sailing: [top speed x, turning x, share of flooding's slowdown].
static func helm_k(tree: SceneTree, ship: Ship) -> Vector3:
	return Vector3(1.0 + station(tree, "helm_speed", ship), 1.0 + station(tree, "helm_turn", ship), 1.0 - minf(station(tree, "helm_flood", ship), 0.9))

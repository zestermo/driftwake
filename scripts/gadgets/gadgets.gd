class_name Gadgets
extends RefCounted
## Gadgets (1.28, docs/v1_28_plan.md "Gadgets and tinkering"): the belt's gadgets, their blueprints, parts and tiers.
## CONTRACT (lead, 2026-10-31): the gadgets agent owns this file and fills it. Other features only call the members
## below (the forge town's master tinkerer, books, the merchant ship, loot):
##   Gadgets.teach(player, blueprint_id) -> bool   a captain learns a blueprint (false: already known / no such one)
##   Gadgets.blueprint_ids() -> Array              every blueprint id (for shops, books and loot tables)
##   Gadgets.part_ids() -> Array                   every part item id (salvage, ore, beast parts: for loot tables)


static func teach(_player: Node, _blueprint_id: String) -> bool:
	return false


static func blueprint_ids() -> Array:
	return []


static func part_ids() -> Array:
	return []

class_name Gadgets
extends RefCounted
## Gadgets (1.28, docs/v1_28_plan.md "Gadgets and tinkering", numbers in GadgetData / docs/gadgets_plan.md): the
## belt's gadgets, their blueprints, parts and tiers.
## CONTRACT (lead, 2026-10-31): other features only call the members below (the forge town's master tinkerer,
## books, the merchant ship, loot):
##   Gadgets.teach(player, blueprint_id) -> bool   a captain learns a blueprint (false: already known / no such one)
##   Gadgets.blueprint_ids() -> Array              every blueprint id (for shops, books and loot tables)
##   Gadgets.part_ids() -> Array                   every part item id (salvage, ore, beast parts: for loot tables)


static func teach(player: Node, blueprint_id: String) -> bool:
	if not blueprint_id in blueprint_ids():
		return false
	var belt = player.gadgets
	if belt.known.has(blueprint_id):
		return false
	belt.known[blueprint_id] = true
	belt.changed.emit()
	player.call("_toast", "Blueprint learned: %s" % GadgetData.GADGETS[gadget_of(blueprint_id)]["name"])
	return true


static func blueprint_ids() -> Array:
	return GadgetData.GADGETS.keys().map(func(g): return "bp_" + str(g))


static func part_ids() -> Array:
	return []


static func gadget_of(blueprint_id: String) -> String:
	return blueprint_id.trim_prefix("bp_")

class_name QuestRewards
extends RefCounted
## What a quest pays (1.26: XP too, XP_SHARE of a level each). A reward is data:
## {"gold": n, "xp": k (XP_SHARE times k; an island's arc: 4), "items": [[item id, n]], "reveal": true (a treasure map: an X on the sea chart),
##  "chart": true (a place on the island the crew hasn't found, put on the held map: Journal picks it),
##  "recipe": meal id (Food.teach), "discount": [shop id, fraction, shop name], "favour": {"who": name, "gift": [[item id, n]]}}.
## Gold, items, the treasure map and the recipe go to every captain in the crew, wherever they are (1.22; each on their
## own machine); the charted place, a discount and a favour are the crew's (Journal.perks, MapFog).

## Gold instead of a map once every treasure's map is in hand (or a recipe already known).
const MAP_GOLD := 30
## (1.26, docs/v1_26_plan.md "XP in co-op": quests are worth XP now) Each captain's share: this much of their own
## next level, to every captain in the crew wherever they are.
const XP_SHARE := 0.25


static func text(r: Dictionary) -> String:
	var out: Array = []
	if int(r.get("gold", 0)) > 0:
		out.append("%d gold" % int(r["gold"]))
	for e in r.get("items", []):
		out.append(_item_text(e))
	if r.get("reveal", false):
		out.append("a treasure map")
	if r.get("chart", false):
		out.append("a hidden place marked on your map")
	if r.has("recipe"):
		out.append("the %s recipe" % str(Food.MEALS[r["recipe"]]["name"]))
	if r.has("discount"):
		out.append("%d%% off at %s" % [roundi(float(r["discount"][1]) * 100.0), str(r["discount"][2])])
	if r.has("favour"):
		out.append("a favour from %s" % str(r["favour"]["who"]))
	out.append("a great deal of experience" if float(r.get("xp", 1.0)) > 1.0 else "experience")
	return ", ".join(out)


static func _item_text(e: Array) -> String:
	var it := ItemDB.get_item(str(e[0]))
	return "%s x%d" % [it.display_name, int(e[1])] if int(e[1]) > 1 else it.display_name


## The captain's own share: gold, items and the map into `p`'s bag and chart. Returns what they got, as text.
static func give(r: Dictionary, p: Player) -> String:
	var inv := p.inventory_component
	var got: Array = []
	var gold := int(r.get("gold", 0))
	if r.get("reveal", false):
		var t := _unmapped(p)
		if t >= 0:
			p.get_node("/root/GameManager").maps[t] = true
			got.append("a treasure map (on your sea chart)")
		else:
			gold += MAP_GOLD
	if r.has("recipe"):
		if Food.teach(p.progression, str(r["recipe"])):
			got.append("the %s recipe (cook it in the galley)" % str(Food.MEALS[r["recipe"]]["name"]))
		else:
			gold += MAP_GOLD
	if gold > 0:
		inv.add_item(ItemDB.get_item("gold"), gold)
		got.push_front("%d gold" % gold)
	for e in r.get("items", []):
		inv.add_item(ItemDB.get_item(str(e[0])), int(e[1]))
		got.append(_item_text(e))
	var xp := roundi(xp_for(p) * float(r.get("xp", 1.0)))
	if xp > 0:
		p.progression.add_xp(xp)
		got.append("%d XP" % xp)
	return ", ".join(got)


## A quest's XP for captain `p`: XP_SHARE of their next level.
static func xp_for(p: Player) -> int:
	if p == null or p.progression == null:
		return 0
	return roundi(float(p.progression.get_script().xp_to_next(int(p.progression.level))) * XP_SHARE)


## Items handed over at a turn-in (a fetch quest's), out of `p`'s bag; false if they're short.
static func pay(cost: Array, p: Player) -> bool:
	if not can_pay(cost, p):
		return false
	for e in cost:
		p.inventory_component.remove_item(ItemDB.get_item(str(e[0])), int(e[1]))
	return true


static func can_pay(cost: Array, p: Player) -> bool:
	return cost.all(func(e): return p.inventory_component.count(str(e[0])) >= int(e[1]))


## The first sea treasure whose map this captain doesn't hold and hasn't dug (-1: none left).
static func _unmapped(p: Player) -> int:
	var sf := p.get_tree().get_first_node_in_group("sea_features")
	var gm := p.get_node("/root/GameManager")
	if sf == null:
		return -1
	for t in range((sf.get("treasures") as Array).size()):
		if not gm.maps.has(t) and not gm.opened.has("treasure_%d" % t):
			return t
	return -1

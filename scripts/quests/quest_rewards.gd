class_name QuestRewards
extends RefCounted
## What a quest pays (never XP: that comes from fighting and discovering). A reward is data:
## {"gold": n, "items": [[item id, n]], "reveal": true (a treasure map: an X on the sea chart),
##  "discount": [shop id, fraction, shop name], "favour": {"who": name, "gift": [[item id, n]]}}.
## Gold, items and the map go to every captain present at the turn-in (each on their own machine);
## a discount and a favour are the crew's (Journal.perks).

## Gold instead of a map once every treasure's map is in hand.
const MAP_GOLD := 30


static func text(r: Dictionary) -> String:
	var out: Array = []
	if int(r.get("gold", 0)) > 0:
		out.append("%d gold" % int(r["gold"]))
	for e in r.get("items", []):
		out.append(_item_text(e))
	if r.get("reveal", false):
		out.append("a treasure map")
	if r.has("discount"):
		out.append("%d%% off at %s" % [roundi(float(r["discount"][1]) * 100.0), str(r["discount"][2])])
	if r.has("favour"):
		out.append("a favour from %s" % str(r["favour"]["who"]))
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
	if gold > 0:
		inv.add_item(ItemDB.get_item("gold"), gold)
		got.push_front("%d gold" % gold)
	for e in r.get("items", []):
		inv.add_item(ItemDB.get_item(str(e[0])), int(e[1]))
		got.append(_item_text(e))
	return ", ".join(got)


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

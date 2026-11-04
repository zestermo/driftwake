extends "res://tools/dev/t/fauna/_creature_case.gd"
## Mushroom crawlers (fauna/shroom_crawler.gd, 1.30): in the forest's pool; it sits still as a mushroom, wakes and
## creeps at a captain near it, swells its cap (its tell) and bursts spores round it, poisoning; dies dropping
## mushrooms; sleeps far.

var poisoned := false


func case() -> Dictionary:
	return {"theme": "forest", "kind": "shroom_crawler", "at": Vector3(0, 0, -4.0),
		"watch": func(_c): poisoned = poisoned or p.get_node_or_null("Poison") != null}


func _process(d: float) -> bool:
	if step == 3 and not TK.ticking(until):
		check("...its spores poison", poisoned)
	return super._process(d)

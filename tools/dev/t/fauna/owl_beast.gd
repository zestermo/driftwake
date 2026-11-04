extends "res://tools/dev/t/fauna/_creature_case.gd"
## Owl-beasts (fauna/owl_beast.gd, 1.30): in the forest's pool; at night it sees a captain from far off and comes,
## rears up with its wings wide (its tell) and drops on them with both talons; dies dropping plumes; sleeps far.


func case() -> Dictionary:
	return {"theme": "forest", "kind": "owl_beast", "at": Vector3(0, 0, -12.0), "night": true}

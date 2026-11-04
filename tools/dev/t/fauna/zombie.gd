extends "res://tools/dev/t/fauna/_creature_case.gd"
## The fog graveyard's zombies (fauna/zombie.gd, 1.30): not in the island's pool (the graveyard's own); one standing
## by a captain claws up out of its grave, winds up (arms raised) and rakes or grabs; dies dropping grave rags; sleeps far.


func case() -> Dictionary:
	return {"theme": "fog", "kind": "zombie", "pool": false, "at": Vector3(0, 0, -5.0), "secs": 16.0}

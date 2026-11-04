extends "res://tools/dev/t/fauna/_creature_case.gd"
## Grave moths (fauna/grave_moth.gd, 1.30): in the fog isle's pool; up and round a captain after dark; it hangs and
## flares its wings (its tell), dives and dusts; dies; sleeps far.


func case() -> Dictionary:
	return {"theme": "fog", "kind": "grave_moth", "at": Vector3(0, 0, -5.0), "night": true}

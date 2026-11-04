extends "res://tools/dev/t/fauna/_creature_case.gd"
## Pale stalkers (fauna/pale_stalker.gd, 1.30): in the fog isle's pool; faded while it stalks (drawn on a broken duty),
## solid as it rears up (its tell) and lunges; dies dropping ivory; sleeps far.

var faded_seen := false


func case() -> Dictionary:
	return {"theme": "fog", "kind": "pale_stalker", "at": Vector3(0, 0, -9.0), "secs": 16.0,
		"watch": func(c): faded_seen = faded_seen or (c.state == S.CHASE and c.anim_a < 0.3)}


func _process(d: float) -> bool:
	if step == 3 and not TK.ticking(until):
		check("...faded while it stalks", faded_seen)
	return super._process(d)

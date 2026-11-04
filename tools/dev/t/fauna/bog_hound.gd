extends "res://tools/dev/t/fauna/_creature_case.gd"
## Bog hounds (fauna/bog_hound.gd, 1.30): packs in the fog isle's pool; the wolves' crouch (its tell) then the lunge
## and bite; dies dropping hide or fish; sleeps far.


func case() -> Dictionary:
	return {"theme": "fog", "kind": "bog_hound", "args": {"lead": true, "pack": 77}, "at": Vector3(0, 0, -7.0)}

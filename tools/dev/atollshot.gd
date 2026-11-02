extends "res://tools/dev/genshot.gd"
## A coral atoll's own shots, on top of genshot's (the shots named in GSHOT_ONLY, default the aerial and these): its
## lagoon from a wader on a sandbar, a shoal of fish seen from above through the water, the stilt town from over the
## lagoon, the causeway out to the boss's flat, the blue hole from above, the reef's wreck and the pearl bed.
## Args as genshot's (an atoll: chain seed 1, id 2).
## `& $env:GODOT --path . --script res://tools/dev/atollshot.gd -- <out_prefix> 1 2`


func _setup(island) -> void:
	if OS.get_environment("GSHOT_ONLY") == "":
		OS.set_environment("GSHOT_ONLY", "aerial,boss,beast,atoll_stilts,atoll_wreck,atoll_pearls,wade,shoal,town,causeway,hole")
	super._setup(island)
	var lp: Dictionary = isl.land_plan
	var v: Vector2 = isl.sites["village"]
	var b: Vector2 = isl.sites["boss"]
	var cw: Array = lp["causeway"]
	var mid: Vector2 = (cw[0] as Vector2).lerp(cw[1], 0.3)
	var side: Vector2 = ((cw[1] as Vector2) - (cw[0] as Vector2)).normalized().orthogonal()
	shots.append(["wade", "wading the causeway out over the lagoon", Vector3(mid.x, 1.5, mid.y), Vector3(b.x, 0.5, b.y), false, 0.0])
	shots.append(["causeway", "the causeway out to the boss's flat", _g(mid + side * 30.0, 14.0), _g((cw[0] as Vector2).lerp(cw[1], 0.6), 0.0), false, 0.0])
	var sh: Node3D = isl.get_node("AtollShoals").get_child(0)
	var sp := Vector2(sh.position.x, sh.position.z)
	shots.append(["shoal", "a shoal over the lagoon floor, from above", Vector3(sp.x + 3.0, 3.5, sp.y + 3.0), Vector3(sp.x, sh.position.y, sp.y), false, 0.0])
	var hole: Array = lp["hole"]
	var hc: Vector2 = hole[0]
	shots.append(["hole", "the blue hole from above", Vector3(hc.x + 30.0, 32.0, hc.y + 30.0), Vector3(hc.x, -4.0, hc.y), false, 0.0])
	var town: Array = isl.places.filter(func(pl): return pl["kind"] == "atoll_stilts")
	if not town.is_empty():
		var ta: Vector2 = town[0]["at"]
		var tf: Vector2 = town[0]["face"]
		shots.append(["town", "the stilt town from over the lagoon", Vector3(ta.x - tf.x * 40.0 + tf.y * 25.0, 12.0, ta.y - tf.y * 40.0 - tf.x * 25.0), Vector3(ta.x, 1.5, ta.y), false, 0.0])
	var only := OS.get_environment("GSHOT_ONLY")
	shots = shots.filter(func(e): return e[0] in only.split(","))
	_aim()

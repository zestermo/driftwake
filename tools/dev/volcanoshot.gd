extends "res://tools/dev/genshot.gd"
## A volcanic island's eruption (volcanic_eruptions.gd), on top of genshot's: the shots named in GSHOT_ONLY (default
## none) then "eruption": the next eruption set off, the camera over its bombs' sector, the frame taken as the first
## bombs' red circles fill the ground and the bombs come down. Args as genshot's (a volcanic node: chain seed 2, id 6).
## `& $env:GODOT --path . --script res://tools/dev/volcanoshot.gd -- <out_prefix> 2 6`


func _setup(island) -> void:
	if OS.get_environment("GSHOT_ONLY") == "":
		OS.set_environment("GSHOT_ONLY", "aerial")
	super._setup(island)
	var er = isl.get_node("VolcanicEruptions")
	var pl: Array = er.plan(er.n)
	var mid: Vector2 = pl[0]
	var cc: Vector2 = isl.land_plan["cone"]["c"]
	var back := (mid - cc).normalized()
	shots.append(["eruption", "an eruption's lava bombs coming down", _g(mid + back * 20.0 + back.orthogonal() * 6.0, 13.0), _g(mid, 0.0), false, 0.0])


func _aim() -> void:
	super._aim()
	if shots[idx][0] == "eruption":
		var er = isl.get_node("VolcanicEruptions")
		var pl: Array = er.plan(er.n)
		var first := INF
		for b in pl[1]:
			first = minf(first, float(b[0]))
		# (an eruption plays only near a captain: ours stands at the sector's edge)
		var mid: Vector2 = pl[0]
		var cc: Vector2 = isl.land_plan["cone"]["c"]
		var at: Vector2 = mid + (mid - cc).normalized() * (er.SPREAD + 12.0)
		var p := get_first_node_in_group("player") as Node3D
		p.global_position = isl.to_global(Vector3(at.x, isl.hv(at) + 1.0, at.y))
		p.reset_physics_interpolation()
		er.erupt_now()
		# (frames until the first bombs' circles are half filled and the next ones fall)
		settle = -int((first - 0.25) * Engine.physics_ticks_per_second)

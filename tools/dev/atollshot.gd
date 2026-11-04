extends "res://tools/dev/genshot.gd"
## A coral atoll's own shots, on top of genshot's (the shots named in GSHOT_ONLY, default the aerial and these): its
## lagoon from a wader on a sandbar, a shoal of fish seen from above through the water, the stilt town from over the
## lagoon, the causeway out to the boss's flat, the blue hole from above, the reef's wreck and the pearl bed.
## Args as genshot's (an atoll: chain seed 1, id 2).
## `& $env:GODOT --path . --script res://tools/dev/atollshot.gd -- <out_prefix> 1 2`


func _setup(island) -> void:
	if OS.get_environment("GSHOT_ONLY") == "":
		OS.set_environment("GSHOT_ONLY", "aerial,boss,beast,atoll_stilts,atoll_wreck,atoll_pearls,wade,shoal,town,causeway,hole,reef_head,reef_clam,reef_arch,reef_moray,floor,basin_surface,basin_wall,basin_deep,basin_pillar,basin_cave,basin_vent")
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
	# (1.30) the seabed: a diver's view along the lagoon floor, and the sandbar's flank where the sand meets the floor
	var fq := sp + Vector2(9.0, 4.0)
	var bed: Node3D = isl.get_node_or_null("AtollSeabed")
	if bed:
		var most: MultiMeshInstance3D = null
		for m in bed.get_children():
			if m.name.begins_with("Grass") and (most == null or (m as MultiMeshInstance3D).multimesh.instance_count > most.multimesh.instance_count):
				most = m
		var g := most.position + most.multimesh.get_instance_transform(0).origin
		sp = Vector2(g.x, g.z)
		fq = sp + Vector2(7.0, 3.0)
	shots.append(["floor", "a diver over a seagrass meadow", Vector3(fq.x, isl.hv(fq) + 1.4, fq.y), Vector3(sp.x, isl.hv(sp) + 0.3, sp.y), false, 0.0])
	var cq: Vector2 = (cw[0] as Vector2).lerp(cw[1], 0.45) + side * 9.0
	shots.append(["flank", "under the water by the causeway's flank", Vector3(cq.x, -1.6, cq.y), Vector3(mid.x, -1.0, mid.y), false, 0.0])
	var dd := Vector2.from_angle((isl.sites["dock"] as Vector2).angle() + 1.3)
	var rr := float(isl.radius) + 120.0
	while rr > 50.0 and isl.hv(dd * rr) < -8.0:
		rr -= 2.0
	shots.append(["drop", "the reef's drop-off outside the ring, from the deep", Vector3(dd.x * (rr + 26.0), -12.0, dd.y * (rr + 26.0)), Vector3(dd.x * rr, -7.0, dd.y * rr), false, 0.0])
	var hole: Array = lp["hole"]
	var hc: Vector2 = hole[0]
	var hr: float = hole[1]
	shots.append(["hole", "the deep basin from above", Vector3(hc.x + hr * 0.9, 45.0, hc.y + hr * 0.9), Vector3(hc.x, -6.0, hc.y), false, 0.0])
	# (1.30) the deep basin: from a swimmer at the surface over its lip, and under the water
	var hd := Vector2(1, 0).rotated(0.7)
	shots.append(["basin_surface", "looking down into the basin from the surface", Vector3(hc.x + hd.x * hr * 1.1, 1.2, hc.y + hd.y * hr * 1.1), Vector3(hc.x + hd.x * hr * 0.4, -18.0, hc.y + hd.y * hr * 0.4), false, 0.0])
	var bn: Node3D = isl.get_node_or_null("AtollBasin")
	if bn:
		var ly: float = float(lp["hole"][2])
		shots.append(["basin_wall", "the basin's reef wall from inside, over the ledge", Vector3(hc.x + hd.x * hr * 0.55, -9.0, hc.y + hd.y * hr * 0.55), Vector3(hc.x + hd.x * hr * 1.0, -7.0, hc.y + hd.y * hr * 1.0), false, 0.0])
		shots.append(["basin_deep", "the basin's floor and its pillars from mid-water", Vector3(hc.x + hd.x * hr * 0.6, ly + 12.0, hc.y + hd.y * hr * 0.6), Vector3(hc.x, ly + 5.0, hc.y), false, 0.0])
		var pil: Array = bn.get_meta("pillars")
		if not pil.is_empty():
			var pq: Vector2 = pil[0]
			shots.append(["basin_pillar", "a coral pillar from the basin's floor", Vector3(pq.x + 11.0, isl.hv(pq) + 3.0, pq.y + 7.0), Vector3(pq.x, isl.hv(pq) + 9.0, pq.y), false, 0.0])
		var caves: Array = bn.get_meta("caves")
		if not caves.is_empty():
			var kq: Vector2 = caves[0]
			var ct := (kq - hc).normalized().orthogonal()
			shots.append(["basin_cave", "a swim-through cave", Vector3(kq.x + ct.x * 13.0, isl.hv(kq) + 2.2, kq.y + ct.y * 13.0), Vector3(kq.x, isl.hv(kq) + 1.6, kq.y), false, 0.0])
		var vents: Array = bn.get_meta("vents")
		if not vents.is_empty():
			var vq: Vector2 = vents[0]
			shots.append(["basin_vent", "a breathing vent's bubbles", Vector3(vq.x + 6.0, isl.hv(vq) + 3.0, vq.y + 4.0), Vector3(vq.x, isl.hv(vq) + 4.0, vq.y), false, 0.0])
	var town: Array = isl.places.filter(func(pl): return pl["kind"] == "atoll_stilts")
	if not town.is_empty():
		var ta: Vector2 = town[0]["at"]
		var tf: Vector2 = town[0]["face"]
		shots.append(["town", "the stilt town from over the lagoon", Vector3(ta.x - tf.x * 40.0 + tf.y * 25.0, 12.0, ta.y - tf.y * 40.0 - tf.x * 25.0), Vector3(ta.x, 1.5, ta.y), false, 0.0])
	# (1.28.1) under the water: a coral head and its outcrop, a giant clam, the reef wall outside the ring
	var reef: Node3D = isl.get_node_or_null("AtollReef")
	if reef:
		for e in [["reef_head", "Spar_", "a coral head under the water, an outcrop to break a spar from"], ["reef_clam", "Clam_", "a giant clam on the lagoon floor"], ["reef_arch", "Arch", "a swim-through arch of coral rock"], ["reef_moray", "Moray", "a moray's crevice"]]:
			var found: Array = reef.get_children().filter(func(m): return m.name.begins_with(e[1]))
			if not found.is_empty():
				var at: Vector3 = (found[0] as Node3D).position
				shots.append([e[0], e[2], at + Vector3(3.2, 0.9, 2.4), at + Vector3(0, 0.5, 0), false, 0.0])
	var only := OS.get_environment("GSHOT_ONLY")
	shots = shots.filter(func(e): return e[0] in only.split(","))
	# (the aerial last: the island's last build steps, its clear lagoon among them, are still running at the first shot)
	shots = shots.filter(func(e): return e[0] != "aerial") + shots.filter(func(e): return e[0] == "aerial")
	_aim()

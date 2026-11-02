class_name AtollSpots
extends RefCounted
## The coral atoll's fishing spots and spear-diving grounds, for the fishing system to hook into (the atoll is meant to
## be the chain's best fishing): each a Marker3D in group "fishing_spots" (line fishing from where you stand) or
## "spear_spots" (dive and spear: its marker on the bottom), under the island's "AtollSpots" node, with metadata
## "kind" (the group's word: "line" or "spear"), "where" (pier, pass, hole, dropoff, heads, flat), "theme" ("atoll"),
## "depth" (m of water there) and "r" (the ground it covers, m). list(isl) is the same as data, island space.
## The stilt town's platforms add theirs (AtollTown) under its own node, in the same groups.

const D := preload("res://scripts/island/themes/atoll_data.gd")
const L := preload("res://scripts/island/themes/atoll_land.gd")
## Coral heads looked for on this grid (m), and kept this far apart.
const HEAD_GRID := 12.0
const HEAD_GAP := 34.0
const HEADS_MAX := 8


## Every spot on the island but the town's: [{"at": Vector3 (island space; y the water's surface for line spots, the
## bottom for spear spots), "kind", "where", "depth", "r"}].
static func list(isl) -> Array:
	var lp: Dictionary = isl.land_plan
	var out: Array = []
	# the passes: the sea runs in and out through them, and the fish with it (from the islets either side)
	for pa in lp["passes"]:
		if L.pass_at(isl, lp, float(pa)) <= 0.0:
			continue
		for u in [0.15, 0.85]:
			var q := L.ring_point(isl, float(pa), u)
			out.append(_spot(isl, q, "line", "pass", 8.0))
	# the blue hole: its rim to fish from, its floor to dive
	if lp.has("hole"):
		var hole: Array = lp["hole"]
		var c: Vector2 = hole[0]
		out.append(_spot(isl, c, "line", "hole", float(hole[1])))
		out.append(_spot(isl, c, "spear", "hole", float(hole[1]) * 0.6))
	# coral heads in the lagoon: the spear-divers' ground
	var heads: Array = []
	var reach: float = isl.radius
	var gx := -reach
	while gx < reach and heads.size() < HEADS_MAX:
		var gz := -reach
		while gz < reach and heads.size() < HEADS_MAX:
			var q := Vector2(gx, gz)
			gz += HEAD_GRID
			var h: float = isl.hv(q)
			if h > -0.4 or h < -2.0 or not L.on_head(lp, q) or isl._coast_t(q) > -float(lp["w"]) - D.LAGOON_EDGE:
				continue
			if heads.any(func(o): return (o as Vector2).distance_to(q) < HEAD_GAP) or isl.sites["boss"].distance_to(q) < 50.0:
				continue
			heads.append(q)
		gx += HEAD_GRID
	for q in heads:
		out.append(_spot(isl, q, "spear", "heads", 7.0))
	# the reef's drop-off outside the ring, off the islets either side of the dock (deep-water fish)
	var da: float = (isl.sites["dock"] as Vector2).angle()
	for off in [1.2, -1.6, PI]:
		var a: float = da + float(off)
		var r0: float = L.ring_r(isl, a)[0]
		out.append(_spot(isl, Vector2.from_angle(a) * (r0 + D.REEF_FLAT + 4.0), "line", "dropoff", 10.0))
	# the boss's flat's edge, where the tide pools are (once it's beaten it's the quietest water on the atoll)
	var b: Vector2 = isl.sites["boss"]
	out.append(_spot(isl, b + (b - (isl.sites["village"] as Vector2)).normalized() * 40.0, "line", "flat", 8.0))
	return out


static func _spot(isl, q: Vector2, kind: String, where: String, r: float) -> Dictionary:
	var h: float = isl.hv(q)
	var y := 0.0 if kind == "line" else h
	return {"at": Vector3(q.x, y, q.y), "kind": kind, "where": where, "depth": maxf(-h, 0.0), "r": r}


## The markers (a build step: GenIsland.finish_steps through AtollTheme.steps).
static func build(isl) -> void:
	var node := Node3D.new()
	node.name = "AtollSpots"
	isl.add_child(node)
	var i := 0
	for s in list(isl):
		add_marker(node, s, i)
		i += 1


## One spot's marker under `parent` (its "at" in the parent's space).
static func add_marker(parent: Node3D, s: Dictionary, i: int) -> Marker3D:
	var m := Marker3D.new()
	m.name = "%s%d" % ["FishSpot" if s["kind"] == "line" else "SpearSpot", i]
	m.position = s["at"]
	for k in ["kind", "where", "depth", "r"]:
		m.set_meta(k, s[k])
	m.set_meta("theme", "atoll")
	m.add_to_group("fishing_spots" if s["kind"] == "line" else "spear_spots")
	parent.add_child(m)
	return m

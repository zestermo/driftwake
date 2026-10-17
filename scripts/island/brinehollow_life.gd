extends RefCounted
## Brinehollow's town life (2026-10-17, docs/brinehollow_polish_plan.md step 3), built at the end of
## StarterIsland.build (its LIFE hook) from `town_spots`: the townsfolk on routines (BrinehollowCast.townsfolk,
## made in that order with fixed names; where each is follows Weather.hour, so a guest's town matches the
## host's with no messages). They walk the town's walk graph (Town: the paths, a ring round the plaza, the long
## stair, the upper lanes) between spots resolved by id (_spot: shop and stall counters and fronts, the plaza
## and its benches, the Salted Gull's bar, seats and fire, the upper town's doors, the quay, the stair).

const Folk := preload("res://scripts/island/brinehollow_folk.gd")
const RING_R := 9.5
const JOIN := 3.2


static func build(isl: StarterIsland) -> void:
	var life := Node3D.new()
	life.name = "TownLife"
	isl.add_child(life)
	var town := Town.new(isl)
	isl.kit.timed("life people", func(): _people(isl, town))


# --------------------------------------------------------------------------
# The walk graph and the town's floors
# --------------------------------------------------------------------------
class Town:
	extends RefCounted
	var isl: StarterIsland
	var graph := AStar2D.new()
	var stair: PackedVector3Array
	## [island -> local Transform3D, half extents Vector2, floor y]
	var floors: Array = []
	var ring_ids: Array = []

	func _init(island: StarterIsland) -> void:
		isl = island
		stair = isl.town_spots["stair"]
		var lines: Array = isl.paths.duplicate()
		lines.append_array(isl.town_spots["lanes"])
		var ring := PackedVector2Array()
		for k in range(25):
			ring.append(StarterIsland.VILLAGE + Vector2.from_angle(TAU * k / 24.0) * RING_R)
		var flat := PackedVector2Array()
		for q in stair:
			flat.append(Vector2(q.x, q.z))
		lines.append(flat)
		var grid := {}
		var owner := {}
		for li in range(lines.size()):
			var pts := _dense(lines[li])
			var prev := -1
			for q in pts:
				var id := graph.get_point_count()
				graph.add_point(id, q)
				owner[id] = li
				var cell := Vector2i(floori(q.x / JOIN), floori(q.y / JOIN))
				if not grid.has(cell):
					grid[cell] = []
				grid[cell].append(id)
				if prev >= 0:
					graph.connect_points(prev, id)
				prev = id
		var ring_first := graph.get_point_count()
		for k in range(ring.size()):
			var id := ring_first + k
			graph.add_point(id, ring[k])
			ring_ids.append(id)
			if k > 0:
				graph.connect_points(id - 1, id)
		# lines that touch: points of different lines within JOIN of each other
		for cell in grid:
			for id in grid[cell]:
				var q := graph.get_point_position(id)
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						for o in grid.get(cell + Vector2i(dx, dz), []):
							if o > id and owner[o] != owner[id] and graph.get_point_position(o).distance_to(q) < JOIN:
								graph.connect_points(id, o)
		# the ends that come into the plaza (and the stair's foot) onto the ring
		for li in range(lines.size()):
			var pl: PackedVector2Array = lines[li]
			for q in [pl[0], pl[pl.size() - 1]]:
				if q.distance_to(StarterIsland.VILLAGE) < 20.0:
					graph.connect_points(_nearest(q, owner, li), _ring_near(q))
		var tav: Node3D = isl._tavern
		floors.append([tav.transform.affine_inverse(), Vector2(5.8, 4.3), isl.kit.marker_y(tav, "Barkeep")])

	func _dense(pl: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array([pl[0]])
		for i in range(1, pl.size()):
			var n := maxi(int(ceil(pl[i - 1].distance_to(pl[i]) / 2.5)), 1)
			for k in range(1, n + 1):
				out.append(pl[i - 1].lerp(pl[i], float(k) / n))
		return out

	func _nearest(q: Vector2, owner: Dictionary, li: int) -> int:
		var best := -1
		for id in owner:
			if owner[id] == li and (best < 0 or graph.get_point_position(id).distance_squared_to(q) < graph.get_point_position(best).distance_squared_to(q)):
				best = id
		return best

	func _ring_near(q: Vector2) -> int:
		var best: int = ring_ids[0]
		for id in ring_ids:
			if graph.get_point_position(id).distance_squared_to(q) < graph.get_point_position(best).distance_squared_to(q):
				best = id
		return best

	## The walk from island point a to b over the graph (a and b at its ends).
	func route(a: Vector2, b: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array([a])
		out.append_array(graph.get_point_path(graph.get_closest_point(a), graph.get_closest_point(b)))
		out.append(b)
		return out

	## The height of what's walked on at p: the long stair's treads, a building's floor, else `ground`.
	func y_at(p: Vector2, ground: float) -> float:
		if absf(p.x - StarterIsland.UP_X) < 1.6 and p.y > stair[0].z and p.y < stair[stair.size() - 1].z:
			for i in range(1, stair.size()):
				if p.y <= stair[i].z:
					return lerpf(stair[i - 1].y, stair[i].y, (p.y - stair[i - 1].z) / maxf(stair[i].z - stair[i - 1].z, 0.01))
		for f in floors:
			var l: Vector3 = f[0] * Vector3(p.x, 0, p.y)
			if absf(l.x) < f[1].x and absf(l.z) < f[1].y:
				return f[2]
		return ground


# --------------------------------------------------------------------------
# Spots: {"at", "face", "act", "kind", "lane" (island points from the spot out to the street), "y", "seat_y"}
# --------------------------------------------------------------------------
static func _named(list: Array, n: String) -> Node3D:
	for s in list:
		if s.name == n:
			return s
	push_error("BrinehollowLife: no %s in the town" % n)
	return null


static func _old_stall(isl: StarterIsland, i: int) -> Node3D:
	return [isl._stall_a, isl._stall_fish, isl._stall_cloth, isl._stall_pots][i]


static func _counter(isl: StarterIsland, n: String) -> Node3D:
	if n.begins_with("market"):
		return _old_stall(isl, int(n.substr(6)))
	if n.begins_with("Shop"):
		return _named(isl.town_spots["shops"], n)
	return _named(isl.town_spots["stalls"], n)


## Behind a counter, and the way round it to the front ("front": where a customer stands).
static func _at_counter(isl: StarterIsland, node: Node3D, front: bool) -> Dictionary:
	var kit := isl.kit
	var lp := func(v: Vector3) -> Vector2: return kit.local_point(node, v)
	var face := kit.marker_face(node, "Vendor")
	if node.has_node("Counter"):
		var v: Vector3 = (node.get_node("Vendor") as Node3D).position
		var c: Vector3 = (node.get_node("Customer") as Node3D).position
		var dx := float(node.get_node("Door").position.x)
		var out_x := v.x + signf(v.x - dx) * 1.45
		if front:
			return {"at": lp.call(c), "face": kit.marker_face(node, "Customer"), "act": "stand", "kind": "front", "lane": PackedVector2Array([lp.call(c + Vector3(0, 0, 1.2))])}
		return {"at": lp.call(v), "face": face, "act": "stand", "kind": "vendor",
			"lane": PackedVector2Array([lp.call(Vector3(out_x, 0, v.z)), lp.call(Vector3(out_x, 0, c.z)), lp.call(c + Vector3(0, 0, 1.2))])}
	if node.has_node("BarrowMesh"):
		var c := lp.call(Vector3(0.1, 0, 1.4)) as Vector2
		if front:
			return {"at": c, "face": kit.marker_face(node, "Customer"), "act": "stand", "kind": "front", "lane": PackedVector2Array([lp.call(Vector3(0.1, 0, 2.6))])}
		return {"at": kit.marker_point(node, "Vendor"), "face": face, "act": "stand", "kind": "vendor",
			"lane": PackedVector2Array([c, lp.call(Vector3(0.1, 0, 2.6))])}
	if node.has_node("RugMesh"):
		if front:
			return {"at": lp.call(Vector3(0, 0, 1.3)), "face": kit.marker_face(node, "Customer"), "act": "stand", "kind": "front",
				"lane": PackedVector2Array([lp.call(Vector3(0, 0, 2.5))])}
		return {"at": kit.marker_point(node, "Vendor"), "face": lp.call(Vector3(0, 0, -1.2)).direction_to(lp.call(Vector3(0, 0, 1.0))), "act": "sit", "kind": "vendor",
			"seat_y": 0.42, "lane": PackedVector2Array([lp.call(Vector3(1.5, 0, -1.2)), lp.call(Vector3(1.5, 0, 1.3)), lp.call(Vector3(0, 0, 2.5))])}
	# a market stall: its counter along local X, the vendor behind
	var w := 3.2
	if front:
		return {"at": lp.call(Vector3(0, 0, 1.6)), "face": -face, "act": "stand", "kind": "front", "lane": PackedVector2Array([lp.call(Vector3(0, 0, 2.6))])}
	return {"at": kit.marker_point(node, "Vendor"), "face": face, "act": "stand", "kind": "vendor",
		"lane": PackedVector2Array([lp.call(Vector3(w * 0.5 + 0.7, 0, -0.75)), lp.call(Vector3(w * 0.5 + 0.7, 0, 1.6)), lp.call(Vector3(0, 0, 2.6))])}


## The Salted Gull inside (local): five places along the bar, eight free seats at the tables, two by the fire.
const BAR := [Vector3(2.5, 0, -1.1), Vector3(3.2, 0, -1.1), Vector3(3.9, 0, -1.1), Vector3(4.6, 0, -1.1), Vector3(5.3, 0, -1.1)]
const SEATS := [[Vector3(-2.15, 0, 2.25), -1.0], [Vector3(-2.95, 0, 0.55), 1.0], [Vector3(-2.15, 0, 0.55), 1.0],
	[Vector3(2.05, 0, 2.85), -1.0], [Vector3(1.25, 0, 1.15), 1.0], [Vector3(2.05, 0, 1.15), 1.0],
	[Vector3(-2.65, 0, -3.25), 1.0], [Vector3(-2.55, 0, -1.55), -1.0]]
const FIRE := [Vector3(-4.3, 0, 1.5), Vector3(-4.3, 0, -1.3)]


static func _in_tavern(isl: StarterIsland, what: String, i: int) -> Dictionary:
	var kit := isl.kit
	var tav: Node3D = isl._tavern
	var lp := func(v: Vector3) -> Vector2: return kit.local_point(tav, v)
	var y := kit.marker_y(tav, "Barkeep")
	var lane := PackedVector2Array([lp.call(Vector3(-0.5, 0, 0.0)), lp.call(Vector3(-1.6, 0, 3.4)), kit.marker_point(tav, "Door")])
	var out := {"y": y, "kind": "tavern", "act": "talk"}
	match what:
		"bar":
			var b: Vector3 = BAR[i]
			out.merge({"at": lp.call(b), "face": lp.call(b).direction_to(lp.call(b - Vector3(0, 0, 1)))})
		"seat":
			var s: Array = SEATS[i]
			var v: Vector3 = s[0]
			out.merge({"at": lp.call(v), "face": lp.call(v).direction_to(lp.call(v + Vector3(0, 0, float(s[1])))), "act": "sit"})
		_:
			var f: Vector3 = FIRE[i]
			out.merge({"at": lp.call(f), "face": lp.call(f).direction_to(lp.call(Vector3(-5.4, 0, 0)))})
	out["lane"] = lane
	return out


## Seats on the plaza's benches (two a bench, facing the well), in order round it.
static func _bench_seats(isl: StarterIsland) -> Array:
	var out: Array = []
	for n in isl.find_children("*Bench*", "Node3D", true, false):
		var c: Vector2 = isl.kit.local_point(n, Vector3.ZERO)
		if c.distance_to(StarterIsland.VILLAGE) < 6.5:
			var along: Vector2 = isl.kit.local_point(n, Vector3.RIGHT) - c
			var face := c.direction_to(StarterIsland.VILLAGE)
			for s: float in [-0.45, 0.45]:
				out.append({"at": c + along * s, "face": face, "act": "sit", "kind": "plaza", "seat_y": 0.47, "lane": PackedVector2Array([c - face * 1.2])})
	return out


## Where `id` is ("vendor:Shop0", "front:market2", "bench:3", "plaza:7", "tavern:bar:1", "home:UpperHouse4", ...).
static func _spot(isl: StarterIsland, id: String, cache: Dictionary) -> Dictionary:
	var parts := id.split(":")
	var kit := isl.kit
	match parts[0]:
		"vendor", "front":
			return _at_counter(isl, _counter(isl, parts[1]), parts[0] == "front")
		"bench":
			if not cache.has("benches"):
				cache["benches"] = _bench_seats(isl)
			return cache["benches"][int(parts[1])]
		"plaza":
			# five knots of three round the well, between its benches and the ring
			var n := int(parts[1])
			var c := StarterIsland.VILLAGE + Vector2.from_angle(0.6 + (n / 3) * TAU / 5.0) * 7.6
			var at := c + Vector2.from_angle(n * 2.1) * 0.85
			return {"at": at, "face": at.direction_to(c), "act": "talk", "kind": "plaza", "lane": PackedVector2Array()}
		"tavern":
			return _in_tavern(isl, parts[1], int(parts[2]))
		"home":
			var h: Node3D = _named(isl.town_spots["houses"], parts[1])
			return {"at": kit.marker_point(h, "Door"), "face": kit.marker_face(h, "Door"), "act": "home", "kind": "home", "lane": PackedVector2Array()}
		"stair":
			# on a lane beside the stair's landing (off the flight)
			var q: Vector3 = isl.town_spots["stair"][1 + int(parts[1]) * 2]
			var at := Vector2(q.x + 3.4, q.z + 1.5)
			return {"at": at, "face": Vector2(0, -1), "act": "stand", "kind": "stair", "lane": PackedVector2Array()}
		"quay":
			if not cache.has("quay"):
				cache["quay"] = _quay_spots(isl)
			return cache["quay"][int(parts[1])]
		"drop":
			var d: Node3D = isl.get_node(parts[1])
			# beside the crates stacked by its door
			var at := kit.local_point(d, Vector3(-0.1, 0, 4.2))
			return {"at": at, "face": at.direction_to(kit.local_point(d, Vector3(1.0, 0, 4.2))), "act": "kneel", "kind": "drop", "lane": PackedVector2Array()}
	push_error("BrinehollowLife: no spot %s" % id)
	return {}


## Where the porters take up their loads on the quay: clear spots by the foot of the street.
static func _quay_spots(isl: StarterIsland) -> Array:
	var h: KitHarbour = isl.harbour
	var out: Array = []
	for s: float in [-6.0, 7.0, -10.0, 11.0, -3.0, 4.0]:
		for d: float in [9.0, 10.5, 12.0, 7.5]:
			var p := h.quay_pt(s, d)
			if not isl.kit.excluded(p, 0.7) and out.all(func(o): return o["at"].distance_to(p) > 2.5):
				out.append({"at": p, "face": h.quay_pt(s, d - 3.0) - p, "act": "kneel", "kind": "quay", "lane": PackedVector2Array()})
				break
	return out


# --------------------------------------------------------------------------
# The people
# --------------------------------------------------------------------------
const AMBIENT := {
	"day": ["Lovely morning for it.", "Mind the cobbles, they're slick by the quay.", "Busy, busy.", "Have you tried Ida's hardtack? Don't."],
	"evening": ["Is it that late already?", "Gus'll have the stew on.", "The lamps are lit. Must be time for a drink."],
	"night": ["Shouldn't you be in bed?", "Quiet tonight.", "Hear that? Just the sea."],
	"vendor": ["Fresh today!", "Best prices on the street!", "Come and look, no charge for looking!", "Two for one, while it lasts!"],
	"front": ["Hmm. Too dear.", "I'll take two. No, one.", "Is this the same as yesterday's?"],
	"tavern": ["Another round!", "Gus! Gus. Gus, the jug.", "Sing it again, Corin!", "To Brinehollow!"],
	"plaza": ["Did you hear about the Morrow's men?", "Lovely day by the well.", "Tilly's been at the bunting again."],
	"quay": ["Heave!", "Mind your back.", "Last one. Said that an hour ago."],
	"drop": ["There.", "That's the lot. For now.", "Odile wants a count. Odile can count."],
	"stair": ["Race you to the top!", "Bet you can't jump three!"],
}


static func _people(isl: StarterIsland, town: Town) -> void:
	var cache := {}
	for e in BrinehollowCast.townsfolk():
		var stays: Array = []
		for p in e["plan"]:
			var sp: Dictionary = _spot(isl, str(p[1]), cache)
			var st := {"h": float(p[0]), "kind": sp["kind"], "at": sp["at"], "face": (sp["face"] as Vector2).normalized(),
				"act": str(p[2]) if p.size() > 2 else str(sp["act"]), "lane": sp["lane"]}
			for k in ["y", "seat_y"]:
				if sp.has(k):
					st[k] = sp[k]
			if p.size() > 3:
				st["carry"] = p[3]
			stays.append(st)
		var walks: Array = []
		for k in range(stays.size()):
			var a: Dictionary = stays[k - 1]
			var b: Dictionary = stays[k]
			var w := PackedVector2Array([a["at"]])
			w.append_array(a["lane"])
			var back: PackedVector2Array = b["lane"].duplicate()
			back.reverse()
			w.append_array(town.route(w[w.size() - 1], back[0] if not back.is_empty() else b["at"]).slice(1))
			if not back.is_empty():
				w.append_array(back.slice(1))
				w.append(b["at"])
			walks.append(w)
		var cfg: Dictionary = e["cfg"]
		var f := Folk.new()
		f.setup(cfg)
		f.town = town
		f.follow(isl, stays, walks, AMBIENT)
		if e.get("carry", false):
			f.load_node = _sack()
			f.humanoid.torso.add_child(f.load_node)
		var first: Dictionary = stays[0]
		f.position = Vector3(first["at"].x, isl.hv(first["at"]), first["at"].y)
		isl.add_child(f)


## A sack on the left shoulder (the torso's space).
static func _sack() -> Node3D:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	mb.add_blob(PSXMat.lit("fabric", Color(0.78, 0.68, 0.5)), Transform3D(Basis(Vector3.BACK, 0.3), Vector3.ZERO), Vector3(0.36, 0.22, 0.24), rng, 0.12, 2, 6, 1.0)
	var mi := mb.to_instance("Load")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(-0.2, 0.62, 0.02)
	mi.visible = false
	return mi
